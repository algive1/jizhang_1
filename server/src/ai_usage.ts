import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Store } from './store.js';
import { auditAdmin, requireAdminPrincipal } from './admin_auth.js';

export function ensureAiUsageSchema(store:Store){
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS ai_usage_events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,user_id TEXT,feature TEXT NOT NULL,provider_id TEXT NOT NULL,model TEXT,
      success INTEGER NOT NULL,latency_ms INTEGER NOT NULL,input_units INTEGER NOT NULL DEFAULT 0,output_units INTEGER NOT NULL DEFAULT 0,
      estimated_cost_micros INTEGER NOT NULL DEFAULT 0,error_code TEXT,created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_ai_usage_time ON ai_usage_events(created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_ai_usage_provider ON ai_usage_events(provider_id,feature,created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_ai_usage_user ON ai_usage_events(user_id,created_at DESC);
  `);
}
export function recordAiUsage(store:Store,event:{userId?:string;feature:string;providerId:string;model?:string;success:boolean;latencyMs:number;inputUnits?:number;outputUnits?:number;estimatedCostMicros?:number;errorCode?:string}){
  ensureAiUsageSchema(store);store.db.prepare('INSERT INTO ai_usage_events(user_id,feature,provider_id,model,success,latency_ms,input_units,output_units,estimated_cost_micros,error_code,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)').run(event.userId??null,event.feature,event.providerId,event.model??null,Number(event.success),Math.max(0,Math.floor(event.latencyMs)),event.inputUnits??0,event.outputUnits??0,event.estimatedCostMicros??0,event.errorCode??null,store.now());
}
export function registerAiUsageAdminRoutes(app:FastifyInstance,store:Store){
  ensureAiUsageSchema(store);
  app.get('/api/v1/admin/ai/usage',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'ai.read');
    const {days}=z.object({days:z.coerce.number().int().min(1).max(90).default(7)}).parse(request.query);const since=store.now()-days*86400;
    const rows=store.db.prepare('SELECT provider_id AS providerId,feature,COUNT(*) requests,SUM(success) successes,ROUND(AVG(latency_ms)) avgLatencyMs,SUM(input_units) inputUnits,SUM(output_units) outputUnits,SUM(estimated_cost_micros) estimatedCostMicros FROM ai_usage_events WHERE created_at>=? GROUP BY provider_id,feature ORDER BY requests DESC').all(since);
    auditAdmin(store,principal,'ai_usage_read',{permission:'ai.read',details:{days}});return {days,since,items:rows};
  });
}
