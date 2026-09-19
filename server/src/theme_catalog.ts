import { timingSafeEqual } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Store } from './store.js';
import { requireCondition as check } from './contract.js';

const hex = z.string().regex(/^#[0-9A-Fa-f]{6}$/);
const theme = z.strictObject({
  id:z.string().regex(/^[a-z0-9_]{2,40}$/),
  name:z.string().trim().min(1).max(40),
  description:z.string().trim().max(120),
  premium:z.boolean(),
  background:hex,surface:hex,surfaceSoft:hex,primary:hex,primaryDark:hex,primarySoft:hex,textPrimary:hex,textSecondary:hex,divider:hex,
});
const catalog = z.strictObject({
  version:z.number().int().positive(),
  themes:z.array(theme).min(1).max(20).refine(v=>new Set(v.map(t=>t.id)).size===v.length,'主题 id 不能重复').refine(v=>v.some(t=>t.id==='fresh_green'&&!t.premium),'必须保留免费的 fresh_green 默认主题'),
});

const initial = catalog.parse({
  version:1,
  themes:[
    {id:'fresh_green',name:'好好绿',description:'明亮、干净的默认主题',premium:false,background:'#FBFCF7',surface:'#FFFFFF',surfaceSoft:'#F5F7EF',primary:'#76A33A',primaryDark:'#527A24',primarySoft:'#EDF4DF',textPrimary:'#1E241C',textSecondary:'#747A70',divider:'#E8EBE2'},
    {id:'mist_blue',name:'云雾蓝',description:'冷白与灰蓝，更安静',premium:true,background:'#F7FAFC',surface:'#FFFFFF',surfaceSoft:'#F0F5F8',primary:'#527C98',primaryDark:'#365D77',primarySoft:'#E4EFF5',textPrimary:'#1D252A',textSecondary:'#707A80',divider:'#E4EAEE'},
    {id:'almond_warm',name:'杏仁暖',description:'奶白与杏色，柔和温暖',premium:true,background:'#FCFAF5',surface:'#FFFFFF',surfaceSoft:'#F8F1E7',primary:'#9B7549',primaryDark:'#74532F',primarySoft:'#F3E6D3',textPrimary:'#29231D',textSecondary:'#7D756C',divider:'#EDE5DA'},
  ],
});

export function registerThemeCatalog(app:FastifyInstance, store:Store) {
  store.db.exec('CREATE TABLE IF NOT EXISTS theme_catalog(id INTEGER PRIMARY KEY CHECK(id=1), data_json TEXT NOT NULL, updated_at INTEGER NOT NULL)');
  store.db.prepare('INSERT OR IGNORE INTO theme_catalog VALUES(1,?,?)').run(JSON.stringify(initial),store.now());
  app.get('/api/v1/themes/catalog',async()=>read(store));
  app.put('/api/v1/admin/themes/catalog',async(req)=>{
    const secret=process.env.MEMBERSHIP_ADMIN_TOKEN;
    check(secret && secret.length>=32,'主题配置管理尚未启用',503);
    const supplied=req.headers.authorization??''; const expected=`Bearer ${secret}`;
    check(supplied.length===expected.length && timingSafeEqual(Buffer.from(supplied),Buffer.from(expected)),'无主题配置管理权限',403);
    const next=catalog.parse(req.body);
    const current=read(store);
    check(next.version>current.version,'主题配置版本必须递增',409);
    store.db.prepare('UPDATE theme_catalog SET data_json=?,updated_at=? WHERE id=1').run(JSON.stringify(next),store.now());
    return next;
  });
}
function read(store:Store):z.infer<typeof catalog>{
  const row=store.db.prepare('SELECT data_json FROM theme_catalog WHERE id=1').get() as {data_json:string}|undefined;
  check(row,'主题配置不存在',500); return catalog.parse(JSON.parse(row!.data_json));
}
