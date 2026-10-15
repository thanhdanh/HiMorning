import { describe,it,expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { stagingConfig } from '../scripts/deploy-staging.mjs';
import { readConfig } from '../backend/functions/src/config.js';
describe('explicit staging deployment boundary',()=>{
 it('retains the safe emulator default and validates a separate non-secret staging configuration',()=>{
  expect(JSON.parse(readFileSync('.firebaserc','utf8')).projects.default).toBe('demo-himorning');
  expect(readConfig(stagingConfig('himorning-staging-check',readFileSync('backend/functions/.env.example','utf8')))).toMatchObject({enabled:false,globalDailyLimit:10});
  const config=JSON.parse(readFileSync('firebase.staging.json','utf8'));
  expect(config.firestore.indexes).toBe('firestore.indexes.json');
 });
 it('rejects missing, demo, traversal and accidental production targets',()=>{
  for(const project of [undefined,'demo-himorning','himorning-production','../himorning-staging','himorning-staging/secret'])expect(()=>stagingConfig(project,'')).toThrow();
 });
 it('rejects secret-bearing or malformed environment files',()=>{
  for(const source of ['MODAL_PROXY_SECRET=do-not-log','OPENAI_API_KEY=do-not-log','not-an-assignment'])expect(()=>stagingConfig('himorning-staging-check',source)).toThrow();
 });
});
