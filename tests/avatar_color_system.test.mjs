import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml  = read('index.html');
const patchSql   = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshSql   = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');
const teacherHtml = read('apps/bingo/teacher.html');

// ── 1. pendingAvatar default includes headColor: '#ffffff'
assert.match(indexHtml, /pendingAvatar=\{head:'head_basic',acc:'acc_none',headColor:'#ffffff'\}/,
  'pendingAvatar default must include headColor:#ffffff');

// ── 2. normalizeAvatarData extracts headColor with hex validation
assert.match(indexHtml, /normalizeAvatarData/,
  'normalizeAvatarData function must exist');
assert.match(indexHtml, /headColor.*#ffffff/,
  'normalizeAvatarData must fall back to #ffffff for invalid/missing headColor');

// ── 3. Farge tab rendered in shop
assert.match(indexHtml, /setShopTab\('color'\).*Farge/s,
  'Avatar shop must include a Farge (color) tab');

// ── 4. purchaseAvatarColor function exists and calls the RPC
assert.match(indexHtml, /async function purchaseAvatarColor/,
  'purchaseAvatarColor async function must be defined');
assert.match(indexHtml, /purchase_avatar_color.*p_color_slot.*headColor/s,
  'purchaseAvatarColor must call purchase_avatar_color RPC with headColor slot');

// ── 5. CSS mask coloring helper exists
assert.match(indexHtml, /_coloredMaskStyle/,
  '_coloredMaskStyle helper must exist in index.html');
assert.match(indexHtml, /-webkit-mask.*mask:/s,
  'Colored mask style must include both -webkit-mask and mask properties');

// ── 6. SQL patch — RPC function defined correctly
assert.match(patchSql, /create or replace function public\.purchase_avatar_color/,
  'v21 patch must define purchase_avatar_color');
assert.match(patchSql, /COLOR_CHANGE_COST.*25/,
  'v21 patch must define cost of 25 XP');
assert.match(patchSql, /'headColor'/,
  "v21 patch must list 'headColor' as a valid slot");
assert.match(patchSql, /#\[0-9a-fA-F\]\{6\}/,
  'v21 patch must validate hex color format');
assert.match(patchSql, /grant execute on function public\.purchase_avatar_color/,
  'v21 patch must grant execute on purchase_avatar_color');

// ── 7. Fresh install SQL includes v21
assert.match(freshSql, /purchase_avatar_color/,
  'fresh install SQL must include purchase_avatar_color');
assert.match(freshSql, /v21_avatar_color/,
  'fresh install SQL must reference v21_avatar_color migration');

// ── 8. Teacher rendering applies headColor
assert.match(teacherHtml, /_tColoredMaskStyle/,
  'teacher.html must define _tColoredMaskStyle for colored avatars');
assert.match(teacherHtml, /avatarData\.headColor/,
  'teacher.html renderAvatarCircleT must read avatarData.headColor');

// ── 9. Color picker live-preview functions exist
assert.match(indexHtml, /function onColorInput/,
  'onColorInput function must exist for live color preview');
assert.match(indexHtml, /function onColorHexInput/,
  'onColorHexInput function must exist for hex text field');

console.log('avatar_color_system: all assertions passed ✓');
