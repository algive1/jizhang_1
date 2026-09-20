import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Store } from './store.js';
import { auditAdmin, requireAdminPrincipal } from './admin_auth.js';
import { queuePushForUser } from './push_delivery.js';

const audience=z.strictObject({
  membership:z.enum(['all','free','member']).default('all'),
  platforms:z.array(z.enum(['android','ios'])).max(2).default([]),
  minCreatedAt:z.number().int().nonnegative().nullable().default(null),
  maxCreatedAt:z.number().int().nonnegative().nullable().default(null),
});

export function ensureCampaignSchema(store:Store){
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS message_campaigns(
      id TEXT PRIMARY KEY,title TEXT NOT NULL,body TEXT NOT NULL,route TEXT,audience_json TEXT NOT NULL,
      status TEXT NOT NULL,scheduled_at INTEGER,created_by TEXT NOT NULL,created_at INTEGER NOT NULL,sent_at INTEGER,
      targeted_users INTEGER NOT NULL DEFAULT 0,queued_devices INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS idx_message_campaigns_status ON message_campaigns(status,scheduled_at,created_at DESC);
  `);
}
function targetUsers(store:Store,a:z.infer<typeof audience>){
  const now=store.now();
  const rows=store.db.prepare('SELECT id,created_at FROM users WHERE (? IS NULL OR created_at>=?) AND (? IS NULL OR created_at<=?) ORDER BY created_at DESC').all(a.minCreatedAt,a.minCreatedAt,a.maxCreatedAt,a.maxCreatedAt) as Array<{id:string;created_at:number}>;
  return rows.filter(u=>{
    if(a.membership==='all')return true;
    let member=false;
    try{member=Boolean(store.db.prepare('SELECT 1 FROM membership_subscriptions WHERE user_id=? AND expires_at>?').get(u.id,now))||Boolean(store.db.prepare('SELECT 1 FROM apple_transactions WHERE user_id=? AND revoked_at IS NULL AND expires_at>?').get(u.id,now))}catch{}
    return a.membership==='member'?member:!member;
  }).filter(u=>a.platforms.length===0||Boolean(store.db.prepare(`SELECT 1 FROM push_devices WHERE user_id=? AND platform IN (${a.platforms.map(()=>'?').join(',')}) LIMIT 1`).get(u.id,...a.platforms)));
}
export function dispatchDueCampaigns(store:Store,limit=20){
  ensureCampaignSchema(store);const now=store.now();
  const rows=store.db.prepare("SELECT * FROM message_campaigns WHERE status='scheduled' AND scheduled_at<=? ORDER BY scheduled_at LIMIT ?").all(now,limit) as any[];
  let sent=0;
  for(const row of rows){
    const users=targetUsers(store,JSON.parse(row.audience_json));
    let queued=0;for(const user of users)queued+=queuePushForUser(store,user.id,{title:row.title,body:row.body,route:row.route});
    store.db.prepare("UPDATE message_campaigns SET status='sent',sent_at=?,targeted_users=?,queued_devices=? WHERE id=? AND status='scheduled'").run(now,users.length,queued,row.id);sent++;
  }return {campaigns:sent};
}
export function registerCampaignRoutes(app:FastifyInstance,store:Store){
  ensureCampaignSchema(store);
  app.post('/api/v1/admin/campaigns',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'messages.write');
    const body=z.strictObject({title:z.string().trim().min(2).max(80),body:z.string().trim().min(2).max(2000),route:z.string().trim().max(180).nullable().default(null),audience:audience.default({membership:'all',platforms:[],minCreatedAt:null,maxCreatedAt:null}),scheduledAt:z.number().int().positive().nullable().default(null)}).parse(request.body);
    const id=randomUUID(),now=store.now(),scheduledAt=body.scheduledAt??now;
    store.db.prepare('INSERT INTO message_campaigns(id,title,body,route,audience_json,status,scheduled_at,created_by,created_at) VALUES(?,?,?,?,?,\'scheduled\',?,?,?)').run(id,body.title,body.body,body.route,JSON.stringify(body.audience),scheduledAt,principal.id,now);
    auditAdmin(store,principal,'campaign_create',{permission:'messages.write',targetType:'campaign',targetId:id,details:{scheduledAt}});
    if(scheduledAt<=now)dispatchDueCampaigns(store);
    return {id,status:scheduledAt<=now?'sent':'scheduled',scheduledAt};
  });
  app.get('/api/v1/admin/campaigns',async request=>{
    requireAdminPrincipal(request.headers['x-admin-token'],'dashboard.read');
    return {campaigns:store.db.prepare('SELECT id,title,route,audience_json AS audienceJson,status,scheduled_at AS scheduledAt,created_by AS createdBy,created_at AS createdAt,sent_at AS sentAt,targeted_users AS targetedUsers,queued_devices AS queuedDevices FROM message_campaigns ORDER BY created_at DESC LIMIT 200').all()};
  });
  app.post('/api/v1/admin/campaigns/dispatch',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'messages.write');const result=dispatchDueCampaigns(store);auditAdmin(store,principal,'campaign_dispatch',{permission:'messages.write',details:result});return result;
  });
}
