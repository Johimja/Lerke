import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

function parseCatalogueCosts(text, varName) {
  const match = text.match(new RegExp(`const ${varName}=\\[[\\s\\S]*?\\];`));
  assert.ok(match, `${varName} must be defined`);
  const costs = new Map();
  for (const m of match[0].matchAll(/key:\s*'(acc_[a-z_]+)'[\s\S]*?xp:\s*(\d+)/g)) {
    costs.set(m[1], Number(m[2]));
  }
  return costs;
}

function parseSqlCosts(sqlText) {
  const costs = new Map();
  for (const m of sqlText.matchAll(/when\s+'(acc_[a-z_]+)'\s+then\s+(\d+)/g)) {
    costs.set(m[1], Number(m[2]));
  }
  return costs;
}

const indexHtml = read('index.html');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessory_costs_patch.sql');

const jsCosts = parseCatalogueCosts(indexHtml, 'ACCESSORY_CATALOGUE');
const freshInstallCosts = parseSqlCosts(freshInstallSql);
const patchCosts = parseSqlCosts(patchSql);

assert.equal(jsCosts.size, 20, 'ACCESSORY_CATALOGUE must define xp for all 20 accessories');
assert.equal(jsCosts.get('acc_none'), 0, 'acc_none must remain free');

for (const [key, xp] of jsCosts) {
  assert.equal(freshInstallCosts.get(key), xp,
    `get_avatar_item_cost in fresh-install SQL must return ${xp} for ${key}`);
  assert.equal(patchCosts.get(key), xp,
    `v20 accessory cost patch must return ${xp} for ${key}`);
}

assert.equal(freshInstallCosts.size, jsCosts.size,
  'fresh-install SQL must not define costs for acc_* keys missing from the JS catalogue');
assert.equal(patchCosts.size, jsCosts.size,
  'v20 accessory cost patch must not define costs for acc_* keys missing from the JS catalogue');
