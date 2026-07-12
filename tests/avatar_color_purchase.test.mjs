import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_purchase.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// --- SQL patch guards ---

assert.match(patchSql, /create or replace function public\.purchase_avatar_color/, 'patch must define purchase_avatar_color');
assert.match(patchSql, /p_color_slot.*text.*p_color.*text/s, 'patch must take p_color_slot and p_color params');
assert.match(patchSql, /p_color_slot not in \('skinColor'\)/, 'patch must validate slot against skinColor');
assert.match(patchSql, /\^#\[0-9a-fA-F\]\{6\}/, 'patch must validate hex color format');
assert.match(patchSql, /v_cost.*:=.*25/, 'patch cost must be 25 XP');
assert.match(patchSql, /grant execute on function public\.purchase_avatar_color/, 'patch must grant execute');
assert.match(freshInstallSql, /purchase_avatar_color/, 'fresh install must include purchase_avatar_color');

// --- index.html: COLOR_PALETTE ---

assert.match(indexHtml, /const COLOR_PALETTE=\[/, 'index.html must define COLOR_PALETTE');
const paletteMatch = indexHtml.match(/const COLOR_PALETTE=\[([\s\S]*?)\];/);
assert.ok(paletteMatch, 'COLOR_PALETTE block found');
const hexMatches = [...paletteMatch[1].matchAll(/hex:'(#[0-9a-fA-F]{6})'/g)];
assert.ok(hexMatches.length >= 10, `COLOR_PALETTE must have at least 10 colors, got ${hexMatches.length}`);
for (const [, hex] of hexMatches) {
  assert.match(hex, /^#[0-9a-fA-F]{6}$/, `COLOR_PALETTE hex ${hex} must be valid #RRGGBB`);
}

// --- index.html: pendingAvatar includes skinColor ---

assert.match(indexHtml, /let pendingAvatar=\{head:'head_basic',acc:'acc_none',skinColor:null\}/, 'pendingAvatar must include skinColor:null default');

// --- index.html: pendingColorPick variable ---

assert.match(indexHtml, /let pendingColorPick=null/, 'index.html must declare pendingColorPick');

// --- index.html: normalizeAvatarData returns skinColor ---

assert.match(indexHtml, /const skinColor=.*avatarData\.skinColor.*#\[0-9a-fA-F\]/, 'normalizeAvatarData must validate and extract skinColor');

// --- index.html: _colorMaskStyle helper ---

assert.match(indexHtml, /function _colorMaskStyle\(col,row,size,url\)/, 'index.html must define _colorMaskStyle');
assert.match(indexHtml, /-webkit-mask.*mask:/, 'index.html _colorMaskStyle must output -webkit-mask and mask');

// --- index.html: avatar-color-layer in renderAvatarCircle ---

assert.match(indexHtml, /avatar-color-layer.*skinColor/, 'renderAvatarCircle must add avatar-color-layer when skinColor set');

// --- index.html: color tab in renderAvatarShop ---

assert.match(indexHtml, /setShopTab\('color'\).*Farger/, 'renderAvatarShop must have Farger tab');
assert.match(indexHtml, /color-palette/, 'renderAvatarShop must render color-palette div');
assert.match(indexHtml, /colorSwatchClick/, 'renderAvatarShop must wire colorSwatchClick');
assert.match(indexHtml, /buyAvatarColor\(\)/, 'renderAvatarShop must wire buyAvatarColor');

// --- index.html: color functions ---

assert.match(indexHtml, /function colorSwatchClick\(hex\)/, 'index.html must define colorSwatchClick');
assert.match(indexHtml, /async function buyAvatarColor\(\)/, 'index.html must define buyAvatarColor');
assert.match(indexHtml, /async function resetAvatarColor\(\)/, 'index.html must define resetAvatarColor');
assert.match(indexHtml, /async function purchaseAvatarColor\(slot,hexColor\)/, 'index.html must define purchaseAvatarColor');
assert.match(indexHtml, /purchase_avatar_color.*p_color_slot.*p_color/, 'purchaseAvatarColor must call the Supabase RPC');

// --- teacher.html: skinColor in renderAvatarCircleT ---

assert.match(teacherHtml, /skinColor.*#\[0-9a-fA-F\]/, 'teacher.html renderAvatarCircleT must validate skinColor');
assert.match(teacherHtml, /t-avatar-color-layer/, 'teacher.html must use t-avatar-color-layer class');
assert.match(teacherHtml, /-webkit-mask.*mask:.*skinColor/, 'teacher.html renderAvatarCircleT must apply CSS mask with skinColor');

console.log('avatar_color_purchase: all assertions passed');
