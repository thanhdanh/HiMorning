import { describe, it, expect, vi } from 'vitest';
import { ModalVerifier } from '../backend/functions/src/modal.js';
const evidence={frames:[{id:'f0',timestampMs:0,dataURL:'data:image/jpeg;base64,eA=='}],payloadHash:'hash',sufficient:true};
function setup(){const request=vi.fn<typeof fetch>();const meter=vi.fn();return {request,meter,provider:new ModalVerifier('https://pilot.modal.run','key','secret','qwen',meter,request)};}
describe('Modal transport boundary',()=>{
 it('dispatches once over authenticated HTTPS and reads results without sending images again',async()=>{
  const s=setup();s.request.mockResolvedValueOnce(Response.json({jobID:'fc-job'})).mockResolvedValueOnce(Response.json({status:'pending'})).mockResolvedValueOnce(Response.json({status:'completed',verdict:{status:'uncertain',reps:[],cue:'none'}})).mockResolvedValueOnce(Response.json({status:'cancelled'}));
  expect(await s.provider.start(evidence,1,123)).toBe('fc-job');expect(await s.provider.get('fc-job')).toEqual({status:'pending'});expect((await s.provider.get('fc-job')).status).toBe('completed');await s.provider.cancel('fc-job');
  const [url,options]=s.request.mock.calls[0];expect(url).toBe('https://pilot.modal.run/jobs');expect(options).toMatchObject({method:'POST',redirect:'error',headers:{'Modal-Key':'key','Modal-Secret':'secret'}});expect(JSON.parse(options!.body as string)).toEqual({model:'qwen',target:1,deadlineAt:123,frames:evidence.frames});
  expect(s.request.mock.calls[1][1]).not.toHaveProperty('body');expect(JSON.stringify(s.meter.mock.calls)).not.toMatch(/dataURL|secret|base64/);
 });
 it('does not retry rejected requests or return provider error bodies',async()=>{
  const s=setup();s.request.mockResolvedValue(new Response('sensitive request body',{status:429}));await expect(s.provider.start(evidence,1,123)).rejects.toThrow('Inference service unavailable');expect(s.request).toHaveBeenCalledOnce();
 });
 it.each([{jobID:'https://attacker.test'},{jobID:'fc-ok',extra:true}])('rejects untrusted job identifiers',async body=>{
  const s=setup();s.request.mockResolvedValue(Response.json(body));await expect(s.provider.start(evidence,1,123)).rejects.toThrow();await expect(s.provider.get('../secret')).rejects.toThrow();expect(s.request).toHaveBeenCalledOnce();
 });
 it('bounds responses and tolerates logging failures',async()=>{
  const request=vi.fn<typeof fetch>().mockResolvedValueOnce(new Response('x'.repeat(65537))).mockResolvedValueOnce(Response.json({jobID:'fc-job'}));
  const provider=new ModalVerifier('https://pilot.modal.run','key','secret','qwen',()=>{throw new Error('logger');},request);
  await expect(provider.start(evidence,1,123)).rejects.toThrow('too large');expect(await provider.start(evidence,1,123)).toBe('fc-job');
  expect(()=>new ModalVerifier('https://pilot.modal.run','','secret','qwen')).toThrow();
 });
});
