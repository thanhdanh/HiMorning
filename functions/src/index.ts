import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { handlers } from './api.js';
import { readConfig } from './config.js';
import { FirestoreStore } from './firestore-store.js';
import { VerificationService } from './service.js';
import { OpenAIVerifier } from './openai.js';
const apiKey=defineSecret('OPENAI_API_KEY');
const options={region:'asia-southeast1',enforceAppCheck:true,minInstances:0,maxInstances:2,memory:'256MiB' as const,concurrency:8};
// Lazy startup: creating/cancelling a session never needs an OpenAI key.
function service(withAI=false) {
 if(!getApps().length)initializeApp();
 const config=readConfig(process.env);
 const provider=withAI&&config.enabled?new OpenAIVerifier(apiKey.value(),config.model):{verify:async()=>{throw new Error('Cloud disabled');}};
 return new VerificationService(new FirestoreStore(getFirestore()),provider,config);
}
const basic=handlers(()=>service()),ai=handlers(()=>service(true));
export const createVerificationSession=onCall({...options,timeoutSeconds:10},basic.create);
export const verifyChallenge=onCall({...options,timeoutSeconds:30,secrets:[apiKey]},ai.verify);
export const cancelVerificationSession=onCall({...options,timeoutSeconds:10},basic.cancel);
