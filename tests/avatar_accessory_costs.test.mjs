import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessory_costs_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

assert.ok(existsSync(join(root, 'media/avatar_head_accessories.png')), 'accessory sheet must exist');

const catalogueMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(catalogueMatch, 'index.html must define ACCESSORY_CATALOGUE');

const itemRe = /key:'(acc_\w+)'[^}]*?xp:(\d+)/g;
const frontendCosts = {};
let m;
while ((m = itemRe.exec(catalogueMatch[1]))) {
  frontendCosts[m[1]] = Number(m[2]);
}
assert.equal(Object.keys(frontendCosts).length, 20, 'expected 20 accessory items in index.html');

for (const [name, sql] of [
  ['supabase_bingo_v20_avatar_accessory_costs_patch.sql', patchSql],
  ['supabase_bingo_fresh_install_v18.sql', freshInstallSql],
]) {
  for (const [key, xp] of Object.entries(frontendCosts)) {
    const re = new RegExp(`when '${key}'\\s+then ${xp}\\b`);
    assert.match(sql, re, `${name} must set ${key} cost to ${xp} (matching index.html)`);
  }
}

assert.equal(frontendCosts.acc_none, 0, 'acc_none must remain free');
