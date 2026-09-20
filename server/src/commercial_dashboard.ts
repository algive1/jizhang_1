import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Store } from './store.js';
import { auditAdmin, requireAdminPrincipal } from './admin_auth.js';

function scalar(store:Store,sql:string,...args:unknown[]){return Number((store.db.prepare(sql).get(...args) as {n:number}|undefined)?.n??0)}
function hasTable(store:Store,name:string){return Boolean(store.db.prepare("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?").get(name))}

export function registerCommercialDashboardRoutes(app:FastifyInstance,store:Store){
  app.get('/api/v1/admin/commercial/overview',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'dashboard.read');
    const {days}=z.object({days:z.coerce.number().int().min(1).max(365).default(30)}).parse(request.query);
    const now=store.now(),since=now-days*86400;
    const orders=hasTable(store,'membership_orders');
    const apple=hasTable(store,'apple_transactions');
    const subscriptions=hasTable(store,'membership_subscriptions');
    const assistant=hasTable(store,'assistant_requests');
    const analytics=hasTable(store,'analytics_events');
    const result={
      period:{days,since,until:now},
      users:{total:scalar(store,'SELECT COUNT(*) n FROM users'),new:scalar(store,'SELECT COUNT(*) n FROM users WHERE created_at>=?',since),activeSessions:scalar(store,'SELECT COUNT(*) n FROM sessions WHERE expires_at>?',now)},
      bookkeeping:{books:scalar(store,'SELECT COUNT(*) n FROM books WHERE is_archived=0'),transactions:scalar(store,"SELECT COUNT(*) n FROM entities WHERE kind='transactions' AND deleted=0")},
      membership:{
        activeSubscriptions:subscriptions?scalar(store,'SELECT COUNT(*) n FROM membership_subscriptions WHERE expires_at>?',now):0,
        activeApple:apple?scalar(store,'SELECT COUNT(DISTINCT user_id) n FROM apple_transactions WHERE revoked_at IS NULL AND expires_at>?',now):0,
        orders:orders?scalar(store,'SELECT COUNT(*) n FROM membership_orders WHERE created_at>=?',since):0,
        paidOrders:orders?scalar(store,"SELECT COUNT(*) n FROM membership_orders WHERE created_at>=? AND status='paid'",since):0,
        recognizedCnyCents:orders?scalar(store,"SELECT COALESCE(SUM(amount_in_cents),0) n FROM membership_orders WHERE created_at>=? AND status='paid'",since):0,
        refundedCnyCents:orders?scalar(store,"SELECT COALESCE(SUM(amount_in_cents),0) n FROM membership_orders WHERE created_at>=? AND status='refunded'",since):0,
        refundOrders:orders?scalar(store,"SELECT COUNT(*) n FROM membership_orders WHERE created_at>=? AND status='refunded'",since):0,
      },
      engagement:{activeInstallations:analytics?scalar(store,'SELECT COUNT(DISTINCT installation_id) n FROM analytics_events WHERE occurred_at>=?',since):0,assistantRequests:assistant?scalar(store,'SELECT COUNT(*) n FROM assistant_requests WHERE created_at>=?',since):0},
      operations:{openTickets:hasTable(store,'support_tickets')?scalar(store,"SELECT COUNT(*) n FROM support_tickets WHERE status IN ('open','in_progress')"):0,pendingPush:hasTable(store,'push_outbox')?scalar(store,"SELECT COUNT(*) n FROM push_outbox WHERE status='pending'"):0,failedPush:hasTable(store,'push_outbox')?scalar(store,"SELECT COUNT(*) n FROM push_outbox WHERE status='failed'"):0},
    };
    auditAdmin(store,principal,'commercial_overview',{permission:'dashboard.read',details:{days}});
    return result;
  });

  app.get('/api/v1/admin/commercial/orders',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'membership.read');
    const q=z.object({status:z.enum(['created','pending','paid','failed','refunded']).optional(),limit:z.coerce.number().int().min(1).max(200).default(50),offset:z.coerce.number().int().min(0).default(0)}).parse(request.query);
    if(!hasTable(store,'membership_orders'))return {orders:[]};
    const rows=q.status?store.db.prepare('SELECT id,user_id AS userId,product_id AS productId,channel,amount_in_cents AS amountInCents,status,provider_trade_no AS providerTradeNo,created_at AS createdAt,updated_at AS updatedAt FROM membership_orders WHERE status=? ORDER BY created_at DESC LIMIT ? OFFSET ?').all(q.status,q.limit,q.offset):store.db.prepare('SELECT id,user_id AS userId,product_id AS productId,channel,amount_in_cents AS amountInCents,status,provider_trade_no AS providerTradeNo,created_at AS createdAt,updated_at AS updatedAt FROM membership_orders ORDER BY created_at DESC LIMIT ? OFFSET ?').all(q.limit,q.offset);
    auditAdmin(store,principal,'commercial_orders',{permission:'membership.read',details:{status:q.status??'all',limit:q.limit,offset:q.offset}});
    return {orders:rows};
  });
}
