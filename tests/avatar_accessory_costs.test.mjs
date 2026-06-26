import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

function parseAccCatalogueCosts(text) {
  const block = text.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
  assert.ok(block, 'ACCESSORY_CATALOGUE block must be present');
  const costs = {};
  for (const m of block[1].matchAll(/key:'(acc_[a-z_]+)'[\s\S]*?xp:(\d+)/g)) {
    costs[m[1]] = Number(m[2]);
  }
  assert.equal(Object.keys(costs).length, 20, 'expected 20 accessory entries');
  return costs;
}

function parseSqlAccCosts(text) {
  const costs = {};
  for (const m of text.matchAll(/when '(acc_[a-z_]+)'\s+then (\d+)/g)) {
    costs[m[1]] = Number(m[2]);
  }
  return costs;
}

const indexHtml = read('index.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessory_costs_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

const frontendCosts = parseAccCatalogueCosts(indexHtml);
const patchCosts = parseSqlAccCosts(patchSql);
const freshCosts = parseSqlAccCosts(freshInstallSql);

assert.deepEqual(patchCosts, frontendCosts, 'patch SQL acc_* costs must match index.html ACCESSORY_CATALOGUE');
assert.deepEqual(freshCosts, frontendCosts, 'fresh-install SQL acc_* costs must match index.html ACCESSORY_CATALOGUE');

assert.equal(frontendCosts.acc_none, 0, 'acc_none must remain free');
for (const [key, cost] of Object.entries(frontendCosts)) {
  if (key === 'acc_none') continue;
  assert.ok(cost > 0, `${key} must have a non-zero XP cost`);
}
