import { describe,it,expect,vi } from 'vitest';
import { createLocalJWKSet,exportJWK,generateKeyPair,SignJWT,type JWTPayload } from 'jose';
import fixture from '../../../shared/contracts/v1/free-demo-frames.json';
import { authorize } from '../src/auth.js';
import { workerConfig } from '../src/config.js';
import { DurableStore,cleanup } from '../src/store.js';
import { prepareDemoEvidence } from '../src/evidence.js';
import { boundedJSON,GeminiVerifier,parseVerdict } from '../src/gemini.js';
import { failureResponse,invoke,decodeCallable } from '../src/api.js';
import { VerificationService } from '../../functions/src/service.js';
import { Failure } from '../../functions/src/errors.js';
import { env,actor,create,submit,uuid,completion,MemoryStorage } from './helpers.js';
describe('free demo trust boundaries',()=>{
 it('decodes native callable integers before strict domain validation',()=>{
  const wrap=(value:unknown,type='Int64Value')=>({'@type':`type.googleapis.com/google.protobuf.${type}`,value});
  expect(decodeCallable({target:wrap('3'),frames:[{timestampMs:wrap('1200','UInt64Value')}],other:null})).toEqual({target:3,frames:[{timestampMs:1200}],other:null});
  for(const value of [wrap('9007199254740992'),wrap('-1','UInt64Value'),wrap('1.5'),wrap(3),wrap('3','Unknown'),{...wrap('3'),extra:true}])expect(()=>decodeCallable(value)).toThrow('Invalid callable integer');
  let nested:unknown=0;for(let i=0;i<12;i++)nested=[nested];
  expect(()=>decodeCallable(nested)).toThrow('too deeply nested');
 });
 it('accepts only exact generated fixtures, rejecting camera substitutions before inference',async()=>{
  const session={sessionID:'a'.repeat(64),nonce:uuid(1)},data=submit(session);
  expect((await prepareDemoEvidence(data,1)).frames).toHaveLength(5);
  for(const frames of [data.frames.slice(1),[...data.frames].reverse(),data.frames.map((frame,i)=>i?frame:{...frame,jpegBase64:fixture.frames[7].jpegBase64}),data.frames.map((frame,i)=>i?frame:{...frame,id:'f9'})])await expect(prepareDemoEvidence({...data,frames},1)).rejects.toMatchObject({code:'invalid-argument'});
 });
 it('pins the free model, default quotas and a separate consent boundary',()=>{
  expect(workerConfig(env)).toMatchObject({model:'gemini-3.5-flash-lite',userDailyLimit:3,globalDailyLimit:10,consentVersion:'2026-10-15-free-demo'});
  for(const bad of [{FIREBASE_APP_ID:''},{FIREBASE_PROJECT_ID:'../other'},{FIREBASE_PROJECT_NUMBER:'not-a-number'},{AI_VERIFICATION_ENABLED:'yes'},{GEMINI_API_KEY:''}])expect(()=>workerConfig({...env,...bad})).toThrow();
  expect(workerConfig({...env,AI_VERIFICATION_ENABLED:'false',GEMINI_API_KEY:''}).enabled).toBe(false);
 });
 it('keeps duplicate claims atomic and never persists images',async()=>{
  const storage=new MemoryStorage(),store=new DurableStore(storage.asStorage());
  const start=vi.fn(async()=> 'fc-test');
  const service=new VerificationService(store,{start,get:async()=>({status:'completed',verdict:{status:'uncertain',reps:[],cue:'none'}}),cancel:async()=>{}},workerConfig(env),prepareDemoEvidence);
  await expect(service.create(actor,{...create(),consentVersion:'2026-10-15'})).rejects.toThrow('Current consent');
  const session=await service.create(actor,create()),data=submit({sessionID:session.sessionID,nonce:session.nonce});
  await Promise.all([service.verify(actor,data),service.verify(actor,data)]);
  expect(start).toHaveBeenCalledOnce();
  const response=await invoke(service,'getVerificationResult',actor,{sessionID:session.sessionID,evidenceID:data.evidenceID});
  expect(await response.json()).toMatchObject({data:{status:'uncertain',verifiedRepCount:0}});
  expect(JSON.stringify([...storage.docs])).not.toMatch(/jpegBase64|data:image/);
  await expect(service.getResult({...actor,uid:'other'},{sessionID:session.sessionID,evidenceID:data.evidenceID})).rejects.toMatchObject({code:'permission-denied'});
 });
 it('rolls back failed store operations and cleans expired metadata across pages',async()=>{
  const storage=new MemoryStorage(),store=new DurableStore(storage.asStorage());
  await expect(store.transaction(async tx=>{tx.set('rollback',{value:1});expect(await tx.get('rollback')).toEqual({value:1});throw new Error('rollback');})).rejects.toThrow();
  expect(storage.docs.size).toBe(0);
  for(let i=0;i<300;i++)storage.docs.set(`entry-${String(i).padStart(3,'0')}`,{deleteAt:new Date(i<280?1000:9000)});
  await cleanup(storage.asStorage(),2000);expect(storage.docs.size).toBe(20);expect(storage.alarm).toBe(9000);
  await cleanup(storage.asStorage(),10000);expect(storage.docs.size).toBe(0);
 });
 it('bounds body reads and exposes only callable-safe error messages',async()=>{
  await expect(boundedJSON(new Response('x'.repeat(100)),99)).rejects.toThrow('Body too large');
  await expect(boundedJSON(new Response(null),100)).rejects.toThrow('Missing body');
  expect(await failureResponse(new Error('secret provider body')).json()).toEqual({error:{status:'UNAVAILABLE',message:'Remote demo unavailable'}});
  const response=failureResponse(new Failure('permission-denied','App attestation required'));
  expect(response.status).toBe(403);expect(await response.json()).toMatchObject({error:{status:'PERMISSION_DENIED'}});
 });
});
describe('bounded Gemini jobs',()=>{
 it('sends one authenticated request, returns a pending job and never retries',async()=>{
  const storage=new MemoryStorage(),tasks:Promise<unknown>[]=[];
  let release!:(value:Response)=>void;
  const request=vi.fn<typeof fetch>(()=>new Promise(resolve=>{release=resolve;}));
  const provider=new GeminiVerifier(storage.asStorage(),{waitUntil:task=>tasks.push(task)},env.GEMINI_API_KEY!,request);
  const evidence=await prepareDemoEvidence(submit({sessionID:'a'.repeat(64),nonce:uuid(1)}),1);
  const id=await provider.start(evidence,1,Date.now()+180000);
  expect(await provider.get(id)).toEqual({status:'pending'});
  const [url,options]=request.mock.calls[0];expect(url).toContain('/models/gemini-3.5-flash-lite:generateContent');
  expect(options).toMatchObject({redirect:'manual',headers:{'x-goog-api-key':env.GEMINI_API_KEY}});
  const payload=JSON.parse(options!.body as string);expect(payload.generationConfig.maxOutputTokens).toBe(800);expect(payload.generationConfig).not.toHaveProperty('temperature');expect(payload.contents[0].parts.filter((part:any)=>part.inlineData)).toHaveLength(5);
  release(Response.json(completion()));await Promise.all(tasks);
  expect(await provider.get(id)).toEqual({status:'completed',verdict:{status:'uncertain',reps:[],cue:'none'}});expect(request).toHaveBeenCalledOnce();
  await expect(provider.start({...evidence,frames:[]},1,Date.now()+180000)).rejects.toThrow('Invalid demo');
  await expect(provider.get('fc-missing')).rejects.toThrow('unavailable');
 });
 it('aborts cancellation and ignores a late completion',async()=>{
  const storage=new MemoryStorage(),tasks:Promise<unknown>[]=[];let release!:(value:Response)=>void;
  const request=vi.fn<typeof fetch>(()=>new Promise(resolve=>{release=resolve;}));
  const provider=new GeminiVerifier(storage.asStorage(),{waitUntil:task=>tasks.push(task)},'test-key',request);
  const evidence=await prepareDemoEvidence(submit({sessionID:'a'.repeat(64),nonce:uuid(1)}),1),id=await provider.start(evidence,1,Date.now()+180000);
  await provider.cancel(id);expect(request.mock.calls[0][1]!.signal!.aborted).toBe(true);
  release(Response.json(completion()));await Promise.all(tasks);await expect(provider.get(id)).rejects.toThrow('unavailable');
  expect((await storage.get<any>(`inferenceJobs/${id}`)).state).toBe('cancelled');
 });
 it.each([new Response('sensitive error',{status:429}),new Response(null,{status:302,headers:{Location:'https://attacker.test'}}),Response.json(completion({status:'complete',reps:[],cue:'none'})),new Response('x'.repeat(65537))])('fails closed on quota, redirects, hallucinated success and oversized responses',async response=>{
  const storage=new MemoryStorage(),tasks:Promise<unknown>[]=[];
  const request=vi.fn<typeof fetch>().mockResolvedValue(response),provider=new GeminiVerifier(storage.asStorage(),{waitUntil:task=>tasks.push(task)},'test-key',request);
  const evidence=await prepareDemoEvidence(submit({sessionID:'a'.repeat(64),nonce:uuid(1)}),1),id=await provider.start(evidence,1,Date.now()+180000);
  await Promise.all(tasks);await expect(provider.get(id)).rejects.toThrow('unavailable');expect(request).toHaveBeenCalledOnce();
  expect(JSON.stringify([...storage.docs])).not.toContain('sensitive');
 });
 it('never parses truncation, refusal, reasoning-only or hallucinated cycles as a valid demo',()=>{
  expect(parseVerdict(completion())).toEqual({status:'uncertain',reps:[],cue:'none'});
  for(const output of [{},{...completion(),promptFeedback:{blockReason:'SAFETY'}},{candidates:[{finishReason:'MAX_TOKENS',content:{parts:[{text:'{}'}]}}]},{candidates:[{finishReason:'STOP',content:{parts:[{text:'{}',thought:true}]}}]},completion({status:'incomplete',reps:[{frameIDs:['f0','f1','f2','f3','f4']}],cue:'none'})])expect(()=>parseVerdict(output)).toThrow();
 });
 it.each(['SERVICE_DISABLED','private-body-with-test-key'])('logs only a bounded HTTP status and known error code',async reason=>{
  const info=vi.spyOn(console,'info').mockImplementation(()=>{});
  try {
   const storage=new MemoryStorage(),tasks:Promise<unknown>[]=[];
   const response=Response.json({error:{message:'private-body-with-test-key',details:[{reason}]}},{status:403});
   const provider=new GeminiVerifier(storage.asStorage(),{waitUntil:task=>tasks.push(task)},'test-key',vi.fn<typeof fetch>().mockResolvedValue(response));
   const evidence=await prepareDemoEvidence(submit({sessionID:'a'.repeat(64),nonce:uuid(1)}),1);
   await provider.start(evidence,1,Date.now()+180000);await Promise.all(tasks);
   const event=JSON.parse(info.mock.calls[0][0]);expect(event.upstreamStatus).toBe(403);
   expect(event.upstreamError).toBe(reason==='SERVICE_DISABLED'?reason:'UNCLASSIFIED_HTTP_ERROR');
   expect(JSON.stringify(info.mock.calls)).not.toContain('private-body');
  }finally{info.mockRestore();}
 });
 it('classifies unstructured request errors without logging the message',async()=>{
  const info=vi.spyOn(console,'info').mockImplementation(()=>{});
  try {
   const storage=new MemoryStorage(),tasks:Promise<unknown>[]=[];
   const response=Response.json({error:{message:'Unsupported parameter responseJsonSchema private-body-with-test-key'}},{status:400});
   const provider=new GeminiVerifier(storage.asStorage(),{waitUntil:task=>tasks.push(task)},'test-key',vi.fn<typeof fetch>().mockResolvedValue(response));
   const evidence=await prepareDemoEvidence(submit({sessionID:'a'.repeat(64),nonce:uuid(1)}),1);
   await provider.start(evidence,1,Date.now()+180000);await Promise.all(tasks);
   expect(JSON.parse(info.mock.calls[0][0])).toMatchObject({upstreamStatus:400,upstreamError:'REQUEST_SCHEMA',upstreamFields:['responseJsonSchema']});
   expect(JSON.stringify(info.mock.calls)).not.toContain('private-body');
  }finally{info.mockRestore();}
 });
});
describe('Firebase tokens on a custom backend',()=>{
 it('verifies signatures, project, audience, timestamps and the allowed iOS app',async()=>{
  const pair=await generateKeyPair('RS256'),jwk={...await exportJWK(pair.publicKey),kid:'test-key'},keys=createLocalJWKSet({keys:[jwk]}),now=Math.floor(Date.now()/1000);
  const authPayload={sub:actor.uid,iss:`https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,aud:env.FIREBASE_PROJECT_ID,iat:now-1,auth_time:now-2,exp:now+300};
  const appPayload={sub:env.FIREBASE_APP_ID,iss:`https://firebaseappcheck.googleapis.com/${env.FIREBASE_PROJECT_NUMBER}`,aud:[`projects/${env.FIREBASE_PROJECT_NUMBER}`],iat:now-1,exp:now+300};
  const sign=(payload:JWTPayload)=>new SignJWT(payload).setProtectedHeader({alg:'RS256',typ:'JWT',kid:'test-key'}).sign(pair.privateKey);
  const headers=async(auth=authPayload,app=appPayload)=>({Authorization:`Bearer ${await sign(auth)}`,'X-Firebase-AppCheck':await sign(app)});
  const check=async(auth=authPayload,app=appPayload)=>authorize(new Request('https://test.workers.dev',{headers:await headers(auth,app)}),env,{auth:keys,app:keys});
  expect(await check()).toEqual(actor);
  for(const change of [{iss:'https://attacker.test'},{aud:'other-project'},{exp:now-1},{iat:now+100},{auth_time:now+100},{sub:''}])await expect(check({...authPayload,...change})).rejects.toMatchObject({code:'unauthenticated'});
  for(const change of [{sub:'another-app'},{iss:'https://attacker.test'},{aud:['projects/999']},{exp:now-1},{iat:now+100}])await expect(check(authPayload,{...appPayload,...change})).rejects.toMatchObject({code:'permission-denied'});
  await expect(authorize(new Request('https://test.workers.dev'),env,{auth:keys,app:keys})).rejects.toMatchObject({code:'unauthenticated'});
  await expect(authorize(new Request('https://test.workers.dev',{headers:{Authorization:`Bearer ${await sign(authPayload)}`}}),env,{auth:keys,app:keys})).rejects.toMatchObject({code:'permission-denied'});
  const wrong=await generateKeyPair('RS256'),invalid=await new SignJWT(authPayload).setProtectedHeader({alg:'RS256',kid:'test-key'}).sign(wrong.privateKey);
  await expect(authorize(new Request('https://test.workers.dev',{headers:{Authorization:`Bearer ${invalid}`}}),env,{auth:keys,app:keys})).rejects.toMatchObject({code:'unauthenticated'});
 });
});
