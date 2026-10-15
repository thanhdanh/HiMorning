import { z } from 'zod';
import { DEMO_CONSENT_VERSION } from '../../functions/src/contracts.js';
import type { Config } from '../../functions/src/config.js';
export const MODEL='gemini-3.5-flash-lite';
export interface Env {
 AI_VERIFICATION_ENABLED:string; FIREBASE_PROJECT_ID:string; FIREBASE_PROJECT_NUMBER:string; FIREBASE_APP_ID:string;
 GEMINI_API_KEY?:string; VERIFICATIONS:DurableObjectNamespace;
}
export function workerConfig(env:Env):Config {
 z.string().regex(/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/).parse(env.FIREBASE_PROJECT_ID);
 z.string().regex(/^\d+$/).parse(env.FIREBASE_PROJECT_NUMBER);
 z.string().startsWith(`1:${env.FIREBASE_PROJECT_NUMBER}:ios:`).min(20).parse(env.FIREBASE_APP_ID);
 const enabled=z.enum(['true','false']).parse(env.AI_VERIFICATION_ENABLED)==='true';
 if(enabled&&!env.GEMINI_API_KEY)throw new Error('Missing server secret');
 return {enabled,model:MODEL,baseURL:'',userDailyLimit:3,globalDailyLimit:10,consentVersion:DEMO_CONSENT_VERSION};
}
