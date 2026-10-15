import { z } from 'zod';
import type { Evidence } from './evidence.js';
import type { Verifier } from './service.js';
const jobSchema=z.object({jobID:z.string().regex(/^fc-[a-zA-Z0-9_-]{1,200}$/)}).strict();
const responseSchema=z.discriminatedUnion('status',[z.object({status:z.literal('pending')}).strict(),z.object({status:z.literal('completed'),verdict:z.unknown()}).strict()]);
export class ModalVerifier implements Verifier {
 constructor(private readonly baseURL:string,private readonly key:string,private readonly secret:string,private readonly model:string,private readonly meter:(data:object)=>void=()=>{},private readonly request:typeof fetch=fetch){if(!key||!secret)throw new Error('Missing inference credentials');}
 private async call(path:string,method:string,body?:unknown){
  const started=Date.now();let status=0;
  try{
   const response=await this.request(`${this.baseURL}${path}`,{method,headers:{'Content-Type':'application/json','Modal-Key':this.key,'Modal-Secret':this.secret},...(body===undefined?{}:{body:JSON.stringify(body)}),redirect:'error',signal:AbortSignal.timeout(method==='POST'?20000:8000)});
   status=response.status;if(!response.ok)throw new Error('Inference service unavailable');
   const reader=response.body?.getReader();if(!reader)throw new Error('Missing inference response');
   const chunks:Uint8Array[]=[];let length=0;
   try{while(true){const {value,done}=await reader.read();if(done)break;length+=value.length;if(length>65536){await reader.cancel();throw new Error('Inference response too large');}chunks.push(value);}}finally{reader.releaseLock();}
   return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  }finally{try{this.meter({provider:'modal',model:this.model,operation:method,durationMs:Date.now()-started,httpStatus:status});}catch{/* Metrics never change a decision. */}}
 }
 async start(evidence:Evidence,target:number,deadlineAt:number){return jobSchema.parse(await this.call('/jobs','POST',{model:this.model,target,deadlineAt,frames:evidence.frames})).jobID;}
 async get(jobID:string){jobSchema.parse({jobID});return responseSchema.parse(await this.call(`/jobs/${encodeURIComponent(jobID)}`,'GET'));}
 async cancel(jobID:string){jobSchema.parse({jobID});await this.call(`/jobs/${encodeURIComponent(jobID)}`,'DELETE');}
}
