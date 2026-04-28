import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const patchSql  = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessories_shop_patch.sql');
const freshSql  = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// ── ACCESSORY_CATALOGUE in index.html ──────────────────────────────────────

// All 20 accessory keys must be present
const ACC_KEYS = [
  'acc_none','acc_crown','acc_tophat','acc_cap','acc_graduation',
  'acc_party_hat','acc_viking','acc_cowboy','acc_headband','acc_beanie',
  'acc_sombrero','acc_laurel','acc_bow','acc_bandana','acc_witch_hat',
  'acc_tiara','acc_chef_hat','acc_antlers','acc_earmuffs','acc_bunny_ears',
];
for (const key of ACC_KEYS) {
  assert.match(indexHtml, new RegExp(`key:'${key}'`), `index.html must contain key '${key}' in ACCESSORY_CATALOGUE`);
}

// acc_none must be free (xp:0)
assert.match(indexHtml, /key:'acc_none'[^}]+xp:0/, 'acc_none must be free (xp:0)');

// Premium accessories must have xp:150
assert.match(indexHtml, /key:'acc_crown'[^}]+xp:150/, 'acc_crown must cost 150 XP');
assert.match(indexHtml, /key:'acc_tiara'[^}]+xp:150/, 'acc_tiara must cost 150 XP');
assert.match(indexHtml, /key:'acc_viking'[^}]+xp:150/, 'acc_viking must cost 150 XP');

// Basic accessories must have xp:50
assert.match(indexHtml, /key:'acc_headband'[^}]+xp:50/, 'acc_headband must cost 50 XP');
assert.match(indexHtml, /key:'acc_cap'[^}]+xp:50/,     'acc_cap must cost 50 XP');

// No acc_* item should remain at xp:0 except acc_none
const accCatalogueMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(accCatalogueMatch, 'ACCESSORY_CATALOGUE must be present');
const catalogueBody = accCatalogueMatch[1];
const freeItems = [...catalogueBody.matchAll(/key:'(acc_\w+)'[^}]+xp:0/g)].map(m => m[1]);
assert.deepEqual(freeItems, ['acc_none'], `Only acc_none should be free; found free: ${freeItems.join(', ')}`);

// ── SQL patch: get_avatar_item_cost must cover acc_* keys ──────────────────

for (const key of ACC_KEYS) {
  assert.match(patchSql, new RegExp(`when '${key}'`), `v20 patch must include cost for '${key}'`);
}

assert.match(patchSql, /when 'acc_none'\s+then 0/,   'acc_none must be free in SQL');
assert.match(patchSql, /when 'acc_crown'\s+then 150/, 'acc_crown must cost 150 XP in SQL');
assert.match(patchSql, /when 'acc_viking'\s+then 150/,'acc_viking must cost 150 XP in SQL');
assert.match(patchSql, /when 'acc_headband'\s+then 50/,'acc_headband must cost 50 XP in SQL');

// head_* keys must still be present (no regression)
assert.match(patchSql, /when 'head_basic'\s+then 0/,  'head_basic must remain free in SQL');
assert.match(patchSql, /when 'head_afro'\s+then 300/,  'head_afro must remain 300 XP in SQL');

// ── Fresh install SQL must also include acc_* costs ────────────────────────

for (const key of ['acc_none', 'acc_crown', 'acc_viking', 'acc_headband']) {
  assert.match(freshSql, new RegExp(`when '${key}'`), `fresh install SQL must include cost for '${key}'`);
}

assert.match(freshSql, /when 'acc_crown'\s+then 150/, 'fresh install SQL: acc_crown must cost 150 XP');

console.log('avatar_accessories_shop: all assertions passed ✅');
