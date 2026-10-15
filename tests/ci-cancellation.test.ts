import { readFileSync } from 'node:fs';
import { describe,expect,it } from 'vitest';

const workflow=readFileSync('.github/workflows/ci.yml','utf8');
const group=workflow.match(/  group: >-\n([\s\S]*?)\n  cancel-in-progress:/)![1].trim().replace(/\s+/g,' ');
// The actual workflow expression uses the shared JavaScript &&/||/== subset.
const valueFor=(value:string,github:object)=>value.replace(/\$\{\{(.*?)\}\}/g,(_,expression)=>
 new Function('github','format',`return (${expression});`)(github,(template:string,value:unknown)=>template.replace('{0}',String(value))));
const groupFor=(github:object)=>valueFor(group,github);
const repository='thanhdanh/HiMorning';
const push=(ref:string,event_name='push')=>({event_name,repository,ref,event:{repository:{default_branch:'main'}}});
const closed=(merged=true,head='codex/example',repo=repository)=>({
 ...push('refs/heads/main','pull_request'),
 event:{repository:{default_branch:'main'},pull_request:{number:13,merged,head:{ref:head,repo:{full_name:repo}}}},
});

describe('CI cancellation after merge',()=>{
 it('keeps the existing branch groups for pushes and manual runs',()=>{
  expect(groupFor(push('refs/heads/main'))).toBe('checks-refs/heads/main');
  expect(groupFor(push('refs/heads/codex/example'))).toBe('checks-refs/heads/codex/example');
  expect(groupFor(push('refs/heads/codex/example','workflow_dispatch'))).toBe('checks-refs/heads/codex/example');
 });
 it('maps a merged PR to its head branch and leaves main in a separate group',()=>{
  expect(groupFor(closed())).toBe(groupFor(push('refs/heads/codex/example')));
  expect(groupFor(closed())).not.toBe(groupFor(push('refs/heads/main')));
  expect(workflow).toMatch(/cancel-in-progress: true/);
 });
 it('isolates unmerged closes, forks and PRs whose head is the default branch',()=>{
  for(const event of [closed(false),closed(true,'main','someone/fork'),closed(true,'main')]){
   expect(groupFor(event)).toBe('checks-closed-pr-13');
  }
 });
 it('handles only closed PR events and skips every runner job for them',()=>{
  expect(workflow).toMatch(/pull_request:\n    types: \[closed\]/);
  for(const job of ['backend','inference','ios'])expect(workflow).toContain(`  ${job}:\n    if: github.event_name != 'pull_request'`);
 });
 it('keeps skipped closure checks separate from the main branch checks',()=>{
  for(const job of ['backend','inference','ios']){
   const name=workflow.match(new RegExp(`  ${job}:\\n    if:.*\\n    name: (.*)`))![1];
   expect(valueFor(name,push('refs/heads/main'))).toBe(job);
   expect(valueFor(name,closed())).toBe(`PR closure (${job})`);
  }
 });
});
