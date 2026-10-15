import { Failure } from '../../functions/src/errors.js';
import type { Actor, VerificationService } from '../../functions/src/service.js';
export const methods={createVerificationSession:'create',verifyChallenge:'verify',getVerificationResult:'getResult',cancelVerificationSession:'cancel'} as const;
export type Method=keyof typeof methods;
const statuses={'invalid-argument':400,'unauthenticated':401,'permission-denied':403,'not-found':404,'already-exists':409,'resource-exhausted':429} as const;
// Firebase native SDKs wrap 64-bit integers even when their values fit a JSON number.
export function decodeCallable(data:unknown,depth=0):unknown {
 if(depth>10)throw new Failure('invalid-argument','Callable data is too deeply nested');
 if(Array.isArray(data))return data.map(value=>decodeCallable(value,depth+1));
 if(data===null||typeof data!=='object')return data;
 const fields=data as Record<string,unknown>;
 if(Object.hasOwn(fields,'@type')) {
  const unsigned=fields['@type']==='type.googleapis.com/google.protobuf.UInt64Value';
  if((!unsigned&&fields['@type']!=='type.googleapis.com/google.protobuf.Int64Value')||Object.keys(fields).length!==2||typeof fields.value!=='string'||!(unsigned?/^\d+$/:/^-?\d+$/).test(fields.value)||!Number.isSafeInteger(Number(fields.value)))throw new Failure('invalid-argument','Invalid callable integer');
  return Number(fields.value);
 }
 return Object.fromEntries(Object.entries(fields).map(([key,value])=>[key,decodeCallable(value,depth+1)]));
}
export function failureResponse(error:unknown) {
 const known=error instanceof Failure,code=known?error.code:'unavailable';
 return Response.json({error:{status:code.toUpperCase().replaceAll('-','_'),message:known?error.message:'Remote demo unavailable'}},{status:known?statuses[error.code]:503,headers:{'Cache-Control':'no-store'}});
}
export async function invoke(service:VerificationService,method:Method,actor:Actor,data:unknown) {
 const output=await service[methods[method]](actor,decodeCallable(data));
 return Response.json({data:output},{headers:{'Cache-Control':'no-store'}});
}
