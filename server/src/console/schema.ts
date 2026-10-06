import type { Store } from "../store.js";

export function ensureConsoleSchema(store: Store) {
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS console_roles(id TEXT PRIMARY KEY,name TEXT NOT NULL,permissions_json TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS console_admins(id TEXT PRIMARY KEY,username TEXT UNIQUE NOT NULL,password_hash TEXT NOT NULL,role_id TEXT NOT NULL REFERENCES console_roles(id),enabled INTEGER NOT NULL DEFAULT 1,created_at INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS console_sessions(token_hash TEXT PRIMARY KEY,admin_id TEXT NOT NULL REFERENCES console_admins(id),expires_at INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS console_logins(id INTEGER PRIMARY KEY,username TEXT NOT NULL,success INTEGER NOT NULL,created_at INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS console_audit(id INTEGER PRIMARY KEY,admin_id TEXT NOT NULL,action TEXT NOT NULL,target TEXT NOT NULL,created_at INTEGER NOT NULL);
    CREATE INDEX IF NOT EXISTS console_audit_time ON console_audit(created_at DESC);
    CREATE TABLE IF NOT EXISTS console_user_state(user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,disabled INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE IF NOT EXISTS console_devices(user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,installation_id TEXT NOT NULL,platform TEXT NOT NULL,app_version TEXT NOT NULL,android_version TEXT,brand TEXT,model TEXT,auto_enabled INTEGER,backup_enabled INTEGER,last_seen_at INTEGER NOT NULL,PRIMARY KEY(user_id,installation_id));
    CREATE INDEX IF NOT EXISTS console_devices_seen ON console_devices(last_seen_at);
    CREATE INDEX IF NOT EXISTS console_users_created ON users(created_at);
    CREATE INDEX IF NOT EXISTS console_sessions_user_seen ON sessions(user_id,last_seen_at);
    CREATE INDEX IF NOT EXISTS console_members_user ON members(user_id);
    CREATE TABLE IF NOT EXISTS console_releases(id TEXT PRIMARY KEY,platform TEXT NOT NULL,version_name TEXT NOT NULL,version_code INTEGER NOT NULL,minimum_version TEXT NOT NULL,download_url TEXT NOT NULL,changelog TEXT NOT NULL,rollout INTEGER NOT NULL DEFAULT 100,status TEXT NOT NULL DEFAULT 'draft',created_at INTEGER NOT NULL,published_at INTEGER,updated_by TEXT NOT NULL,UNIQUE(platform,version_code));
    CREATE INDEX IF NOT EXISTS console_releases_platform ON console_releases(platform,status,version_code DESC);
    CREATE TABLE IF NOT EXISTS console_documents(kind TEXT NOT NULL,key TEXT NOT NULL,version INTEGER NOT NULL,payload_json TEXT NOT NULL,note TEXT NOT NULL,created_by TEXT NOT NULL,created_at INTEGER NOT NULL,PRIMARY KEY(kind,key,version));
    CREATE TABLE IF NOT EXISTS console_publications(kind TEXT NOT NULL,key TEXT NOT NULL,version INTEGER NOT NULL,rollout INTEGER NOT NULL,updated_by TEXT NOT NULL,updated_at INTEGER NOT NULL,fallback_version INTEGER,PRIMARY KEY(kind,key),FOREIGN KEY(kind,key,version) REFERENCES console_documents(kind,key,version));
    CREATE TABLE IF NOT EXISTS console_events(user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,event_id TEXT NOT NULL,trace_id TEXT NOT NULL,occurred_at INTEGER NOT NULL,stage TEXT NOT NULL,status TEXT NOT NULL,package_name TEXT NOT NULL,app_version TEXT NOT NULL,rule_version INTEGER,brand TEXT,android_version TEXT,reason TEXT,metadata_json TEXT NOT NULL,created_at INTEGER NOT NULL,PRIMARY KEY(user_id,event_id));
    CREATE INDEX IF NOT EXISTS console_events_trace ON console_events(user_id,trace_id,occurred_at);
    CREATE INDEX IF NOT EXISTS console_events_filter ON console_events(stage,status,occurred_at);
    CREATE INDEX IF NOT EXISTS console_events_package ON console_events(package_name,app_version,rule_version);
    CREATE INDEX IF NOT EXISTS console_events_time ON console_events(occurred_at);
    CREATE TABLE IF NOT EXISTS console_models(id TEXT PRIMARY KEY,name TEXT NOT NULL,provider TEXT NOT NULL,model TEXT NOT NULL,endpoint TEXT NOT NULL,key_ref TEXT NOT NULL,input_price REAL NOT NULL,output_price REAL NOT NULL,max_tokens INTEGER NOT NULL,timeout_ms INTEGER NOT NULL,enabled INTEGER NOT NULL,priority INTEGER NOT NULL,fallback_id TEXT,updated_at INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS console_ai_calls(id TEXT PRIMARY KEY,user_id TEXT,feature TEXT NOT NULL,model TEXT NOT NULL,status TEXT NOT NULL,input_tokens INTEGER,output_tokens INTEGER,cost_microusd INTEGER,duration_ms INTEGER NOT NULL,created_at INTEGER NOT NULL);
    CREATE INDEX IF NOT EXISTS console_ai_calls_time ON console_ai_calls(created_at,model,status);
    CREATE TABLE IF NOT EXISTS console_operations(id TEXT PRIMARY KEY,kind TEXT NOT NULL,title TEXT NOT NULL,body TEXT NOT NULL,enabled INTEGER NOT NULL DEFAULT 0,updated_at INTEGER NOT NULL);
    CREATE INDEX IF NOT EXISTS console_operations_kind ON console_operations(kind,updated_at);
    CREATE TABLE IF NOT EXISTS console_push_campaigns(id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,title TEXT NOT NULL,body TEXT NOT NULL,route TEXT,state TEXT NOT NULL DEFAULT 'draft',device_count INTEGER NOT NULL DEFAULT 0,created_by TEXT NOT NULL,created_at INTEGER NOT NULL,published_at INTEGER);
    CREATE TABLE IF NOT EXISTS console_push_jobs(job_id TEXT PRIMARY KEY REFERENCES push_outbox(id) ON DELETE CASCADE,campaign_id TEXT NOT NULL REFERENCES console_push_campaigns(id) ON DELETE CASCADE);
    CREATE INDEX IF NOT EXISTS console_push_campaign_time ON console_push_campaigns(created_at DESC);
    CREATE INDEX IF NOT EXISTS console_push_campaign_jobs ON console_push_jobs(campaign_id);
    CREATE TABLE IF NOT EXISTS console_migrations(version INTEGER PRIMARY KEY,applied_at INTEGER NOT NULL);
  `);
  store.db
    .prepare("INSERT OR IGNORE INTO console_migrations VALUES(1,?)")
    .run(store.now());
  store.db
    .prepare("INSERT OR IGNORE INTO console_migrations VALUES(2,?)")
    .run(store.now());
  if (
    !store.db.prepare("SELECT 1 FROM console_migrations WHERE version=3").get()
  ) {
    store.db.transaction(() => {
      store.db.exec(`
        ALTER TABLE console_releases ADD COLUMN revision INTEGER NOT NULL DEFAULT 1;
        ALTER TABLE console_releases ADD COLUMN updated_at INTEGER;
        UPDATE console_releases SET updated_at=created_at;
        ALTER TABLE console_sessions ADD COLUMN session_id TEXT;
        ALTER TABLE console_sessions ADD COLUMN created_at INTEGER;
        ALTER TABLE console_sessions ADD COLUMN last_seen_at INTEGER;
        UPDATE console_sessions SET session_id=lower(hex(randomblob(16)));
        CREATE UNIQUE INDEX console_session_id ON console_sessions(session_id);
        CREATE INDEX console_logins_time ON console_logins(created_at DESC);
      `);
      store.db
        .prepare("INSERT INTO console_migrations VALUES(3,?)")
        .run(store.now());
    })();
  }
}
