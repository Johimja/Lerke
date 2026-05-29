import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessories_patch.sql');
const freshSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// Accessory sprite sheet must exist
assert.ok(existsSync(join(root, 'media/avatar_head_accessories.png')), 'accessory sheet must exist');

// ACCESSORY_CATALOGUE must be present in index.html
assert.match(indexHtml, /const ACCESSORY_CATALOGUE=\[/);

// All 20 acc_ keys must appear in index.html catalogue
const ACC_KEYS = [
  'acc_none','acc_headband','acc_beanie','acc_bow','acc_bandana','acc_party_hat',
  'acc_cap','acc_earmuffs','acc_bunny_ears','acc_graduation','acc_chef_hat',
  'acc_sombrero','acc_antlers','acc_laurel','acc_tophat','acc_cowboy',
  'acc_tiara','acc_witch_hat','acc_crown','acc_viking',
];
for (const key of ACC_KEYS) {
  assert.match(indexHtml, new RegExp(`'${key}'`), `index.html must contain ${key}`);
}

// acc_none and acc_headband must be free (xp:0) in index.html
assert.match(indexHtml, /acc_none[^}]+xp:0/);
assert.match(indexHtml, /acc_headband[^}]+xp:0/);

// Paid accessories must have non-zero XP in index.html
assert.match(indexHtml, /acc_crown[^}]+xp:300/);
assert.match(indexHtml, /acc_viking[^}]+xp:350/);
assert.match(indexHtml, /acc_beanie[^}]+xp:25/);

// SQL patch must cover all 20 acc_ keys
for (const key of ACC_KEYS) {
  assert.match(patchSql, new RegExp(`'${key}'`), `v20 patch must contain ${key}`);
}

// SQL patch: free starters
assert.match(patchSql, /when 'acc_none'\s+then 0/);
assert.match(patchSql, /when 'acc_headband'\s+then 0/);

// SQL patch: premium items
assert.match(patchSql, /when 'acc_crown'\s+then 300/);
assert.match(patchSql, /when 'acc_viking'\s+then 350/);

// Fresh install SQL must also contain acc_ items (kept in sync)
for (const key of ACC_KEYS) {
  assert.match(freshSql, new RegExp(`'${key}'`), `fresh install SQL must contain ${key}`);
}

console.log('avatar_accessories_shop: all assertions passed ✅');
