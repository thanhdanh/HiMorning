import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { contractSchemas } from '../backend/functions/src/contracts.js';
import { prepareEvidence } from '../backend/functions/src/evidence.js';
const read = (name: string) => JSON.parse(readFileSync(`shared/contracts/v1/${name}.json`, 'utf8'));
describe('platform-neutral verification contract', () => {
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
 it('rejects drift in consent, target, frame shape and server outcomes', () => {
  const fixtures = read('wire-fixtures');
  expect(contractSchemas.CreateRequest.safeParse({...fixtures.CreateRequest, target: 0}).success).toBe(false);
  expect(contractSchemas.CreateRequest.safeParse({...fixtures.CreateRequest, consentVersion:'old'}).success).toBe(false);
  expect(contractSchemas.SubmitRequest.safeParse({...fixtures.SubmitRequest, frames:[{...fixtures.SubmitRequest.frames[0], extra:true}]}).success).toBe(false);
  expect(contractSchemas.Decision.safeParse({...fixtures.Decision,status:'self_confirmed'}).success).toBe(false);
 });
});
