// Local Codex rollout schema, observed 2026-10-11. This is not a public API.
const fields = ['input_tokens', 'cached_input_tokens', 'cache_write_input_tokens', 'output_tokens', 'reasoning_output_tokens', 'total_tokens'];
function validateUsage(value) {
 if (!value || fields.some(key => !Number.isSafeInteger(value[key]) || value[key] < 0)
  || value.cached_input_tokens > value.input_tokens || value.reasoning_output_tokens > value.output_tokens
  || value.total_tokens !== value.input_tokens + value.output_tokens) throw new Error('Unsupported or invalid token usage');
 return Object.fromEntries(fields.map(key => [key, value[key]]));
}
function empty() { return Object.fromEntries(fields.map(key => [key, 0])); }
function add(target, usage) { for (const key of fields) target[key] += usage[key]; }
function derived(usage) { return { ...usage, uncached_input_tokens: usage.input_tokens - usage.cached_input_tokens }; }
export function parseRollout(text) {
 const lines = text.split('\n'), records = [];
 let incompleteFinalLine = false;
 for (const [i, line] of lines.entries()) {
  if (!line.trim()) continue;
  try { records.push(JSON.parse(line)); }
  catch {
   if (i === lines.length - 1 && !text.endsWith('\n')) incompleteFinalLine = true;
   else throw new Error(`Malformed rollout JSON at line ${i + 1}`);
  }
 }
 return { records, incompleteFinalLine };
}
export function summarizeUsage(records, { threadID, phaseByTurn = {} }) {
 if (!threadID) throw new Error('Explicit threadID required');
 const seen = new Map(), models = new Map(), totals = empty(), byPhase = {}, byModel = {};
 let duplicateRecords = 0, snapshot = null, capturedThrough = null;
 for (const record of records) {
  const p = record.payload;
  if (record.type === 'turn_context' && p?.turn_id && p.model) models.set(p.turn_id, p.model);
  if (record.type !== 'token_usage_record' || p?.thread_id !== threadID) continue;
  if (typeof p.response_id !== 'string' || !p.response_id || typeof p.turn_id !== 'string') throw new Error('Unsupported usage identity');
  const usage = validateUsage(p.usage);
  const fingerprint = JSON.stringify({ usage, turn: p.turn_id });
  if (seen.has(p.response_id)) {
   if (seen.get(p.response_id) !== fingerprint) throw new Error('Conflicting duplicate response usage');
   duplicateRecords++; continue;
  }
  seen.set(p.response_id, fingerprint);
  add(totals, usage);
  const phase = phaseByTurn[p.turn_id] ?? 'unallocated', model = models.get(p.turn_id) ?? 'unknown';
  byPhase[phase] ??= empty(); byModel[model] ??= empty();
  add(byPhase[phase], usage); add(byModel[model], usage);
  // Only the latest cumulative snapshot is compared; snapshots are never summed.
  snapshot = p.thread_token_usage ? validateUsage(p.thread_token_usage) : null;
  capturedThrough = record.timestamp ?? null;
 }
 const delta = snapshot ? Object.fromEntries(fields.map(key => [key, snapshot[key] - totals[key]])) : null;
 return {
  schemaVersion: 1, source: 'codex-local-token_usage_record', capturedThrough,
  attribution: 'manual turn categories; mixed code/test turns remain combined',
  responses: seen.size, duplicateRecords,
  totals: seen.size ? derived(totals) : null,
  byPhase: Object.fromEntries(Object.entries(byPhase).map(([key,value]) => [key,derived(value)])),
  byModel: Object.fromEntries(Object.entries(byModel).map(([key,value]) => [key,derived(value)])),
  cacheHitRatio: seen.size && totals.input_tokens ? totals.cached_input_tokens / totals.input_tokens : null,
  reconciliation: { matches: delta ? Object.values(delta).every(value => value === 0) : null, delta },
  estimatedCostUSD: null,
  costNote: 'Token telemetry is not an invoice. No subscription-to-API price conversion or assumed price table.'
 };
}
