import { createHash } from 'node:crypto';
import { mkdir, readdir, readFile, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { z } from 'zod';
import { buildPack, challengeContentPack, validatePack } from './lib/challenge-content.mjs';
const sourceDir = new URL('../shared/content/challenges/', import.meta.url);
const outputs = ['../apps/ios/Resources/challenge-content.json', '../backend/worker/content/challenge-content.json'];
const schemaPath = new URL('../shared/contracts/v1/challenge-content.schema.json', import.meta.url);
const fail = message => { console.error(message); process.exit(1); };
const files = (await readdir(sourceDir).catch(() => [])).filter(name => name.endsWith('.json')).sort();
if (!files.length) fail('No source files found in shared/content/challenges/*.json');
const items = [];
for (const name of files) {
 const parsed = JSON.parse(await readFile(new URL(name, sourceDir), 'utf8'));
 if (!Array.isArray(parsed)) fail(`${name}: expected a JSON array of items`);
 items.push(...parsed);
}
const version = Number((await readFile(new URL('VERSION', sourceDir), 'utf8').catch(() => '')).trim());
if (!Number.isInteger(version) || version < 1) fail('shared/content/challenges/VERSION must hold a single integer >= 1');
const generatedAt = (await readFile(new URL('GENERATED_AT', sourceDir), 'utf8').catch(() => '')).trim();
if (!generatedAt) fail('shared/content/challenges/GENERATED_AT must hold an ISO timestamp');
const pack = buildPack(items, { version, generatedAt });
const { valid, errors } = validatePack(pack);
if (errors.length) fail(`${errors.length} validation error(s):\n${errors.map(error => ` - ${error}`).join('\n')}`);
const sha = createHash('sha256').update(JSON.stringify(valid)).digest('hex');
const recorded = (await readFile(new URL('CONTENT_SHA', sourceDir), 'utf8').catch(() => '')).trim().split(' ');
if (Number(recorded[0]) === version && recorded[1] !== sha) fail(`Content changed but shared/content/challenges/VERSION is still ${version}. Bump VERSION so clients and the ETag pick up the change.`);
const json = JSON.stringify({ ...pack, items: valid }, null, 1) + '\n';
for (const output of outputs) {
 const url = new URL(output, import.meta.url);
 await mkdir(dirname(fileURLToPath(url)), { recursive: true });
 await writeFile(url, json);
}
await writeFile(new URL('CONTENT_SHA', sourceDir), `${version} ${sha}\n`);
await writeFile(schemaPath, JSON.stringify(z.toJSONSchema(challengeContentPack), null, 2) + '\n');
console.log(`Built challenge content v${version}: ${valid.length} items from ${files.length} file(s)`);
