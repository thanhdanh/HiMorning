import fixture from '../../../shared/contracts/v1/free-demo-frames.json';
import { submissionSchema } from '../../functions/src/contracts.js';
import { Failure, parse } from '../../functions/src/errors.js';
import { hash, type Evidence } from '../../functions/src/policy.js';
export async function prepareDemoEvidence(input:unknown,target:number):Promise<Evidence> {
 const data=parse(submissionSchema,input);
 if(data.frames.length!==target*5||data.frames.some((frame,index)=>{
  const expected=fixture.frames[index];
  return frame.id!==expected.id||frame.timestampMs!==expected.timestampMs||frame.jpegBase64!==expected.jpegBase64;
 }))throw new Failure('invalid-argument','This free demo accepts only the bundled generated images');
 return {frames:data.frames.map(frame=>({id:frame.id,timestampMs:frame.timestampMs,dataURL:`data:image/jpeg;base64,${frame.jpegBase64}`})),payloadHash:hash(JSON.stringify(data)),sufficient:true};
}
