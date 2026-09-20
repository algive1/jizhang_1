import { registerAssistantPolicy } from './assistant_policy.js';
import { registerInsightRoutes } from './insights.js';
import Fastify from 'fastify';
import { registerMembershipCatalog } from './membership_catalog.js';
import { registerPaymentRoutes } from './payment.js';
import { registerAppleIapRoutes } from './apple_iap.js';
import { registerDiagnosticsRoutes } from './diagnostics.js';
import rateLimit from '@fastify/rate-limit';
import rawBody from 'fastify-raw-body';
import { createHash, randomBytes, randomUUID, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { z } from 'zod';
import { ApiError, identifier, kinds, mutationSchema, nullableId, requireCondition as check } from './contract.js';
import { Store } from './store.js';
import type { AssistantModelProvider } from './assistant_ai.js';
import { registerMarketDataRoutes, type ServerMarketDataProvider } from './market_data.js';
import { registerPersonalCloudRoutes } from './personal_cloud.js';
import { registerAppUpdateRoutes } from './app_update.js';
import { registerAnalyticsRoutes } from './analytics.js';
import { registerPushRoutes } from './push.js';
import { registerAdConfigRoutes } from './ads.js';
import { registerThemeCatalog } from './theme_catalog.js';
import { registerMessageCenterRoutes } from './message_center.js';
import { registerSupportRoutes } from './support.js';
import { registerAdminRoutes } from './admin.js';
import { registerOperationalRoutes } from './ops.js';
import { startPushWorker } from './push_delivery.js';
const scrypt = promisify(scryptCallback);
const usernameField = z.string().trim().toLowerCase().regex(/^[a-z0-9_]{3,40}$/);
const deviceNameField = z.string().trim().min(1).max(80).optional();
const credentials = z.strictObject({ username: usernameField, password: z.string().min(10).max(128), deviceName: deviceNameField });
const registration = z.strictObject({ username: usernameField, password: z.string().min(10).max(128), displayName: z.string().trim().min(1).max(24).optional(), deviceName: deviceNameField });
const changePasswordSchema = z.strictObject({ currentPassword: z.string().min(10).max(128), newPassword: z.string().min(10).max(128) });
const recoverySchema = z.strictObject({ username: usernameField, recoveryKey: z.string().min(20).max(200), newPassword: z.string().min(10).max(128), deviceName: deviceNameField });
const deleteAccountSchema = z.strictObject({
  password: z.string().min(10).max(128),
  confirmation: z.literal('DELETE'),
});
type AuthUser = { id:string; username:string; displayName:string|null };
const hashToken = (token:string) => createHash('sha256').update(token).digest('hex');
const hashRecoveryKey = (key:string) => createHash('sha256').update(key).digest('hex');
async function passwordHash(password:string, salt=randomBytes(16).toString('hex')) {
  const digest = await scrypt(password,salt,64) as Buffer;
  return `${salt}:${digest.toString('hex')}`;
}
async function passwordMatches(password:string, encoded:string|undefined) {
  if (!encoded) return false;
  const salt=encoded.split(':')[0]??'00000000000000000000000000000000';
  const actual=await passwordHash(password,salt);
  return actual.length===encoded.length && timingSafeEqual(Buffer.from(actual),Buffer.from(encoded));
}
export async function createApp(
  path:string,
  modelProvider?: AssistantModelProvider,
  marketProvider?: ServerMarketDataProvider,
) {
  const app = Fastify({ logger:false, bodyLimit:16*1024*1024 });
  const store = new Store(path);
  let stopPushWorker = () => {};
  await app.register(rawBody, { field: 'rawBody', global: false, encoding: 'utf8', runFirst: true });
  app.addContentTypeParser('application/x-www-form-urlencoded', { parseAs: 'string' }, (_request, body, done) => done(null, body));
  await app.register(rateLimit,{max:300,timeWindow:'1 minute'});
  app.addHook('onClose',async()=>{stopPushWorker();store.db.close();});
  app.setErrorHandler((error,_req,reply)=>{
    if(error instanceof z.ZodError) return reply.code(400).send({message:'请求字段无效',issues:error.issues.map(i=>({path:i.path,message:i.message}))});
    if(error instanceof ApiError) return reply.code(error.statusCode).send({message:error.message,details:error.details});
    const e=error as {statusCode?:number};
    if(!e.statusCode || e.statusCode>=500) console.error(error);
    return reply.code(e.statusCode??500).send({message:e.statusCode===429?'请求过于频繁，请稍后重试':'服务端未能处理请求'});
  });
  const authenticate = (header:string|undefined) => {
    check(header?.startsWith('Bearer '),'请先登录',401);
    const row=store.db.prepare('SELECT u.id,u.username,u.display_name AS displayName FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at>?').get(hashToken(header!.slice(7)),store.now()) as AuthUser|undefined;
    check(row,'登录已失效，请重新登录',401);return row;
  };
  const session=(user:AuthUser,deviceName?:string)=>{
    const token=randomBytes(32).toString('base64url');
    const tokenHash=hashToken(token);
    const expiresAt=store.now()+30*86400;
    const sessionId=randomUUID();
    const now=store.now();
    store.db.prepare(
      'INSERT INTO sessions(token_hash,user_id,expires_at,session_id,device_name,created_at,last_seen_at) VALUES(?,?,?,?,?,?,?)'
    ).run(tokenHash,user.id,expiresAt,sessionId,deviceName??'当前设备',now,now);
    return {user,token,expiresAt};
  };
  registerAppUpdateRoutes(app);
  registerAdConfigRoutes(app);
  registerAnalyticsRoutes(app,store);
  registerMembershipCatalog(app,store);
  registerThemeCatalog(app,store);
  registerPaymentRoutes(app,store,authenticate);
  registerAppleIapRoutes(app,store,authenticate);
  registerPersonalCloudRoutes(app,store,authenticate);
  registerDiagnosticsRoutes(app,store,authenticate);
  registerPushRoutes(app,store,authenticate);
  registerMessageCenterRoutes(app,store,authenticate);
  registerSupportRoutes(app,store,authenticate);
  registerAdminRoutes(app,store);
  registerOperationalRoutes(app,store);
  registerMarketDataRoutes(app, marketProvider);
  registerAssistantPolicy(app,store,authenticate,modelProvider);
  registerInsightRoutes(app,store,authenticate);
  stopPushWorker = startPushWorker(store);
  app.post('/api/v1/auth/register',{config:{rateLimit:{max:10,timeWindow:'1 minute'}}},async(req,reply)=>{
    const {username,password,displayName,deviceName}=registration.parse(req.body);
    check(!store.db.prepare('SELECT 1 FROM users WHERE username=?').get(username),'用户名已被使用',409);
    const password_hash=await passwordHash(password);
    // Hashing is asynchronous: recheck inside the insertion transaction.
    const user=store.db.transaction(()=>{
      check(!store.db.prepare('SELECT 1 FROM users WHERE username=?').get(username),'用户名已被使用',409);
      const user:AuthUser={id:randomUUID(),username,displayName:displayName ?? null};
      store.db.prepare('INSERT INTO users(id,username,password_hash,created_at,display_name) VALUES(?,?,?,?,?)').run(user.id,username,password_hash,store.now(),user.displayName);return user;
    })();
    return reply.code(201).send(session(user,deviceName));
  });
  app.post('/api/v1/auth/login',{config:{rateLimit:{max:15,timeWindow:'1 minute'}}},async(req)=>{
    const {username,password,deviceName}=credentials.parse(req.body);
    const user=store.db.prepare('SELECT id,username,password_hash,display_name AS displayName FROM users WHERE username=?').get(username) as (AuthUser & {password_hash:string})|undefined;
    check(user && await passwordMatches(password,user.password_hash),'用户名或密码错误',401);
    return session({id:user.id,username:user.username,displayName:user.displayName},deviceName);
  });
  app.get('/api/v1/auth/me',async(req)=>({user:authenticate(req.headers.authorization)}));
  app.post('/api/v1/auth/logout',async(req)=>{
    authenticate(req.headers.authorization);
    store.db.prepare('DELETE FROM sessions WHERE token_hash=?').run(hashToken(req.headers.authorization!.slice(7)));
    return {ok:true};
  });
  app.patch('/api/v1/account/profile',async(req)=>{
    const user=authenticate(req.headers.authorization);
    const {displayName}=z.strictObject({displayName:z.string().trim().min(1).max(24)}).parse(req.body);
    store.db.prepare('UPDATE users SET display_name=? WHERE id=?').run(displayName,user.id);
    return {user:{...user,displayName}};
  });
  app.post('/api/v1/auth/change-password',async(req)=>{
    const user=authenticate(req.headers.authorization);
    const body=changePasswordSchema.parse(req.body);
    const row=store.db.prepare('SELECT password_hash FROM users WHERE id=?').get(user.id) as {password_hash:string}|undefined;
    check(row && await passwordMatches(body.currentPassword,row.password_hash),'当前密码错误',401);
    check(body.currentPassword!==body.newPassword,'新密码不能与当前密码相同',400);
    const next=await passwordHash(body.newPassword);
    const currentHash=hashToken(req.headers.authorization!.slice(7));
    store.db.transaction(()=>{
      store.db.prepare('UPDATE users SET password_hash=?,password_changed_at=? WHERE id=?').run(next,store.now(),user.id);
      store.db.prepare('DELETE FROM sessions WHERE user_id=? AND token_hash<>?').run(user.id,currentHash);
    })();
    return {ok:true};
  });
  app.post('/api/v1/auth/recovery-key/rotate',async(req)=>{
    const user=authenticate(req.headers.authorization);
    const recoveryKey=randomBytes(24).toString('base64url');
    store.db.prepare('UPDATE users SET recovery_key_hash=? WHERE id=?').run(hashRecoveryKey(recoveryKey),user.id);
    return {recoveryKey};
  });
  app.post('/api/v1/auth/recover',{config:{rateLimit:{max:8,timeWindow:'1 minute'}}},async(req)=>{
    const {username,recoveryKey,newPassword,deviceName}=recoverySchema.parse(req.body);
    const row=store.db.prepare('SELECT id,username,password_hash,display_name AS displayName,recovery_key_hash FROM users WHERE username=?').get(username) as (AuthUser & {password_hash:string;recovery_key_hash:string|null})|undefined;
    const provided=hashRecoveryKey(recoveryKey);
    check(row?.recovery_key_hash && timingSafeEqual(Buffer.from(provided),Buffer.from(row.recovery_key_hash)),'账号或恢复密钥无效',401);
    const nextPassword=await passwordHash(newPassword);
    const nextRecoveryKey=randomBytes(24).toString('base64url');
    store.db.transaction(()=>{
      store.db.prepare('UPDATE users SET password_hash=?,password_changed_at=?,recovery_key_hash=? WHERE id=?').run(nextPassword,store.now(),hashRecoveryKey(nextRecoveryKey),row!.id);
      store.db.prepare('DELETE FROM sessions WHERE user_id=?').run(row!.id);
    })();
    return {...session({id:row!.id,username:row!.username,displayName:row!.displayName},deviceName),recoveryKey:nextRecoveryKey};
  });
  app.get('/api/v1/auth/sessions',async(req)=>{
    const user=authenticate(req.headers.authorization);
    const currentHash=hashToken(req.headers.authorization!.slice(7));
    const rows=store.db.prepare('SELECT token_hash,session_id,device_name,created_at,last_seen_at,expires_at FROM sessions WHERE user_id=? ORDER BY created_at DESC').all(user.id) as Array<{token_hash:string;session_id:string;device_name:string|null;created_at:number|null;last_seen_at:number|null;expires_at:number}>;
    return {sessions:rows.map(row=>({
      id:row.session_id,
      deviceName:row.device_name??'设备',
      createdAt:row.created_at,
      lastSeenAt:row.last_seen_at,
      expiresAt:row.expires_at,
      current:row.token_hash===currentHash,
    }))};
  });
  app.delete('/api/v1/auth/sessions/:sessionId',async(req)=>{
    const user=authenticate(req.headers.authorization);
    const {sessionId}=z.object({sessionId:z.string().min(1).max(100)}).parse(req.params);
    const currentHash=hashToken(req.headers.authorization!.slice(7));
    const target=store.db.prepare('SELECT token_hash FROM sessions WHERE session_id=? AND user_id=?').get(sessionId,user.id) as {token_hash:string}|undefined;
    check(target,'登录设备不存在',404);
    store.db.prepare('DELETE FROM sessions WHERE session_id=? AND user_id=?').run(sessionId,user.id);
    return {ok:true,current:target.token_hash===currentHash};
  });
  app.post('/api/v1/auth/logout-all',async(req)=>{
    const user=authenticate(req.headers.authorization);
    store.db.prepare('DELETE FROM sessions WHERE user_id=?').run(user.id);
    return {ok:true};
  });
  app.delete('/api/v1/account',async(req)=>{
    const user=authenticate(req.headers.authorization);
    const body=deleteAccountSchema.parse(req.body);
    const row=store.db.prepare(
      'SELECT password_hash FROM users WHERE id=?'
    ).get(user.id) as {password_hash:string}|undefined;
    check(row && await passwordMatches(body.password,row.password_hash),'密码错误',401);
    const activeOwned=(store.db.prepare(
      'SELECT COUNT(*) AS n FROM books WHERE owner_user_id=? AND is_archived=0'
    ).get(user.id) as {n:number}).n;
    check(
      activeOwned===0,
      '请先归档或处理你创建的共享账本，再注销账号',
      409,
    );
    const anonymousUsername =
      'deleted_' + createHash('sha256').update(user.id).digest('hex').slice(0,30);
    store.db.transaction(()=>{
      // Delete private cloud content and direct personal telemetry first.
      store.db.prepare('DELETE FROM cloud_datasets WHERE user_id=?').run(user.id);
      store.db.prepare('DELETE FROM insight_feedback WHERE user_id=?').run(user.id);
      store.db.prepare('DELETE FROM insight_profiles WHERE user_id=?').run(user.id);
      store.db.prepare('DELETE FROM diagnostic_events WHERE user_id=?').run(user.id);
      store.db.prepare('DELETE FROM push_outbox WHERE user_id=?').run(user.id);
      store.db.prepare('DELETE FROM push_devices WHERE user_id=?').run(user.id);
      store.db.prepare('DELETE FROM announcement_reads WHERE user_id=?').run(user.id);
      store.db.prepare('DELETE FROM support_tickets WHERE user_id=?').run(user.id);
      // Leaving books owned by other people must not erase their shared data.
      store.db.prepare("DELETE FROM members WHERE user_id=? AND role<>'owner'").run(user.id);
      store.db.prepare(
        "UPDATE invitations SET status='revoked' WHERE invited_by=? AND status='pending'"
      ).run(user.id);
      store.db.prepare('DELETE FROM sessions WHERE user_id=?').run(user.id);
      // Shared-ledger/payment audit rows retain only the opaque user id. The
      // account row is irreversibly anonymised so FK-backed audit history stays
      // valid without retaining username, display name, recovery key or login.
      store.db.prepare(
        'UPDATE users SET username=?,display_name=NULL,recovery_key_hash=NULL,'
          + 'password_hash=?,password_changed_at=? WHERE id=?'
      ).run(
        anonymousUsername,
        'deleted:' + randomBytes(64).toString('hex'),
        store.now(),
        user.id,
      );
    })();
    return {
      ok:true,
      deleted:true,
      retainedSharedAuditIdentity:user.id,
    };
  });
  app.get('/api/v1/books',async(req)=>({books:store.list(authenticate(req.headers.authorization).id)}));
  app.post('/api/v1/books',async(req)=>{
    const user=authenticate(req.headers.authorization);
    const body=z.strictObject({id:identifier,name:z.string().trim().min(1).max(40),type:z.enum(['family','enterprise']),asset_source_book_id:nullableId,entities:z.array(z.strictObject({kind:z.enum(kinds),id:identifier,data:z.record(z.string(),z.unknown())})).max(100000)}).parse(req.body);
    return store.create(user.id,body.id,body.name,body.type,body.entities,body.asset_source_book_id ?? null);
  });
  const bookId=(params:unknown)=>z.object({id:identifier}).parse(params).id;
  app.get('/api/v1/books/:id/snapshot',async(req)=>store.snapshot(bookId(req.params),authenticate(req.headers.authorization).id));
  app.get('/api/v1/books/:id/changes',async(req)=>{
    const {cursor}=z.object({cursor:z.coerce.number().int().nonnegative().default(0)}).parse(req.query);
    return store.changes(bookId(req.params),authenticate(req.headers.authorization).id,cursor);
  });
  app.post('/api/v1/books/:id/mutations',async(req)=>{
    const user=authenticate(req.headers.authorization);const {operations}=z.strictObject({operations:z.array(mutationSchema).min(1).max(2000)}).parse(req.body);
    return store.mutate(bookId(req.params),user.id,operations);
  });
  app.get('/api/v1/books/:id/members',async(req)=>{
    const id=bookId(req.params);store.role(id,authenticate(req.headers.authorization).id);
    return {members:store.db.prepare('SELECT u.id AS user_id,u.username,u.display_name,m.role,m.joined_at FROM members m JOIN users u ON u.id=m.user_id WHERE m.book_id=? ORDER BY COALESCE(NULLIF(TRIM(u.display_name),\'\'),u.username)').all(id)};
  });
  app.patch('/api/v1/books/:id/members/:userId',async(req)=>{
    const p=z.object({id:identifier,userId:identifier}).parse(req.params);
    const {role}=z.strictObject({role:z.enum(['admin','member'])}).parse(req.body);
    return store.memberChange(p.id,authenticate(req.headers.authorization).id,p.userId,role);
  });
  app.delete('/api/v1/books/:id/members/:userId',async(req)=>{
    const p=z.object({id:identifier,userId:identifier}).parse(req.params);
    return store.memberChange(p.id,authenticate(req.headers.authorization).id,p.userId);
  });
  app.post('/api/v1/books/:id/transfer-ownership',async(req)=>{
    const id=bookId(req.params);const user=authenticate(req.headers.authorization);
    const {userId}=z.strictObject({userId:identifier}).parse(req.body);
    return store.transferOwnership(id,user.id,userId);
  });
  app.post('/api/v1/books/:id/disband',async(req)=>{
    const id=bookId(req.params);const user=authenticate(req.headers.authorization);
    return store.disband(id,user.id);
  });
  app.post('/api/v1/books/:id/invitations',async(req)=>store.invite(bookId(req.params),authenticate(req.headers.authorization).id));
  app.get('/api/v1/books/:id/invitations',async(req)=>{
    const id=bookId(req.params);store.manager(id,authenticate(req.headers.authorization).id);
    return {invitations:store.db.prepare('SELECT * FROM invitations WHERE book_id=? ORDER BY expires_at DESC').all(id)};
  });
  app.delete('/api/v1/books/:id/invitations/:invitationId',async(req)=>{
    const p=z.object({id:identifier,invitationId:identifier}).parse(req.params);store.manager(p.id,authenticate(req.headers.authorization).id);
    const result=store.db.prepare("UPDATE invitations SET status='revoked' WHERE id=? AND book_id=? AND status='pending'").run(p.invitationId,p.id);
    check(result.changes===1,'邀请不存在或已被使用',409);return {ok:true};
  });
  app.post('/api/v1/invitations/accept',async(req)=>store.accept(z.strictObject({code:z.string().min(1).max(100)}).parse(req.body).code,authenticate(req.headers.authorization).id));
  app.get('/api/v1/books/:id/logs',async(req)=>{
    const id=bookId(req.params);store.role(id,authenticate(req.headers.authorization).id);
    return {logs:store.db.prepare('SELECT c.seq,c.kind,c.entity_id,c.actor_id,u.username,c.created_at,c.deleted FROM changes c JOIN users u ON u.id=c.actor_id WHERE c.book_id=? ORDER BY c.seq DESC LIMIT 100').all(id)};
  });
  return {app,store};
}
