import { prepareEvidence } from '../backend/functions/src/evidence.js';
import { describe, it, expect, vi } from 'vitest';
import { VerificationService } from '../backend/functions/src/service.js';
import { actor, config, createInput, complete, frames, MemoryStore, uuid } from './helpers.js';
function setup(overrides={},shared?:MemoryStore){
 const store=shared??new MemoryStore();let time=Date.UTC(2026,9,15);
 const start=vi.fn(async()=> 'fc-test'),get=vi.fn(async():Promise<any>=>({status:'completed',verdict:complete()})),cancel=vi.fn(async()=>{});
 const service=new VerificationService(store,{start,get,cancel},{...config,...overrides},prepareEvidence,()=>time);
 return {service,store,start,get,cancel,setTime:(t:number)=>{time=t;},now:()=>time};
}
async function submission(session:any,id=2){return {...lookup(session,id),nonce:session.nonce,consentVersion:'2026-10-15',frames:await frames()};}
function lookup(session:any,id=2){return {sessionID:session.sessionID,evidenceID:uuid(id)};}
describe('asynchronous verification and cost controls',()=>{
 it('creates an idempotent ten-minute session with unchanged image bounds',async()=>{
  const s=setup(),session=await s.service.create(actor,createInput());
  expect(await s.service.create(actor,createInput())).toEqual(session);expect(session.expiresAt).toBe(s.now()+600000);expect(session.limits.maxFrames).toBe(250);
  await expect(s.service.create(actor,createInput(1,2))).rejects.toMatchObject({code:'already-exists'});
 });
 it('requires identity, App Check, current consent and a bounded target',async()=>{
  const s=setup();for(const who of [{...actor,uid:''},{...actor,appCheck:false}])await expect(s.service.create(who,createInput())).rejects.toThrow();
  for(const input of [{...createInput(),target:51},{...createInput(),target:0},{...createInput(),consentVersion:'old'},{...createInput(),challenge:'situp'},{...createInput(),extra:true}])await expect(s.service.create(actor,input)).rejects.toThrow();
 });
 it('dispatches once, polls without photos and caches the final decision',async()=>{
  const s=setup(),session=await s.service.create(actor,createInput()),data=await submission(session);
  const pending=await s.service.verify(actor,data);expect(pending.status).toBe('pending');expect(await s.service.verify(actor,data)).toEqual(pending);
  const decision=await s.service.getResult(actor,lookup(session));expect(decision.status).toBe('verified');expect(decision.decisionID).toBe(pending.decisionID);
  expect(await s.service.getResult(actor,lookup(session))).toEqual(decision);expect(await s.service.verify(actor,data)).toEqual(decision);
  expect(s.start).toHaveBeenCalledOnce();expect(s.get).toHaveBeenCalledOnce();expect(s.get).toHaveBeenCalledWith('fc-test');
  expect(s.start.mock.calls[0]).toHaveLength(3);expect(JSON.stringify([...s.store.docs.values()])).not.toContain(data.frames[0].jpegBase64);
  expect(JSON.stringify([...s.store.docs.values()])).not.toContain('dataURL');
  await expect(s.service.verify(actor,{...data,frames:(await frames()).map(frame=>({...frame,timestampMs:frame.timestampMs+1}))})).rejects.toMatchObject({code:'already-exists'});
 });
 it('never redispatches while acknowledgement is outstanding',async()=>{
  const s=setup();let release!:(id:string)=>void;s.start.mockImplementationOnce(()=>new Promise(resolve=>{release=resolve;}));
  const session=await s.service.create(actor,createInput()),data=await submission(session),first=s.service.verify(actor,data);
  await vi.waitFor(()=>expect(s.start).toHaveBeenCalledOnce());expect((await s.service.verify(actor,data)).status).toBe('pending');expect((await s.service.getResult(actor,lookup(session))).status).toBe('pending');
  expect(s.get).not.toHaveBeenCalled();release('fc-test');expect((await first).status).toBe('pending');expect(s.start).toHaveBeenCalledOnce();
 });
 it('never retries an ambiguous dispatch failure or leaks its error',async()=>{
  const s=setup();s.start.mockRejectedValueOnce(new Error('secret payload'));
  const session=await s.service.create(actor,createInput()),data=await submission(session),decision=await s.service.verify(actor,data);
  expect(decision).toMatchObject({status:'unavailable',reasonCode:'provider_unavailable'});expect(await s.service.verify(actor,data)).toEqual(decision);expect(await s.service.getResult(actor,lookup(session))).toEqual(decision);expect(s.start).toHaveBeenCalledOnce();expect(JSON.stringify(decision)).not.toContain('secret');
 });
 it('cancels a job accepted after the user already stopped',async()=>{
  const s=setup();let release!:(id:string)=>void;s.start.mockImplementationOnce(()=>new Promise(resolve=>{release=resolve;}));
  const session=await s.service.create(actor,createInput()),data=await submission(session),first=s.service.verify(actor,data);
  await vi.waitFor(()=>expect(s.start).toHaveBeenCalledOnce());await s.service.cancel(actor,{sessionID:session.sessionID});release('fc-late');
  expect((await first).status).toBe('cancelled');expect(s.cancel).toHaveBeenCalledWith('fc-late');expect((await s.service.getResult(actor,lookup(session))).status).toBe('cancelled');
 });
 it('rejects success racing with cancellation and tolerates cancellation transport errors',async()=>{
  const s=setup();let release!:(value:any)=>void;s.get.mockImplementationOnce(()=>new Promise(resolve=>{release=resolve;}));s.cancel.mockRejectedValue(new Error('offline'));
  const session=await s.service.create(actor,createInput());await s.service.verify(actor,await submission(session));const pending=s.service.getResult(actor,lookup(session));
  await vi.waitFor(()=>expect(s.get).toHaveBeenCalledOnce());expect(await s.service.cancel(actor,{sessionID:session.sessionID})).toEqual({status:'cancelled'});release({status:'completed',verdict:complete()});expect((await pending).status).toBe('cancelled');
 });
 it('bounds waiting at 180 seconds, cancels compute and never accepts a late result',async()=>{
  const s=setup(),session=await s.service.create(actor,createInput());await s.service.verify(actor,await submission(session));s.setTime(s.now()+180000);
  const decision=await s.service.getResult(actor,lookup(session));expect(decision).toMatchObject({status:'unavailable',reasonCode:'verification_timeout'});expect(s.cancel).toHaveBeenCalledWith('fc-test');expect(s.get).not.toHaveBeenCalled();expect(await s.service.getResult(actor,lookup(session))).toEqual(decision);
 });
 it('rechecks the deadline after a provider result arrives',async()=>{
  const s=setup(),session=await s.service.create(actor,createInput());await s.service.verify(actor,await submission(session));s.get.mockImplementationOnce(async()=>{s.setTime(s.now()+180001);return {status:'completed',verdict:complete()};});expect((await s.service.getResult(actor,lookup(session))).status).toBe('unavailable');
 });
 it('rejects malformed verdicts and overlapping frame cycles',async()=>{
  const s=setup(),session=await s.service.create(actor,createInput());await s.service.verify(actor,await submission(session));s.get.mockResolvedValueOnce({status:'completed',verdict:{status:'complete',reps:[{frameIDs:['f0','f0','f2','f3','f4']}],cue:'none'}});expect((await s.service.getResult(actor,lookup(session))).status).toBe('uncertain');
 });
 it('throttles provider polling and treats provider failures as unavailable',async()=>{
  const s=setup(),session=await s.service.create(actor,createInput());await s.service.verify(actor,await submission(session));s.get.mockResolvedValueOnce({status:'pending'});
  expect((await s.service.getResult(actor,lookup(session))).status).toBe('pending');expect((await s.service.getResult(actor,lookup(session))).status).toBe('pending');expect(s.get).toHaveBeenCalledOnce();
  s.setTime(s.now()+1000);s.get.mockRejectedValueOnce(new Error('secret'));expect((await s.service.getResult(actor,lookup(session))).status).toBe('unavailable');expect(s.cancel).toHaveBeenCalledOnce();
 });
 it('protects status and cancellation by owner and attestation',async()=>{
  const s=setup(),session=await s.service.create(actor,createInput()),data=await submission(session);await s.service.verify(actor,data);
  for(const who of [{...actor,uid:'other'},{...actor,uid:''},{...actor,appCheck:false}]){
   await expect(s.service.getResult(who,lookup(session))).rejects.toThrow();await expect(s.service.cancel(who,{sessionID:session.sessionID})).rejects.toThrow();
  }
  await expect(s.service.verify(actor,{...data,nonce:uuid(99)})).rejects.toMatchObject({code:'permission-denied'});
  await expect(s.service.getResult(actor,lookup(session,99))).rejects.toMatchObject({code:'not-found'});
  await expect(s.service.getResult(actor,{...lookup(session),jobID:'fc-forged'})).rejects.toMatchObject({code:'invalid-argument'});
 });
 it('enforces one attempt, default-off, insufficient evidence, and shared quotas',async()=>{
  const off=setup({enabled:false}),closed=await off.service.create(actor,createInput());expect((await off.service.verify(actor,await submission(closed))).reasonCode).toBe('cloud_disabled');expect(off.start).not.toHaveBeenCalled();
  const s=setup({userDailyLimit:1,globalDailyLimit:1}),session=await s.service.create(actor,createInput());
  expect((await s.service.verify(actor,{...await submission(session),frames:await frames(2)})).reasonCode).toBe('insufficient_evidence');expect(s.start).not.toHaveBeenCalled();
  await s.service.verify(actor,await submission(session));expect((await s.service.verify(actor,await submission(session,3))).reasonCode).toBe('attempt_limit');
  const next=await s.service.create(actor,createInput(2));expect((await s.service.verify(actor,await submission(next))).reasonCode).toBe('quota_exhausted');
  const other={...actor,uid:'other'},third=await s.service.create(other,createInput(3));expect((await s.service.verify(other,await submission(third))).reasonCode).toBe('quota_exhausted');expect(s.start).toHaveBeenCalledOnce();
 });
 it('applies the kill switch to pending jobs and expires old sessions',async()=>{
  const s=setup(),session=await s.service.create(actor,createInput());await s.service.verify(actor,await submission(session));
  const off=new VerificationService(s.store,{start:s.start,get:s.get,cancel:s.cancel},{...config,enabled:false},prepareEvidence,s.now);expect((await off.getResult(actor,lookup(session))).reasonCode).toBe('cloud_disabled');expect(s.cancel).toHaveBeenCalledOnce();
  s.setTime(session.expiresAt);expect((await s.service.getResult(actor,lookup(session))).status).toBe('expired');await expect(s.service.cancel(actor,{sessionID:'b'.repeat(64)})).rejects.toMatchObject({code:'not-found'});
 });
});
