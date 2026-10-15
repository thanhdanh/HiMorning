import { z } from 'zod';
export interface Config { enabled:boolean; model:string; baseURL:string; userDailyLimit:number; globalDailyLimit:number; consentVersion?:string }
export function readConfig(env:Record<string,string|undefined>):Config {
 const enabled=z.enum(['true','false']).parse(env.AI_VERIFICATION_ENABLED??'false')==='true';
 const cap=(value:string|undefined,fallback:number,max:number)=>z.coerce.number().int().min(1).max(max).parse(value??fallback);
 let baseURL=env.AI_BASE_URL??'';
 if(baseURL||enabled){let url:URL;try{url=new URL(baseURL);}catch{throw new Error('Invalid AI_BASE_URL');}if(url.protocol!=='https:'||!url.hostname.endsWith('.modal.run')||url.username||url.password||url.port||url.search||url.hash||url.pathname!=='/')throw new Error('AI_BASE_URL must be a Modal HTTPS origin');baseURL=url.origin;}
 return {enabled,baseURL,model:z.string().min(1).max(100).parse(env.AI_MODEL??'qwen_qwen3.5-9b'),userDailyLimit:cap(env.AI_USER_DAILY_LIMIT,3,20),globalDailyLimit:cap(env.AI_GLOBAL_DAILY_LIMIT,10,10000)};
}
