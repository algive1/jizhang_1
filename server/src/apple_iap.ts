import { createVerify, X509Certificate } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Store } from './store.js';
import { requireCondition as check } from './contract.js';

type User={id:string;username:string};
type Authenticate=(header:string|undefined)=>User;
type Json=Record<string,unknown>;

const clientTransaction=z.strictObject({
  productId:z.string().min(1).max(160),
  purchaseId:z.string().max(160).nullable().optional(),
  source:z.string().min(1).max(40),
  verificationData:z.string().min(10).max(200000),
  restored:z.boolean().default(false),
});

const products:Record<string,{plan:string;months:number}>={
  'haohaojizhang.membership.monthly':{plan:'monthly',months:1},
  'haohaojizhang.membership.quarterly':{plan:'quarterly',months:3},
  'haohaojizhang.membership.yearly':{plan:'yearly',months:12},
};

function ensureSchema(store:Store){
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS apple_transactions(
      transaction_id TEXT PRIMARY KEY,
      original_transaction_id TEXT NOT NULL,
      user_id TEXT NOT NULL REFERENCES users(id),
      product_id TEXT NOT NULL,
      environment TEXT NOT NULL,
      purchased_at INTEGER,
      expires_at INTEGER,
      revoked_at INTEGER,
      raw_jws TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_apple_transactions_original
      ON apple_transactions(original_transaction_id);
    CREATE TABLE IF NOT EXISTS apple_notifications(
      notification_uuid TEXT PRIMARY KEY,
      notification_type TEXT NOT NULL,
      subtype TEXT,
      signed_at INTEGER,
      original_transaction_id TEXT,
      received_at INTEGER NOT NULL
    );
  `);
  const columns=store.db.prepare('PRAGMA table_info(apple_notifications)').all() as Array<{name:string}>;
  if(!columns.some(column=>column.name==='signed_at')) store.db.exec('ALTER TABLE apple_notifications ADD COLUMN signed_at INTEGER');
  if(!columns.some(column=>column.name==='original_transaction_id')) store.db.exec('ALTER TABLE apple_notifications ADD COLUMN original_transaction_id TEXT');
}

function b64url(value:string){return Buffer.from(value.replace(/-/g,'+').replace(/_/g,'/').padEnd(Math.ceil(value.length/4)*4,'='),'base64');}

function appleRoots():X509Certificate[]{
  const paths=(process.env.APPLE_ROOT_CA_PATHS??'').split(',').map(v=>v.trim()).filter(Boolean);
  return paths.filter(existsSync).map(path=>new X509Certificate(readFileSync(path)));
}

function verifyAppleJws(jws:string):Json{
  const parts=jws.split('.');
  check(parts.length===3,'Apple 签名数据格式无效',400);
  const header=JSON.parse(b64url(parts[0]).toString('utf8')) as Json;
  const chain=header.x5c;
  check(header.alg==='ES256','Apple JWS 算法无效',400);
  check(Array.isArray(chain)&&chain.length>=2,'Apple 签名证书链缺失',400);
  const certs=(chain as unknown[]).map(value=>new X509Certificate(Buffer.from(String(value),'base64')));
  const leaf=certs[0]!;
  const now=Date.now();
  check(Date.parse(leaf.validFrom)<=now&&Date.parse(leaf.validTo)>=now,'Apple 签名证书已过期',400);
  for(let i=0;i<certs.length-1;i++){
    const child=certs[i]!;
    const issuer=certs[i+1]!;
    check(child.checkIssued(issuer)&&child.verify(issuer.publicKey),'Apple 证书链校验失败',400);
  }
  const roots=appleRoots();
  check(roots.length>0,'服务端未配置 Apple Root CA',503);
  const top=certs[certs.length-1]!;
  check(roots.some(root=>(top.fingerprint256===root.fingerprint256)||(top.checkIssued(root)&&top.verify(root.publicKey))),'Apple 根证书不受信任',400);
  const verifier=createVerify('SHA256');
  verifier.update(`${parts[0]!}.${parts[1]!}`);
  verifier.end();
  check(verifier.verify(leaf.publicKey,b64url(parts[2]!)),'Apple 签名校验失败',400);
  const payload=JSON.parse(b64url(parts[1]!).toString('utf8')) as Json;
  const expectedBundle=process.env.APPLE_BUNDLE_ID?.trim();
  if(expectedBundle&&payload.bundleId!==undefined) check(String(payload.bundleId)===expectedBundle,'Apple Bundle ID 不匹配',400);
  return payload;
}

function transactionPayload(signedTransactionInfo:string):Json{
  return verifyAppleJws(signedTransactionInfo);
}

function bindTransaction(store:Store,userId:string,payload:Json,raw:string){
  const transactionId=String(payload.transactionId??'');
  const original=String(payload.originalTransactionId??transactionId);
  const productId=String(payload.productId??'');
  check(transactionId&&original&&products[productId],'Apple 交易商品无效',400);
  const existing=store.db.prepare('SELECT user_id FROM apple_transactions WHERE original_transaction_id=? LIMIT 1').get(original) as {user_id:string}|undefined;
  check(!existing||existing.user_id===userId,'该 App Store 订阅已绑定其他账号',409);
  const expiresAt=Number(payload.expiresDate??0);
  const purchasedAt=Number(payload.purchaseDate??0);
  const revokedAt=Number(payload.revocationDate??0);
  const environment=String(payload.environment??'Unknown');
  store.db.prepare(`
    INSERT INTO apple_transactions(transaction_id,original_transaction_id,user_id,product_id,environment,purchased_at,expires_at,revoked_at,raw_jws,updated_at)
    VALUES(?,?,?,?,?,?,?,?,?,?)
    ON CONFLICT(transaction_id) DO UPDATE SET
      product_id=excluded.product_id,environment=excluded.environment,
      purchased_at=excluded.purchased_at,expires_at=excluded.expires_at,
      revoked_at=excluded.revoked_at,raw_jws=excluded.raw_jws,updated_at=excluded.updated_at
  `).run(transactionId,original,userId,productId,environment,
    purchasedAt?Math.floor(purchasedAt/1000):null,
    expiresAt?Math.floor(expiresAt/1000):null,
    revokedAt?Math.floor(revokedAt/1000):null,raw,store.now());

}

export function registerAppleIapRoutes(app:FastifyInstance,store:Store,authenticate:Authenticate){
  ensureSchema(store);
  app.post('/api/v1/membership/apple/transactions',async(req)=>{
    const user=authenticate(req.headers.authorization);
    const body=clientTransaction.parse(req.body);
    check(body.source.toLowerCase().includes('app'),'仅接受 App Store 验证数据',400);
    const payload=transactionPayload(body.verificationData);
    check(String(payload.productId??'')===body.productId,'Apple 商品与客户端不匹配',400);
    bindTransaction(store,user.id,payload,body.verificationData);
    return {ok:true};
  });
  app.post('/api/v1/payments/apple/notify',async(req)=>{
    const signedPayload=z.object({signedPayload:z.string().min(10).max(400000)}).parse(req.body).signedPayload;
    const envelope=verifyAppleJws(signedPayload);
    const uuid=String(envelope.notificationUUID??'');
    const type=String(envelope.notificationType??'UNKNOWN');
    if(uuid){
      const seen=store.db.prepare('SELECT 1 FROM apple_notifications WHERE notification_uuid=?').get(uuid);
      if(seen)return {ok:true};
      store.db.prepare('INSERT INTO apple_notifications(notification_uuid,notification_type,subtype,signed_at,original_transaction_id,received_at) VALUES(?,?,?,?,NULL,?)').run(uuid,type,String(envelope.subtype??''),Number(envelope.signedDate??0)?Math.floor(Number(envelope.signedDate)/1000):null,store.now());
    }
    if(type==='TEST') return {ok:true};
    const data=(envelope.data??{}) as Json;
    const expectedBundle=process.env.APPLE_BUNDLE_ID?.trim();
    if(expectedBundle&&data.bundleId!==undefined) check(String(data.bundleId)===expectedBundle,'Apple 通知 Bundle ID 不匹配',400);
    const expectedEnvironment=process.env.APPLE_ENVIRONMENT?.trim();
    if(expectedEnvironment&&data.environment!==undefined) check(String(data.environment)===expectedEnvironment,'Apple 通知环境不匹配',400);
    const signed=String(data.signedTransactionInfo??'');
    if(signed){
      const payload=transactionPayload(signed);
      const original=String(payload.originalTransactionId??payload.transactionId??'');
      const signedAt=Number(envelope.signedDate??0)?Math.floor(Number(envelope.signedDate)/1000):store.now();
      const latest=store.db.prepare('SELECT MAX(signed_at) AS signed_at FROM apple_notifications WHERE original_transaction_id=?').get(original) as {signed_at:number|null}|undefined;
      if(latest?.signed_at&&latest.signed_at>signedAt) return {ok:true};
      if(uuid) store.db.prepare('UPDATE apple_notifications SET original_transaction_id=? WHERE notification_uuid=?').run(original,uuid);
      const owner=store.db.prepare('SELECT user_id FROM apple_transactions WHERE original_transaction_id=? LIMIT 1').get(original) as {user_id:string}|undefined;
      if(owner) bindTransaction(store,owner.user_id,payload,signed);
    }
    return {ok:true};
  });
}
