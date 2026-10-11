import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';
import { Failure } from './errors.js';
import type { VerificationService } from './service.js';
export function handlers(service: () => VerificationService) {
 const invoke=(method:'create'|'verify'|'cancel')=>async(request:CallableRequest<unknown>)=>{
  try { return await service()[method]({uid:request.auth?.uid??'',appCheck:!!request.app},request.data); }
  catch(error) { if(error instanceof Failure)throw new HttpsError(error.code,error.message);throw new HttpsError('internal','Verification service unavailable'); }
 };
 return {create:invoke('create'),verify:invoke('verify'),cancel:invoke('cancel')};
}
