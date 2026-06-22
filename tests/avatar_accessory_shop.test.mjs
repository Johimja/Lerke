import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_accessory_shop_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

assert.ok(existsSync(join(root, 'media/avatar_head_accessories.png')), 'accessory sheet must exist');

const catalogueMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(catalogueMatch, 'ACCESSORY_CATALOGUE must exist in index.html');

const itemRe = /key:'(acc_\w+)'[\s\S]*?xp:(\d+)/g;
const frontendCosts = new Map();
let m;
while ((m = itemRe.exec(catalogueMatch[1]))) {
  frontendCosts.set(m[1], Number(m[2]));
}
assert.equal(frontendCosts.size, 20, 'expected 20 accessory items in index.html catalogue');
assert.equal(frontendCosts.get('acc_none'), 0, 'acc_none must stay free');

// every non-free accessory must have a positive cost
for (const [key, xp] of frontendCosts) {
  if (key !== 'acc_none') assert.ok(xp > 0, `${key} should have a non-zero XP cost`);
}

for (const sql of [patchSql, freshInstallSql]) {
  for (const [key, xp] of frontendCosts) {
    assert.match(
      sql,
      new RegExp(`when '${key}'\\s+then ${xp}\\b`),
      `${key} cost (${xp}) must match between index.html and SQL`
    );
  }
}
