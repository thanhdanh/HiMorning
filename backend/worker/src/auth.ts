import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';
import { Failure } from '../../functions/src/errors.js';
import type { Actor } from '../../functions/src/service.js';
import type { Env } from './config.js';
const options={timeoutDuration:5000,cacheMaxAge:3600000};
const authKeys=createRemoteJWKSet(new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'),options);
const appKeys=createRemoteJWKSet(new URL('https://firebaseappcheck.googleapis.com/v1/jwks'),options);
export async function authorize(request:Request,env:Env,keys:{auth:JWTVerifyGetKey;app:JWTVerifyGetKey}={auth:authKeys,app:appKeys}):Promise<Actor> {
 const bearer=request.headers.get('Authorization')??'',appToken=request.headers.get('X-Firebase-AppCheck')??'';
 if(!bearer.startsWith('Bearer ')||bearer.length>8192)throw new Failure('unauthenticated','Sign in for cloud verification');
 const now=Math.floor(Date.now()/1000);
 let uid:string;
 try {
  const {payload}=await jwtVerify(bearer.slice(7),keys.auth,{algorithms:['RS256'],issuer:`https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,audience:env.FIREBASE_PROJECT_ID,requiredClaims:['sub','exp','iat','auth_time']});
  if(!payload.sub||payload.sub.length>128||typeof payload.iat!=='number'||payload.iat>now||typeof payload.auth_time!=='number'||payload.auth_time<0||payload.auth_time>now)throw new Error('Invalid identity');
  uid=payload.sub;
 }catch{throw new Failure('unauthenticated','Invalid sign-in token');}
 if(!appToken||appToken.length>8192)throw new Failure('permission-denied','App attestation required');
 try {
  const {payload}=await jwtVerify(appToken,keys.app,{algorithms:['RS256'],typ:'JWT',issuer:`https://firebaseappcheck.googleapis.com/${env.FIREBASE_PROJECT_NUMBER}`,audience:`projects/${env.FIREBASE_PROJECT_NUMBER}`,requiredClaims:['sub','exp','iat']});
  if(payload.sub!==env.FIREBASE_APP_ID||typeof payload.iat!=='number'||payload.iat>now)throw new Error('Invalid attestation');
 }catch{throw new Failure('permission-denied','Invalid app attestation');}
 return {uid,appCheck:true};
}
