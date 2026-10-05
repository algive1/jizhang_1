import type { Query } from './types';
const tokenKey='haohao-console-session';
export const sessionToken=()=>sessionStorage.getItem(tokenKey);
export function saveSession(token:string|null) {if(token) sessionStorage.setItem(tokenKey,token);else sessionStorage.removeItem(tokenKey);}
export class ApiError extends Error {constructor(message:string,public status:number) {super(message);}}
export async function request<T>(path:string,options:{method?:string;body?:unknown;query?:Query;signal?:AbortSignal}={}):Promise<T> {
  const query=new URLSearchParams();
  for(const [key,value] of Object.entries(options.query??{})) if(value!==undefined && value!=='') query.set(key,String(value));
  const token=sessionToken();
  const response=await fetch(`/api/v1/console${path}${query.size?'?'+query:''}`,{method:options.method??'GET',headers:{...(token?{Authorization:`Bearer ${token}`}:{}) ,...(options.body===undefined?{}:{'Content-Type':'application/json'})},body:options.body===undefined?undefined:JSON.stringify(options.body),signal:options.signal?AbortSignal.any([options.signal,AbortSignal.timeout(15000)]):AbortSignal.timeout(15000)});
  const result=await response.json() as {data:T;message?:string};
  if(!response.ok) {if(response.status===401 && path!=='/auth/login') {saveSession(null);window.dispatchEvent(new Event('session-expired'));}throw new ApiError(result.message??'服务请求失败，请重试',response.status);}
  return result.data;
}
