import { describe, it, expect, vi, beforeEach } from 'vitest';
const sdk=vi.hoisted(()=>({parse:vi.fn(),options:vi.fn()}));
vi.mock('openai',()=>({default:class { responses={parse:sdk.parse};constructor(options:unknown){sdk.options(options);} }}));
import { OpenAIVerifier } from '../functions/src/openai.js';
import { prepareEvidence } from '../functions/src/evidence.js';
import { frames, uuid, complete } from './helpers.js';
beforeEach(()=>{vi.clearAllMocks();});
describe('OpenAI bounded adapter',()=>{
 it('uses ordered images, strict schema, store false, capped output and zero SDK retries',async()=>{
  sdk.parse.mockResolvedValue({status:'completed',output_parsed:complete(),usage:{input_tokens:500,output_tokens:50}});
  const evidence=await prepareEvidence({sessionID:'a'.repeat(64),nonce:uuid(1),evidenceID:uuid(2),consentVersion:'2026-10-11',frames:await frames()},1);
  const meter=vi.fn();const verifier=new OpenAIVerifier('not-a-real-key','test-model',meter); const result=await verifier.verify(evidence,1);
  expect(result).toEqual(complete());expect(meter).toHaveBeenCalledWith({model:'test-model',inputTokens:500,outputTokens:50,reasoningTokens:0});expect(sdk.options).toHaveBeenCalledWith(expect.objectContaining({maxRetries:0,timeout:15000}));
  const request=sdk.parse.mock.calls[0][0];expect(request).toMatchObject({model:'test-model',store:false,max_output_tokens:800});
  expect(request.reasoning).toEqual({effort:'none'});expect(request.text.verbosity).toBe('low');expect(request.text.format.strict).toBe(true);const content=request.input[1].content;
  expect(content.filter((c:any)=>c.type==='input_image')).toHaveLength(5);
  expect(content.filter((c:any)=>c.type==='input_text').map((c:any)=>c.text).join(' ')).toMatch(/f0.*0.*f1.*300.*f2/s);
  expect(request).not.toHaveProperty('tools');expect(sdk.parse).toHaveBeenCalledOnce();
 });
 it.each([{status:'incomplete',output_parsed:complete()},{status:'completed',output_parsed:null},{status:'completed',output_parsed:{status:'complete'}}])('treats incomplete/refused/unparsed output as uncertain',async(response)=>{
  sdk.parse.mockResolvedValue(response); const verifier=new OpenAIVerifier('fake','test-model');
  expect((await verifier.verify({frames:[],payloadHash:'x',sufficient:true},1)).status).toBe('uncertain');
 });
 it('propagates provider errors without retrying',async()=>{
  sdk.parse.mockRejectedValue(new Error('429'));const verifier=new OpenAIVerifier('fake','test-model');
  await expect(verifier.verify({frames:[],payloadHash:'x',sufficient:true},1)).rejects.toThrow('429');expect(sdk.parse).toHaveBeenCalledOnce();
 });
});
