import { z } from 'zod';
import type { Store } from '../store.js';

export const pageQuery = z.object({page:z.coerce.number().int().min(1).default(1),pageSize:z.coerce.number().int().min(1).max(100).default(20),q:z.string().trim().max(100).default(''),sort:z.enum(['createdAt','lastSeenAt']).default('createdAt'),order:z.enum(['asc','desc']).default('desc')});
export type PageInput = z.infer<typeof pageQuery>;
export function paginate<T>(store:Store,input:PageInput,select:string,from:string,args:unknown[]=[],order='created_at DESC') {
  const total=(store.db.prepare(`SELECT COUNT(*) AS n ${from}`).get(...args) as {n:number}).n;
  const items=store.db.prepare(`${select} ${from} ORDER BY ${order} LIMIT ? OFFSET ?`).all(...args,input.pageSize,(input.page-1)*input.pageSize) as T[];
  return {items,total,page:input.page,pageSize:input.pageSize};
}
export function redact(value:string) {
  return value.replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi,'[邮箱已脱敏]')
    .replace(/(?:\d[ -]?){7,}/g,'[号码已脱敏]').replace(/(?:Bearer\s+|(?:token|password|api[_-]?key)\s*[:=]\s*)[^\s,;]+/gi,'[凭据已脱敏]');
}
