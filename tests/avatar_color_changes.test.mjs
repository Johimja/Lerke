import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
function read(relPath) { return readFileSync(join(root, relPath), 'utf8'); }

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// --- SQL patch checks ---
assert.match(patchSql, /create or replace function public\.purchase_avatar_color/, 'patch must define purchase_avatar_color');
assert.match(patchSql, /p_color_slot.*text/, 'patch must accept p_color_slot');
assert.match(patchSql, /p_color.*text/, 'patch must accept p_color');
assert.match(patchSql, /v_color_cost.*25/, 'color cost must be 25 XP');
assert.match(patchSql, /grant execute.*purchase_avatar_color/, 'patch must grant execute');
assert.match(freshInstallSql, /purchase_avatar_color/, 'fresh install must include purchase_avatar_color');

// --- index.html constants ---
assert.match(indexHtml, /const DEFAULT_SKIN_COLOR='#c8a882'/, 'DEFAULT_SKIN_COLOR must be defined');
assert.match(indexHtml, /const SKIN_COLOR_COST=25/, 'SKIN_COLOR_COST must be 25');
assert.match(indexHtml, /const SKIN_SWATCHES=\[/, 'SKIN_SWATCHES must be defined');

// SKIN_SWATCHES must have a free default entry
assert.match(indexHtml, /free:true/, 'at least one swatch must be free');

// pendingAvatar must include skinColor
assert.match(indexHtml, /pendingAvatar=\{head:'head_basic',acc:'acc_none',skinColor:DEFAULT_SKIN_COLOR\}/, 'pendingAvatar must include skinColor');

// normalizeAvatarData must handle skinColor
assert.match(indexHtml, /skinColor.*#[0-9a-fA-F]{6}.*normalizeAvatarData|normalizeAvatarData[\s\S]{0,200}skinColor/m, 'normalizeAvatarData must normalize skinColor');
assert.match(indexHtml, /return \{head,acc,skinColor\}/, 'normalizeAvatarData must return skinColor');

// _maskSpriteStyle must be defined
assert.match(indexHtml, /function _maskSpriteStyle\(/, '_maskSpriteStyle must be defined');
assert.match(indexHtml, /mask-size/, 'mask-size must be used');
assert.match(indexHtml, /mask-position/, 'mask-position must be used');

// avatar-layer CSS must use mask-image not background-image
const avatarLayerMatch = indexHtml.match(/\.avatar-layer\{[^}]+\}/);
assert.ok(avatarLayerMatch, '.avatar-layer CSS must exist');
assert.ok(avatarLayerMatch[0].includes('mask-image'), '.avatar-layer must use mask-image');
assert.ok(!avatarLayerMatch[0].includes('background-image'), '.avatar-layer must not use background-image');

// renderAvatarCircle must use _maskSpriteStyle for head layer
assert.match(indexHtml, /renderAvatarCircle[\s\S]{0,600}_maskSpriteStyle/m, 'renderAvatarCircle must use _maskSpriteStyle');

// Farge tab in shop
assert.match(indexHtml, /Farge/, 'avatar shop must have a Farge tab');
assert.match(indexHtml, /colorSwatchClick/, 'colorSwatchClick must be referenced in shop');

// colorSwatchClick function exists
assert.match(indexHtml, /async function colorSwatchClick/, 'colorSwatchClick must be defined');
assert.match(indexHtml, /purchase_avatar_color/, 'colorSwatchClick must call purchase_avatar_color RPC');

// --- teacher.html checks ---
const tAvatarLayerMatch = teacherHtml.match(/\.t-avatar-layer\{[^}]+\}/);
assert.ok(tAvatarLayerMatch, '.t-avatar-layer CSS must exist');
assert.ok(tAvatarLayerMatch[0].includes('mask-image'), '.t-avatar-layer must use mask-image');
assert.ok(!tAvatarLayerMatch[0].includes('background-image'), '.t-avatar-layer must not use background-image');

assert.match(teacherHtml, /function _tMaskSpriteStyle\(/, 'teacher.html must define _tMaskSpriteStyle');
assert.match(teacherHtml, /renderAvatarCircleT[\s\S]{0,600}_tMaskSpriteStyle/m, 'renderAvatarCircleT must use _tMaskSpriteStyle');
assert.match(teacherHtml, /skinColor.*avatarData\.skinColor|avatarData\.skinColor.*skinColor/, 'renderAvatarCircleT must read skinColor from avatarData');

console.log('avatar_color_changes: all assertions passed');
