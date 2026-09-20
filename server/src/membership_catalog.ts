import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Store } from './store.js';
import { requireCondition as check } from './contract.js';
import { auditAdmin, requireAdminPrincipal } from './admin_auth.js';

const text = z.string().trim().min(1).max(300);
const plan = z.strictObject({id:z.enum(['monthly','quarterly','yearly']),title:text,months:z.union([z.literal(1),z.literal(3),z.literal(12)]),priceInCents:z.number().int().positive().max(10000000),description:text,recommended:z.boolean()});
export const catalogSchema = z.strictObject({
  plans:z.array(plan).length(3).refine(p=>new Set(p.map(v=>v.id)).size===3 && p.filter(v=>v.recommended).length===1 && p.every(v=>v.months===({monthly:1,quarterly:3,yearly:12}[v.id])), '需要月、季、年三档及一个推荐套餐'),
  benefits:z.array(z.strictObject({id:z.enum(['automatic','books','statistics','cloud','assets','export','theme','support','categories','adfree']),title:text,subtitle:text,detail:text})).length(8).refine(p=>new Set(p.map(v=>v.id)).size===8),
  faqs:z.array(z.strictObject({id:text,question:text,answer:z.string().trim().min(1).max(2000)})).min(3).max(30).refine(p=>new Set(p.map(v=>v.id)).size===p.length),
});
export function registerMembershipCatalog(app:FastifyInstance,store:Store) {
  store.db.exec('CREATE TABLE IF NOT EXISTS membership_catalog(id INTEGER PRIMARY KEY CHECK(id=1), data_json TEXT NOT NULL)');
  // One source for the initial editorial configuration and the offline App preview.
  const candidates = [
    resolve(process.cwd(), 'assets/config/membership_catalog.json'),
    resolve(process.cwd(), '../assets/config/membership_catalog.json'),
  ];
  const source = candidates.find((candidate) => existsSync(candidate));
  check(source, '会员配置文件不存在', 500);
  const initial=catalogSchema.parse(JSON.parse(readFileSync(source!, 'utf8')));
  store.db.prepare('INSERT OR IGNORE INTO membership_catalog VALUES(1,?)').run(JSON.stringify(initial));
  app.get('/api/v1/membership/catalog',async()=>getMembershipCatalog(store));
  app.put('/api/v1/admin/membership/catalog',async(req)=>{
    const principal=requireAdminPrincipal(req.headers['x-admin-token'],'membership.write');
    const value=catalogSchema.parse(req.body);
    store.db.prepare('UPDATE membership_catalog SET data_json=? WHERE id=1').run(JSON.stringify(value));
    auditAdmin(store,principal,'membership_catalog_update',{permission:'membership.write'});
    return value;
  });
}

export function getMembershipCatalog(store: Store): z.infer<typeof catalogSchema> {
  const row = store.db.prepare('SELECT data_json FROM membership_catalog WHERE id=1').get() as { data_json: string } | undefined;
  check(row, '会员配置不存在', 500);
  return catalogSchema.parse(JSON.parse(row.data_json));
}
