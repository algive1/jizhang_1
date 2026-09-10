import { mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { createApp } from './app.js';
const file=resolve(process.env.LEDGER_DB_PATH??'data/shared-ledger.sqlite');
mkdirSync(dirname(file),{recursive:true});
const {app}=await createApp(file);
const address=await app.listen({host:'127.0.0.1',port:Number(process.env.PORT??8787)});
console.log(`Shared ledger listening at ${address}`);
for(const signal of ['SIGINT','SIGTERM']) process.on(signal,()=>{void app.close();});
