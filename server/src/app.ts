import { registerAssistantPolicy } from './assistant_policy.js';
import Fastify from 'fastify';
import { registerMembershipCatalog } from './membership_catalog.js';
import { registerPaymentRoutes } from './payment.js';
import { registerDiagnosticsRoutes } from './diagnostics.js';
import rateLimit from '@fastify/rate-limit';
import rawBody from 'fastify-raw-body';
import { createHash, randomBytes, randomUUID, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { z } from 'zod';
import { ApiError, identifier, kinds, mutationSchema, nullableId, requireCondition as check } from './contract.js';
import { Store } from './store.js';
import type { AssistantModelProvider } from './assistant_ai.js';
const scrypt = promisify(scryptCallback);
const credentials = z.strictObject({ username: z.string().trim().toLowerCase().regex(/^[a-z0-9_]{3,40}$/), password: z.string().min(10).max(128) });
const hashToken = (token:string) => createHash('sha256').update(token).digest('hex');
async function passwordHash(password:string, salt=randomBytes(16).toString('hex')) {
  const digest = await scrypt(password,salt,64) as Buffer;
  return `${salt}:${digest.toString('hex')}`;
}
export async function createApp(path:string, modelProvider?: AssistantModelProvider) {
  const app = Fastify({ logger:false, bodyLimit:16*1024*1024 });
  const store = new Store(path);
  await app.register(rawBody, { field: 'rawBody', global: false, encoding: 'utf8', runFirst: true });
  app.addContentTypeParser('application/x-www-form-urlencoded', { parseAs: 'string' }, (_request, body, done) => done(null, body));
  await app.register(rateLimit,{max:300,timeWindow:'1 minute'});
  app.addHook('onClose',async()=>{store.db.close();});
  app.setErrorHandler((error,_req,reply)=>{
    if(error instanceof z.ZodError) return reply.code(400).send({message:'请求字段无效',issues:error.issues.map(i=>({path:i.path,message:i.message}))});
    if(error instanceof ApiError) return reply.code(error.statusCode).send({message:error.message,details:error.details});
    const e=error as {statusCode?:number};
    if(!e.statusCode || e.statusCode>=500) console.error(error);
    return reply.code(e.statusCode??500).send({message:e.statusCode===429?'请求过于频繁，请稍后重试':'服务端未能处理请求'});
  });
  const authenticate = (header:string|undefined) => {
    check(header?.startsWith('Bearer '),'请先登录',401);
    const row=store.db.prepare('SELECT u.id,u.username FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at>?').get(hashToken(header!.slice(7)),store.now()) as {id:string;username:string}|undefined;
    check(row,'登录已失效，请重新登录',401);return row;
  };
  const session=(user:{id:string;username:string})=>{
    const token=randomBytes(32).toString('base64url');
    const expiresAt=store.now()+30*86400;
    store.db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(hashToken(token),user.id,expiresAt);
    return {user,token,expiresAt};
  };
  registerMembershipCatalog(app,store);
  registerPaymentRoutes(app,store,authenticate);
  registerDiagnosticsRoutes(app,store,authenticate);
  registerAssistantPolicy(app,store,authenticate,modelProvider);
  app.get('/health',async()=>({status:'ok',schemaVersion:1}));
  app.post('/api/v1/auth/register',{config:{rateLimit:{max:10,timeWindow:'1 minute'}}},async(req,reply)=>{
    const {username,password}=credentials.parse(req.body);
    check(!store.db.prepare('SELECT 1 FROM users WHERE username=?').get(username),'用户名已被使用',409);
    const password_hash=await passwordHash(password);
    // Hashing is asynchronous: recheck inside the insertion transaction.
    const user=store.db.transaction(()=>{
      check(!store.db.prepare('SELECT 1 FROM users WHERE username=?').get(username),'用户名已被使用',409);
      const user={id:randomUUID(),username};
      store.db.prepare('INSERT INTO users VALUES(?,?,?,?)').run(user.id,username,password_hash,store.now());return user;
    })();
    return reply.code(201).send(session(user));
  });
  app.post('/api/v1/auth/login',{config:{rateLimit:{max:15,timeWindow:'1 minute'}}},async(req)=>{
    const {username,password}=credentials.parse(req.body);
    const user=store.db.prepare('SELECT * FROM users WHERE username=?').get(username) as {id:string;username:string;password_hash:string}|undefined;
    const salt=user?.password_hash.split(':')[0]??'00000000000000000000000000000000';
    const actual=await passwordHash(password,salt);
    check(user && actual.length===user.password_hash.length && timingSafeEqual(Buffer.from(actual),Buffer.from(user.password_hash)),'用户名或密码错误',401);
    return session({id:user.id,username:user.username});
  });
  app.get('/api/v1/auth/me',async(req)=>({user:authenticate(req.headers.authorization)}));
  app.post('/api/v1/auth/logout',async(req)=>{
    authenticate(req.headers.authorization);
    store.db.prepare('DELETE FROM sessions WHERE token_hash=?').run(hashToken(req.headers.authorization!.slice(7)));
    return {ok:true};
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
    return {members:store.db.prepare('SELECT u.id AS user_id,u.username,m.role,m.joined_at FROM members m JOIN users u ON u.id=m.user_id WHERE m.book_id=? ORDER BY u.username').all(id)};
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
