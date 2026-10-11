import { describe, it, expect, vi } from 'vitest';
import { VerificationService } from '../backend/functions/src/service.js';
import { actor, config, createInput, complete, frames, MemoryStore, uuid } from './helpers.js';
function setup(overrides = {}, shared?: MemoryStore) {
 const store = shared ?? new MemoryStore(); let time = Date.UTC(2026,9,11);
 const verify = vi.fn(async () => complete());
 const service = new VerificationService(store, { verify }, {...config,...overrides}, () => time);
 return { service, store, verify, setTime: (t: number) => { time = t; }, now: () => time };
}
async function submission(session: any, id = 2) { return { sessionID: session.sessionID, nonce: session.nonce, evidenceID: uuid(id), consentVersion: '2026-10-11', frames: await frames() }; }
describe('verification lifecycle and cost controls', () => {
 it('creates a server-owned snapshot idempotently, forbidding changed request reuse', async () => {
  const s = setup(); const a = await s.service.create(actor, createInput());
  expect(await s.service.create(actor, createInput())).toEqual(a);
  expect(a.expiresAt).toBe(s.now()+120000); expect(a.limits.maxFrames).toBe(25);
  await expect(s.service.create(actor, createInput(1,2))).rejects.toMatchObject({code:'already-exists'});
 });
 it('requires auth, App Check, current consent and a bounded target', async () => {
  const s = setup();
  for (const who of [{...actor,uid:''},{...actor,appCheck:false}]) await expect(s.service.create(who,createInput())).rejects.toThrow();
  for(const input of [{...createInput(),target:6},{...createInput(),target:0},{...createInput(),consentVersion:'old'},{...createInput(),challenge:'situp'},{...createInput(),extra:true}]) await expect(s.service.create(actor,input)).rejects.toThrow();
 });
 it('runs one inference and returns identical cached result on duplicate submission', async () => {
  const s=setup();const session=await s.service.create(actor,createInput());const data=await submission(session);
  const first=await s.service.verify(actor,data); expect(first.status).toBe('verified');
  expect(await s.service.verify(actor,data)).toEqual(first); expect(s.verify).toHaveBeenCalledTimes(1);
  await expect(s.service.verify(actor,{...data,frames:await frames(6)})).rejects.toMatchObject({code:'already-exists'});
  expect(JSON.stringify([...s.store.docs])).not.toContain(data.frames[0].jpegBase64);
 });
 it('does not write Firestore again for duplicate cancellation',async()=>{
  const s=setup();const session=await s.service.create(actor,createInput());
  await s.service.cancel(actor,{sessionID:session.sessionID});const writes=s.store.writes;
  expect(await s.service.cancel(actor,{sessionID:session.sessionID})).toEqual({status:'cancelled'});
  expect(s.store.writes).toBe(writes);
 });
 it('concurrent duplicate requests reserve only once, with pending for the second', async () => {
  const s=setup();let release!: (value:any)=>void; s.verify.mockImplementationOnce(()=>new Promise(resolve=>{release=resolve;}));
  const session=await s.service.create(actor,createInput()); const data=await submission(session);
  const first=s.service.verify(actor,data); await vi.waitFor(()=>expect(s.verify).toHaveBeenCalledOnce());
  expect((await s.service.verify(actor,data)).status).toBe('pending');
  release(complete()); expect((await first).status).toBe('verified');expect(s.verify).toHaveBeenCalledOnce();
 });
 it('cancellation wins over late completion, including cached replay', async () => {
  const s=setup();let release!: (value:any)=>void;s.verify.mockImplementationOnce(()=>new Promise(resolve=>{release=resolve;}));
  const session=await s.service.create(actor,createInput());const data=await submission(session);
  const pending=s.service.verify(actor,data);await vi.waitFor(()=>expect(s.verify).toHaveBeenCalledOnce());
  expect(await s.service.cancel(actor,{sessionID:session.sessionID})).toEqual({status:'cancelled'});
  release(complete());expect((await pending).status).toBe('cancelled');expect((await s.service.verify(actor,data)).status).toBe('cancelled');
 });
 it('blocks other owners, wrong nonce, expired sessions and new attempts after completion', async () => {
  const s=setup();const session=await s.service.create(actor,createInput());const data=await submission(session);
  await expect(s.service.verify({...actor,uid:'other'},data)).rejects.toMatchObject({code:'permission-denied'});
  await expect(s.service.cancel({...actor,uid:'other'},{sessionID:session.sessionID})).rejects.toMatchObject({code:'permission-denied'});
  await expect(s.service.verify(actor,{...data,nonce:uuid(99)})).rejects.toMatchObject({code:'permission-denied'});
  await s.service.verify(actor,data);
  expect((await s.service.verify(actor,{...data,evidenceID:uuid(3)})).status).toBe('unavailable');expect(s.verify).toHaveBeenCalledOnce();
  s.setTime(session.expiresAt);expect((await s.service.verify(actor,data)).status).toBe('expired');
 });
 it('never reclaims a stale attempt or retries a failed provider call', async () => {
  const s=setup();s.verify.mockRejectedValueOnce(new Error('sensitive provider message'));
  const session=await s.service.create(actor,createInput()); const data=await submission(session);
  const failed=await s.service.verify(actor,data);expect(failed).toMatchObject({status:'unavailable',reasonCode:'provider_unavailable'});
  expect(JSON.stringify(failed)).not.toContain('sensitive');expect(await s.service.verify(actor,data)).toEqual(failed);expect(s.verify).toHaveBeenCalledOnce();
 });
 it('does not charge for disabled cloud or insufficient evidence', async () => {
  const s=setup({enabled:false}); const session=await s.service.create(actor,createInput());
  expect((await s.service.verify(actor,await submission(session))).status).toBe('unavailable'); expect(s.verify).not.toHaveBeenCalled();
  const short=setup();const two=await short.service.create(actor,createInput(1,2));expect((await short.service.verify(actor,await submission(two))).reasonCode).toBe('insufficient_evidence');expect(short.verify).not.toHaveBeenCalled();
 });
 it('atomically caps user and global model calls, even with multiple service instances', async () => {
  const s=setup({userDailyLimit:1,globalDailyLimit:2});
  const a=await s.service.create(actor,createInput(1)); const b=await s.service.create(actor,createInput(2));
  await s.service.verify(actor,await submission(a));expect((await s.service.verify(actor,await submission(b))).reasonCode).toBe('quota_exhausted');
  const other={...actor,uid:'other'}; const c=await s.service.create(other,createInput(3));await s.service.verify(other,await submission(c));
  const third={...actor,uid:'third'}; const t=setup({userDailyLimit:1,globalDailyLimit:2},s.store);const d=await t.service.create(third,createInput(4));expect((await t.service.verify(third,await submission(d))).reasonCode).toBe('quota_exhausted');expect(t.verify).not.toHaveBeenCalled();
 });
 it('limits session creation before it becomes an unbounded database write path', async () => {
  const s=setup(); for(let i=1;i<=20;i++) await s.service.create(actor,createInput(i));
  await expect(s.service.create(actor,createInput(21))).rejects.toMatchObject({code:'resource-exhausted'});
  expect(await s.service.create(actor,createInput(1))).toHaveProperty('sessionID');
 });
 it('ignores late expired results and turns an abandoned lease into uncertain without a new inference', async () => {
  const s=setup();let release!: (value:any)=>void;s.verify.mockImplementationOnce(()=>new Promise(resolve=>{release=resolve;}));
  const session=await s.service.create(actor,createInput());const data=await submission(session);
  const pending=s.service.verify(actor,data);await vi.waitFor(()=>expect(s.verify).toHaveBeenCalledOnce());
  s.setTime(s.now()+26000);expect((await s.service.verify(actor,data)).reasonCode).toBe('attempt_interrupted');
  release(complete());expect((await pending).status).toBe('uncertain');expect(s.verify).toHaveBeenCalledOnce();
 });
 it('returns expired when session TTL passes during inference and refuses missing sessions', async () => {
  const s=setup();const session=await s.service.create(actor,createInput()); const data=await submission(session);
  s.verify.mockImplementationOnce(async()=>{s.setTime(session.expiresAt);return complete();});
  expect((await s.service.verify(actor,data)).status).toBe('expired');
  await expect(s.service.cancel(actor,{sessionID:'b'.repeat(64)})).rejects.toMatchObject({code:'not-found'});
  await expect(s.service.verify(actor,{...data,sessionID:'b'.repeat(64)})).rejects.toMatchObject({code:'not-found'});
 });
});
