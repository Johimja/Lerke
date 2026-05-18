import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessories_shop.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// JS catalogue: 20 accessories present, acc_none is free, paid items have xp > 0
assert.match(indexHtml, /const ACCESSORY_CATALOGUE=\[/);
assert.match(indexHtml, /acc_none.*xp:0/);
assert.match(indexHtml, /acc_crown.*xp:300/);
assert.match(indexHtml, /acc_headband.*xp:50/);
assert.match(indexHtml, /acc_bow.*xp:50/);
assert.match(indexHtml, /acc_tiara.*xp:225/);

// Every acc_* key in the JS catalogue must appear in the SQL patch
const accKeys = [
  'acc_none','acc_crown','acc_tophat','acc_cap','acc_graduation','acc_party_hat',
  'acc_viking','acc_cowboy','acc_headband','acc_beanie','acc_sombrero','acc_laurel',
  'acc_bow','acc_bandana','acc_witch_hat','acc_tiara','acc_chef_hat','acc_antlers',
  'acc_earmuffs','acc_bunny_ears',
];

for (const key of accKeys) {
  assert.match(patchSql, new RegExp(`when '${key}'`), `SQL patch missing cost for ${key}`);
}

// Fresh install SQL must also include all acc_* keys
for (const key of accKeys) {
  assert.match(freshInstallSql, new RegExp(`when '${key}'`), `Fresh install SQL missing cost for ${key}`);
}

// Head keys must still be present in the patch (not removed by accident)
assert.match(patchSql, /when 'head_basic'\s+then 0/);
assert.match(patchSql, /when 'head_afro'\s+then 300/);

// acc_none is free in SQL
assert.match(patchSql, /when 'acc_none'\s+then 0/);

// acc_crown costs 300 (legendary tier)
assert.match(patchSql, /when 'acc_crown'\s+then 300/);

console.log('avatar_accessories_shop: all assertions passed ✅');
