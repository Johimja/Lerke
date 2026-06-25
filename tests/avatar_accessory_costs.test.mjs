import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

function parseAccessoryCatalogueXp(html) {
  const block = html.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/)[1];
  const xp = {};
  for (const m of block.matchAll(/key:'(acc_[a-z_]+)'[^}]*?xp:(\d+)/g)) {
    xp[m[1]] = Number(m[2]);
  }
  return xp;
}

function parseSqlAccessoryCosts(sql) {
  const xp = {};
  for (const m of sql.matchAll(/when '(acc_[a-z_]+)'\s+then (\d+)/g)) {
    xp[m[1]] = Number(m[2]);
  }
  return xp;
}

const indexHtml = read('index.html');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_accessory_costs_patch.sql');

const jsXp = parseAccessoryCatalogueXp(indexHtml);
assert.equal(Object.keys(jsXp).length, 20, 'index.html ACCESSORY_CATALOGUE must have 20 acc_ items');
assert.equal(jsXp.acc_none, 0, 'acc_none must remain free');

for (const sqlText of [freshInstallSql, patchSql]) {
  const sqlXp = parseSqlAccessoryCosts(sqlText);
  assert.deepEqual(sqlXp, jsXp, 'SQL get_avatar_item_cost acc_* costs must match index.html ACCESSORY_CATALOGUE');
}
