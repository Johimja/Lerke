import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const sql = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessory_costs_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

assert.ok(existsSync(join(root, 'media/avatar_head_accessories.png')), 'accessory sheet must exist');

const catalogueMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(catalogueMatch, 'ACCESSORY_CATALOGUE must exist in index.html');

const itemRe = /key:'(acc_[a-z_]+)'[\s\S]*?xp:(\d+)/g;
const catalogueCosts = new Map();
let m;
while ((m = itemRe.exec(catalogueMatch[1]))) {
  catalogueCosts.set(m[1], Number(m[2]));
}
assert.equal(catalogueCosts.size, 20, 'expected 20 accessory items in index.html catalogue');
assert.equal(catalogueCosts.get('acc_none'), 0, 'acc_none must stay free');

function sqlCosts(sqlText) {
  const re = /when '(acc_[a-z_]+)'\s+then (\d+)/g;
  const costs = new Map();
  let mm;
  while ((mm = re.exec(sqlText))) {
    costs.set(mm[1], Number(mm[2]));
  }
  return costs;
}

for (const [label, sqlText] of [
  ['v20 patch', sql],
  ['fresh install v18', freshInstallSql],
]) {
  const costs = sqlCosts(sqlText);
  assert.equal(costs.size, 20, `${label}: expected 20 acc_* cost entries`);
  for (const [key, xp] of catalogueCosts) {
    assert.equal(costs.get(key), xp, `${label}: ${key} cost must match index.html (${xp} XP)`);
  }
}

// V20 should only redefine the cost helper, not the generic purchase RPC.
assert.doesNotMatch(sql, /create or replace function public\.purchase_avatar_item/, 'V20 must not redefine purchase_avatar_item');
