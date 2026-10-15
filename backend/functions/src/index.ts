import { info } from 'firebase-functions/logger';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { handlers } from './api.js';
import { readConfig } from './config.js';
import { FirestoreStore } from './firestore-store.js';
import { VerificationService } from './service.js';
import { prepareEvidence } from './evidence.js';
import { ModalVerifier } from './modal.js';
const proxyKey=defineSecret('MODAL_PROXY_KEY'),proxySecret=defineSecret('MODAL_PROXY_SECRET');
const options={region:'asia-southeast1',enforceAppCheck:true,minInstances:0,maxInstances:1,memory:'256MiB' as const,concurrency:8};
// Lazy startup keeps session creation independent of inference credentials.
function service(withAI=false) {
 if(!getApps().length)initializeApp();
 const config=readConfig(process.env);
 const unavailable=async():Promise<never>=>{throw new Error('Cloud disabled');};
 const provider=withAI&&config.enabled?new ModalVerifier(config.baseURL,proxyKey.value(),proxySecret.value(),config.model,usage=>info('verification_usage',usage)):{start:unavailable,get:unavailable,cancel:async()=>{}};
 return new VerificationService(new FirestoreStore(getFirestore()),provider,config,prepareEvidence);
}
const basic=handlers(()=>service()),ai=handlers(()=>service(true));
export const createVerificationSession=onCall({...options,timeoutSeconds:10},basic.create);
export const verifyChallenge=onCall({...options,timeoutSeconds:30,secrets:[proxyKey,proxySecret]},ai.verify);
export const getVerificationResult=onCall({...options,timeoutSeconds:30,secrets:[proxyKey,proxySecret]},ai.getResult);
export const cancelVerificationSession=onCall({...options,timeoutSeconds:30,secrets:[proxyKey,proxySecret]},ai.cancel);
