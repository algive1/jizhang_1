import type { FastifyInstance } from 'fastify';
import type { Store } from './store.js';
import { auditAdmin, requireAdminPrincipal } from './admin_auth.js';

export function registerAdminHealthRoutes(app:FastifyInstance,store:Store){
  app.get('/api/v1/admin/system/health',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'logs.read');
    const db=store.db.prepare('PRAGMA quick_check').get() as Record<string,unknown>;
    const pageCount=Number(store.db.pragma('page_count',{simple:true}));const pageSize=Number(store.db.pragma('page_size',{simple:true}));
    const tables=(store.db.prepare("SELECT COUNT(*) n FROM sqlite_master WHERE type='table'").get() as {n:number}).n;
    const envChecks={
      adminToken:Boolean(process.env.ADMIN_TOKEN),
      appleBundle:Boolean(process.env.APPLE_BUNDLE_ID),
      appleRoots:Boolean(process.env.APPLE_ROOT_CA_PATHS),
      fcm:Boolean(process.env.FCM_PROJECT_ID&&process.env.FCM_CLIENT_EMAIL&&process.env.FCM_PRIVATE_KEY),
      apns:Boolean(process.env.APNS_KEY_ID&&process.env.APNS_TEAM_ID&&process.env.APNS_PRIVATE_KEY&&process.env.APNS_BUNDLE_ID),
      deepseek:Boolean(process.env.DEEPSEEK_API_KEY),
    };
    auditAdmin(store,principal,'system_health_read',{permission:'logs.read'});
    return {database:{quickCheck:Object.values(db)[0]??'unknown',tables,estimatedBytes:pageCount*pageSize},configuration:envChecks,now:store.now()};
  });
}
