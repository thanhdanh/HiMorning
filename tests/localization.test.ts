import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
function strings(locale: string, table = 'Localizable') {
 const source = readFileSync(`apps/ios/Resources/${locale}.lproj/${table}.strings`, 'utf8');
 const result: Record<string,string> = {};
 for (const line of source.split('\n').filter(line => line.trim() && !line.trim().startsWith('//'))) {
  const match = line.match(/^("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");$/);
  if (!match) throw new Error(`Invalid strings entry: ${line}`);
  const key = JSON.parse(match[1]); expect(result).not.toHaveProperty(key);
  result[key] = JSON.parse(match[2]);
 }
 return result;
}
describe('English and Vietnamese app copy', () => {
 it('ships matching, nonempty translations with the same format placeholders', () => {
  const en = strings('en'), vi = strings('vi');
  expect(Object.keys(en).length).toBeGreaterThan(50);
  expect(Object.keys(vi).sort()).toEqual(Object.keys(en).sort());
  for (const [key,value] of Object.entries(en)) {
   expect(value).toBe(key); expect(vi[key].trim()).not.toBe('');
   expect(vi[key].match(/%(?:\d+\$)?(?:lld|d|@|%)/g) ?? []).toEqual(value.match(/%(?:\d+\$)?(?:lld|d|@|%)/g) ?? []);
  }
 });
 it('covers native copy and keeps Vietnamese in translation resources', () => {
  const en = strings('en');
  for (const file of readdirSync('apps/ios/HiMorning').filter(file => file.endsWith('.swift'))) {
   const source = readFileSync(`apps/ios/HiMorning/${file}`, 'utf8');
   expect(source, file).not.toMatch(/[À-ỹ]/u);
   for (const match of source.matchAll(/appText\(("(?:[^"\\]|\\.)*")/g)) expect(en, `${file}: ${match[1]}`).toHaveProperty(JSON.parse(match[1]));
  }
 });
 it('has an English and a Vietnamese entry for every literal appText key in any Swift source', () => {
  const en = strings('en'), vi = strings('vi');
  const swiftFiles = (dir: string): string[] => readdirSync(dir, { withFileTypes: true }).flatMap(entry =>
   entry.isDirectory() ? swiftFiles(join(dir, entry.name)) : entry.name.endsWith('.swift') ? [join(dir, entry.name)] : []);
  const files = swiftFiles('apps/ios/HiMorning');
  expect(files.length).toBeGreaterThan(10);
  let checked = 0;
  for (const file of files) {
   for (const match of readFileSync(file, 'utf8').matchAll(/appText\(\s*("(?:[^"\\]|\\.)*")/g)) {
    if (/\\[(u]/.test(match[1])) continue;
    const key = JSON.parse(match[1]); checked++;
    expect(en, `${file}: ${key}`).toHaveProperty([key]);
    expect(vi, `${file}: ${key}`).toHaveProperty([key]);
   }
  }
  expect(checked).toBeGreaterThan(100);
 });
 it('localizes the permissions used by the app and omits the legacy speech permission', () => {
  const project = readFileSync('apps/ios/project.yml', 'utf8');
  for (const locale of ['en','vi']) {
   const info = strings(locale,'InfoPlist');
   for (const key of ['NSCameraUsageDescription','NSAlarmKitUsageDescription','NSMicrophoneUsageDescription']) {
    expect(info[key].length).toBeGreaterThan(20);
    expect(project).toContain(`${key}:`);
   }
   expect(info).not.toHaveProperty('NSSpeechRecognitionUsageDescription');
  }
  expect(project).not.toContain('NSSpeechRecognitionUsageDescription:');
 });
 it('keeps the read-aloud UI-test fixture sentence in both app languages', () => {
  const en = strings('en'), vi = strings('vi');
  const key = 'Small steps create steady progress.';
  expect(en).toHaveProperty(key);
  expect(vi).toHaveProperty(key);
 });
 it('ships at least one item of each kind per language in the bundled pack', () => {
  const pack = JSON.parse(readFileSync('apps/ios/Resources/challenge-content.json', 'utf8'));
  for (const language of ['en','vi']) for (const kind of ['readAloud','readAndChoose','riddle']) {
   expect(pack.items.some((item: {language:string;kind:string}) => item.language === language && item.kind === kind), `${language} ${kind}`).toBe(true);
  }
 });
});
