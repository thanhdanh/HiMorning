import fixture from '../../../shared/contracts/v1/free-demo-frames.json';
import { DEMO_CONSENT_VERSION } from '../../functions/src/contracts.js';
import type { Env } from '../src/config.js';
export const env:Env={AI_VERIFICATION_ENABLED:'true',FIREBASE_PROJECT_ID:'himorning-staging-0109',FIREBASE_PROJECT_NUMBER:'574230907604',FIREBASE_APP_ID:'1:574230907604:ios:0123456789abcdef',GEMINI_API_KEY:'test-only-not-a-real-key',VERIFICATIONS:undefined as never};
export const actor={uid:'demo-user',appCheck:true};
export const uuid=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
export const create=(n=1)=>({requestID:uuid(n),challenge:'pushup',target:1,consentVersion:DEMO_CONSENT_VERSION});
export const submit=(session:{sessionID:string;nonce:string})=>({...session,evidenceID:uuid(2),consentVersion:DEMO_CONSENT_VERSION,frames:fixture.frames.slice(0,5)});
export const completion=(verdict:unknown={status:'uncertain',reps:[],cue:'none'})=>({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(verdict)}]}}]});
export class MemoryStorage {
 docs=new Map<string,unknown>();alarm:number|null=null;
 private tail:Promise<unknown>=Promise.resolve();
 asStorage(){return this as unknown as DurableObjectStorage;}
 async get<T>(key:string){return structuredClone(this.docs.get(key)) as T|undefined;}
 async put(key:string|Record<string,unknown>,value?:unknown){if(typeof key==='string')this.docs.set(key,structuredClone(value));else for(const [path,item] of Object.entries(key))this.docs.set(path,structuredClone(item));}
 async transaction<T>(operation:(tx:DurableObjectTransaction)=>Promise<T>):Promise<T>{
  const next=this.tail.then(()=>operation(this as unknown as DurableObjectTransaction));this.tail=next.catch(()=>{});return next;
 }
 async list<T>({startAfter='',limit=256}={}) {return new Map([...this.docs].sort(([a],[b])=>a.localeCompare(b)).filter(([key])=>key>startAfter).slice(0,limit).map(([key,value])=>[key,structuredClone(value) as T]));}
 async delete(keys:string[]){for(const key of keys)this.docs.delete(key);return keys.length;}
 async getAlarm(){return this.alarm;}
 async setAlarm(value:number){this.alarm=value;}
}
