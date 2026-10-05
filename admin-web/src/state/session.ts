import { reactive } from 'vue';
import { api } from '../api/console';
import { saveSession,sessionToken } from '../api/client';
import type { Admin } from '../api/types';
export const session=reactive<{admin:Admin|null}>({admin:null});
let loading:Promise<void>|null=null;
export function can(permission:string) {return session.admin?.permissions.includes(permission)??false;}
export async function loadSession() {
  if(session.admin || !sessionToken()) return;
  if(!loading) loading=api.me().then(value=>{session.admin=value;}).finally(()=>{loading=null;});
  return loading;
}
export async function signIn(username:string,password:string) {const value=await api.login(username,password);saveSession(value.token);await loadSession();}
export async function signOut() {try{await api.logout();}finally{session.admin=null;saveSession(null);}}
