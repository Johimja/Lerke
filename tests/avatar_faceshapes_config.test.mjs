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
const accessoryCostSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessory_costs.sql');

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

// Avatar-8: accessory XP costs must match between index.html catalogue and the SQL patch
assert.match(indexHtml, /const ACCESSORY_CATALOGUE=\[/);
const accBlockMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(accBlockMatch, 'ACCESSORY_CATALOGUE block must be found in index.html');
const accEntries = [...accBlockMatch[1].matchAll(/key:'(acc_[a-z_]+)'[\s\S]*?xp:(\d+)/g)]
  .map(([, key, xp]) => [key, Number(xp)]);
assert.equal(accEntries.length, 20, 'ACCESSORY_CATALOGUE must have 20 entries');

for (const [key, xp] of accEntries) {
  const sqlMatch = accessoryCostSql.match(new RegExp(`when '${key}'\\s+then (\\d+)`));
  assert.ok(sqlMatch, `${key} must have a cost defined in supabase_bingo_v20_avatar_accessory_costs.sql`);
  assert.equal(Number(sqlMatch[1]), xp, `${key} XP cost must match between index.html and the SQL patch`);
}

assert.deepEqual(accEntries.find(([key]) => key === 'acc_none'), ['acc_none', 0], 'acc_none must stay free');
