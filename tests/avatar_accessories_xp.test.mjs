import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const indexHtml = readFileSync(join(root, 'index.html'), 'utf8');
const v20Sql = readFileSync(join(root, 'supabase/sql/supabase_bingo_v20_avatar_accessories_xp.sql'), 'utf8');

// --- index.html: ACCESSORY_CATALOGUE has real XP costs ---

// Extract the ACCESSORY_CATALOGUE block
const accCatalogueMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(accCatalogueMatch, 'ACCESSORY_CATALOGUE must exist in index.html');
const catBlock = accCatalogueMatch[1];

// acc_none is always free
assert.match(catBlock, /key:'acc_none'[\s\S]*?xp:0/);

// Crown is top-tier (300 XP)
assert.match(catBlock, /key:'acc_crown'[\s\S]*?xp:300/);

// Tiara is premium (200 XP)
assert.match(catBlock, /key:'acc_tiara'[\s\S]*?xp:200/);

// Basic accessories are cheap (50 XP)
for (const key of ['acc_cap', 'acc_headband', 'acc_beanie']) {
  const re = new RegExp(`key:'${key}'[\\s\\S]*?xp:50`);
  assert.match(catBlock, re, `${key} must cost 50 XP`);
}

// No accessories should still have xp:0 except acc_none
const allZero = [...catBlock.matchAll(/key:'(acc_[^']+)'[\s\S]*?xp:0/g)].map(m => m[1]);
assert.deepEqual(allZero, ['acc_none'], 'Only acc_none should have xp:0');

// --- v20 SQL: get_avatar_item_cost includes all acc_* keys ---

assert.match(v20Sql, /when 'acc_none'\s+then 0/);
assert.match(v20Sql, /when 'acc_crown'\s+then 300/);
assert.match(v20Sql, /when 'acc_tiara'\s+then 200/);
assert.match(v20Sql, /when 'acc_viking'\s+then 175/);
assert.match(v20Sql, /when 'acc_cap'\s+then 50/);

// Head face-shapes must still be present in v20 SQL
assert.match(v20Sql, /when 'head_basic'\s+then 0/);
assert.match(v20Sql, /when 'head_afro'\s+then 300/);

// All 20 acc keys must appear in the SQL
const accKeys = [
  'acc_none','acc_crown','acc_tophat','acc_cap','acc_graduation','acc_party_hat',
  'acc_viking','acc_cowboy','acc_headband','acc_beanie','acc_sombrero','acc_laurel',
  'acc_bow','acc_bandana','acc_witch_hat','acc_tiara','acc_chef_hat','acc_antlers',
  'acc_earmuffs','acc_bunny_ears',
];
for (const key of accKeys) {
  assert.match(v20Sql, new RegExp(`when '${key}'`), `v20 SQL must include cost for ${key}`);
}

console.log('avatar_accessories_xp: all assertions passed ✅');
