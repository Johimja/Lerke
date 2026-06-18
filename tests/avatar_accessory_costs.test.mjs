import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const sqlPatch = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessory_costs.sql');

const accEntryRe = /\{key:'(acc_\w+)',[^}]*xp:(\d+)\}/g;
const jsCosts = new Map();
for (const m of indexHtml.matchAll(accEntryRe)) {
  jsCosts.set(m[1], Number(m[2]));
}

assert.equal(jsCosts.size, 20, 'expected all 20 accessory items in index.html ACCESSORY_CATALOGUE');
assert.equal(jsCosts.get('acc_none'), 0, 'acc_none must stay free');

const sqlCaseRe = /when '(acc_\w+)'\s+then (\d+)/g;
const sqlCosts = new Map();
for (const m of sqlPatch.matchAll(sqlCaseRe)) {
  sqlCosts.set(m[1], Number(m[2]));
}

for (const [key, xp] of jsCosts) {
  assert.equal(sqlCosts.get(key), xp, `${key} cost mismatch: index.html=${xp} sql=${sqlCosts.get(key)}`);
}
assert.equal(sqlCosts.size, jsCosts.size, 'sql patch must define costs for exactly the accessory keys in index.html');
