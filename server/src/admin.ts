import { createHash, timingSafeEqual } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { requireCondition as check } from './contract.js';
import {
  createAnnouncement,
  ensureMessageCenterSchema,
} from './message_center.js';
import { runRetention, retentionPolicy } from './maintenance.js';
import {
  dispatchPushOutbox,
  ensurePushDeliverySchema,
  queuePushForAllRegisteredUsers,
} from './push_delivery.js';
import { ensureSupportSchema } from './support.js';
import type { Store } from './store.js';

function digest(value: string) {
  return createHash('sha256').update(value).digest();
}

function requireAdmin(header: string | string[] | undefined) {
  const configured = (process.env.ADMIN_TOKEN ?? '').trim();
  check(configured.length >= 24, '管理后台未启用', 404);
  const provided = (Array.isArray(header) ? header[0] : header) ?? '';
  check(timingSafeEqual(digest(configured), digest(provided)), '管理令牌无效', 401);
}

function ensureAdminSchema(store: Store) {
  ensureMessageCenterSchema(store);
  ensureSupportSchema(store);
  ensurePushDeliverySchema(store);
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS admin_audit_log(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      action TEXT NOT NULL,
      details_json TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_admin_audit_time
      ON admin_audit_log(created_at DESC);
  `);
}

function audit(store: Store, action: string, details: Record<string, unknown> = {}) {
  store.db.prepare(
    'INSERT INTO admin_audit_log(action,details_json,created_at) VALUES(?,?,?)',
  ).run(action, JSON.stringify(details), store.now());
}

const adminHtml = `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>好好记账管理后台</title>
<style>
body{font-family:system-ui,-apple-system,sans-serif;max-width:1040px;margin:0 auto;padding:28px;background:#f5f7ef;color:#182016}
h1{margin:0 0 20px}.card{background:white;border:1px solid #dfe6d7;border-radius:16px;padding:18px;margin:14px 0}
input,textarea,select,button{font:inherit;padding:10px;border:1px solid #ccd5c4;border-radius:10px}textarea{width:100%;min-height:100px;box-sizing:border-box}
button{background:#4d6b45;color:white;cursor:pointer}.row{display:flex;gap:10px;flex-wrap:wrap}.row>*{flex:1;min-width:180px}
pre{white-space:pre-wrap;background:#f7f8f4;padding:12px;border-radius:10px;overflow:auto}.muted{color:#687064;font-size:13px}
</style>
</head>
<body>
<h1>好好记账管理后台</h1>
<div class="card"><div class="row"><input id="token" type="password" placeholder="ADMIN_TOKEN"><button onclick="saveToken()">保存令牌</button><button onclick="loadSummary()">刷新概览</button></div><p class="muted">令牌仅保存在当前浏览器 sessionStorage。</p></div>
<div class="card"><h2>运行概览</h2><pre id="summary">尚未加载</pre></div>
<div class="card"><h2>发布公告</h2><div class="row"><input id="title" placeholder="标题"><input id="route" placeholder="应用路由（可选）"></div><p><textarea id="body" placeholder="公告正文"></textarea></p><button onclick="publish()">发布并推送</button><pre id="publishResult"></pre></div>
<div class="card"><h2>反馈工单</h2><button onclick="tickets()">刷新工单</button><pre id="tickets">尚未加载</pre></div>
<div class="card"><h2>运维</h2><div class="row"><button onclick="maintenance()">执行留存清理</button><button onclick="pushNow()">立即处理推送队列</button></div><pre id="ops"></pre></div>
<script>
const tokenEl=document.getElementById('token');tokenEl.value=sessionStorage.getItem('haohao-admin-token')||'';
function saveToken(){sessionStorage.setItem('haohao-admin-token',tokenEl.value)}
async function api(path,options){saveToken();const r=await fetch(path,Object.assign({},options||{},{headers:Object.assign({'x-admin-token':tokenEl.value,'content-type':'application/json'},(options&&options.headers)||{})}));const t=await r.text();if(!r.ok)throw new Error(r.status+' '+t);try{return JSON.parse(t)}catch{return t}}
async function loadSummary(){try{document.getElementById('summary').textContent=JSON.stringify(await api('/api/v1/admin/summary'),null,2)}catch(e){document.getElementById('summary').textContent=String(e)}}
async function publish(){try{const data=await api('/api/v1/admin/announcements',{method:'POST',body:JSON.stringify({title:document.getElementById('title').value,body:document.getElementById('body').value,route:document.getElementById('route').value||null})});document.getElementById('publishResult').textContent=JSON.stringify(data,null,2);loadSummary()}catch(e){document.getElementById('publishResult').textContent=String(e)}}
async function tickets(){try{document.getElementById('tickets').textContent=JSON.stringify(await api('/api/v1/admin/support-tickets'),null,2)}catch(e){document.getElementById('tickets').textContent=String(e)}}
async function maintenance(){try{document.getElementById('ops').textContent=JSON.stringify(await api('/api/v1/admin/maintenance/run',{method:'POST',body:'{}'}),null,2)}catch(e){document.getElementById('ops').textContent=String(e)}}
async function pushNow(){try{document.getElementById('ops').textContent=JSON.stringify(await api('/api/v1/admin/push/dispatch',{method:'POST',body:'{}'}),null,2)}catch(e){document.getElementById('ops').textContent=String(e)}}
</script>
</body></html>`;

export function registerAdminRoutes(app: FastifyInstance, store: Store) {
  ensureAdminSchema(store);

  app.get('/admin', async (request, reply) => {
    if (!(process.env.ADMIN_TOKEN ?? '').trim()) {
      return reply.code(404).send({ message: '管理后台未启用' });
    }
    return reply.type('text/html; charset=utf-8').send(adminHtml);
  });

  app.get('/api/v1/admin/summary', async (request) => {
    requireAdmin(request.headers['x-admin-token']);
    const scalar = (sql: string, ...args: unknown[]) =>
      (store.db.prepare(sql).get(...args) as { n: number }).n;
    return {
      now: store.now(),
      users: scalar('SELECT COUNT(*) AS n FROM users'),
      activeSessions: scalar(
        'SELECT COUNT(*) AS n FROM sessions WHERE expires_at>?',
        store.now(),
      ),
      books: scalar('SELECT COUNT(*) AS n FROM books WHERE is_archived=0'),
      openTickets: scalar(
        "SELECT COUNT(*) AS n FROM support_tickets WHERE status IN ('open','in_progress')",
      ),
      announcements: scalar('SELECT COUNT(*) AS n FROM announcements'),
      registeredPushDevices: scalar('SELECT COUNT(*) AS n FROM push_devices'),
      pendingPush: scalar("SELECT COUNT(*) AS n FROM push_outbox WHERE status='pending'"),
      failedPush: scalar("SELECT COUNT(*) AS n FROM push_outbox WHERE status='failed'"),
      retention: retentionPolicy(),
    };
  });

  app.get('/api/v1/admin/support-tickets', async (request) => {
    requireAdmin(request.headers['x-admin-token']);
    const tickets = store.db.prepare(
      'SELECT id,user_id AS userId,installation_id AS installationId,subject,message,'
        + 'contact,app_version AS appVersion,status,created_at AS createdAt,'
        + 'updated_at AS updatedAt,resolved_at AS resolvedAt '
        + 'FROM support_tickets ORDER BY created_at DESC LIMIT 200',
    ).all();
    return { tickets };
  });

  app.patch('/api/v1/admin/support-tickets/:id', async (request) => {
    requireAdmin(request.headers['x-admin-token']);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const { status } = z.strictObject({
      status: z.enum(['open', 'in_progress', 'resolved', 'closed']),
    }).parse(request.body);
    const now = store.now();
    const result = store.db.prepare(
      'UPDATE support_tickets SET status=?,updated_at=?,resolved_at=? WHERE id=?',
    ).run(
      status,
      now,
      status === 'resolved' || status === 'closed' ? now : null,
      id,
    );
    check(result.changes === 1, '工单不存在', 404);
    audit(store, 'support_ticket_status', { id, status });
    return { ok: true };
  });

  app.post('/api/v1/admin/announcements', async (request) => {
    requireAdmin(request.headers['x-admin-token']);
    const input = z.strictObject({
      title: z.string().trim().min(2).max(80),
      body: z.string().trim().min(2).max(2000),
      route: z.string().trim().max(180).nullable().optional(),
      expiresAt: z.number().int().positive().nullable().optional(),
    }).parse(request.body);
    const announcement = createAnnouncement(store, input);
    const queued = queuePushForAllRegisteredUsers(store, {
      title: announcement.title,
      body: announcement.body,
      route: announcement.route,
    });
    audit(store, 'announcement_created', {
      id: announcement.id,
      queued,
    });
    return { announcement, queued };
  });

  app.post('/api/v1/admin/push/dispatch', async (request) => {
    requireAdmin(request.headers['x-admin-token']);
    const result = await dispatchPushOutbox(store, 200);
    audit(store, 'push_dispatch', result);
    return result;
  });

  app.post('/api/v1/admin/maintenance/run', async (request) => {
    requireAdmin(request.headers['x-admin-token']);
    const result = runRetention(store);
    audit(store, 'maintenance_run', {
      deleted: result.deleted,
    });
    return result;
  });
}
