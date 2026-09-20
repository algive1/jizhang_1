import { randomBytes,createHash,timingSafeEqual } from 'node:crypto';
import type { Store } from './store.js';
import { ApiError } from './contract.js';
import type { AdminPrincipal } from './admin_auth.js';

export function ensureSensitiveAccessSchema(store:Store){store.db.exec(`
 CREATE TABLE IF NOT EXISTS admin_sensitive_grants(
 token_hash TEXT PRIMARY KEY,admin_id TEXT NOT NULL,admin_role TEXT NOT NULL,reason TEXT NOT NULL,expires_at INTEGER NOT NULL,created_at INTEGER NOT NULL
 );
 CREATE INDEX IF NOT EXISTS idx_admin_sensitive_grants_expiry ON admin_sensitive_grants(expires_at);
`)}
const hash=(v:string)=>createHash('sha256').update(v).digest('hex');
export function issueSensitiveGrant(store:Store,p:AdminPrincipal,reason:string){
 if(p.role!=='super_admin')throw new ApiError(403,'仅超级管理员可以申请敏感数据访问');
 ensureSensitiveAccessSchema(store);store.db.prepare('DELETE FROM admin_sensitive_grants WHERE expires_at<=?').run(store.now());
 const token=randomBytes(32).toString('base64url'),expiresAt=store.now()+300;
 store.db.prepare('INSERT INTO admin_sensitive_grants VALUES(?,?,?,?,?,?)').run(hash(token),p.id,p.role,reason,expiresAt,store.now());
 return {token,expiresAt};
}
export function requireSensitiveGrant(store:Store,p:AdminPrincipal,token:string|string[]|undefined){
 if(p.role!=='super_admin')throw new ApiError(403,'仅超级管理员可以查看敏感财务数据');
 const supplied=(Array.isArray(token)?token[0]:token)??'';if(!supplied)throw new ApiError(401,'需要临时敏感数据访问授权');
 ensureSensitiveAccessSchema(store);const row=store.db.prepare('SELECT token_hash,reason,expires_at FROM admin_sensitive_grants WHERE admin_id=? AND expires_at>? ORDER BY created_at DESC LIMIT 20').all(p.id,store.now()) as Array<{token_hash:string;reason:string;expires_at:number}>;
 const digest=hash(supplied),matched=row.find(x=>timingSafeEqual(Buffer.from(x.token_hash),Buffer.from(digest)));if(!matched)throw new ApiError(401,'敏感数据访问授权无效或已过期');
 return matched;
}
