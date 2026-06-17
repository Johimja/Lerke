import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessory_costs_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

const catalogueMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(catalogueMatch, 'ACCESSORY_CATALOGUE must exist in index.html');

const frontendCosts = {};
for (const itemMatch of catalogueMatch[1].matchAll(/key:'(acc_[a-z_]+)'[\s\S]*?xp:(\d+)/g)) {
  frontendCosts[itemMatch[1]] = Number(itemMatch[2]);
}
assert.equal(Object.keys(frontendCosts).length, 20, 'expected 20 accessory items in index.html');
assert.equal(frontendCosts.acc_none, 0, 'acc_none must stay free');
assert.ok(Object.values(frontendCosts).some(xp => xp > 0), 'at least one accessory must cost XP');

for (const sql of [patchSql, freshInstallSql]) {
  const sqlCosts = {};
  for (const itemMatch of sql.matchAll(/when '(acc_[a-z_]+)'\s+then (\d+)/g)) {
    sqlCosts[itemMatch[1]] = Number(itemMatch[2]);
  }
  assert.deepEqual(sqlCosts, frontendCosts, 'SQL accessory costs must match index.html ACCESSORY_CATALOGUE');
}
