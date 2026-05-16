import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
function read(p) { return readFileSync(join(root, p), 'utf8'); }

const indexHtml = read('index.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_accessories_shop_patch.sql');
const freshSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// Sprite sheet must exist with correct dimensions
assert.ok(existsSync(join(root, 'media/avatar_head_accessories.png')), 'accessory sheet must exist');
const buf = readFileSync(join(root, 'media/avatar_head_accessories.png'));
assert.equal(buf.toString('ascii', 1, 4), 'PNG');
assert.equal(buf.readUInt32BE(16), 1024, 'accessory sheet width must be 1024');
assert.equal(buf.readUInt32BE(20), 1280, 'accessory sheet height must be 1280');

// All 20 acc_* keys must be present in index.html ACCESSORY_CATALOGUE
const accKeys = [
  'acc_none','acc_crown','acc_tophat','acc_cap','acc_graduation','acc_party_hat',
  'acc_viking','acc_cowboy','acc_headband','acc_beanie','acc_sombrero','acc_laurel',
  'acc_bow','acc_bandana','acc_witch_hat','acc_tiara','acc_chef_hat','acc_antlers',
  'acc_earmuffs','acc_bunny_ears',
];
for (const key of accKeys) {
  assert.match(indexHtml, new RegExp(`key:'${key}'`), `index.html must have ${key} in ACCESSORY_CATALOGUE`);
}

// acc_none, acc_headband, acc_beanie must be free (xp:0) in index.html
assert.match(indexHtml, /key:'acc_none'[^}]*xp:0/, 'acc_none must be free');
assert.match(indexHtml, /key:'acc_headband'[^}]*xp:0/, 'acc_headband must be free');
assert.match(indexHtml, /key:'acc_beanie'[^}]*xp:0/, 'acc_beanie must be free');

// Paid accessories must have xp > 0 in index.html
assert.doesNotMatch(indexHtml, /key:'acc_crown'[^}]*xp:0/, 'acc_crown must not be free');
assert.doesNotMatch(indexHtml, /key:'acc_viking'[^}]*xp:0/, 'acc_viking must not be free');

// SQL patch must handle all 20 acc_* keys in get_avatar_item_cost
for (const key of accKeys) {
  assert.match(patchSql, new RegExp(`when '${key}'`), `patch SQL must handle ${key}`);
}
// Same for fresh install SQL
for (const key of accKeys) {
  assert.match(freshSql, new RegExp(`when '${key}'`), `fresh install SQL must handle ${key}`);
}

// acc_none free, acc_viking 250 in SQL
assert.match(patchSql, /when 'acc_none'\s+then 0/);
assert.match(patchSql, /when 'acc_viking'\s+then 250/);

// purchase_avatar_item RPC must still be present in fresh install
assert.match(freshSql, /purchase_avatar_item/);

console.log('avatar_accessories_shop tests passed ✅');
