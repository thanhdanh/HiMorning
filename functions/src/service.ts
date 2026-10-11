import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { Failure, parse } from './errors.js';
import { CONSENT_VERSION, POLICY_VERSION, LIMITS, sessionIDSchema, submissionSchema, prepareEvidence, decide, hash, type Evidence } from './evidence.js';
import type { Config } from './config.js';
import type { Store } from './store.js';
export interface Actor { uid: string; appCheck: boolean }
export interface Verifier { verify(evidence: Evidence, target: number): Promise<unknown> }
export interface Result { status: 'verified'|'incomplete'|'uncertain'|'unavailable'|'pending'|'cancelled'|'expired'; reasonCode: string; decisionID: string; verifiedRepCount?: number; cue?: string }
interface Session { ownerUID: string; nonce: string; target: number; requestHash: string; expiresAt: number; deleteAt: Date; state: 'open'|'processing'|'finished'|'cancelled'; attemptID?: string; consentVersion: string; policyVersion: string }
interface Attempt { payloadHash: string; state: 'running'|'done'; leaseUntil: number; decisionID: string; deleteAt: Date; model: string; policyVersion: string; result?: Result }
interface Bucket { used: number; deleteAt: Date }
const createSchema = z.object({ requestID: z.uuid(), challenge: z.literal('pushup'), target: z.number().int().min(1).max(5), consentVersion: z.literal(CONSENT_VERSION) }).strict();
const cancelSchema = z.object({ sessionID: sessionIDSchema }).strict();
const expiry = (now: number) => new Date(now + 2 * 86400000);
function authorize(actor: Actor) {
 if (!actor.uid) throw new Failure('unauthenticated', 'Sign in for cloud verification');
 if (!actor.appCheck) throw new Failure('permission-denied', 'App attestation required');
}
function owned(session: Session | undefined, actor: Actor): asserts session is Session {
 if (!session) throw new Failure('not-found', 'Session not found');
 if (session.ownerUID !== actor.uid) throw new Failure('permission-denied', 'Session owner mismatch');
}
const result = (status: Result['status'], reasonCode: string, decisionID = ''): Result => ({ status, reasonCode, decisionID });
function terminal(session: Session, now: number): Result | undefined {
 if (session.state === 'cancelled') return result('cancelled', 'session_cancelled');
 if (session.expiresAt <= now) return result('expired', 'session_expired');
}
export class VerificationService {
 constructor(private readonly store: Store, private readonly provider: Verifier, private readonly config: Config, private readonly clock: () => number = Date.now) {}
 async create(actor: Actor, input: unknown) {
  authorize(actor); const data = parse(createSchema, input); const id = hash(`${actor.uid}:${data.requestID}`); const path = `verificationSessions/${id}`;
  const requestHash = hash(JSON.stringify(data));
  const session = await this.store.transaction(async tx => {
   const current = await tx.get<Session>(path);
   if (current) { owned(current, actor); if (current.requestHash !== requestHash) throw new Failure('already-exists', 'Request ID already used'); return current; }
   const now = this.clock(), day = new Date(now).toISOString().slice(0,10);
   const userPath = `quotaBuckets/create-${hash(actor.uid)}-${day}`, globalPath = `quotaBuckets/create-global-${day}`;
   const user = await tx.get<Bucket>(userPath), global = await tx.get<Bucket>(globalPath);
   if ((user?.used ?? 0) >= 20 || (global?.used ?? 0) >= 1000) throw new Failure('resource-exhausted', 'Session creation limit reached');
   const created: Session = { ownerUID: actor.uid, nonce: randomUUID(), target: data.target, requestHash, expiresAt: now + 120000, deleteAt: expiry(now), state: 'open', consentVersion: CONSENT_VERSION, policyVersion: POLICY_VERSION };
   tx.set(userPath, {used:(user?.used ?? 0)+1,deleteAt:expiry(now)}); tx.set(globalPath,{used:(global?.used ?? 0)+1,deleteAt:expiry(now)}); tx.set(path,created); return created;
  });
  return { sessionID: id, nonce: session.nonce, expiresAt: session.expiresAt, limits: LIMITS };
 }
 async cancel(actor: Actor, input: unknown) {
  authorize(actor); const data = parse(cancelSchema,input);const path=`verificationSessions/${data.sessionID}`;
  await this.store.transaction(async tx => { const session=await tx.get<Session>(path); owned(session,actor);tx.set(path,{...session,state:'cancelled'}); });
  return {status:'cancelled' as const};
 }
 async verify(actor: Actor, input: unknown): Promise<Result> {
  authorize(actor);const data=parse(submissionSchema,input);const path=`verificationSessions/${data.sessionID}`, attemptPath=`${path}/attempts/${data.evidenceID}`;
  const session = await this.store.transaction(async tx => { const s=await tx.get<Session>(path);owned(s,actor);if(s.nonce!==data.nonce)throw new Failure('permission-denied','Invalid session nonce');return s; });
  const closed=terminal(session,this.clock());if(closed)return closed;
  if(!this.config.enabled)return result('unavailable','cloud_disabled');
  const evidence=await prepareEvidence(data,session.target);
  if(!evidence.sufficient)return result('uncertain','insufficient_evidence');
  const claim = await this.store.transaction(async tx => {
   const current=await tx.get<Session>(path), attempt=await tx.get<Attempt>(attemptPath);owned(current,actor);
   const now=this.clock(), stopped=terminal(current,now);if(stopped)return {result:stopped};
   if(attempt) {
    if(attempt.payloadHash!==evidence.payloadHash)throw new Failure('already-exists','Evidence ID already used');
    if(attempt.result)return {result:attempt.result};
    if(attempt.leaseUntil<=now) {
     const interrupted=result('uncertain','attempt_interrupted',attempt.decisionID);
     tx.set(attemptPath,{...attempt,state:'done',result:interrupted});tx.set(path,{...current,state:'finished'});return {result:interrupted};
    }
    return {result:result('pending','verification_pending',attempt.decisionID)};
   }
   if(current.state!=='open')return {result:result('unavailable','attempt_limit')};
   const day=new Date(now).toISOString().slice(0,10), userPath=`quotaBuckets/ai-${hash(actor.uid)}-${day}`,globalPath=`quotaBuckets/ai-global-${day}`;
   const user=await tx.get<Bucket>(userPath),global=await tx.get<Bucket>(globalPath);
   if((user?.used??0)>=this.config.userDailyLimit||(global?.used??0)>=this.config.globalDailyLimit)return {result:result('unavailable','quota_exhausted')};
   const decisionID=randomUUID();
   tx.set(userPath,{used:(user?.used??0)+1,deleteAt:expiry(now)});tx.set(globalPath,{used:(global?.used??0)+1,deleteAt:expiry(now)});
   tx.set(attemptPath,{payloadHash:evidence.payloadHash,state:'running',leaseUntil:now+25000,decisionID,deleteAt:expiry(now),model:this.config.model,policyVersion:POLICY_VERSION});
   tx.set(path,{...current,state:'processing',attemptID:data.evidenceID});return {decisionID};
  });
  if ('result' in claim) return claim.result!;
  let decision: Result;
  // Firestore can retry its transaction callback. Paid work MUST stay outside it.
  try { decision={...decide(await this.provider.verify(evidence,session.target),evidence,session.target),decisionID:claim.decisionID}; }
  catch { decision=result('unavailable','provider_unavailable',claim.decisionID); }
  return this.store.transaction(async tx => {
   const current=await tx.get<Session>(path),attempt=await tx.get<Attempt>(attemptPath);owned(current,actor);
   const now=this.clock(),stopped=terminal(current,now);if(stopped)return stopped;
   if (!attempt) return result('uncertain','attempt_interrupted',claim.decisionID);
   if (attempt.result) return attempt.result;
   if (attempt.leaseUntil<=now) decision=result('uncertain','attempt_interrupted',attempt.decisionID);
   tx.set(attemptPath,{...attempt,state:'done',result:decision});tx.set(path,{...current,state:'finished'});return decision;
  });
 }
}
