import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Store } from './store.js';
import { auditAdmin, requireAdminPrincipal } from './admin_auth.js';

export function registerAdminUserRoutes(app:FastifyInstance,store:Store){
  app.get('/api/v1/admin/users',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'users.read');
    const q=z.object({q:z.string().trim().max(80).default(''),limit:z.coerce.number().int().min(1).max(200).default(50),offset:z.coerce.number().int().min(0).max(1000000).default(0)}).parse(request.query);
    const pattern=`%${q.q}%`;
    const users=store.db.prepare(`SELECT u.id,u.username,u.display_name AS displayName,u.created_at AS createdAt,
      (SELECT COUNT(*) FROM sessions s WHERE s.user_id=u.id AND s.expires_at>?) AS activeSessions,
      (SELECT COUNT(*) FROM members m WHERE m.user_id=u.id) AS bookCount
      FROM users u WHERE (?='' OR u.username LIKE ? OR COALESCE(u.display_name,'') LIKE ?)
      ORDER BY u.created_at DESC LIMIT ? OFFSET ?`).all(store.now(),q.q,pattern,pattern,q.limit,q.offset);
    auditAdmin(store,principal,'user_list',{permission:'users.read',details:{query:Boolean(q.q),limit:q.limit,offset:q.offset}});
    return {users};
  });

  app.get('/api/v1/admin/users/:userId/diagnostics',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'users.read');
    const {userId}=z.object({userId:z.string().min(1).max(100)}).parse(request.params);
    const user=store.db.prepare('SELECT id,username,display_name AS displayName,created_at AS createdAt FROM users WHERE id=?').get(userId);
    if(!user) return {user:null};
    const scalar=(sql:string,...args:unknown[])=>Number((store.db.prepare(sql).get(...args) as {n:number}|undefined)?.n??0);
    auditAdmin(store,principal,'user_diagnostics',{permission:'users.read',targetType:'user',targetId:userId});
    return {user,metrics:{
      activeSessions:scalar('SELECT COUNT(*) n FROM sessions WHERE user_id=? AND expires_at>?',userId,store.now()),
      books:scalar('SELECT COUNT(*) n FROM members WHERE user_id=?',userId),
      diagnostics:scalar('SELECT COUNT(*) n FROM diagnostic_events WHERE user_id=?',userId),
      supportTickets:scalar('SELECT COUNT(*) n FROM support_tickets WHERE user_id=?',userId),
      pushDevices:scalar('SELECT COUNT(*) n FROM push_devices WHERE user_id=?',userId),
    }};
  });

  app.get('/api/v1/admin/users/:userId/sensitive-ledger',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'users.sensitive.read');
    const {userId}=z.object({userId:z.string().min(1).max(100)}).parse(request.params);
    const {reason}=z.object({reason:z.string().trim().min(8).max(500)}).parse(request.query);
    const books=store.db.prepare('SELECT b.id,b.name,b.type,m.role FROM members m JOIN books b ON b.id=m.book_id WHERE m.user_id=? ORDER BY b.updated_at DESC').all(userId) as Array<{id:string;name:string;type:string;role:string}>;
    const transactions=[];
    for(const book of books){
      const rows=store.db.prepare(`SELECT entity_id AS id,data_json AS dataJson,version FROM entities
        WHERE book_id=? AND kind='transactions' AND deleted=0 ORDER BY version DESC LIMIT 500`).all(book.id) as any[];
      transactions.push({book,...{transactions:rows.map(r=>({id:r.id,version:r.version,data:JSON.parse(r.dataJson)}))}});
    }
    auditAdmin(store,principal,'sensitive_ledger_read',{permission:'users.sensitive.read',targetType:'user',targetId:userId,reason,details:{bookCount:books.length}});
    return {userId,books:transactions};
  });

  app.get('/api/v1/admin/users/:userId/sensitive-investments',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'investments.sensitive.read');
    const {userId}=z.object({userId:z.string().min(1).max(100)}).parse(request.params);
    const {reason}=z.object({reason:z.string().trim().min(8).max(500)}).parse(request.query);
    const books=store.db.prepare('SELECT book_id FROM members WHERE user_id=?').all(userId) as Array<{book_id:string}>;
    const result=[];
    for(const {book_id} of books){
      const assets=store.db.prepare(`SELECT kind,entity_id AS id,data_json AS dataJson,version FROM entities
        WHERE book_id=? AND kind IN ('investment_accounts','investment_holdings','investment_transactions') AND deleted=0 ORDER BY kind,version DESC LIMIT 1000`).all(book_id) as any[];
      if(assets.length) result.push({bookId:book_id,items:assets.map(r=>({kind:r.kind,id:r.id,version:r.version,data:JSON.parse(r.dataJson)}))});
    }
    auditAdmin(store,principal,'sensitive_investment_read',{permission:'investments.sensitive.read',targetType:'user',targetId:userId,reason});
    return {userId,books:result};
  });
}
