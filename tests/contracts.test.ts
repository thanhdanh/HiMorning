import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { contractSchemas } from '../backend/functions/src/contracts.js';
import { prepareEvidence } from '../backend/functions/src/evidence.js';
const read = (name: string) => JSON.parse(readFileSync(`shared/contracts/v1/${name}.json`, 'utf8'));
describe('platform-neutral verification contract', () => {
 it('publishes current wake-mode presets',()=>{
  expect(read('wake-modes')).toEqual({gentle:{reps:0,snoozes:2},balanced:{reps:5,snoozes:1},focused:{reps:10,snoozes:0}});
 });
 it('exports JSON schemas that match the backend wire schemas', () => {
  const contract = read('verification.schema');
  expect(contract.$id).toBe('urn:himorning:verification:v1');
  expect(Object.keys(contract.$defs).sort()).toEqual(Object.keys(contractSchemas).sort());
  for (const [name, schema] of Object.entries(contractSchemas)) {
   const { $schema, ...definition } = z.toJSONSchema(schema);
   expect(contract.$defs[name]).toEqual(definition);
  }
 });
 it('accepts shared wire fixtures, including ordered synthetic JPEG evidence', async () => {
  const fixtures = read('wire-fixtures');
  for(const file of ['wire-fixtures','free-demo-wire'])for (const [name, schema] of Object.entries(contractSchemas)) expect(schema.safeParse(read(file)[name]).success, `${file}: ${name}`).toBe(true);
  const evidence = await prepareEvidence(fixtures.SubmitRequest, fixtures.CreateRequest.target);
  expect(evidence.sufficient).toBe(true);
  expect(evidence.frames).toHaveLength(5);
 });
 it.each([1,5,10,20,50])('accepts target %i and bounded counts', target => {
  expect(contractSchemas.CreateRequest.safeParse({...read('wire-fixtures').CreateRequest,target}).success).toBe(true);
  expect(contractSchemas.Decision.safeParse({...read('wire-fixtures').Decision,verifiedRepCount:target}).success).toBe(true);
 });
 it('retains legacy session limits while publishing bounded fifty-cycle limits',()=>{
  const response=read('wire-fixtures').CreateResponse;
  expect(contractSchemas.CreateResponse.safeParse({...response,limits:{...response.limits,maxFrames:25,maxTotalBytes:1250000}}).success).toBe(true);
  expect(response.limits).toMatchObject({maxFrames:250,maxFrameBytes:50000,maxTotalBytes:12500000,maxDimension:512});
  expect(contractSchemas.SubmitRequest.safeParse({...read('wire-fixtures').SubmitRequest,frames:Array.from({length:251},()=>read('wire-fixtures').SubmitRequest.frames[0])}).success).toBe(false);
 });
 it('rejects drift in consent, target, frame shape and server outcomes', () => {
  const fixtures = read('wire-fixtures');
  expect(contractSchemas.CreateRequest.safeParse({...fixtures.CreateRequest, target: 51}).success).toBe(false);
  expect(contractSchemas.CreateRequest.safeParse({...fixtures.CreateRequest, consentVersion:'old'}).success).toBe(false);
  expect(contractSchemas.SubmitRequest.safeParse({...fixtures.SubmitRequest, frames:[{...fixtures.SubmitRequest.frames[0], extra:true}]}).success).toBe(false);
  expect(contractSchemas.Decision.safeParse({...fixtures.Decision,status:'self_confirmed'}).success).toBe(false);
 });
});
