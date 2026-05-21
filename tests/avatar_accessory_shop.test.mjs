import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_accessory_shop_patch.sql');

// All 20 acc keys must be in ACCESSORY_CATALOGUE
const ACC_KEYS = [
  'acc_none','acc_headband','acc_bow','acc_cap','acc_beanie','acc_bandana','acc_earmuffs',
  'acc_party_hat','acc_chef_hat','acc_bunny_ears','acc_graduation','acc_cowboy','acc_antlers',
  'acc_sombrero','acc_laurel','acc_tophat','acc_witch_hat','acc_tiara','acc_viking','acc_crown',
];

for (const key of ACC_KEYS) {
  assert.match(indexHtml, new RegExp(`key:'${key}'`), `ACCESSORY_CATALOGUE must contain ${key}`);
  assert.match(patchSql, new RegExp(`when '${key}'`), `SQL must contain cost for ${key}`);
}

// acc_none must be free (xp:0) in index.html
assert.match(indexHtml, /key:'acc_none'[^}]+xp:0/, 'acc_none must be free');

// Paid accessories must have xp > 0 in index.html
const PAID_KEYS = ACC_KEYS.filter(k => k !== 'acc_none');
for (const key of PAID_KEYS) {
  const m = indexHtml.match(new RegExp(`key:'${key}'[^}]+xp:(\\d+)`));
  assert.ok(m, `ACCESSORY_CATALOGUE must have xp for ${key}`);
  assert.ok(parseInt(m[1], 10) > 0, `${key} must have xp > 0, got ${m[1]}`);
}

// SQL patch must not break existing head_* costs
assert.match(patchSql, /when 'head_afro'\s+then 300/);
assert.match(patchSql, /when 'head_basic'\s+then 0/);

// acc_crown must be the most expensive accessory (250 XP)
assert.match(patchSql, /when 'acc_crown'\s+then 250/);

// purchase_avatar_item RPC must still be present in v17 SQL (not removed)
const v17Sql = read('supabase/sql/archive/legacy-migrations/supabase_bingo_v17_avatar_shop.sql');
assert.match(v17Sql, /create or replace function public\.purchase_avatar_item/);

console.log('avatar_accessory_shop: all assertions passed');
