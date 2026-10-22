import { z } from 'zod';
export const readAloudTokenRange = [18, 30];
const filled = z.string().refine(value => value.trim().length > 0, 'must not be blank');
export const challengeContentItem = z.strictObject({
 id: filled,
 kind: z.enum(['readAloud', 'readAndChoose', 'riddle']),
 language: z.enum(['en', 'vi']),
 text: filled,
 choices: z.array(filled).optional(),
 answerIndex: z.number().int().optional(),
 source: filled,
 license: filled,
 attribution: z.string().optional(),
}).superRefine((item, ctx) => {
 const issue = message => ctx.addIssue({ code: 'custom', message });
 if (item.kind === 'readAloud') {
  if (item.choices !== undefined || item.answerIndex !== undefined) issue('readAloud must not have choices or answerIndex');
  const count = tokenCount(item.text);
  if (count < readAloudTokenRange[0] || count > readAloudTokenRange[1]) issue(`readAloud needs ${readAloudTokenRange[0]}-${readAloudTokenRange[1]} tokens, got ${count}`);
  return;
 }
 if (item.choices?.length !== 3) issue('choices must have exactly 3 entries');
 if (!Number.isInteger(item.answerIndex) || item.answerIndex < 0 || item.answerIndex > 2) issue('answerIndex must be 0-2');
});
export const challengeContentPack = z.object({
 version: z.number().int().min(1),
 generatedAt: z.iso.datetime(),
 items: z.array(challengeContentItem),
});
export function tokens(text, language) {
 const nfc = text.normalize('NFC');
 const folded = language === 'vi' ? nfc.toLowerCase() : nfc.toLowerCase().normalize('NFD').replace(/\p{M}/gu, '');
 return folded.match(/[\p{L}\p{N}]+/gu) ?? [];
}
export function tokenCount(text, language = 'en') { return tokens(text, language).length; }
const label = (item, index) => `items[${index}]${typeof item?.id === 'string' ? ` (${item.id})` : ''}`;
export function validatePack(pack) {
 const errors = [], valid = [], ids = new Set(), texts = new Set();
 const shape = challengeContentPack.extend({ items: z.array(z.unknown()) }).safeParse(pack);
 if (!shape.success) {
  for (const issue of shape.error.issues) errors.push(`${issue.path.join('.') || 'pack'}: ${issue.message}`);
  if (!Array.isArray(pack?.items)) return { valid, errors };
 }
 for (const [index, raw] of pack.items.entries()) {
  const parsed = challengeContentItem.safeParse(raw);
  if (!parsed.success) {
   for (const issue of parsed.error.issues) errors.push(`${label(raw, index)}: ${issue.path.join('.') || 'item'}: ${issue.message}`);
   continue;
  }
  const item = parsed.data, key = `${item.language}|${tokens(item.text, item.language).join(' ')}`;
  if (ids.has(item.id)) { errors.push(`${label(item, index)}: duplicate id`); continue; }
  if (texts.has(key)) { errors.push(`${label(item, index)}: duplicate text`); continue; }
  ids.add(item.id); texts.add(key); valid.push(item);
 }
 return { valid, errors };
}
const byCode = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
export function buildPack(items, { version, generatedAt }) {
 const sorted = [...items].sort((a, b) => byCode(a.language, b.language) || byCode(a.kind, b.kind) || byCode(a.id, b.id));
 return { version, generatedAt, items: sorted };
}
