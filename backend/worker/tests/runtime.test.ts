import { afterAll,beforeAll,it,expect,vi } from 'vitest';
import { build } from 'esbuild';
import { Miniflare,Response as MFResponse,convertV4MiniflareOptions,type Request as MFRequest } from 'miniflare';
import { generateKeyPair,exportJWK,SignJWT } from 'jose';
import { fileURLToPath } from 'node:url';
import { env,actor,create,submit,completion } from './helpers.js';
let runtime:Miniflare|undefined,headers:Record<string,string>,otherHeaders:Record<string,string>,inferences=0;
beforeAll(async()=>{
 const pair=await generateKeyPair('RS256'),jwk={...await exportJWK(pair.publicKey),kid:'runtime-test'},now=Math.floor(Date.now()/1000);
 const sign=(payload:Record<string,unknown>)=>new SignJWT(payload).setProtectedHeader({alg:'RS256',typ:'JWT',kid:'runtime-test'}).setIssuedAt(now-1).setExpirationTime(now+300).sign(pair.privateKey);
 const attestation=await sign({sub:env.FIREBASE_APP_ID,iss:`https://firebaseappcheck.googleapis.com/${env.FIREBASE_PROJECT_NUMBER}`,aud:[`projects/${env.FIREBASE_PROJECT_NUMBER}`]});
 const identity=async(uid:string)=>({'Content-Type':'application/json',Authorization:`Bearer ${await sign({sub:uid,auth_time:now-1,iss:`https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,aud:env.FIREBASE_PROJECT_ID})}`,'X-Firebase-AppCheck':attestation});
 headers=await identity(actor.uid);otherHeaders=await identity('other-user');
 const bundle=await build({entryPoints:[fileURLToPath(new URL('../src/worker.ts',import.meta.url))],bundle:true,format:'esm',platform:'node',write:false,external:['cloudflare:workers','node:*'],logLevel:'silent'});
 const {VERIFICATIONS,...bindings}=env;
 runtime=new Miniflare(convertV4MiniflareOptions({
  modules:true,script:bundle.outputFiles[0].text,compatibilityDate:'2026-10-15',compatibilityFlags:['nodejs_compat'],
  bindings,durableObjects:{VERIFICATIONS:{className:'VerificationHub',useSQLite:true}},
  outboundService:async(request:MFRequest)=>{
   if(request.url==='https://firebaseappcheck.googleapis.com/v1/jwks'||request.url==='https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com')return MFResponse.json({keys:[jwk]});
   if(request.url==='https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent'){
    expect(request.headers.get('x-goog-api-key')).toBe(env.GEMINI_API_KEY);inferences++;
    const body=await request.json() as any;expect(body.contents[0].parts.filter((part:any)=>part.inlineData)).toHaveLength(5);
    return MFResponse.json(completion());
   }
   throw new Error(`Unexpected test outbound host: ${new URL(request.url).hostname}`);
  },
 }));
 await runtime.ready;
});
afterAll(async()=>{await runtime?.dispose();});
it('runs the callable protocol through real workerd, signed Firebase tokens and SQLite state',async()=>{
 const call=(name:string,data:unknown,auth=headers)=>runtime!.dispatchFetch(`https://demo.workers.dev/${name}`,{method:'POST',headers:auth,body:JSON.stringify({data})});
 expect((await runtime!.dispatchFetch('https://demo.workers.dev/health')).status).toBe(200);
 expect((await call('createVerificationSession',create(),{'Content-Type':'application/json'})).status).toBe(401);
 expect((await call('createVerificationSession',create(),{'Content-Type':'application/json',Authorization:headers.Authorization})).status).toBe(403);
 expect((await call('unknown',{})).status).toBe(404);
 expect((await runtime!.dispatchFetch('https://demo.workers.dev/createVerificationSession')).status).toBe(400);
 const wrapped=(value:number)=>({'@type':'type.googleapis.com/google.protobuf.Int64Value',value:String(value)});
 const created=await call('createVerificationSession',{...create(),target:wrapped(1)});expect(created.status).toBe(200);
 const {data:session}=await created.json() as any,data=submit({sessionID:session.sessionID,nonce:session.nonce});
 const nativeData={...data,frames:data.frames.map(frame=>({...frame,timestampMs:wrapped(frame.timestampMs)}))};
 const repeated=await Promise.all([call('verifyChallenge',nativeData),call('verifyChallenge',nativeData)]);
 for(const response of repeated){expect(response.status).toBe(200);expect(await response.json()).toMatchObject({data:{status:'pending'}});}
 expect(inferences).toBe(1);
 await vi.waitFor(async()=>{
  const response=await call('getVerificationResult',{sessionID:session.sessionID,evidenceID:data.evidenceID});
  expect(await response.json()).toMatchObject({data:{status:'uncertain',verifiedRepCount:0}});
 },{timeout:4000,interval:100});
 expect(inferences).toBe(1);
 expect((await call('getVerificationResult',{sessionID:session.sessionID,evidenceID:data.evidenceID},otherHeaders)).status).toBe(403);
 const bad={...data,frames:data.frames.map((frame,i)=>i?frame:{...frame,jpegBase64:'camera-image-is-not-allowed'})};
 expect((await call('verifyChallenge',bad)).status).toBe(400);expect(inferences).toBe(1);
 const cancelled=await call('cancelVerificationSession',{sessionID:session.sessionID});expect(await cancelled.json()).toEqual({data:{status:'cancelled'}});
 expect(await (await call('getVerificationResult',{sessionID:session.sessionID,evidenceID:data.evidenceID})).json()).toMatchObject({data:{status:'cancelled'}});
 const malformed=await runtime!.dispatchFetch('https://demo.workers.dev/createVerificationSession',{method:'POST',headers,body:'{"data":{},"uid":"forged"}'});expect(malformed.status).toBe(400);
 expect((await runtime!.dispatchFetch('https://demo.workers.dev/createVerificationSession',{method:'POST',headers,body:'x'.repeat(32769)})).status).toBe(400);
});
