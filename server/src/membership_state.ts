import type { Store } from './store.js';
import { productByAppleId, resolvedEntitlements } from './entitlements.js';

export type MembershipState={status:'active'|'inactive';provider:string|null;productId:string|null;startedAt:number|null;expiresAt:number|null;entitlements:Array<Record<string,unknown>>};
export function membershipState(store:Store,userId:string):MembershipState{
  const now=store.now();let best:{provider:string;productId:string;startedAt:number;expiresAt:number}|null=null;
  try{
    const sub=store.db.prepare('SELECT provider,product_id AS productId,started_at AS startedAt,expires_at AS expiresAt FROM membership_subscriptions WHERE user_id=? AND expires_at>? ORDER BY expires_at DESC LIMIT 1').get(userId,now) as any;
    if(sub)best=sub;
    const apple=store.db.prepare('SELECT product_id AS productId,purchased_at AS startedAt,expires_at AS expiresAt FROM apple_transactions WHERE user_id=? AND revoked_at IS NULL AND expires_at>? ORDER BY expires_at DESC LIMIT 1').get(userId,now) as any;
    if(apple&&(!best||apple.expiresAt>best.expiresAt)){const mapped=productByAppleId(store,apple.productId);best={provider:'apple',productId:mapped?.id??apple.productId,startedAt:apple.startedAt,expiresAt:apple.expiresAt}}
  }catch{}
  if(!best)return {status:'inactive',provider:null,productId:null,startedAt:null,expiresAt:null,entitlements:resolvedEntitlements(store,userId,null)};
  return {status:'active',...best,entitlements:resolvedEntitlements(store,userId,best.productId).map(x=>({...x,source:best!.provider,expiresAt:best!.expiresAt}))};
}
export function hasMembership(store:Store,userId:string){return membershipState(store,userId).status==='active'}
