import { describe, it, expect, vi } from 'vitest';
import { handlers } from '../functions/src/api.js';
import { readConfig } from '../functions/src/config.js';
import { Failure } from '../functions/src/errors.js';
import * as entry from '../functions/src/index.js';
describe('callable boundary and deployment defaults',()=>{
 it('has zero warm instances and mandatory App Check on every callable',()=>{
  for(const fn of [entry.createVerificationSession,entry.verifyChallenge,entry.cancelVerificationSession]) {
   expect(fn.__endpoint.callableTrigger).toMatchObject({});
   expect(fn.__endpoint.minInstances).toBe(0);
   expect(fn.__endpoint.maxInstances).toBe(2);
  }
 });
 it('defaults off and rejects unsafe configuration instead of silently removing caps',()=>{
  expect(readConfig({})).toMatchObject({enabled:false,userDailyLimit:3,globalDailyLimit:100});
  for(const env of [{AI_USER_DAILY_LIMIT:'0'},{AI_GLOBAL_DAILY_LIMIT:'NaN'},{AI_VERIFICATION_ENABLED:'yes'},{AI_GLOBAL_DAILY_LIMIT:'100001'}]) expect(()=>readConfig(env)).toThrow();
  expect(readConfig({AI_VERIFICATION_ENABLED:'true',OPENAI_MODEL:'custom-snapshot'}).model).toBe('custom-snapshot');
 });
 it('passes authenticated identity and App Check from context, never from client data',async()=>{
  const service={create:vi.fn(async()=>({sessionID:'s'})),verify:vi.fn(async()=>({status:'verified'})),cancel:vi.fn(async()=>({status:'cancelled'}))};const api=handlers(()=>service as any);
  const request:any={auth:{uid:'real-user'},app:{appId:'attested'},data:{uid:'forged'}};
  await api.create(request);await api.verify(request);await api.cancel(request);
  for(const method of Object.values(service)) expect(method).toHaveBeenCalledWith({uid:'real-user',appCheck:true},request.data);
 });
 it('maps domain errors and sanitizes unexpected errors without logging payloads',async()=>{
  const service={create:vi.fn().mockRejectedValue(new Failure('permission-denied','wrong owner'))};const api=handlers(()=>service as any);
  await expect(api.create({data:{}} as any)).rejects.toMatchObject({code:'permission-denied'});
  service.create.mockRejectedValue(new Error('secret frame content'));await expect(api.create({data:{}} as any)).rejects.toMatchObject({code:'internal',message:'Verification service unavailable'});
 });
});
