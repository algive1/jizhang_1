import { z } from 'zod';
import type { Store } from './store.js';
import { AssistantModelUnavailable, type AssistantModelProvider } from './assistant_ai.js';
import { ensureAiControlSchema } from './ai_control.js';
import { recordAiUsage } from './ai_usage.js';

const responseSchema=z.object({choices:z.array(z.object({message:z.object({content:z.string()})})).min(1),usage:z.object({prompt_tokens:z.number().optional(),completion_tokens:z.number().optional()}).optional()});
type ProviderRow={id:string;base_url:string|null;model:string;secret_env:string|null;timeout_ms:number;config_json:string};

export class RoutedAssistantProvider implements AssistantModelProvider{
  constructor(private readonly store:Store,private readonly feature='assistant.chat'){}
  private providers():ProviderRow[]{
    ensureAiControlSchema(this.store);
    const route=this.store.db.prepare('SELECT provider_ids_json FROM ai_routes WHERE feature=?').get(this.feature) as {provider_ids_json:string}|undefined;
    if(route){
      const ids=JSON.parse(route.provider_ids_json) as string[];
      const get=this.store.db.prepare("SELECT id,base_url,model,secret_env,timeout_ms,config_json FROM ai_providers WHERE id=? AND kind='llm' AND enabled=1");
      return ids.map(id=>get.get(id) as ProviderRow|undefined).filter((x):x is ProviderRow=>Boolean(x));
    }
    return this.store.db.prepare("SELECT id,base_url,model,secret_env,timeout_ms,config_json FROM ai_providers WHERE kind='llm' AND enabled=1 ORDER BY priority,id").all() as ProviderRow[];
  }
  async complete(input:{systemPrompt:string;userText:string}):Promise<string>{
    const rows=this.providers();
    if(!rows.length && process.env.DEEPSEEK_API_KEY)rows.push({id:'env.deepseek',base_url:process.env.DEEPSEEK_BASE_URL??'https://api.deepseek.com',model:process.env.DEEPSEEK_MODEL??'deepseek-chat',secret_env:'DEEPSEEK_API_KEY',timeout_ms:30000,config_json:'{}'});
    if(!rows.length)throw new AssistantModelUnavailable('No enabled LLM provider route');
    let last='provider unavailable';
    for(const row of rows){
      const started=Date.now(),secret=row.secret_env?process.env[row.secret_env]:undefined;
      try{
        if(!secret)throw new Error('secret not configured');
        const base=(row.base_url??'https://api.deepseek.com').replace(/\/$/,'');
        const config=JSON.parse(row.config_json||'{}') as Record<string,unknown>;
        const response=await fetch(`${base}/chat/completions`,{method:'POST',headers:{Authorization:`Bearer ${secret}`,'Content-Type':'application/json'},body:JSON.stringify({model:row.model,messages:[{role:'system',content:input.systemPrompt},{role:'user',content:input.userText}],temperature:Number(config.temperature??0.2),max_tokens:Number(config.maxTokens??512),stream:false}),signal:AbortSignal.timeout(row.timeout_ms)});
        if(!response.ok)throw new Error(`HTTP ${response.status}`);
        const parsed=responseSchema.safeParse(await response.json());if(!parsed.success)throw new Error('invalid response');
        const content=parsed.data.choices[0]!.message.content.trim();if(!content)throw new Error('empty response');
        recordAiUsage(this.store,{feature:this.feature,providerId:row.id,model:row.model,success:true,latencyMs:Date.now()-started,inputUnits:parsed.data.usage?.prompt_tokens,outputUnits:parsed.data.usage?.completion_tokens});
        return content.slice(0,4000);
      }catch(error){
        last=String(error);recordAiUsage(this.store,{feature:this.feature,providerId:row.id,model:row.model,success:false,latencyMs:Date.now()-started,errorCode:last.slice(0,120)});
      }
    }
    throw new AssistantModelUnavailable(last);
  }
}
