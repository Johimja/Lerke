import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

function pngSize(relPath) {
  const buf = readFileSync(join(root, relPath));
  assert.equal(buf.toString('ascii', 1, 4), 'PNG', `${relPath} must be a PNG`);
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

const indexHtml  = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql   = read('supabase/sql/archive/Patches/supabase_bingo_v20_accessories_shop_patch.sql');

// ── Spritesheet ──────────────────────────────────────────────────────────────

assert.ok(existsSync(join(root, 'media/avatar_head_accessories.png')),
  'avatar_head_accessories.png must exist');
assert.deepEqual(pngSize('media/avatar_head_accessories.png'), { width: 1024, height: 1280 });

// ── ACCESSORY_CATALOGUE in index.html ────────────────────────────────────────

const ACC_KEYS = [
  'acc_none','acc_crown','acc_tophat','acc_cap','acc_graduation','acc_party_hat',
  'acc_viking','acc_cowboy','acc_headband','acc_beanie','acc_sombrero','acc_laurel',
  'acc_bow','acc_bandana','acc_witch_hat','acc_tiara','acc_chef_hat','acc_antlers',
  'acc_earmuffs','acc_bunny_ears',
];

assert.match(indexHtml, /const ACCESSORY_CATALOGUE=\[/, 'ACCESSORY_CATALOGUE must exist');

for (const key of ACC_KEYS) {
  assert.match(indexHtml, new RegExp(`'${key}'`), `index.html must contain '${key}'`);
}

// Free items: acc_none and acc_headband must have xp:0
assert.match(indexHtml, /acc_none.*?xp:0/s, 'acc_none must be free (xp:0)');
assert.match(indexHtml, /acc_headband.*?xp:0/s, 'acc_headband must be free (xp:0)');

// At least some items must be paid — tiara at 200 XP
assert.match(indexHtml, /acc_tiara.*?xp:200/s, 'acc_tiara must cost 200 XP');
assert.match(indexHtml, /acc_crown.*?xp:125/s,  'acc_crown must cost 125 XP');
assert.match(indexHtml, /acc_viking.*?xp:150/s, 'acc_viking must cost 150 XP');

// No acc_* item in ACCESSORY_CATALOGUE should have xp:0 except acc_none and acc_headband
// (i.e., at least 18 items must have a non-zero cost)
const catalogue = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/)?.[1] ?? '';
const zeroCostAcc = [...catalogue.matchAll(/key:'(acc_\w+)'[^}]*xp:0/g)].map(m => m[1]);
assert.deepEqual(zeroCostAcc.sort(), ['acc_headband','acc_none'].sort(),
  'Only acc_none and acc_headband should be free');

// ── ACCESSORY_CATALOGUE_T in teacher.html ─────────────────────────────────────

assert.match(teacherHtml, /const ACCESSORY_CATALOGUE_T=\[/, 'ACCESSORY_CATALOGUE_T must exist in teacher.html');

for (const key of ACC_KEYS) {
  assert.match(teacherHtml, new RegExp(`'${key}'`), `teacher.html must contain '${key}'`);
}

// ── SQL patch ────────────────────────────────────────────────────────────────

assert.match(patchSql, /get_avatar_item_cost/, 'SQL patch must update get_avatar_item_cost');

for (const key of ACC_KEYS) {
  assert.match(patchSql, new RegExp(`'${key}'`), `SQL patch must include '${key}'`);
}

assert.match(patchSql, /when 'acc_none'\s+then 0/,  'acc_none must cost 0 in SQL');
assert.match(patchSql, /when 'acc_tiara'\s+then 200/, 'acc_tiara must cost 200 in SQL');

console.log('avatar_accessories_shop: all assertions passed ✅');
