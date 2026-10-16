// A focused guard for accidentally committed privileged credentials.
// Firebase client identifiers are reviewed explicitly; they are not backend authorization.
import {execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const patterns = [
  ['private key', /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/],
  ['service-account key', /"private_key"\s*:\s*"[^"\s]+/],
  ['OAuth refresh token', /"refresh_token"\s*:\s*"[^"\s]+/],
  ['OAuth client secret', /"client_secret"\s*:\s*"[^"\s]+/],
  ['GitHub access token', /\bgh[pousr]_[A-Za-z0-9]{30,}\b/],
  ['GitHub fine-grained token', /\bgithub_pat_[A-Za-z0-9_]{40,}\b/],
];
export function findings(text) {
  return patterns.filter(([,pattern])=>pattern.test(text)).map(([name])=>name);
}
if (process.argv.includes('--self-test')) {
  assert.ok(findings(['-----BEGIN ', 'PRIVATE KEY-----'].join('')).includes('private key'));
  assert.ok(findings(JSON.stringify({['refresh_'+'token']:'synthetic-value'})).includes('OAuth refresh token'));
  assert.ok(findings(['ghp_', 'x'.repeat(36)].join('')).includes('GitHub access token'));
  assert.deepEqual(findings('const projectId = "demo-klasc";'),[]);
  console.log('Credential guard self-test passed.');
} else {
  const files = execFileSync('git',['ls-files','-z'],{encoding:'utf8'}).split('\0').filter(Boolean);
  const cfg=JSON.parse(readFileSync('assets/firebase-config.json','utf8'));
  const reviewedDigests=new Set(['e010ac3080a410478fbeb12ed4f4e229a404a1bb6aa0d8fe442c1a6efd7820a0','f28933ab4b7f10dd72333545d11dffff72c7a83815e9bbe2db7046e83d6f3f7c']);
  const reviewedKeys=new Set([cfg.apiKey,cfg.apiKeyAndroid]);
  for(const key of reviewedKeys) {
    if(!reviewedDigests.has(createHash('sha256').update(key).digest('hex'))) throw new Error('Firebase client identifier changed; security review and new fingerprint required.');
  }
  const configPaths=new Set(['assets/firebase-config.json','android/app/google-services.json']);
  let count=0;
  for (const file of files) {
    const bytes=readFileSync(file); if(bytes.includes(0)) continue;
    const text=bytes.toString('utf8');
    const issues=findings(text);
    for (const match of text.matchAll(/\bAIza[0-9A-Za-z_-]{35}\b/g)) {
      if (!configPaths.has(file)||!reviewedKeys.has(match[0])) issues.push('unreviewed Google API key');
    }
    if (issues.length) { console.error(`${file}: ${[...new Set(issues)].join(', ')}`); count++; }
  }
  if(process.argv.includes('--history')) {
    const history=execFileSync('git',['log','-p','--all','--format=','--'],{encoding:'utf8',maxBuffer:16*1024*1024});
    const issues=findings(history);
    if(issues.length) {console.error(`Commit history: ${issues.join(', ')}`);count++;}
    for(const match of history.matchAll(/\bAIza[0-9A-Za-z_-]{35}\b/g)) {
      if(!reviewedKeys.has(match[0])) {console.error('Commit history: unreviewed Google API key');count++;break;}
    }
    if(!count) console.log('Recorded commit history credential check passed.');
  }
  if(count) {process.exitCode=1;} else console.log(`Credential guard passed for ${files.length} tracked files; only reviewed Firebase client identifiers are allowed.`);
}
