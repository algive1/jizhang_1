import {randomUUID} from 'node:crypto';
import {createApp} from '../../server/src/app.js';
import {encodePassword} from '../../server/src/console/auth.js';
const {app,store}=await createApp(':memory:');
for(const [username,role] of [['browser_admin','super'],['browser_support','support']]) {
  store.db.prepare('INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)').run(randomUUID(),username,await encodePassword('browser-test-password-2026'),role,store.now());
}
await app.inject({method:'POST',url:'/api/v1/auth/register',payload:{username:'browser_user',password:'browser-user-password',displayName:'浏览器测试用户'}});
await app.listen({port:8790,host:'127.0.0.1'});
for(const signal of ['SIGTERM','SIGINT'])process.on(signal,()=>{void app.close();});
