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
const accessorySql = read('supabase/sql/archive/Patches/supabase_bingo_v20_accessory_shop_patch.sql');

assert.ok(existsSync(join(root, 'media/avatar_faceshapes.png')), 'canonical faceshape sheet must exist');
assert.deepEqual(pngSize('media/avatar_faceshapes.png'), { width: 1024, height: 1280 });

assert.ok(existsSync(join(root, 'media/avatar_head_accessories.png')), 'accessories sheet must exist');
assert.deepEqual(pngSize('media/avatar_head_accessories.png'), { width: 1024, height: 1280 });

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

// Avatar-8: accessory shop — v20 SQL patch assertions
assert.match(accessorySql, /when 'acc_none'\s+then 0/, 'acc_none must be free');
assert.match(accessorySql, /when 'acc_party_hat'\s+then 0/, 'acc_party_hat must be free');
assert.match(accessorySql, /when 'acc_headband'\s+then 0/, 'acc_headband must be free');
assert.match(accessorySql, /when 'acc_viking'\s+then 300/, 'acc_viking must cost 300 XP');
assert.match(accessorySql, /when 'acc_crown'\s+then 250/, 'acc_crown must cost 250 XP');
assert.match(accessorySql, /when 'head_basic'\s+then 0/, 'v20 patch must preserve head_basic=0');

// ACCESSORY_CATALOGUE in index.html has 20 items with XP costs
assert.match(indexHtml, /const ACCESSORY_CATALOGUE=\[/);
assert.match(indexHtml, /acc_none.*xp:0/);
assert.match(indexHtml, /acc_viking.*xp:300/);
assert.match(indexHtml, /acc_crown.*xp:250/);
