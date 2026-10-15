import { describe, it, expect } from 'vitest';
import sharp from 'sharp';
import { prepareEvidence, decide } from '../backend/functions/src/evidence.js';
import { frames, uuid, complete } from './helpers.js';
const request = async () => ({ sessionID: 'a'.repeat(64), nonce: uuid(1), evidenceID: uuid(2), consentVersion: '2026-10-15', frames: await frames() });
describe('bounded evidence and conservative decision', () => {
 it('validates, strips image metadata and hashes content deterministically', async () => {
  const data = await request(); const a = await prepareEvidence(data, 1); const b = await prepareEvidence(data, 1);
  expect(a.payloadHash).toBe(b.payloadHash); expect(a.frames).toHaveLength(5); expect(a.sufficient).toBe(true);
  expect(a.frames[0].dataURL).toMatch(/^data:image\/jpeg;base64,/);
  expect((await prepareEvidence({ ...data, frames: await frames(6) }, 1)).payloadHash).not.toBe(a.payloadHash);
 });
 it('keeps too-short evidence uncertain without guessing', async () => {
  expect((await prepareEvidence(await request(), 2)).sufficient).toBe(false);
 });
 it('rejects adjacent cycles that share their boundary frame', async () => {
  const evidence = await prepareEvidence({...await request(), frames: await frames(10)}, 2);
  const verdict = complete(2);
  verdict.reps[1].frameIDs = ['f4','f5','f6','f7','f8'];
  expect(decide(verdict, evidence, 2).status).toBe('uncertain');
  expect(decide(complete(2), evidence, 2).status).toBe('verified');
 });
 it.each(['url', 'bad-base64', 'png', 'oversize', 'dimensions', 'duplicate-id', 'duplicate-image', 'time-order', 'too-many', 'negative-time', 'unknown-field', 'consent'])('rejects %s before inference', async (kind) => {
  const data: any = await request();
  if (kind === 'url') data.frames[0].jpegBase64 = 'https://example.com/image.jpg';
  if (kind === 'bad-base64') data.frames[0].jpegBase64 = '!!!!';
  if (kind === 'png') data.frames[0].jpegBase64 = (await sharp({create:{width:40,height:40,channels:3,background:'red'}}).png().toBuffer()).toString('base64');
  if (kind === 'oversize') data.frames[0].jpegBase64 = 'A'.repeat(70000);
  if (kind === 'dimensions') data.frames[0].jpegBase64 = (await sharp({create:{width:513,height:40,channels:3,background:'red'}}).jpeg().toBuffer()).toString('base64');
  if (kind === 'duplicate-id') data.frames[1].id = data.frames[0].id;
  if (kind === 'duplicate-image') data.frames[1].jpegBase64 = data.frames[0].jpegBase64;
  if (kind === 'time-order') data.frames[1].timestampMs = 0;
  if (kind === 'too-many') data.frames = await frames(26);
  if (kind === 'negative-time') data.frames[0].timestampMs = -1;
  if (kind === 'unknown-field') data.remoteURL = 'https://example.com';
  if (kind === 'consent') data.consentVersion = 'old';
  await expect(prepareEvidence(data, 1)).rejects.toThrow();
 });
 it('only accepts fully observed, ordered, distinct cycles and allowed cues', async () => {
  const evidence = await prepareEvidence({...await request(), frames: await frames(10)}, 2);
  expect(decide(complete(2), evidence, 2).status).toBe('verified');
  expect(decide(complete(1), evidence, 2).status).toBe('incomplete');
  for(const invalid of [null, { ...complete(2), cue:'free-text' }, { ...complete(2), reps:[{frameIDs:['f0','f1','f2','f3','missing']}] }, { ...complete(2), reps:[complete().reps[0],complete().reps[0]] }, { ...complete(), reps:[{frameIDs:['f4','f3','f2','f1','f0']}] }, { ...complete(), reps: [...complete(2).reps, ...complete(2).reps] }]) {
   expect(decide(invalid, evidence, 2).status).toBe('uncertain');
  }
  expect(decide({status:'incomplete',reps:[],cue:'none'}, evidence, 2).status).toBe('incomplete');
  expect(decide({status:'uncertain',reps:[],cue:'adjust_camera'}, evidence, 2).status).toBe('uncertain');
 });
});
