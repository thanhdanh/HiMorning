import { spawnSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
export function stagingConfig(project,source){
 if(!project||!project.includes('staging')||!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project)||project.startsWith('demo-'))throw new Error('Set FIREBASE_STAGING_PROJECT to a real project ID containing staging. Emulator defaults are never deployment targets.');
 const env=Object.fromEntries(source.split('\n').filter(line=>line.trim()&&!line.trim().startsWith('#')).map(line=>{
  const match=line.match(/^([A-Z_]+)=(.*)$/);if(!match)throw new Error('Use unquoted KEY=value staging configuration');return [match[1],match[2]];
 }));
 if(Object.keys(env).some(key=>!['AI_VERIFICATION_ENABLED','AI_BASE_URL','AI_MODEL','AI_USER_DAILY_LIMIT','AI_GLOBAL_DAILY_LIMIT'].includes(key)))throw new Error('Staging files may contain only non-secret AI configuration');
 return env;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const project=process.env.FIREBASE_STAGING_PROJECT;
 stagingConfig(project,'');
 const env=stagingConfig(project,await readFile(new URL(`../backend/functions/.env.${project}`,import.meta.url),'utf8'));
 const {readConfig}=await import('../backend/functions/lib/config.js');
 readConfig(env);
 if(process.argv.includes('--check'))console.log(`Validated staging configuration for ${project}; nothing deployed.`);
 else {
  const run=spawnSync('pnpm',['exec','firebase','deploy','--config','firebase.staging.json','--project',project,'--only','functions,firestore:rules,firestore:indexes'],{stdio:'inherit'});
  process.exitCode=run.status??1;
 }
}
