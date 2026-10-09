import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAdmin, audit } from './admin_auth.js';
import { getMembershipCatalog } from './membership_catalog.js';
import { membershipCurrent } from './payment.js';
import { requireCondition as check } from './contract.js';
import type { Store } from './store.js';

export const membershipAdjustmentSchema = z.strictObject({productId:z.string().max(64).nullable(),durationDays:z.number().int().min(0).max(36500),reason:z.string().trim().min(1).max(300)});
export function adjustMembership(store:Store,id:string,input:z.infer<typeof membershipAdjustmentSchema>){
  check(store.db.prepare("SELECT 1 FROM users WHERE id=? AND username NOT LIKE 'deleted_%'").get(id),'用户不存在',404);
  const product=getMembershipCatalog(store).plans.find(p=>p.id===input.productId);
  check(input.productId===null || product,'套餐不存在',400);
  check(input.productId===null || input.durationDays>0,'开通天数必须大于零',400);
  const now=store.now();
  store.db.prepare('INSERT INTO membership_adjustments(user_id,version_id,product_id,started_at,expires_at,updated_at,reason) VALUES(?,?,?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET version_id=excluded.version_id,product_id=excluded.product_id,started_at=excluded.started_at,expires_at=excluded.expires_at,updated_at=excluded.updated_at,reason=excluded.reason')
    .run(id,product?.versionId??null,product?.id??'',now,now+input.durationDays*86400,now,input.reason);
  return membershipCurrent(store,id,true);
}

export function registerMembershipAdmin(app:FastifyInstance,store:Store){
  app.get('/api/v1/admin/membership/users',async req=>{
    requireAdmin(req.headers['x-admin-token']);
    const {q,page}=z.object({q:z.string().max(80).default(''),page:z.coerce.number().int().min(1).default(1)}).parse(req.query);
    const rows=store.db.prepare("SELECT id,username,display_name AS displayName FROM users WHERE username NOT LIKE 'deleted_%' AND (instr(username,?)>0 OR instr(COALESCE(display_name,''),?)>0 OR id=?) ORDER BY created_at DESC,id LIMIT 50 OFFSET ?").all(q,q,q,(page-1)*50) as {id:string;username:string;displayName:string|null}[];
    return {users:rows.map(u=>({...u,...membershipCurrent(store,u.id,true)})),page};
  });
  app.put('/api/v1/admin/membership/users/:id',async req=>{
    requireAdmin(req.headers['x-admin-token']);
    const {id}=z.object({id:z.string().uuid()}).parse(req.params);
    const input=membershipAdjustmentSchema.parse(req.body);
    return store.db.transaction(()=>{
      const result=adjustMembership(store,id,input);
      audit(store,'membership_adjusted',{userId:id,...input,versionId:result.membership.plan});
      return result;
    })();
  });
  app.get('/api/v1/admin/membership/users/:id/history',async req=>{
    requireAdmin(req.headers['x-admin-token']);
    const {id}=z.object({id:z.string().uuid()}).parse(req.params);
    check(store.db.prepare('SELECT 1 FROM users WHERE id=?').get(id),'用户不存在',404);
    return {
      orders:store.db.prepare('SELECT id,product_id AS productId,channel,amount_in_cents AS amountInCents,status,created_at AS createdAt FROM membership_orders WHERE user_id=? ORDER BY created_at DESC LIMIT 100').all(id),
      apple:store.db.prepare('SELECT transaction_id AS id,product_id AS productId,purchased_at AS createdAt,expires_at AS expiresAt,revoked_at AS revokedAt FROM apple_transactions WHERE user_id=? ORDER BY updated_at DESC LIMIT 100').all(id),
      adjustments:store.db.prepare("SELECT details_json AS details,created_at AS createdAt FROM admin_audit_log WHERE action='membership_adjusted' AND json_extract(details_json,'$.userId')=? ORDER BY id DESC LIMIT 100").all(id),
    };
  });
}

export const membershipAdminHtml=String.raw`
<style>
.member-admin table{width:100%;border-collapse:collapse;font-size:14px}.member-admin th,.member-admin td{padding:10px;text-align:left;border-bottom:1px solid #e5e9e0;vertical-align:top}
.member-admin label{display:flex;flex-direction:column;gap:5px;font-size:13px}.member-admin label.check{flex-direction:row;align-items:center;min-width:100px}.member-admin input[type=checkbox]{width:18px;height:18px;accent-color:#4d6b45}
.member-admin details{border-bottom:1px solid #e5e9e0;padding:14px 0}.member-admin summary{font-weight:600;cursor:pointer;margin-bottom:12px}.member-admin .fields{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;margin:12px 0}
.member-admin .scroll-table{overflow:auto}.member-admin .scroll-table table{min-width:620px}.member-admin select[multiple]{min-height:120px}.member-admin .status{min-height:22px;color:#4d6b45}.member-admin .error{color:#b32828}.member-admin img{width:28px;height:28px;object-fit:contain}.member-admin button:disabled{opacity:.5;cursor:wait}input:focus,select:focus,textarea:focus,button:focus-visible{outline:2px solid #4d6b45;outline-offset:2px}::selection{background:#dcebcf}input{caret-color:#4d6b45}
</style>
<section class="card member-admin" id="memberAdmin"><h2>会员管理</h2><p class="muted">版本与权益模板 → 套餐覆盖 → 用户会员。保存后应用重新进入会员页即可加载最新配置。</p>
<div class="row"><button onclick="memberLoad()">加载会员配置</button><button id="memberSave" onclick="memberSave()" disabled>保存全部配置</button></div><p id="memberStatus" class="status" role="status" aria-live="polite">尚未加载</p>
<div id="memberConfig" hidden><h3>会员版本与权益模板</h3><div id="memberVersions"></div><button onclick="memberAddVersion()">添加 Family 版本</button>
<h3>会员套餐</h3><p class="muted">价格单位为元，控制安卓支付。iOS 展示与扣款使用 App Store 价格；月、季、年 App Store 套餐保持现有周期与 Pro 等级，其他套餐用于安卓支付。</p><div id="memberPlans"></div><button onclick="memberAddPlan()">新增套餐</button>
<h3>权益与图标</h3><div id="memberBenefits"></div><button onclick="memberAddBenefit()">新增权益</button>
<h3>权益图标库</h3><div id="memberIcons"></div><button onclick="memberAddIcon()">新增图标链接</button></div>
<h3>用户会员</h3><div class="row"><input id="memberSearch" aria-label="用户搜索" placeholder="用户名 / 昵称 / 用户 ID"><button onclick="memberUsers(1)">搜索用户</button></div><div id="memberUsers" class="scroll-table"></div>
<div class="row"><button onclick="memberUsers(Math.max(1,memberPage-1))">上一页</button><button onclick="memberUsers(memberPage+1)">下一页</button></div>
<form id="memberUserForm" hidden onsubmit="memberAdjust(event)"><h3 id="memberUserTitle">调整会员</h3><input id="memberUserId" type="hidden"><div class="fields"><label>会员身份<select id="memberUserPlan"></select></label><label>从现在起有效天数<input id="memberDays" type="number" min="1" max="36500" value="30" required></label><label>调整原因<input id="memberReason" maxlength="300" required></label></div><button type="submit">保存会员调整</button></form>
<div id="memberHistory" class="scroll-table"></div></section>`;

export const membershipAdminScript=String.raw`
let memberDraft=null,memberDirty=false,memberBusy=false,memberPage=1,memberUserRows=[];
const me=id=>document.getElementById(id);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const memberFeatures={automaticBookkeeping:'自动记账',cloudSync:'云同步',multiDevice:'多设备',aiAnalysis:'消费分析',voiceAi:'语音 AI',ocr:'账单识别',advancedReport:'资产报表',familyBook:'共享账本',dataExport:'数据导出',basicBackup:'备份',adFree:'无广告',customTheme:'主题'};
const defaultBenefitKeys={automatic:['automaticBookkeeping','voiceAi','ocr'],statistics:['advancedReport','aiAnalysis'],books:['familyBook'],cloud:['cloudSync','multiDevice','basicBackup'],export:['dataExport'],adfree:['adFree'],theme:['customTheme'],assets:['advancedReport']};
function memberMessage(text,error=false){me('memberStatus').textContent=text;me('memberStatus').className=error?'status error':'status'}
function memberField(label,key,value,type='text'){return '<label>'+esc(label)+'<input data-f="'+key+'" type="'+type+'" value="'+esc(value)+'"'+(type==='number'?' step="0.01" min="0"':'')+'></label>'}
function memberCheck(label,key,value){return '<label class="check"><input data-f="'+key+'" type="checkbox" '+(value?'checked':'')+'>'+esc(label)+'</label>'}
function memberSelect(label,key,values,selected,multiple=false){const selectedValues=Array.isArray(selected)?selected:[selected];return '<label>'+esc(label)+'<select aria-label="'+esc(label)+'" data-f="'+key+'" '+(multiple?'multiple':'')+'>'+values.map(v=>'<option value="'+esc(v[0])+'" '+(selectedValues.includes(v[0])?'selected':'')+'>'+esc(v[1])+'</option>').join('')+'</select></label>'}
function memberRead(node){const out={};node.querySelectorAll('[data-f]').forEach(el=>out[el.dataset.f]=el.multiple?Array.from(el.selectedOptions,x=>x.value):el.type==='checkbox'?el.checked:el.type==='number'?Number(el.value):el.value);return out}
function memberCollect(){if(!memberDraft)return;memberDraft.versions=Array.from(me('memberVersions').children,n=>memberRead(n));memberDraft.benefits=Array.from(me('memberBenefits').children,n=>memberRead(n));memberDraft.benefitIcons=Array.from(me('memberIcons').children,n=>memberRead(n));memberDraft.plans=Array.from(me('memberPlans').children,n=>{const p=memberRead(n);p.priceInCents=Math.round(p.price*100);p.originalPriceInCents=Math.round(p.originalPrice*100);delete p.price;delete p.originalPrice;p.rightOverrides=Array.from(n.querySelectorAll('[data-right]'),r=>({benefitId:r.dataset.right,enabled:r.querySelector('input[type=checkbox]').checked,value:r.querySelector('input[type=text]').value}));return p})}
function memberRender(){
 const c=memberDraft;me('memberConfig').hidden=false;me('memberSave').disabled=false;
 me('memberVersions').innerHTML=c.versions.map(v=>'<details open><summary>'+esc(v.title)+'</summary><input data-f="id" type="hidden" value="'+esc(v.id)+'"><div class="fields">'+memberField('版本名称','title',v.title)+memberField('描述','description',v.description)+memberField('排序','sortOrder',v.sortOrder,'number')+memberCheck('启用','enabled',v.enabled)+memberSelect('权益模板（可多选）','benefitIds',c.benefits.map(b=>[b.id,b.title]),v.benefitIds??c.benefits.map(b=>b.id),true)+'</div></details>').join('');
 me('memberBenefits').innerHTML=c.benefits.map(b=>'<details><summary>'+esc(b.title)+'</summary><div class="fields">'+memberField('权益 ID','id',b.id)+memberField('名称','title',b.title)+memberField('默认权益值','subtitle',b.subtitle)+memberField('权益说明','detail',b.detail)+memberSelect('权益图标','iconUrl',[['','内置图标'],...c.benefitIcons.map(i=>[i.url,i.name]),...(b.iconUrl&&!c.benefitIcons.some(i=>i.url===b.iconUrl)?[[b.iconUrl,'当前图标']]:[])],b.iconUrl)+memberCheck('启用','enabled',b.enabled)+memberSelect('实际授予功能（可多选）','entitlementKeys',Object.entries(memberFeatures),b.entitlementKeys??defaultBenefitKeys[b.id]??[],true)+'</div></details>').join('');
 me('memberPlans').innerHTML=c.plans.map(p=>'<details><summary>'+esc(p.title)+' · ¥'+(p.priceInCents/100).toFixed(2)+(p.enabled?'':' · 已停用')+'</summary><div class="fields">'+memberField('套餐 ID','id',p.id)+memberSelect('会员版本','versionId',c.versions.map(v=>[v.id,v.title]),p.versionId)+memberField('套餐名称','title',p.title)+memberSelect('周期','months',[[1,'月卡'],[3,'季卡'],[12,'年卡']].map(v=>[String(v[0]),v[1]]),String(p.months))+memberField('售价（元）','price',p.priceInCents/100,'number')+memberField('原价（元，0 表示不展示）','originalPrice',p.originalPriceInCents/100,'number')+memberField('描述','description',p.description)+memberField('角标','tag',p.tag)+memberField('排序','sortOrder',p.sortOrder,'number')+memberCheck('推荐','recommended',p.recommended)+memberCheck('启用','enabled',p.enabled)+'</div><h4>套餐权益覆盖</h4><div class="scroll-table"><table><thead><tr><th>权益</th><th>启用</th><th>覆盖值（留空使用模板）</th></tr></thead><tbody>'+c.benefits.map(b=>{const r=p.rightOverrides.find(r=>r.benefitId===b.id);return '<tr data-right="'+esc(b.id)+'"><td>'+esc(b.title)+'</td><td><input type="checkbox" aria-label="启用'+esc(b.title)+'" '+(r?.enabled!==false?'checked':'')+'></td><td><input type="text" aria-label="覆盖'+esc(b.title)+'" value="'+esc(r?.value??'')+'"></td></tr>'}).join('')+'</tbody></table></div></details>').join('');
 me('memberIcons').innerHTML=c.benefitIcons.map(i=>'<div class="fields">'+memberField('图标 ID','id',i.id)+memberField('图标名称','name',i.name)+memberField('HTTPS 图标地址','url',i.url,'url')+'</div>').join('');
 me('memberPlans').querySelectorAll('[data-f=id]').forEach(el=>el.readOnly=true);
}
async function memberLoad(){if(memberDirty){memberMessage('有未保存的修改，请先保存配置。',true);return}try{memberDraft=await api('/api/v1/admin/membership/catalog');memberRender();memberMessage('配置已加载');await memberUsers(1)}catch(e){memberMessage(String(e),true)}}
async function memberSave(){if(memberBusy)return;memberBusy=true;me('memberSave').disabled=true;try{memberCollect();memberDraft.plans.forEach(p=>p.months=Number(p.months));memberDraft=await api('/api/v1/admin/membership/catalog',{method:'PUT',body:JSON.stringify(memberDraft)});memberDirty=false;memberRender();memberMessage('会员配置已保存')}catch(e){memberMessage(String(e),true)}finally{memberBusy=false;me('memberSave').disabled=!memberDraft}}
function memberAddPlan(){memberCollect();memberDraft.plans.push({id:'plan_'+Date.now(),title:'新套餐',months:1,priceInCents:800,originalPriceInCents:0,versionId:memberDraft.versions[0].id,description:'灵活选择',recommended:false,tag:'',enabled:false,sortOrder:memberDraft.plans.length,rightOverrides:[]});memberDirty=true;memberRender();me('memberPlans').lastElementChild.open=true}
function memberAddVersion(){memberCollect();if(memberDraft.versions.some(v=>v.id==='family'))return memberMessage('Family 版本已存在');memberDraft.versions.push({id:'family',title:'Family 会员',description:'家庭共享权益',enabled:false,sortOrder:1,benefitIds:memberDraft.benefits.map(b=>b.id)});memberDirty=true;memberRender()}
function memberAddBenefit(){memberCollect();memberDraft.benefits.push({id:'benefit_'+Date.now(),title:'新权益',subtitle:'权益内容',detail:'权益说明',enabled:false,iconUrl:'',entitlementKeys:[]});memberDirty=true;memberRender();me('memberBenefits').lastElementChild.open=true}
function memberAddIcon(){memberCollect();memberDraft.benefitIcons.push({id:'icon_'+Date.now(),name:'新图标',url:''});memberDirty=true;memberRender();memberMessage('填写 HTTPS 地址后保存，再从权益图标下拉框选择。')}
me('memberConfig').addEventListener('input',()=>{memberDirty=true;memberMessage('有未保存的修改')});window.addEventListener('beforeunload',e=>{if(memberDirty){e.preventDefault();e.returnValue=''}});
const memberDate=v=>v?new Date(v*1000).toLocaleString('zh-CN',{timeZone:'Asia/Shanghai'}):'—';
async function memberUsers(page){try{const r=await api('/api/v1/admin/membership/users?q='+encodeURIComponent(me('memberSearch').value)+'&page='+page);memberPage=r.page;memberUserRows=r.users;me('memberUsers').innerHTML='<table><thead><tr><th>用户</th><th>等级</th><th>状态</th><th>到期时间</th><th>操作</th></tr></thead><tbody>'+r.users.map((u,i)=>'<tr><td>'+esc(u.displayName||u.username)+'<br><span class="muted">'+esc(u.username)+'</span></td><td>'+esc(u.membership.plan)+'</td><td>'+esc({active:'有效',expired:'已过期',canceled:'已取消'}[u.membership.status]||u.membership.status)+'</td><td>'+memberDate(u.subscription?.expiresAt)+'</td><td><button onclick="memberEditUser('+i+')">调整 / 记录</button></td></tr>').join('')+'</tbody></table><p class="muted">第 '+memberPage+' 页 · '+r.users.length+' 位用户</p>'}catch(e){memberMessage(String(e),true)}}
async function memberEditUser(index){try{const u=memberUserRows[index];if(!memberDraft){memberDraft=await api('/api/v1/admin/membership/catalog');memberRender()}me('memberUserId').value=u.id;me('memberUserTitle').textContent='调整会员：'+(u.displayName||u.username);me('memberUserPlan').innerHTML='<option value="">普通用户（取消会员）</option>'+memberDraft.plans.map(p=>'<option value="'+esc(p.id)+'">'+esc(p.title)+' · '+esc(p.versionId)+'</option>').join('');me('memberUserPlan').value=u.subscription?.productId??'';me('memberDays').value=u.subscription?Math.max(1,Math.ceil((u.subscription.expiresAt-Date.now()/1000)/86400)):30;me('memberReason').value='';me('memberUserForm').hidden=false;const h=await api('/api/v1/admin/membership/users/'+encodeURIComponent(u.id)+'/history');me('memberHistory').innerHTML='<h3>会员记录</h3><table><thead><tr><th>时间</th><th>来源</th><th>内容</th></tr></thead><tbody>'+h.orders.map(o=>'<tr><td>'+memberDate(o.createdAt)+'</td><td>'+esc(o.channel)+'</td><td>'+esc(o.productId)+' · ¥'+(o.amountInCents/100).toFixed(2)+' · '+esc(o.status)+'</td></tr>').join('')+h.apple.map(o=>'<tr><td>'+memberDate(o.createdAt)+'</td><td>App Store</td><td>'+esc(o.productId)+' · 到期 '+memberDate(o.expiresAt)+'</td></tr>').join('')+h.adjustments.map(a=>{const d=JSON.parse(a.details);return '<tr><td>'+memberDate(a.createdAt)+'</td><td>后台调整</td><td>'+esc(d.productId??'取消会员')+' · '+esc(d.durationDays)+' 天 · '+esc(d.reason)+'</td></tr>'}).join('')+'</tbody></table>';me('memberUserForm').scrollIntoView({behavior:'smooth',block:'start'})}catch(e){memberMessage(String(e),true)}}
async function memberAdjust(event){event.preventDefault();const button=event.submitter;if(button.disabled)return;button.disabled=true;try{await api('/api/v1/admin/membership/users/'+encodeURIComponent(me('memberUserId').value),{method:'PUT',body:JSON.stringify({productId:me('memberUserPlan').value||null,durationDays:me('memberUserPlan').value?Number(me('memberDays').value):0,reason:me('memberReason').value})});memberMessage('用户会员已调整');me('memberUserForm').hidden=true;me('memberHistory').innerHTML='';await memberUsers(memberPage)}catch(e){memberMessage(String(e),true)}finally{button.disabled=false}}
`;
