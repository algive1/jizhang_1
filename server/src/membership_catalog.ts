import { existsSync, readFileSync } from 'node:fs';
import { timingSafeEqual } from 'node:crypto';
import { resolve } from 'node:path';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Store } from './store.js';
import { requireCondition as check } from './contract.js';
import { requireAdmin, audit } from './admin_auth.js';

const text = z.string().trim().min(1).max(300);
const key = z.string().regex(/^[a-z][a-z0-9_-]{0,63}$/);
export const entitlementKeys = ['automaticBookkeeping','cloudSync','multiDevice','aiAnalysis','voiceAi','ocr','advancedReport','familyBook','dataExport','basicBackup','adFree','customTheme'] as const;
const defaultRights: Record<string, string[]> = {
  automatic:['automaticBookkeeping','voiceAi','ocr'], statistics:['advancedReport','aiAnalysis'],
  books:['familyBook'], cloud:['cloudSync','multiDevice','basicBackup'], export:['dataExport'],
  adfree:['adFree'], theme:['customTheme'], assets:['advancedReport'],
};
const iconUrl = z.union([z.literal(''),z.string().url().max(2000).refine(v=>v.startsWith('https://'),'图标须使用 HTTPS 地址')]).default('');
const version = z.strictObject({id:z.enum(['pro','family']),title:text,description:z.string().max(300).default(''),enabled:z.boolean().default(true),sortOrder:z.number().int().min(0).default(0),benefitIds:z.array(key).max(30).optional()});
export const planSchema = z.strictObject({
  id:key,title:text,months:z.union([z.literal(1),z.literal(3),z.literal(12)]),priceInCents:z.number().int().positive().max(10000000),
  description:text,recommended:z.boolean(),versionId:z.enum(['pro','family']).default('pro'),
  originalPriceInCents:z.number().int().min(0).max(10000000).default(0),tag:z.string().trim().max(12).default(''),
  enabled:z.boolean().default(true),sortOrder:z.number().int().min(0).default(0),
  aiDailyLimit:z.number().int().min(0).max(10000).optional(),
  rightOverrides:z.array(z.strictObject({benefitId:key,enabled:z.boolean(),value:z.string().max(300).default('')})).max(30).default([]),
}).refine(p=>!p.originalPriceInCents || p.originalPriceInCents>=p.priceInCents,'原价不能低于售价');
export const catalogSchema = z.strictObject({
  versions:z.array(version).min(1).max(2).default([{id:'pro',title:'Pro 会员',description:'',enabled:true,sortOrder:0}]),
  plans:z.array(planSchema).max(50),
  benefits:z.array(z.strictObject({id:key,title:text,subtitle:text,detail:z.string().trim().min(1).max(2000),iconUrl,enabled:z.boolean().default(true),entitlementKeys:z.array(z.enum(entitlementKeys)).max(12).optional()})).max(30),
  benefitIcons:z.array(z.strictObject({id:key,name:text,url:iconUrl.refine(v=>!!v,'请填写图标地址')})).max(100).default([]),
  faqs:z.array(z.strictObject({id:text,question:text,answer:z.string().trim().min(1).max(2000)})).min(3).max(30).refine(p=>new Set(p.map(v=>v.id)).size===p.length),
}).superRefine((c,ctx)=>{
  const invalid=(message:string)=>ctx.addIssue({code:'custom',message});
  for(const rows of [c.versions,c.plans,c.benefits,c.benefitIcons,c.faqs]) if(new Set(rows.map(v=>v.id)).size!==rows.length) invalid('配置 ID 不能重复');
  for(const v of c.versions){
    if((v.benefitIds??[]).some(id=>!c.benefits.some(b=>b.id===id))) invalid('版本权益不存在');
    if(c.plans.filter(p=>p.versionId===v.id&&p.enabled&&p.recommended).length>1) invalid('每个版本最多一个推荐套餐');
  }
  for(const p of c.plans){
    if(!c.versions.some(v=>v.id===p.versionId)) invalid('套餐所属版本不存在');
    if(new Set(p.rightOverrides.map(r=>r.benefitId)).size!==p.rightOverrides.length||p.rightOverrides.some(r=>!c.benefits.some(b=>b.id===r.benefitId))) invalid('套餐权益覆盖无效');
    const appleMonths:Record<string,number>={monthly:1,quarterly:3,yearly:12};
    if(appleMonths[p.id]&&(p.months!==appleMonths[p.id]||p.versionId!=='pro')) invalid('现有 App Store 套餐的周期和等级不可改变');
  }
});
export type MembershipCatalog=z.infer<typeof catalogSchema>;
export type MembershipProduct=z.infer<typeof planSchema>;

export function planBenefits(catalog:MembershipCatalog,product:Pick<MembershipProduct,'versionId'|'rightOverrides'>){
  const ids=catalog.versions.find(v=>v.id===product.versionId)?.benefitIds;
  return catalog.benefits.filter(b=>b.enabled&&(!ids||ids.includes(b.id))).flatMap(b=>{
    const override=product.rightOverrides.find(r=>r.benefitId===b.id);
    return override?.enabled===false?[]:[{...b,subtitle:override?.value||b.subtitle}];
  });
}
export function planEntitlements(catalog:MembershipCatalog,product:Pick<MembershipProduct,'versionId'|'rightOverrides'>):string[]{
  return [...new Set(planBenefits(catalog,product).flatMap(b=>b.entitlementKeys??defaultRights[b.id]??[]))];
}
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
  const authorize=(headers:Record<string,unknown>)=>{
    if(headers['x-admin-token']!==undefined) return requireAdmin(headers['x-admin-token'] as string);
    const secret=process.env.MEMBERSHIP_ADMIN_TOKEN;
    check(secret && secret.length>=32,'会员配置管理尚未启用',503);
    const supplied=String(headers.authorization??'');
    const expected=`Bearer ${secret}`;
    check(supplied.length===expected.length && timingSafeEqual(Buffer.from(supplied),Buffer.from(expected)),'无会员配置管理权限',403);
  };
  app.get('/api/v1/admin/membership/catalog',async req=>{authorize(req.headers);return getMembershipCatalog(store);});
  app.put('/api/v1/admin/membership/catalog',async(req)=>{
    authorize(req.headers);
    const value=catalogSchema.parse(req.body);
    store.db.transaction(()=>{
      store.db.prepare('UPDATE membership_catalog SET data_json=? WHERE id=1').run(JSON.stringify(value));
      audit(store,'membership_catalog_updated',{plans:value.plans.map(p=>p.id)});
    })();
    return value;
  });
}

export function getMembershipCatalog(store: Store): z.infer<typeof catalogSchema> {
  const row = store.db.prepare('SELECT data_json FROM membership_catalog WHERE id=1').get() as { data_json: string } | undefined;
  check(row, '会员配置不存在', 500);
  return catalogSchema.parse(JSON.parse(row.data_json));
}
