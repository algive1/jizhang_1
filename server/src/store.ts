import Database from 'better-sqlite3';
import { randomUUID } from 'node:crypto';
import { ApiError, requireCondition as check, schemas, type Kind, type Data, type Entity, type Mutation } from './contract.js';
export type Role = 'owner' | 'admin' | 'member';
export interface Book { id: string; name: string; type: string; owner_user_id: string; created_at: number; updated_at: number; is_archived: number; version: number }
export class Store {
  readonly db: Database.Database;
  constructor(path: string) {
    this.db = new Database(path);
    this.db.pragma('foreign_keys = ON');
    this.db.pragma('journal_mode = WAL');
    const version = this.db.pragma('user_version', { simple: true }) as number;
    check(version <= 1, '服务端数据库版本过新', 500);
    if (version < 1) this.db.transaction(() => {
      this.db.exec(`
        CREATE TABLE users(id TEXT PRIMARY KEY, username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, created_at INTEGER NOT NULL);
        CREATE TABLE sessions(token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), expires_at INTEGER NOT NULL);
        CREATE TABLE books(id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, owner_user_id TEXT NOT NULL REFERENCES users(id), created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, is_archived INTEGER NOT NULL DEFAULT 0, version INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE members(book_id TEXT NOT NULL REFERENCES books(id), user_id TEXT NOT NULL REFERENCES users(id), role TEXT NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY(book_id,user_id));
        CREATE TABLE invitations(id TEXT PRIMARY KEY, book_id TEXT NOT NULL REFERENCES books(id), code TEXT UNIQUE NOT NULL, invited_by TEXT NOT NULL REFERENCES users(id), expires_at INTEGER NOT NULL, status TEXT NOT NULL);
        CREATE TABLE entities(book_id TEXT NOT NULL REFERENCES books(id),kind TEXT NOT NULL,id TEXT NOT NULL,version INTEGER NOT NULL,data_json TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(book_id,kind,id));
        CREATE TABLE changes(seq INTEGER PRIMARY KEY AUTOINCREMENT,book_id TEXT NOT NULL,kind TEXT NOT NULL,entity_id TEXT NOT NULL,version INTEGER NOT NULL,deleted INTEGER NOT NULL,data_json TEXT NOT NULL,actor_id TEXT NOT NULL,created_at INTEGER NOT NULL);
        CREATE INDEX idx_changes_book ON changes(book_id,seq);
        CREATE TABLE operations(user_id TEXT NOT NULL,operation_id TEXT NOT NULL,book_id TEXT NOT NULL,result_json TEXT NOT NULL,PRIMARY KEY(user_id,operation_id));
        PRAGMA user_version=1;
      `);
    })();
    this.db.exec('CREATE TABLE IF NOT EXISTS book_import_versions(book_id TEXT NOT NULL,kind TEXT NOT NULL,entity_id TEXT NOT NULL,version INTEGER NOT NULL,PRIMARY KEY(book_id,kind,entity_id))');
  }
  now() { return Math.floor(Date.now()/1000); }
  book(id: string): Book {
    const book = this.db.prepare('SELECT * FROM books WHERE id=?').get(id) as Book | undefined;
    check(book, '账本不存在', 404); return book;
  }
  role(book: string, user: string): Role {
    const member = this.db.prepare('SELECT role FROM members WHERE book_id=? AND user_id=?').get(book,user) as {role: Role} | undefined;
    check(member, '你已不在该共享账本中', 403); return member.role;
  }
  writable(book: string, user: string) {
    const role = this.role(book,user); check(!this.book(book).is_archived, '账本已归档', 403); return role;
  }
  manager(book: string, user: string) { check(this.writable(book,user) !== 'member', '只有所有者或管理员可以操作',403); }
  list(user: string) { return this.db.prepare('SELECT b.*,m.role FROM books b JOIN members m ON m.book_id=b.id WHERE m.user_id=?').all(user); }
  get(book: string, kind: Kind, id: string): Entity | undefined {
    if (kind === 'books') { const b = this.book(book); return {kind,id:book,version:b.version,deleted:!!b.is_archived,data:{...b,family_id:book}}; }
    const row = this.db.prepare('SELECT * FROM entities WHERE book_id=? AND kind=? AND id=?').get(book,kind,id) as {version:number;deleted:number;data_json:string} | undefined;
    return row && {kind,id,version:row.version,deleted:!!row.deleted,data:JSON.parse(row.data_json) as Data};
  }
  all(book: string, kind?: Kind): Entity[] {
    const rows = (kind ? this.db.prepare('SELECT * FROM entities WHERE book_id=? AND kind=?').all(book,kind) : this.db.prepare('SELECT * FROM entities WHERE book_id=?').all(book)) as {kind:Kind;id:string;version:number;deleted:number;data_json:string}[];
    return rows.map(r => ({kind:r.kind,id:r.id,version:r.version,deleted:!!r.deleted,data:JSON.parse(r.data_json) as Data}));
  }
  snapshot(book: string, user: string) {
    const role = this.role(book,user);
    return {book:{...this.book(book),family_id:book},role,entities:this.all(book),cursor:this.cursor(book)};
  }
  cursor(book: string) { return (this.db.prepare('SELECT COALESCE(MAX(seq),0) AS n FROM changes WHERE book_id=?').get(book) as {n:number}).n; }
  changes(book: string, user: string, cursor: number) {
    this.role(book,user);
    const rows = this.db.prepare('SELECT * FROM changes WHERE book_id=? AND seq>? ORDER BY seq LIMIT 500').all(book,cursor) as {seq:number;kind:Kind;entity_id:string;version:number;deleted:number;data_json:string}[];
    return {changes:rows.map(r=>({seq:r.seq,kind:r.kind,id:r.entity_id,version:r.version,deleted:!!r.deleted,data:JSON.parse(r.data_json) as Data})),cursor:rows.at(-1)?.seq ?? cursor,hasMore:rows.length===500};
  }
  write(book: string, kind: Kind, id: string, data: Data, actor: string, deleted = false): Entity {
    const version = (kind === 'books' ? this.book(book).version : this.get(book,kind,id)?.version ?? 0) + 1;
    if (kind === 'books') this.db.prepare('UPDATE books SET name=?,is_archived=?,updated_at=?,version=? WHERE id=?').run(data.name,data.is_archived,this.now(),version,book);
    else this.db.prepare('INSERT INTO entities VALUES(?,?,?,?,?,?) ON CONFLICT(book_id,kind,id) DO UPDATE SET version=excluded.version,data_json=excluded.data_json,deleted=excluded.deleted').run(book,kind,id,version,JSON.stringify(data),Number(deleted));
    const canonical = kind === 'books' ? {...this.book(book),family_id:book} : data;
    this.db.prepare('INSERT INTO changes(book_id,kind,entity_id,version,deleted,data_json,actor_id,created_at) VALUES(?,?,?,?,?,?,?,?)').run(book,kind,id,version,Number(deleted),JSON.stringify(canonical),actor,this.now());
    return {kind,id,version,deleted,data:canonical};
  }
  create(user: string, id: string, name: string, type: string, entities: Array<{kind:Kind;id:string;data:Data}>) {
    return this.db.transaction(() => {
      const existing = this.db.prepare('SELECT * FROM books WHERE id=?').get(id) as Book | undefined;
      if (existing) { check(existing.owner_user_id===user,'账本标识已被使用',409); return this.importSnapshot(id,user); }
      const owned = (this.db.prepare('SELECT COUNT(*) n FROM books WHERE owner_user_id=? AND is_archived=0').get(user) as {n:number}).n;
      check(owned<3,'已达到三个自建共享账本上限',409);
      this.db.prepare('INSERT INTO books VALUES(?,?,?,?,?,?,0,1)').run(id,name,type,user,this.now(),this.now());
      this.db.prepare('INSERT INTO members VALUES(?,?,?,?)').run(id,user,'owner',this.now());
      const rank: Record<Kind,number> = {books:0,accounts:1,categories:2,goals:3,goal_milestones:4,transactions:5,goal_contributions:6,budgets:7};
      const sorted = [...entities].sort((a,b)=>rank[a.kind]-rank[b.kind] || Number(a.data.parent_id!=null)-Number(b.data.parent_id!=null));
      for (const e of sorted) {
        check(e.kind!=='books','快照不能包含其他账本');
        const data = schemas[e.kind].parse(e.data);
        check(data.id===e.id && (!('book_id' in data) || data.book_id===id),'数据不属于目标账本');
        if (e.kind==='transactions') this.validateMetadata(data);
        if (e.kind==='transactions') Object.assign(data,{created_by:user,updated_by:user,user_id:user,visibility:'shared',sync_status:'synced'});
        if (e.kind==='goals') Object.assign(data,{created_by:user,updated_by:user});
        if (e.kind==='goal_contributions') data.contributor_user_id=user;
        check(!this.get(id,e.kind,e.id),'快照中记录标识重复');
        this.write(id,e.kind,e.id,data,user);
      }
      this.validateAndRecalculate(id,user);
      for(const e of this.all(id)) this.db.prepare('INSERT INTO book_import_versions VALUES(?,?,?,?)').run(id,e.kind,e.id,e.version);
      this.db.prepare('INSERT INTO book_import_versions VALUES(?,?,?,?)').run(id,'books',id,1);
      return this.importSnapshot(id,user);
    })();
  }
  importSnapshot(book:string,user:string) {
    return {...this.snapshot(book,user),initialVersions:this.db.prepare('SELECT kind,entity_id AS id,version FROM book_import_versions WHERE book_id=?').all(book)};
  }
  mutate(book: string, user: string, operations: Mutation[]) {
    return this.db.transaction(() => {
      const role=this.writable(book,user);
      const seen=new Set<string>();
      const applied: Array<{operationId:string;kind:Kind;id:string;version:number}>=[];
      for (const op of operations) {
        const receipt=this.db.prepare('SELECT book_id,result_json FROM operations WHERE user_id=? AND operation_id=?').get(user,op.operationId) as {book_id:string;result_json:string}|undefined;
        if (receipt) { check(receipt.book_id===book,'操作标识已被使用',409); applied.push(JSON.parse(receipt.result_json)); continue; }
        const previous=this.get(book,op.kind,op.id);
        if (role==='member') check(op.kind==='transactions' && (!previous || previous.data.created_by===user) && op.data.type!=='adjustment','没有修改这项数据的权限',403);
        if (op.kind==='books') { check(op.id===book,'账本标识不匹配'); if (op.data.is_archived===1) check(role==='owner','只有所有者可以归档账本',403); }
        if (previous?.deleted && op.action!=='delete' && !['budgets','goal_milestones'].includes(op.kind)) throw new ApiError(409,'记录已删除', {operationId:op.operationId,remote:previous});
        const key=op.kind+':'+op.id;
        if (!seen.has(key) && (previous?.version??0)!==op.expectedVersion) throw new ApiError(409,'记录已被其他成员修改',{operationId:op.operationId,remote:previous??null});
        seen.add(key);
        if (op.kind==='goal_contributions' && previous) throw new ApiError(409,'目标贡献不可覆盖，请追加调整记录',{operationId:op.operationId,remote:previous});
        if (op.action==='delete') {
          check(previous,'记录不存在',404);
          check(['budgets','goal_milestones'].includes(op.kind),'此记录需要归档或软删除');
        }
        const data=op.action==='delete' ? {...previous!.data} : schemas[op.kind].parse(op.data);
        check(data.id===op.id && (!('book_id' in data) || data.book_id===book),'记录与账本不匹配');
        if (op.kind==='transactions') {
          if (!previous) {for(const field of ['account_id','destination_account_id']) if(data[field]) check(this.get(book,'accounts',String(data[field]))?.data.is_archived===0,'新流水不能使用已归档或不存在的账户');}
          if (previous) check(data.created_at===previous.data.created_at,'不能修改创建时间');
          Object.assign(data,{created_by:previous?.data.created_by??user,updated_by:user,user_id:previous?.data.user_id??user,visibility:'shared',sync_status:'synced'});
          if (data.type==='adjustment' && !previous) {
            const account=this.get(book,'accounts',String(data.account_id));
            if (account?.version!==op.expectedAccountVersion) throw new ApiError(409,'校准期间账户余额已改变',{operationId:op.operationId,remote:account});
          }
          this.validateMetadata(data);
        }
        if (op.kind==='accounts' && previous) check(data.opening_balance_in_cents===previous.data.opening_balance_in_cents && data.currency===previous.data.currency,'已有账户需通过余额校准调整，不能改变币种');
        if (op.kind==='books') check(data.type===this.book(book).type && data.owner_user_id===this.book(book).owner_user_id,'共享后不能修改类型或所有者');
        if (op.kind==='goals') Object.assign(data,{created_by:previous?.data.created_by??user,updated_by:user});
        if (op.kind==='goal_contributions') {
          data.contributor_user_id=user;
          if (data.type==='adjustment') {
            const goal=this.get(book,'goals',String(data.goal_id));
            if (goal?.version!==op.expectedGoalVersion && !seen.has('goals:'+String(data.goal_id))) throw new ApiError(409,'调整期间目标金额已改变',{operationId:op.operationId,remote:goal});
          }
        }
        const result=this.write(book,op.kind,op.id,data,user,op.action==='delete');
        const receiptData={operationId:op.operationId,kind:op.kind,id:op.id,version:result.version};
        this.db.prepare('INSERT INTO operations VALUES(?,?,?,?)').run(user,op.operationId,book,JSON.stringify(receiptData));
        applied.push(receiptData);
      }
      this.validateAndRecalculate(book,user);
      return {applied,...this.snapshot(book,user)};
    })();
  }
  validateMetadata(data:Data) {
    if (!data.metadata_json) return;
    let metadata:unknown;
    try { metadata=JSON.parse(String(data.metadata_json)); }
    catch { throw new ApiError(400,'流水附加数据无效'); }
    check(typeof metadata==='object' && metadata!==null && !Array.isArray(metadata) && Object.keys(metadata).every(k=>k==='tags'),'共享流水不能包含通知原文或附件路径');
    if ('tags' in metadata) check(Array.isArray(metadata.tags) && metadata.tags.length<=100 && metadata.tags.every(t=>typeof t==='string' && t.length<=200),'标签格式无效');
  }
  validateAndRecalculate(book: string, actor: string) {
    const live=(kind:Kind)=>this.all(book,kind).filter(e=>!e.deleted);
    const accounts=new Map(live('accounts').map(e=>[e.id,e]));
    const categories=new Map(live('categories').map(e=>[e.id,e]));
    const goals=new Map(live('goals').map(e=>[e.id,e]));
    const balances=new Map([...accounts].map(([id,e])=>[id,Number(e.data.opening_balance_in_cents)]));
    for (const c of categories.values()) if(c.data.parent_id) {const p=categories.get(String(c.data.parent_id));check(p && !p.data.parent_id && p.data.type===c.data.type && p.id!==c.id,'分类父级必须属于同一本账且仅支持两级');}
    for (const e of live('transactions')) {
      const d=e.data; const account=accounts.get(String(d.account_id));
      check(account && account.data.currency===d.currency,'流水账户不存在或币种不一致');
      for(const key of ['category_id','subcategory_id']) if(d[key]) check(categories.has(String(d[key])),'流水分类不属于本账本');
      if(d.subcategory_id) check(categories.get(String(d.subcategory_id))!.data.parent_id===d.category_id,'子分类与主分类不匹配');
      const amount=Number(d.amount_in_cents);check(Number.isSafeInteger(amount) && (d.type==='adjustment' ? amount!==0 : amount>0),'流水金额无效');
      if(d.original_transaction_id) check(this.get(book,'transactions',String(d.original_transaction_id)),'关联原流水不属于本账本');
      if(d.type==='transfer') {const destination=accounts.get(String(d.destination_account_id));check(destination && destination.id!==account.id && destination.data.currency===d.currency,'转账需使用本账本的两个同币种账户');}
      if(d.deleted_at!=null) continue;
      const outgoing=['expense','lend','repayment','assetPurchase','transfer'].includes(String(d.type));
      balances.set(account.id,balances.get(account.id)!+(outgoing?-amount:amount));
      if(d.type==='transfer') {
        const destination=accounts.get(String(d.destination_account_id));check(destination && destination.id!==account.id && destination.data.currency===d.currency,'转账需使用本账本的两个同币种账户');
        balances.set(destination.id,balances.get(destination.id)!+amount);
      }
    }
    for(const [id,balance] of balances) {check(Number.isSafeInteger(balance),'余额超出范围');const account=accounts.get(id)!;if(account.data.balance_in_cents!==balance)this.write(book,'accounts',id,{...account.data,balance_in_cents:balance},actor);}
    const budgetKeys=new Set<string>();
    for(const b of live('budgets')) {if(b.data.category_id)check(categories.has(String(b.data.category_id)),'预算分类不属于本账本');const key=String(b.data.month_key)+':'+String(b.data.category_id??'');check(!budgetKeys.has(key),'同月同分类已有预算');budgetKeys.add(key);}
    const totals=new Map([...goals.keys()].map(id=>[id,0]));
    for(const c of live('goal_contributions')) {check(goals.has(String(c.data.goal_id)),'贡献的目标不存在');if(c.data.source_transaction_id)check(this.get(book,'transactions',String(c.data.source_transaction_id)),'贡献关联流水不存在');const amount=Number(c.data.amount_in_cents);check(c.data.type==='adjustment'||amount>0,'贡献金额无效');totals.set(String(c.data.goal_id),totals.get(String(c.data.goal_id))!+(c.data.type==='withdraw'?-amount:amount));}
    for(const [id,total] of totals) {
      check(total>=0 && Number.isSafeInteger(total),'目标金额不能为负数或超出范围');const goal=goals.get(id)!;
      const status=['archived','paused'].includes(String(goal.data.status)) ? goal.data.status : total>=Number(goal.data.target_amount_in_cents)?'completed':'active';
      if(goal.data.current_amount_in_cents!==total||goal.data.status!==status)this.write(book,'goals',id,{...goal.data,current_amount_in_cents:total,status},actor);
      const milestones=live('goal_milestones').filter(m=>m.data.goal_id===id);
      check(milestones.some(m=>m.data.amount_in_cents===goal.data.target_amount_in_cents),'目标节点必须包含最终金额');
      check(new Set(milestones.map(m=>m.data.amount_in_cents)).size===milestones.length,'目标节点金额不能重复');
      for(const m of milestones) {check(Number(m.data.amount_in_cents)<=Number(goal.data.target_amount_in_cents),'节点不能高于最终目标');if(total>=Number(m.data.amount_in_cents)&&m.data.completed_at==null)this.write(book,'goal_milestones',m.id,{...m.data,completed_at:this.now()},actor);}
    }
    for(const m of live('goal_milestones'))check(goals.has(String(m.data.goal_id)),'节点的目标不存在');
  }
  invite(book: string,user: string) {
    return this.db.transaction(()=>{this.manager(book,user);const invitation={id:randomUUID(),book_id:book,code:randomUUID().replaceAll('-',''),invited_by:user,expires_at:this.now()+7*86400,status:'pending'};this.db.prepare('INSERT INTO invitations VALUES(@id,@book_id,@code,@invited_by,@expires_at,@status)').run(invitation);return invitation;})();
  }
  accept(code:string,user:string) {
    return this.db.transaction(()=>{const invitation=this.db.prepare('SELECT * FROM invitations WHERE code=?').get(code) as {id:string;book_id:string;expires_at:number;status:string}|undefined;check(invitation&&invitation.status==='pending'&&invitation.expires_at>this.now(),'邀请无效、已使用或已过期',409);check(!this.book(invitation.book_id).is_archived,'账本已归档',403);check(!this.db.prepare('SELECT 1 FROM members WHERE book_id=? AND user_id=?').get(invitation.book_id,user),'你已是该账本成员',409);this.db.prepare('INSERT INTO members VALUES(?,?,?,?)').run(invitation.book_id,user,'member',this.now());this.db.prepare("UPDATE invitations SET status='accepted' WHERE id=?").run(invitation.id);return this.snapshot(invitation.book_id,user);})();
  }
  memberChange(book:string,actor:string,target:string,role?:'admin'|'member') {
    return this.db.transaction(()=>{const actorRole=this.writable(book,actor);const targetRole=this.role(book,target);check(targetRole!=='owner','所有者不能退出或被移除',403);if(role){check(actorRole==='owner','只有所有者可以设置角色',403);this.db.prepare('UPDATE members SET role=? WHERE book_id=? AND user_id=?').run(role,book,target);}else{check(actor===target||actorRole==='owner'||(actorRole==='admin'&&targetRole==='member'),'没有移除该成员的权限',403);this.db.prepare('DELETE FROM members WHERE book_id=? AND user_id=?').run(book,target);}this.db.prepare('INSERT INTO changes(book_id,kind,entity_id,version,deleted,data_json,actor_id,created_at) VALUES(?,?,?,?,?,?,?,?)').run(book,'members',target,0,Number(!role),JSON.stringify({role:role??null}),actor,this.now());return {ok:true};})();
  }
}
