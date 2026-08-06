import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
function read(p) { return readFileSync(join(root, p), 'utf8'); }

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// --- SQL patch assertions ---
assert.match(patchSql, /purchase_avatar_color/, 'patch must define purchase_avatar_color');
assert.match(patchSql, /p_color_slot text/, 'function must accept p_color_slot');
assert.match(patchSql, /p_color.*text/, 'function must accept p_color');
assert.match(patchSql, /Ugyldig fargespor/, 'must reject invalid slot');
assert.match(patchSql, /Ugyldig farge/, 'must reject invalid hex color');
assert.match(patchSql, /Ikke nok XP/, 'must check XP balance');
assert.match(patchSql, /v_color_cost.*:=.*25/, 'color change cost must be 25 XP');
assert.match(patchSql, /when p_color is null then 0/, 'reset to default must be free (0 XP)');
assert.match(patchSql, /grant execute on function public\.purchase_avatar_color/, 'must grant execute');

// Both SQL files must define purchase_avatar_color
for (const [name, sql] of [['patch', patchSql], ['fresh_install', freshInstallSql]]) {
  assert.match(sql, /purchase_avatar_color/, `${name} must define purchase_avatar_color`);
}

// --- index.html assertions ---
assert.match(indexHtml, /DEFAULT_SKIN_COLOR='#[0-9a-fA-F]{6}'/, 'index.html must define DEFAULT_SKIN_COLOR');
assert.match(indexHtml, /avatar-layer-colored/, 'index.html must define avatar-layer-colored CSS class');
assert.match(indexHtml, /mask-image:url\('media\/avatar_faceshapes\.png'\)/, 'index.html must use mask-image for face layer');
assert.match(indexHtml, /_coloredFaceLayerStyle/, 'index.html must define _coloredFaceLayerStyle helper');
assert.match(indexHtml, /skinColor:null/, 'pendingAvatar must include skinColor field');
assert.match(indexHtml, /normalizeAvatarData[\s\S]*?skinColor/, 'normalizeAvatarData must extract skinColor');
assert.match(indexHtml, /currentShopTab==='color'/, 'renderAvatarShop must handle color tab');
assert.match(indexHtml, /renderColorTab\(\)/, 'renderAvatarShop must call renderColorTab');
assert.match(indexHtml, /purchase_avatar_color/, 'index.html must call purchase_avatar_color RPC');
assert.match(indexHtml, /saveAvatarColor/, 'index.html must define saveAvatarColor function');
assert.match(indexHtml, /onColorPickerChange/, 'index.html must define onColorPickerChange');
assert.match(indexHtml, /onColorPickerReset/, 'index.html must define onColorPickerReset');
assert.match(indexHtml, /Fargeskifte koster 25 XP/, 'color tab must explain XP cost to user');

// The color tab (Farge) must appear as a tab in the shop
assert.match(indexHtml, /Farge<\/div>/, 'shop tabs must include Farge tab');

// normalizeAvatarData must return skinColor with hex validation
assert.match(indexHtml, /\/\^#\[0-9A-Fa-f\]\{6\}\$\//, 'normalizeAvatarData must validate skinColor hex format');

// --- teacher.html assertions ---
assert.match(teacherHtml, /t-avatar-layer-colored/, 'teacher.html must define t-avatar-layer-colored CSS class');
assert.match(teacherHtml, /mask-image:url\('\.\.\/\.\.\/media\/avatar_faceshapes\.png'\)/, 'teacher.html must use mask-image for face layer');
assert.match(teacherHtml, /DEFAULT_SKIN_COLOR_T/, 'teacher.html must define DEFAULT_SKIN_COLOR_T constant');
assert.match(teacherHtml, /skinColor.*DEFAULT_SKIN_COLOR_T/, 'renderAvatarCircleT must use skinColor with fallback to DEFAULT_SKIN_COLOR_T');

// DEFAULT_SKIN_COLOR must match between index.html and teacher.html
const skinColorMatch = indexHtml.match(/DEFAULT_SKIN_COLOR='(#[0-9a-fA-F]{6})'/);
assert.ok(skinColorMatch, 'index.html must have DEFAULT_SKIN_COLOR constant');
const teacherMatch = teacherHtml.match(/DEFAULT_SKIN_COLOR_T='(#[0-9a-fA-F]{6})'/);
assert.ok(teacherMatch, 'teacher.html must have DEFAULT_SKIN_COLOR_T constant');
assert.equal(skinColorMatch[1], teacherMatch[1], 'DEFAULT_SKIN_COLOR must match DEFAULT_SKIN_COLOR_T');

console.log('avatar_color.test.mjs: all assertions passed ✓');
