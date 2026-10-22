import { createHash } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { buildPack, challengeContentPack, tokenCount, validatePack } from '../scripts/lib/challenge-content.mjs';
const read = (path: string) => JSON.parse(readFileSync(new URL(path, import.meta.url), 'utf8'));
const sample = () => read('../shared/contracts/v1/fixtures/challenge-content.sample.json');
const base = { source: 'himorning', license: 'original' };
const words = (n: number) => Array.from({ length: n }, (_, i) => `word${i}`).join(' ');
const readAloud = (id: string, text: string, language = 'en') => ({ id, kind: 'readAloud', language, text, ...base });
const choice = (id: string, overrides = {}) => ({ id, kind: 'riddle', language: 'en', text: `Question ${id}?`, choices: ['a', 'b', 'c'], answerIndex: 0, ...base, ...overrides });
const pack = (items: unknown[]) => ({ version: 1, generatedAt: '2026-10-18T00:00:00Z', items });
describe('challenge content pack', () => {
 it('accepts the shared sample fixture', () => {
  const result = validatePack(sample());
  expect(result.errors).toEqual([]);
  expect(result.valid).toHaveLength(12);
 });
 it('rejects a 17-token readAloud', () => {
  expect(validatePack(pack([readAloud('short', words(17))])).errors).toHaveLength(1);
  expect(validatePack(pack([readAloud('ok', words(18))])).errors).toEqual([]);
  expect(validatePack(pack([readAloud('long', words(31))])).errors).toHaveLength(1);
 });
 it('rejects a duplicate id', () => {
  const result = validatePack(pack([choice('dup'), choice('dup', { text: 'Another one?' })]));
  expect(result.errors).toHaveLength(1);
  expect(result.errors[0]).toContain('duplicate id');
  expect(result.valid).toHaveLength(1);
 });
 it('rejects answerIndex 3', () => {
  expect(validatePack(pack([choice('a', { answerIndex: 3 })])).errors).toHaveLength(1);
 });
 it('rejects 2 choices', () => {
  expect(validatePack(pack([choice('a', { choices: ['a', 'b'] })])).errors).toHaveLength(1);
 });
 it('rejects language "fr"', () => {
  expect(validatePack(pack([choice('a', { language: 'fr' })])).errors).toHaveLength(1);
 });
 it('rejects blank fields, choices on readAloud and null answerIndex', () => {
  expect(validatePack(pack([choice('a', { text: '  ' })])).errors).toHaveLength(1);
  expect(validatePack(pack([choice('b', { choices: ['a', ' ', 'c'] })])).errors).toHaveLength(1);
  expect(validatePack(pack([{ ...readAloud('c', words(20)), choices: ['a', 'b', 'c'], answerIndex: 0 }])).errors).toHaveLength(1);
  expect(validatePack(pack([choice('d', { answerIndex: undefined })])).errors).toHaveLength(1);
 });
 it('rejects duplicate normalised text per language across kinds but not across languages', () => {
  const dup = validatePack(pack([choice('a', { text: 'Café, au lait!' }), choice('b', { kind: 'readAndChoose', text: 'cafe au LAIT' })]));
  expect(dup.errors).toHaveLength(1);
  expect(dup.errors[0]).toContain('duplicate text');
  expect(validatePack(pack([choice('a', { text: 'Cafe au lait' }), choice('b', { text: 'Café au lait', language: 'vi' })])).errors).toEqual([]);
  expect(validatePack(pack([choice('c', { text: 'Bà', language: 'vi' }), choice('d', { text: 'Ba', language: 'vi' })])).errors).toEqual([]);
 });
 it('reports pack-level shape errors', () => {
  expect(validatePack({ version: 0, generatedAt: 'nope', items: [] }).errors.length).toBeGreaterThan(0);
 });
 it('counts tokens like the Swift tokenizer', () => {
  expect(tokenCount("Good morning, it's 6:30!")).toBe(6);
  expect(tokenCount('Chào buổi sáng')).toBe(3);
  expect(tokenCount('Chào buổi sáng'.normalize('NFD'), 'vi')).toBe(3);
 });
 it('published JSON schema matches the zod schema', () => {
  const { $schema, ...expected } = z.toJSONSchema(challengeContentPack);
  const { $schema: published, ...actual } = read('../shared/contracts/v1/challenge-content.schema.json');
  expect(actual).toEqual(expected);
 });
 it('buildPack output is sorted and stable', () => {
  const items = [choice('z', { language: 'vi', text: 'Zeta?' }), choice('b'), readAloud('m', words(20)), choice('a', { kind: 'readAndChoose' }), choice('a2')];
  const first = buildPack(items, { version: 2, generatedAt: '2026-10-18T00:00:00Z' });
  expect(buildPack([...items].reverse(), { version: 2, generatedAt: '2026-10-18T00:00:00Z' })).toEqual(first);
  expect(first.items.map(i => i.id)).toEqual(['m', 'a', 'a2', 'b', 'z']);
  expect(first.version).toBe(2);
 });
 it('bundled pack meets minimum counts per kind and language', () => {
  const bundled = read('../apps/ios/Resources/challenge-content.json');
  expect(validatePack(bundled).errors).toEqual([]);
  const minimums = { en: { readAloud: 200, readAndChoose: 40, riddle: 40 }, vi: { readAloud: 100, readAndChoose: 30, riddle: 30 } };
  for (const [language, kinds] of Object.entries(minimums)) {
   for (const [kind, minimum] of Object.entries(kinds)) {
    const count = bundled.items.filter((i: { kind: string; language: string }) => i.language === language && i.kind === kind).length;
    expect(count, `${language} ${kind}`).toBeGreaterThanOrEqual(minimum);
   }
  }
 });
 it('bundled pack copies match a fresh build from the sources', () => {
  const dir = '../shared/content/challenges/';
  const files = readdirSync(new URL(dir, import.meta.url)).filter(name => name.endsWith('.json')).sort();
  const items = files.flatMap(name => read(dir + name));
  const text = (name: string) => readFileSync(new URL(dir + name, import.meta.url), 'utf8').trim();
  const fresh = buildPack(items, { version: Number(text('VERSION')), generatedAt: text('GENERATED_AT') });
  const ios = readFileSync(new URL('../apps/ios/Resources/challenge-content.json', import.meta.url), 'utf8');
  const worker = readFileSync(new URL('../backend/worker/content/challenge-content.json', import.meta.url), 'utf8');
  expect(ios).toBe(worker);
  expect(JSON.parse(ios)).toEqual(fresh);
 });
 it('CONTENT_SHA matches the current sources and VERSION', () => {
  const dir = '../shared/content/challenges/';
  const files = readdirSync(new URL(dir, import.meta.url)).filter(name => name.endsWith('.json')).sort();
  const text = (name: string) => readFileSync(new URL(dir + name, import.meta.url), 'utf8').trim();
  const built = buildPack(files.flatMap(name => read(dir + name)), { version: Number(text('VERSION')), generatedAt: text('GENERATED_AT') });
  const sha = createHash('sha256').update(JSON.stringify(validatePack(built).valid)).digest('hex');
  expect(text('CONTENT_SHA')).toBe(`${text('VERSION')} ${sha}`);
 });
});
