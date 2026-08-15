import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml    = read('index.html');
const teacherHtml  = read('apps/bingo/teacher.html');
const patchSql     = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshSql     = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// --- SQL: purchase_avatar_color RPC exists in both files ---
for (const [name, sql] of [['patch', patchSql], ['fresh-install', freshSql]]) {
  assert.match(sql, /purchase_avatar_color/, `${name} must define purchase_avatar_color`);
  assert.match(sql, /invalid_slot/,          `${name} must validate slot name`);
  assert.match(sql, /invalid_color/,         `${name} must validate hex color format`);
  assert.match(sql, /insufficient_xp/,       `${name} must check XP balance`);
  assert.match(sql, /skinColor/,             `${name} must list skinColor as a valid slot`);
  assert.match(sql, /v_cost.*25|25.*v_cost/, `${name} must set cost to 25 XP`);
  assert.match(sql, /grant execute.*purchase_avatar_color/, `${name} must grant execute`);
}

// --- index.html: color shop tab exists ---
assert.match(indexHtml, /setShopTab\('color'\)/, 'index.html must have color shop tab');
assert.match(indexHtml, /Farge/, 'index.html must label color tab as Farge');

// --- index.html: purchaseAvatarColor function ---
assert.match(indexHtml, /async function purchaseAvatarColor/, 'index.html must define purchaseAvatarColor');
assert.match(indexHtml, /purchase_avatar_color/, 'index.html must call purchase_avatar_color RPC');
assert.match(indexHtml, /p_color_slot.*skinColor|skinColor.*p_color_slot/, 'index.html must pass skinColor slot');

// --- index.html: clearAvatarColor function ---
assert.match(indexHtml, /async function clearAvatarColor/, 'index.html must define clearAvatarColor');

// --- index.html: previewAvatarColor function ---
assert.match(indexHtml, /function previewAvatarColor/, 'index.html must define previewAvatarColor');

// --- index.html: normalizeAvatarData passes through skinColor ---
assert.match(indexHtml, /skinColor.*normalizeAvatarData|normalizeAvatarData[\s\S]{0,400}skinColor/,
  'normalizeAvatarData must handle skinColor');

// --- index.html: pendingAvatar includes skinColor ---
assert.match(indexHtml, /pendingAvatar=\{head:.*skinColor/, 'pendingAvatar default must include skinColor');

// --- index.html: renderAvatarCircle uses mask-image for tinting ---
assert.match(indexHtml, /mask-image.*avatar_faceshapes|avatar_faceshapes.*mask-image/,
  'renderAvatarCircle must use CSS mask-image for skinColor tinting');
assert.match(indexHtml, /avatar-tinted-layer/, 'index.html must define avatar-tinted-layer CSS class');

// --- teacher.html: renderAvatarCircleT uses mask-image for tinting ---
assert.match(teacherHtml, /mask-image.*avatar_faceshapes|avatar_faceshapes.*mask-image/,
  'renderAvatarCircleT must use CSS mask-image for skinColor tinting');
assert.match(teacherHtml, /t-avatar-tinted-layer/, 'teacher.html must define t-avatar-tinted-layer CSS class');

console.log('avatar_color_shop.test.mjs: all checks passed ✅');
