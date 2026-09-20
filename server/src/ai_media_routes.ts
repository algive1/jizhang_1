import type { FastifyInstance } from 'fastify';
import type { Store } from './store.js';
import { ApiError } from './contract.js';
import { transcribeAudio, recognizeImage } from './ai_binary_runtime.js';

type Authenticate=(header:string|undefined)=>{id:string};
function bodyBuffer(body:unknown,max:number){if(Buffer.isBuffer(body)){if(body.length>max)throw new ApiError(413,'上传内容过大');return body}if(body instanceof Uint8Array){const b=Buffer.from(body);if(b.length>max)throw new ApiError(413,'上传内容过大');return b}throw new ApiError(400,'请求体必须为二进制内容')}
export function registerAiMediaRoutes(app:FastifyInstance,store:Store,authenticate:Authenticate){
  app.post('/api/v1/ai/asr',{config:{rateLimit:{max:20,timeWindow:'1 minute'}}},async req=>{
    const user=authenticate(req.headers.authorization);const mime=String(req.headers['content-type']??'audio/m4a').split(';')[0]!;
    if(!mime.startsWith('audio/'))throw new ApiError(415,'仅支持音频内容');
    const result=await transcribeAudio(store,{userId:user.id,bytes:bodyBuffer(req.body,20*1024*1024),filename:String(req.headers['x-filename']??'voice.m4a').slice(0,120),mime});
    return {text:result.text,source:'asr',providerId:result.providerId};
  });
  app.post('/api/v1/ai/ocr',{config:{rateLimit:{max:30,timeWindow:'1 minute'}}},async req=>{
    const user=authenticate(req.headers.authorization);const mime=String(req.headers['content-type']??'image/jpeg').split(';')[0]!;
    if(!mime.startsWith('image/'))throw new ApiError(415,'仅支持图片内容');
    const result=await recognizeImage(store,{userId:user.id,bytes:bodyBuffer(req.body,12*1024*1024),mime});
    return {text:result.text,source:'ocr',providerId:result.providerId};
  });
}
