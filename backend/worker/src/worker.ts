import { DurableObject } from 'cloudflare:workers';
import { Failure } from '../../functions/src/errors.js';
import { VerificationService, type Actor } from '../../functions/src/service.js';
import { authorize } from './auth.js';
import { methods, invoke, failureResponse, type Method } from './api.js';
import { workerConfig, MODEL, type Env } from './config.js';
import { DurableStore, cleanup } from './store.js';
import { GeminiVerifier, boundedJSON } from './gemini.js';
import { prepareDemoEvidence } from './evidence.js';
export class VerificationHub extends DurableObject<Env> {
 private readonly service:VerificationService;
 constructor(ctx:DurableObjectState,env:Env) {
  super(ctx,env);
  this.service=new VerificationService(new DurableStore(ctx.storage),new GeminiVerifier(ctx.storage,ctx,env.GEMINI_API_KEY??''),workerConfig(env),prepareDemoEvidence);
 }
 async fetch(request:Request) {
  try {
   const method=new URL(request.url).pathname.slice(1) as Method;
   if(!Object.hasOwn(methods,method))throw new Failure('not-found','Endpoint not found');
   const {actor,data}=await request.json<{actor:Actor;data:unknown}>();
   const response=await invoke(this.service,method,actor,data);
   if(await this.ctx.storage.getAlarm()===null)await this.ctx.storage.setAlarm(Date.now()+2*86400000);
   return response;
  }catch(error){return failureResponse(error);}
 }
 async alarm(){await cleanup(this.ctx.storage);}
}
export default {
 async fetch(request:Request,env:Env):Promise<Response> {
  const started=Date.now(),path=new URL(request.url).pathname;
  try {
   if(path==='/health'&&request.method==='GET')return Response.json({status:'ok',mode:'synthetic-demo',model:MODEL,enabled:env.AI_VERIFICATION_ENABLED==='true'},{headers:{'Cache-Control':'no-store'}});
   const method=path.slice(1) as Method;
   if(!Object.hasOwn(methods,method))throw new Failure('not-found','Endpoint not found');
   if(request.method!=='POST'||request.headers.get('Content-Type')?.split(';')[0].trim()!=='application/json')throw new Failure('invalid-argument','Use a JSON POST request');
   workerConfig(env);
   const actor=await authorize(request,env);
   let input;
   try {input=await boundedJSON(new Response(request.body),32768);}catch{throw new Failure('invalid-argument','Invalid request body');}
   if(!input||typeof input!=='object'||Object.keys(input).length!==1||!Object.hasOwn(input,'data'))throw new Failure('invalid-argument','Expected callable data');
   // A new object name applies the placement hint; existing objects do not move.
   const hub=env.VERIFICATIONS.get(env.VERIFICATIONS.idFromName('free-pilot-enam-v1'),{locationHint:'enam'});
   const response=await hub.fetch(new Request(`https://internal/${method}`,{method:'POST',body:JSON.stringify({actor,data:input.data})}));
   try{console.info(JSON.stringify({event:'demo_request',operation:method,httpStatus:response.status,durationMs:Date.now()-started}));}catch{/* Metrics cannot change a response. */}
   return response;
  }catch(error){return failureResponse(error);}
 },
};
