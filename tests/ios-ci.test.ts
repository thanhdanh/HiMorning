import { spawnSync } from 'node:child_process';
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, describe, expect, it } from 'vitest';

const temporary = mkdtempSync(join(tmpdir(), 'himorning-ios-ci-'));
const executable = join(temporary, 'xcodebuild');
writeFileSync(executable, `#!/bin/sh
printf '%s\\n' "$@"
case "$*" in
 *-resolvePackageDependencies*)
  if [ "\${TEST_MISSING_ARTIFACT:-}" = 1 ] && [ ! -f "$TEST_MARKER" ]; then
   touch "$TEST_MARKER"
   printf 'file not found at path: %s/himorning-derived/SourcePackages/artifacts/firebase-ios-sdk/FirebaseAnalytics/FirebaseAnalytics.zip\\n' "$RUNNER_WORKSPACE"
   exit 74
  fi
  exit "\${TEST_RESOLVE_EXIT:-0}"
  ;;
esac
exit "\${TEST_XCODE_EXIT:-0}"
`);
chmodSync(executable, 0o755);
afterAll(() => rmSync(temporary, { recursive: true, force: true }));
const run = (args: string[], exit = '0', extraEnv:Record<string,string>={}) => spawnSync('sh', ['scripts/test-ios.sh', ...args], {
 encoding: 'utf8',
 env: { ...process.env, PATH: `${temporary}:${process.env.PATH}`, RUNNER_WORKSPACE: join(temporary, 'workspace with spaces'), RUNNER_TEMP: temporary, TEST_XCODE_EXIT: exit, ...extraEnv },
});
const packages=join(temporary,'workspace with spaces','himorning-derived','SourcePackages');
function seedPackageCache(){
 for(const name of ['artifacts/firebase-ios-sdk','artifacts/other-package'])mkdirSync(join(packages,name),{recursive:true});
 writeFileSync(join(packages,'workspace-state.json'),'{}');
}

describe('iOS CI test selection', () => {
 it('runs all native units and existing bilingual UI smoke tests on push', () => {
  const result = run(['simulator-id', 'push']);
  expect(result.status).toBe(0);
  const args = result.stdout.trim().split('\n');
  expect(args).toContain('platform=iOS Simulator,id=simulator-id');
  expect(args).toContain(join(temporary, 'workspace with spaces', 'himorning-derived'));
  expect(args).toContain('-only-testing:HiMorningTests');
  const selectors = args.filter(arg => arg.startsWith('-only-testing:HiMorningUITests/'));
  expect(selectors).toHaveLength(8);
  expect(selectors).toContain('-only-testing:HiMorningUITests/DeviceFixesUITests/testEnabledAlarmChallengeEditClosesAndKeepsTheNewChoiceInBothLanguages');
  expect(selectors).toContain('-only-testing:HiMorningUITests/ChallengeCelebrationUITests/testReadingSuccessCelebratesAndReturnsHomeInBothLanguages');
  expect(selectors).toContain('-only-testing:HiMorningUITests/ChallengeCelebrationUITests/testReadAloudRetryKeepsTheSentenceAndClearsThePreviousScore');
  expect(selectors).toContain('-only-testing:HiMorningUITests/ChallengeCelebrationUITests/testAwakeConfirmationCountsDownBeforeEnabling');
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
 it('repairs a missing Firebase archive once without deleting other package caches',()=>{
  seedPackageCache();
  const result=run(['simulator-id','push'],'0',{TEST_MISSING_ARTIFACT:'1',TEST_MARKER:join(temporary,'missing-once')});
  expect(result.status).toBe(0);
  expect(result.stdout.match(/^-resolvePackageDependencies$/gm)).toHaveLength(2);
  expect(result.stdout.match(/^test$/gm)).toHaveLength(1);
  expect(existsSync(join(packages,'workspace-state.json'))).toBe(false);
  expect(existsSync(join(packages,'artifacts/firebase-ios-sdk'))).toBe(false);
  expect(existsSync(join(packages,'artifacts/other-package'))).toBe(true);
 });
 it('preserves cached packages and the exit code for unrelated resolution errors',()=>{
  seedPackageCache();
  const result=run(['simulator-id','push'],'0',{TEST_RESOLVE_EXIT:'74'});
  expect(result.status).toBe(74);
  expect(result.stdout.match(/^-resolvePackageDependencies$/gm)).toHaveLength(1);
  expect(result.stdout).not.toMatch(/^test$/m);
  expect(existsSync(join(packages,'workspace-state.json'))).toBe(true);
  expect(existsSync(join(packages,'artifacts/firebase-ios-sdk'))).toBe(true);
 });
 it('fails after one repair attempt when resolution still fails',()=>{
  seedPackageCache();
  const result=run(['simulator-id','push'],'0',{TEST_MISSING_ARTIFACT:'1',TEST_MARKER:join(temporary,'still-missing'),TEST_RESOLVE_EXIT:'74'});
  expect(result.status).toBe(74);
  expect(result.stdout.match(/^-resolvePackageDependencies$/gm)).toHaveLength(2);
  expect(result.stdout).not.toMatch(/^test$/m);
 });
});
