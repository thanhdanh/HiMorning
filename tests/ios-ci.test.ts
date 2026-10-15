import { spawnSync } from 'node:child_process';
import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, describe, expect, it } from 'vitest';

const temporary = mkdtempSync(join(tmpdir(), 'himorning-ios-ci-'));
const executable = join(temporary, 'xcodebuild');
writeFileSync(executable, '#!/bin/sh\nprintf "%s\\n" "$@"\nexit "${TEST_XCODE_EXIT:-0}"\n');
chmodSync(executable, 0o755);
afterAll(() => rmSync(temporary, { recursive: true, force: true }));
const run = (args: string[], exit = '0') => spawnSync('sh', ['scripts/test-ios.sh', ...args], {
 encoding: 'utf8',
 env: { ...process.env, PATH: `${temporary}:${process.env.PATH}`, RUNNER_WORKSPACE: join(temporary, 'workspace with spaces'), RUNNER_TEMP: temporary, TEST_XCODE_EXIT: exit },
});

describe('iOS CI test selection', () => {
 it('runs all native units and existing bilingual UI smoke tests on push', () => {
  const result = run(['simulator-id', 'push']);
  expect(result.status).toBe(0);
  const args = result.stdout.trim().split('\n');
  expect(args).toContain('platform=iOS Simulator,id=simulator-id');
  expect(args).toContain(join(temporary, 'workspace with spaces', 'himorning-derived'));
  expect(args).toContain('-only-testing:HiMorningTests');
  const selectors = args.filter(arg => arg.startsWith('-only-testing:HiMorningUITests/'));
  expect(selectors).toHaveLength(4);
  for (const selector of selectors) {
   const [, suite, name] = selector.split('/');
   expect(readFileSync(`apps/ios/HiMorningUITests/${suite}.swift`, 'utf8')).toContain(`func ${name}()`);
  }
  expect(args.at(-1)).toBe('test');
 });
 it('runs the complete scheme on manual dispatch', () => {
  const result = run(['simulator-id', 'workflow_dispatch']);
  expect(result.status).toBe(0);
  expect(result.stdout).not.toMatch(/-(only|skip)-testing:/);
  expect(result.stdout.trim().split('\n').at(-1)).toBe('test');
 });
 it('fails for missing destinations or unknown events, and preserves test failures', () => {
  expect(run([]).status).not.toBe(0);
  expect(run(['simulator-id', 'unknown']).status).toBe(64);
  expect(run(['simulator-id', 'push'], '65').status).toBe(65);
 });
});
