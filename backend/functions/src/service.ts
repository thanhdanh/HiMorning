import { randomUUID } from 'node:crypto';
import { createSchema, cancelSchema, resultSchema, SESSION_DURATION_MS, JOB_DURATION_MS, type VerificationResult as Result } from './contracts.js';
export type { VerificationResult as Result } from './contracts.js';
import { Failure, parse } from './errors.js';
import { CONSENT_VERSION, POLICY_VERSION, LIMITS, submissionSchema, decide, hash, type Evidence, type DecisionEvidence } from './policy.js';
import type { Config } from './config.js';
import type { Store } from './store.js';
export interface Actor { uid:string; appCheck:boolean }
export interface Verifier {
 start(evidence:Evidence,target:number,deadlineAt:number):Promise<string>;
 get(jobID:string):Promise<{status:'pending'}|{status:'completed';verdict:unknown}>;
 cancel(jobID:string):Promise<void>;
}
interface Session { ownerUID:string; nonce:string; target:number; requestHash:string; expiresAt:number; deleteAt:Date; state:'open'|'processing'|'finished'|'cancelled'; attemptID?:string; consentVersion:string; policyVersion:string }
interface Attempt { payloadHash:string; state:'running'|'done'; leaseUntil:number; decisionID:string; deleteAt:Date; model:string; policyVersion:string; evidence:DecisionEvidence; jobID?:string; nextPollAt?:number; result?:Result }
interface Bucket { used:number; deleteAt:Date }
const expiry=(now:number)=>new Date(now+2*86400000);
const result=(status:Result['status'],reasonCode:string,decisionID=''):Result=>({status,reasonCode,decisionID});
function authorize(actor:Actor){if(!actor.uid)throw new Failure('unauthenticated','Sign in for cloud verification');if(!actor.appCheck)throw new Failure('permission-denied','App attestation required');}
function owned(session:Session|undefined,actor:Actor):asserts session is Session {if(!session)throw new Failure('not-found','Session not found');if(session.ownerUID!==actor.uid)throw new Failure('permission-denied','Session owner mismatch');}
function terminal(session:Session,now:number):Result|undefined {if(session.state==='cancelled')return result('cancelled','session_cancelled');if(session.expiresAt<=now)return result('expired','session_expired');}
export class VerificationService {
 constructor(private readonly store:Store,private readonly provider:Verifier,private readonly config:Config,private readonly prepare:(input:unknown,target:number)=>Promise<Evidence>,private readonly clock:()=>number=Date.now){}
 async create(actor:Actor,input:unknown){
  authorize(actor);const data=parse(createSchema,input);if(data.consentVersion!==(this.config.consentVersion??CONSENT_VERSION))throw new Failure('invalid-argument','Current consent required');const id=hash(`${actor.uid}:${data.requestID}`),path=`verificationSessions/${id}`,requestHash=hash(JSON.stringify(data));
  const session=await this.store.transaction(async tx=>{
   const current=await tx.get<Session>(path);
   if(current){owned(current,actor);if(current.requestHash!==requestHash)throw new Failure('already-exists','Request ID already used');return current;}
   const now=this.clock(),day=new Date(now).toISOString().slice(0,10),userPath=`quotaBuckets/create-${hash(actor.uid)}-${day}`,globalPath=`quotaBuckets/create-global-${day}`;
   const user=await tx.get<Bucket>(userPath),global=await tx.get<Bucket>(globalPath);
   if((user?.used??0)>=20||(global?.used??0)>=1000)throw new Failure('resource-exhausted','Session creation limit reached');
   const created:Session={ownerUID:actor.uid,nonce:randomUUID(),target:data.target,requestHash,expiresAt:now+SESSION_DURATION_MS,deleteAt:expiry(now),state:'open',consentVersion:data.consentVersion,policyVersion:POLICY_VERSION};
   tx.set(userPath,{used:(user?.used??0)+1,deleteAt:expiry(now)});tx.set(globalPath,{used:(global?.used??0)+1,deleteAt:expiry(now)});tx.set(path,created);return created;
  });
  return {sessionID:id,nonce:session.nonce,expiresAt:session.expiresAt,limits:LIMITS};
 }
 private async cancelJob(jobID?:string){if(jobID){try{await this.provider.cancel(jobID);}catch{/* A remote cancellation failure cannot undo a local exit. */}}}
 async cancel(actor:Actor,input:unknown){
  authorize(actor);const data=parse(cancelSchema,input),path=`verificationSessions/${data.sessionID}`;
  const jobID=await this.store.transaction(async tx=>{
   const session=await tx.get<Session>(path);owned(session,actor);
   const attemptPath=session.attemptID?`${path}/attempts/${session.attemptID}`:undefined;
   const attempt=attemptPath?await tx.get<Attempt>(attemptPath):undefined;
   tx.set(path,{...session,state:'cancelled'});
   if(attempt&&attemptPath)tx.set(attemptPath,{...attempt,state:'done',result:result('cancelled','session_cancelled',attempt.decisionID)});
   return attempt?.jobID;
  });
  await this.cancelJob(jobID);return {status:'cancelled' as const};
 }
 private async finish(actor:Actor,path:string,attemptPath:string,decision:Result):Promise<Result>{
  return this.store.transaction(async tx=>{
   const session=await tx.get<Session>(path),attempt=await tx.get<Attempt>(attemptPath);owned(session,actor);
   const closed=terminal(session,this.clock());if(closed)return closed;
   if(!attempt)throw new Failure('not-found','Attempt not found');
   if(attempt.result)return attempt.result;
   const final=attempt.leaseUntil<=this.clock()?result('unavailable','verification_timeout',attempt.decisionID):decision;
   tx.set(attemptPath,{...attempt,state:'done',result:final});tx.set(path,{...session,state:'finished'});return final;
  });
 }
 async verify(actor:Actor,input:unknown):Promise<Result>{
  authorize(actor);const data=parse(submissionSchema,input);if(data.consentVersion!==(this.config.consentVersion??CONSENT_VERSION))throw new Failure('invalid-argument','Current consent required');const path=`verificationSessions/${data.sessionID}`,attemptPath=`${path}/attempts/${data.evidenceID}`;
  const session=await this.store.transaction(async tx=>{const s=await tx.get<Session>(path);owned(s,actor);if(s.nonce!==data.nonce)throw new Failure('permission-denied','Invalid session nonce');return s;});
  const closed=terminal(session,this.clock());if(closed)return closed;
  if(!this.config.enabled)return result('unavailable','cloud_disabled');
  const evidence=await this.prepare(data,session.target);
  if(!evidence.sufficient)return result('uncertain','insufficient_evidence');
  const claim=await this.store.transaction(async tx=>{
   const current=await tx.get<Session>(path),attempt=await tx.get<Attempt>(attemptPath);owned(current,actor);
   const now=this.clock(),stopped=terminal(current,now);if(stopped)return {result:stopped};
   if(attempt){
    if(attempt.payloadHash!==evidence.payloadHash)throw new Failure('already-exists','Evidence ID already used');
    return {result:attempt.result??result(attempt.leaseUntil<=now?'unavailable':'pending',attempt.leaseUntil<=now?'verification_timeout':'verification_pending',attempt.decisionID)};
   }
   if(current.state!=='open')return {result:result('unavailable','attempt_limit')};
   const day=new Date(now).toISOString().slice(0,10),userPath=`quotaBuckets/ai-${hash(actor.uid)}-${day}`,globalPath=`quotaBuckets/ai-global-${day}`;
   const user=await tx.get<Bucket>(userPath),global=await tx.get<Bucket>(globalPath);
   if((user?.used??0)>=this.config.userDailyLimit||(global?.used??0)>=this.config.globalDailyLimit)return {result:result('unavailable','quota_exhausted')};
   const decisionID=randomUUID(),deadlineAt=now+JOB_DURATION_MS;
   tx.set(userPath,{used:(user?.used??0)+1,deleteAt:expiry(now)});tx.set(globalPath,{used:(global?.used??0)+1,deleteAt:expiry(now)});
   tx.set(attemptPath,{payloadHash:evidence.payloadHash,state:'running',leaseUntil:deadlineAt,decisionID,deleteAt:expiry(now),model:this.config.model,policyVersion:POLICY_VERSION,evidence:{frames:evidence.frames.map(({id})=>({id})),sufficient:evidence.sufficient}} satisfies Attempt);
   tx.set(path,{...current,state:'processing',attemptID:data.evidenceID});return {decisionID,deadlineAt};
  });
  if('result' in claim)return claim.result!;
  let jobID:string|undefined;
  // Transactions can replay. Dispatch once outside them; never retry an ambiguous acknowledgement.
  try{
   jobID=await this.provider.start(evidence,session.target,claim.deadlineAt);
   const pending=await this.store.transaction(async tx=>{
    const current=await tx.get<Session>(path),attempt=await tx.get<Attempt>(attemptPath);owned(current,actor);
    if(!attempt)throw new Failure('not-found','Attempt not found');
    const stopped=terminal(current,this.clock())??attempt.result??(attempt.leaseUntil<=this.clock()?result('unavailable','verification_timeout',attempt.decisionID):undefined);
    tx.set(attemptPath,{...attempt,jobID,...(stopped?{state:'done',result:stopped}:{})});
    return stopped??result('pending','verification_pending',attempt.decisionID);
   });
   if(pending.status!=='pending')await this.cancelJob(jobID);
   return pending;
  }catch{await this.cancelJob(jobID);return this.finish(actor,path,attemptPath,result('unavailable','provider_unavailable',claim.decisionID));}
 }
 async getResult(actor:Actor,input:unknown):Promise<Result>{
  authorize(actor);const data=parse(resultSchema,input),path=`verificationSessions/${data.sessionID}`,attemptPath=`${path}/attempts/${data.evidenceID}`;
  const snapshot=await this.store.transaction(async tx=>{
   const session=await tx.get<Session>(path),attempt=await tx.get<Attempt>(attemptPath);owned(session,actor);
   const stopped=terminal(session,this.clock());if(stopped)return {result:stopped};
   if(!attempt||session.attemptID!==data.evidenceID)throw new Failure('not-found','Attempt not found');
   if(attempt.result)return {result:attempt.result};
   if(!this.config.enabled||attempt.leaseUntil<=this.clock())return {session,attempt,stop:true as const};
   if(!attempt.jobID||(attempt.nextPollAt??0)>this.clock())return {result:result('pending','verification_pending',attempt.decisionID)};
   tx.set(attemptPath,{...attempt,nextPollAt:this.clock()+1000});return {session,attempt,stop:false as const};
  });
  if('result' in snapshot)return snapshot.result!;
  const {session,attempt}=snapshot;
  if(snapshot.stop){await this.cancelJob(attempt.jobID);return this.finish(actor,path,attemptPath,result('unavailable',this.config.enabled?'verification_timeout':'cloud_disabled',attempt.decisionID));}
  try{
   const response=await this.provider.get(attempt.jobID!);
   if(response.status==='pending')return result('pending','verification_pending',attempt.decisionID);
   return this.finish(actor,path,attemptPath,{...decide(response.verdict,attempt.evidence,session.target),decisionID:attempt.decisionID});
  }catch{await this.cancelJob(attempt.jobID);return this.finish(actor,path,attemptPath,result('unavailable','provider_unavailable',attempt.decisionID));}
 }
}
