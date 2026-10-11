import { describe, expect, it } from 'vitest';
import { parseRollout, summarizeUsage } from '../scripts/lib/ai-usage.mjs';
const usage = { input_tokens: 100, cached_input_tokens: 60, cache_write_input_tokens: 0, output_tokens: 20, reasoning_output_tokens: 5, total_tokens: 120 };
const context = { type: 'turn_context', payload: { turn_id: 'turn-a', model: 'recorded-model' } };
const record = (id = 'response-a', overrides = {}) => ({ type: 'token_usage_record', timestamp: '2026-10-11T10:00:00Z', payload: { thread_id: 'this-thread', turn_id: 'turn-a', response_id: id, usage, thread_token_usage: usage, ...overrides } });
const options = { threadID: 'this-thread', phaseByTurn: { 'turn-a': 'implementation_testing' } };
describe('AI engineering token evidence', () => {
 it('counts each response once and does not add cumulative snapshots or subset tokens', () => {
  const report = summarizeUsage([context, record(), record(), { type: 'event_msg', payload: { type: 'token_count', info: { total_token_usage: usage } } }], options);
  expect(report.totals).toMatchObject({ input_tokens: 100, cached_input_tokens: 60, uncached_input_tokens: 40, output_tokens: 20, reasoning_output_tokens: 5, total_tokens: 120 });
  expect(report.responses).toBe(1); expect(report.duplicateRecords).toBe(1); expect(report.reconciliation.matches).toBe(true);
  expect(report.estimatedCostUSD).toBeNull();
 });
 it('assigns observed requests by turn, retains unknown phases and attributes model from context', () => {
  const doubled = Object.fromEntries(Object.entries(usage).map(([k,v]) => [k,v*2]));
  const report = summarizeUsage([context, record(), record('response-b', { turn_id: 'untagged', thread_token_usage: doubled })], options);
  expect(report.byPhase.implementation_testing.total_tokens).toBe(120);
  expect(report.byPhase.unallocated.total_tokens).toBe(120);
  expect(report.byModel['recorded-model'].total_tokens).toBe(120);
  expect(report.byModel.unknown.total_tokens).toBe(120);
  expect(report.reconciliation.matches).toBe(true);
 });
 it('excludes other conversations and never exports transcript content or response identifiers', () => {
  const report = summarizeUsage([record('private-id', { thread_id: 'other-thread' }), record(), { type: 'response_item', payload: { content: 'private prompt' } }], options);
  expect(report.responses).toBe(1);
  expect(JSON.stringify(report)).not.toMatch(/private|response-a|this-thread|turn-a/);
 });
 it('fails on conflicting duplicates and invalid token arithmetic instead of silently inventing totals', () => {
  expect(() => summarizeUsage([record(), record('response-a', { usage: { ...usage, output_tokens: 21, total_tokens: 121 } })], options)).toThrow(/conflict/i);
  for (const invalid of [{ ...usage, cached_input_tokens: 101 }, { ...usage, reasoning_output_tokens: 21 }, { ...usage, total_tokens: 999 }, { ...usage, output_tokens: -1 }, { ...usage, input_tokens: 0.5 }]) {
   expect(() => summarizeUsage([record('bad', { usage: invalid })], options)).toThrow(/usage/i);
  }
 });
 it('marks an incomplete ledger when the cumulative snapshot includes unobserved usage', () => {
  const report = summarizeUsage([record('a', { thread_token_usage: { ...usage, input_tokens: 200, total_tokens: 220 } })], options);
  expect(report.reconciliation.matches).toBe(false);
  expect(report.reconciliation.delta.total_tokens).toBe(100);
 });
 it('preserves unavailable telemetry as null, not zero usage', () => {
  const report = summarizeUsage([{ type: 'event_msg', payload: {} }], options);
  expect(report.totals).toBeNull(); expect(report.reconciliation.matches).toBeNull();
  expect(() => summarizeUsage([record('missing', { usage: undefined })], options)).toThrow(/usage/i);
 });
 it('ignores only an unfinished final JSONL record and rejects malformed complete lines', () => {
  expect(parseRollout(JSON.stringify(record()) + '\n{"unfinished":').incompleteFinalLine).toBe(true);
  expect(parseRollout(JSON.stringify(record()) + '\n').records).toHaveLength(1);
  expect(() => parseRollout('not-json\n' + JSON.stringify(record()))).toThrow(/line 1/i);
 });
});
