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
  return {
    width: buf.readUInt32BE(16),
    height: buf.readUInt32BE(20),
  };
}

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const avatarSql = read('supabase/sql/archive/legacy-migrations/supabase_bingo_v18_avatar_faceshapes.sql');

assert.ok(existsSync(join(root, 'media/avatar_faceshapes.png')), 'canonical faceshape sheet must exist');
assert.deepEqual(pngSize('media/avatar_faceshapes.png'), { width: 1024, height: 1280 });

for (const [name, text] of [
  ['index.html', indexHtml],
  ['apps/bingo/teacher.html', teacherHtml],
  ['supabase_bingo_v18_avatar_faceshapes.sql', avatarSql],
]) {
  assert.match(text, /avatar_faceshapes\.png/, `${name} must reference avatar_faceshapes.png`);
  assert.doesNotMatch(text, /avatarspreadsheet\.png/, `${name} must not reference avatarspreadsheet.png`);
}

assert.match(indexHtml, /4 cols × 5 rows/);
assert.match(indexHtml, /const AVATAR_ITEM_CATALOGUE=\[/);
assert.match(indexHtml, /head_flat_top/);
assert.match(indexHtml, /head_hood/);
assert.match(avatarSql, /when 'head_afro'\s+then 300/);
assert.doesNotMatch(avatarSql, /outfit_|face_/);

// Avatar-8: accessories catalogue has XP costs and SQL knows all acc_* keys
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessories_shop.sql');

// Catalogue must exist in index.html
assert.match(indexHtml, /const ACCESSORY_CATALOGUE=\[/);
// acc_none is still free
assert.match(indexHtml, /key:'acc_none'.*xp:0/);
// At least one paid accessory (crown at 150 XP)
assert.match(indexHtml, /key:'acc_crown'.*xp:150/);
// All 20 acc keys present in index.html catalogue
const accKeys = [
  'acc_none','acc_crown','acc_tophat','acc_cap','acc_graduation','acc_party_hat',
  'acc_viking','acc_cowboy','acc_headband','acc_beanie','acc_sombrero','acc_laurel',
  'acc_bow','acc_bandana','acc_witch_hat','acc_tiara','acc_chef_hat','acc_antlers',
  'acc_earmuffs','acc_bunny_ears',
];
for (const k of accKeys) {
  assert.match(indexHtml, new RegExp(`key:'${k}'`), `index.html must include ${k}`);
}
// SQL patch covers acc_none (free) and a spread of acc costs
assert.match(patchSql, /when 'acc_none'\s+then 0/);
assert.match(patchSql, /when 'acc_crown'\s+then 150/);
assert.match(patchSql, /when 'acc_viking'\s+then 200/);
// SQL patch still includes all head_* items
assert.match(patchSql, /when 'head_afro'\s+then 300/);
