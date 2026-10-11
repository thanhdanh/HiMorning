import { beforeAll, afterAll, beforeEach, describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc } from 'firebase/firestore';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { FirestoreStore } from '../backend/functions/src/firestore-store.js';
import { VerificationService } from '../backend/functions/src/service.js';
import { actor, config, createInput, complete, frames, uuid } from './helpers.js';
let env: RulesTestEnvironment;
const admin=initializeApp({projectId:'demo-himorning'},'tests');const db=getFirestore(admin);
beforeAll(async()=>{env=await initializeTestEnvironment({projectId:'demo-himorning',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync('firestore.rules','utf8')}});});
beforeEach(async()=>{await env.clearFirestore();});
afterAll(async()=>{await env?.cleanup();await db.terminate();await deleteApp(admin);});
describe('Firestore rules and real transaction integration',()=>{
 it('allows only owner preferences with bounded schema; blocks unauthenticated access',async()=>{
  const own=env.authenticatedContext(actor.uid).firestore();const other=env.authenticatedContext('other').firestore();const guest=env.unauthenticatedContext().firestore();
  const path=`users/${actor.uid}`;const prefs={locale:'vi',theme:'light',guidance:false};
  await assertSucceeds(setDoc(doc(own,path),prefs));await assertSucceeds(getDoc(doc(own,path)));
  await assertFails(getDoc(doc(other,path)));await assertFails(getDoc(doc(guest,path)));
  await assertFails(setDoc(doc(own,path),{...prefs,openai_verified:true}));
  await assertFails(setDoc(doc(own,path),{...prefs,theme:'unbounded'}));
 });
 it('denies all client access to server verdicts, quotas and unsupported collections',async()=>{
  const own=env.authenticatedContext(actor.uid).firestore();
  for(const path of ['verificationSessions/one','verificationSessions/one/attempts/two','quotaBuckets/global','users/guest-1/wakeSessions/one','any/thing']){
   await assertFails(setDoc(doc(own,path),{status:'verified'}));await assertFails(getDoc(doc(own,path)));
  }
 });
 it('claims one real Firestore attempt across two service instances and never persists camera bytes',async()=>{
  const store=new FirestoreStore(db);let release!:(value:any)=>void;const verify=vi.fn(()=>new Promise<any>(resolve=>{release=resolve;}));
  const a=new VerificationService(store,{verify},config);const b=new VerificationService(store,{verify},config);
  const session=await a.create(actor,createInput());const data={sessionID:session.sessionID,nonce:session.nonce,evidenceID:uuid(2),consentVersion:'2026-10-11',frames:await frames()};
  const first=a.verify(actor,data);await vi.waitFor(()=>expect(verify).toHaveBeenCalledOnce());expect((await b.verify(actor,data)).status).toBe('pending');
  release(complete());const result=await first;expect(result.status).toBe('verified');expect(await b.verify(actor,data)).toEqual(result);
  const snapshots=await db.collection(`verificationSessions/${session.sessionID}/attempts`).get();expect(snapshots.size).toBe(1);
  expect(JSON.stringify(snapshots.docs.map(d=>d.data()))).not.toContain(data.frames[0].jpegBase64);expect(verify).toHaveBeenCalledOnce();
 });
 it('reserves a shared global quota transactionally under concurrent users',async()=>{
  const store=new FirestoreStore(db);const verify=vi.fn(async()=>complete());const service=new VerificationService(store,{verify},{...config,globalDailyLimit:1});
  const users=[actor,{...actor,uid:'other'}];const sessions=await Promise.all(users.map((u,i)=>service.create(u,createInput(i+1))));
  const results=await Promise.all(sessions.map(async(s,i)=>service.verify(users[i],{sessionID:s.sessionID,nonce:s.nonce,evidenceID:uuid(i+4),consentVersion:'2026-10-11',frames:await frames()})));
  // Only the exact contract is submitted; public session limits are not request fields.
  expect(results.filter(x=>x.status==='verified')).toHaveLength(1);expect(results.filter(x=>x.reasonCode==='quota_exhausted')).toHaveLength(1);expect(verify).toHaveBeenCalledOnce();
 });
});
