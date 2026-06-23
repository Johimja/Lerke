import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_accessory_costs_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

const catalogueMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(catalogueMatch, 'ACCESSORY_CATALOGUE must exist in index.html');

const itemRe = /key:'(acc_[a-z_]+)'[\s\S]*?xp:(\d+)/g;
const frontendCosts = new Map();
for (const m of catalogueMatch[1].matchAll(itemRe)) {
  frontendCosts.set(m[1], Number(m[2]));
}

assert.equal(frontendCosts.size, 20, 'expected 20 accessory items in ACCESSORY_CATALOGUE');
assert.equal(frontendCosts.get('acc_none'), 0, 'acc_none must remain free');

const nonFreeCount = [...frontendCosts.values()].filter((xp) => xp > 0).length;
assert.equal(nonFreeCount, 19, 'all accessories except acc_none must have an XP cost (Avatar-8)');

function sqlCosts(sqlText) {
  const costs = new Map();
  for (const m of sqlText.matchAll(/when '(acc_[a-z_]+)'\s+then\s+(\d+)/g)) {
    costs.set(m[1], Number(m[2]));
  }
  return costs;
}

for (const [name, sqlText] of [
  ['supabase_bingo_v20_accessory_costs_patch.sql', patchSql],
  ['supabase_bingo_fresh_install_v18.sql', freshInstallSql],
]) {
  const costs = sqlCosts(sqlText);
  assert.equal(costs.size, 20, `${name} must price all 20 accessory keys`);
  for (const [key, xp] of frontendCosts) {
    assert.equal(costs.get(key), xp, `${name}: ${key} cost must match frontend catalogue (${xp})`);
  }
}
