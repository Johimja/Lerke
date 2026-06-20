import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const costSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessory_costs_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

const catalogueMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(catalogueMatch, 'ACCESSORY_CATALOGUE must exist in index.html');

const jsCosts = new Map();
for (const m of catalogueMatch[1].matchAll(/key:'(acc_[a-z_]+)'[\s\S]*?xp:(\d+)/g)) {
  jsCosts.set(m[1], Number(m[2]));
}
assert.equal(jsCosts.size, 20, 'expected 20 accessory items in index.html catalogue');
assert.equal(jsCosts.get('acc_none'), 0, 'acc_none must remain free');
assert.ok([...jsCosts.values()].some((xp) => xp > 0), 'at least one accessory must have a non-zero XP cost');

for (const sql of [costSql, freshInstallSql]) {
  for (const [key, xp] of jsCosts) {
    assert.match(
      sql,
      new RegExp(`when '${key}'\\s+then ${xp}\\b`),
      `${key} cost in SQL must match index.html (expected ${xp})`,
    );
  }
}
