import { readFileSync, readdirSync } from 'node:fs';
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
 it('localizes challenge meanings while keeping English learning sentences in English', () => {
  const en = strings('en'), vi = strings('vi');
  const source = readFileSync('apps/ios/HiMorningCore/Sources/HiMorningCore/Challenge.swift', 'utf8');
  const content = source.split('public enum EnglishChallengeContent {')[1]?.split('///')[0];
  expect(content).toBeTruthy();
  if (!content) throw new Error('English challenge content was not found');
  for (const match of content.matchAll(/(?:sentence|text):("(?:[^"\\]|\\.)*")/g)) {
   const key = JSON.parse(match[1]);
   expect(en).toHaveProperty(key);
   expect(vi[key]).toBe(key);
  }
  for (const list of content.matchAll(/choices:\[([^\]]+)\]/g)) {
   for (const match of list[1].matchAll(/"(?:[^"\\]|\\.)*"/g)) {
    const key = JSON.parse(match[0]);
    expect(en).toHaveProperty(key);
    expect(vi[key]).toBeTruthy();
    expect(vi[key]).not.toBe(key);
   }
  }
 });
});
