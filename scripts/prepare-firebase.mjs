import { mkdir, rm, writeFile, access, copyFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
// Only this ignored, generated deployment directory is replaced.
const target = new URL('../.firebase/functions/',import.meta.url);
await mkdir(new URL('../.firebase/',import.meta.url),{recursive:true});
await rm(target,{recursive:true,force:true});
const result = spawnSync('pnpm',['--filter','@himorning/functions','deploy','--prod',fileURLToPath(target)],{stdio:'inherit'});
if (result.status !== 0) process.exit(result.status ?? 1);
await writeFile(new URL('pnpm-workspace.yaml',target),'packages: []\nonlyBuiltDependencies:\n  - sharp\n');
await access(new URL('pnpm-lock.yaml',target));
await access(new URL('lib/index.js',target));
const staging=process.env.FIREBASE_STAGING_PROJECT;
if(staging){
 if(!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(staging)||!staging.includes('staging')||staging.startsWith('demo-'))throw new Error('Invalid staging project');
 await copyFile(new URL(`../backend/functions/.env.${staging}`,import.meta.url),new URL(`.env.${staging}`,target));
}
console.log('Prepared .firebase/functions with a standalone production lockfile. Nothing was deployed.');
