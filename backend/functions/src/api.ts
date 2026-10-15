import { info } from 'firebase-functions/logger';
import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';
import { Failure } from './errors.js';
import type { VerificationService } from './service.js';
export function handlers(service: () => VerificationService) {
 const invoke=(method:'create'|'verify'|'getResult'|'cancel')=>async(request:CallableRequest<unknown>)=>{
  try {
   const output=await service()[method]({uid:request.auth?.uid??'',appCheck:!!request.app},request.data);
   if((method==='verify'||method==='getResult')&&'status' in output){try{info('verification_decision',{operation:method,status:output.status});}catch{/* Logging cannot change a decision. */}}
   return output;
  }
  catch(error) { if(error instanceof Failure)throw new HttpsError(error.code,error.message);throw new HttpsError('internal','Verification service unavailable'); }
 };
 return {create:invoke('create'),verify:invoke('verify'),getResult:invoke('getResult'),cancel:invoke('cancel')};
}
