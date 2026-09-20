import type { Store } from './store.js';
import { ensureAiControlSchema } from './ai_control.js';
import { recordAiUsage } from './ai_usage.js';
import { ApiError } from './contract.js';

type Row={id:string;base_url:string|null;model:string;secret_env:string|null;timeout_ms:number;config_json:string};
export type BinaryAiResult={text:string;providerId:string;model:string};

function rows(store:Store,feature:string,kind:'asr'|'ocr'):Row[]{
  ensureAiControlSchema(store);
  const route=store.db.prepare('SELECT provider_ids_json FROM ai_routes WHERE feature=?').get(feature) as {provider_ids_json:string}|undefined;
  const get=store.db.prepare('SELECT id,base_url,model,secret_env,timeout_ms,config_json FROM ai_providers WHERE id=? AND kind=? AND enabled=1');
  if(route)return (JSON.parse(route.provider_ids_json) as string[]).map(id=>get.get(id,kind) as Row|undefined).filter((x):x is Row=>Boolean(x));
  return store.db.prepare('SELECT id,base_url,model,secret_env,timeout_ms,config_json FROM ai_providers WHERE kind=? AND enabled=1 ORDER BY priority,id').all(kind) as Row[];
}
export async function transcribeAudio(store:Store,input:{userId:string;bytes:Buffer;filename:string;mime:string;feature?:string}):Promise<BinaryAiResult>{
  const feature=input.feature??'voice.asr';let last='ASR unavailable';
  for(const row of rows(store,feature,'asr')){const started=Date.now();try{
    const key=row.secret_env?process.env[row.secret_env]:undefined;if(!key)throw new Error('secret not configured');
    const form=new FormData();form.set('model',row.model);form.set('file',new Blob([new Uint8Array(input.bytes)],{type:input.mime}),input.filename);
    const response=await fetch(`${(row.base_url??'https://api.openai.com/v1').replace(/\/$/,'')}/audio/transcriptions`,{method:'POST',headers:{Authorization:`Bearer ${key}`},body:form,signal:AbortSignal.timeout(row.timeout_ms)});
    const data=await response.json() as {text?:string};if(!response.ok||!data.text)throw new Error(`HTTP ${response.status}`);
    recordAiUsage(store,{userId:input.userId,feature,providerId:row.id,model:row.model,success:true,latencyMs:Date.now()-started,inputUnits:input.bytes.length});return {text:data.text,providerId:row.id,model:row.model};
  }catch(e){last=String(e);recordAiUsage(store,{userId:input.userId,feature,providerId:row.id,model:row.model,success:false,latencyMs:Date.now()-started,inputUnits:input.bytes.length,errorCode:last.slice(0,120)})}}
  throw new ApiError(503,'语音识别服务暂时不可用');
}
export async function recognizeImage(store:Store,input:{userId:string;bytes:Buffer;mime:string;feature?:string}):Promise<BinaryAiResult>{
  const feature=input.feature??'bill.ocr';let last='OCR unavailable';
  for(const row of rows(store,feature,'ocr')){const started=Date.now();try{
    const key=row.secret_env?process.env[row.secret_env]:undefined;if(!key)throw new Error('secret not configured');
    const cfg=JSON.parse(row.config_json||'{}') as {path?:string};const path=cfg.path??'/ocr';
    const response=await fetch(`${(row.base_url??'').replace(/\/$/,'')}${path}`,{method:'POST',headers:{Authorization:`Bearer ${key}`,'Content-Type':input.mime},body:new Uint8Array(input.bytes),signal:AbortSignal.timeout(row.timeout_ms)});
    const data=await response.json() as {text?:string};if(!response.ok||!data.text)throw new Error(`HTTP ${response.status}`);
    recordAiUsage(store,{userId:input.userId,feature,providerId:row.id,model:row.model,success:true,latencyMs:Date.now()-started,inputUnits:input.bytes.length});return {text:data.text,providerId:row.id,model:row.model};
  }catch(e){last=String(e);recordAiUsage(store,{userId:input.userId,feature,providerId:row.id,model:row.model,success:false,latencyMs:Date.now()-started,inputUnits:input.bytes.length,errorCode:last.slice(0,120)})}}
  throw new ApiError(503,'图片识别服务暂时不可用');
}
