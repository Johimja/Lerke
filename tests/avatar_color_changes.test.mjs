import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_colors_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// --- SQL patch contains the RPC ---
assert.match(patchSql, /create or replace function public\.purchase_avatar_color/, 'patch must define purchase_avatar_color');
assert.match(patchSql, /grant execute on function public\.purchase_avatar_color/, 'patch must grant execute');
assert.match(patchSql, /p_color_slot\s+text/, 'RPC must accept p_color_slot');
assert.match(patchSql, /p_color\s+text/, 'RPC must accept p_color');
assert.match(patchSql, /v_cost\s+int\s*:=\s*25/, 'color change must cost 25 XP');
assert.match(patchSql, /skinColor/, 'patch must reference skinColor as valid slot');
assert.match(patchSql, /#\[0-9a-fA-F\]\{6\}/, 'patch must validate 6-digit hex format');
assert.match(patchSql, /v_profile\.total_xp - v_cost/, 'patch must deduct XP correctly');
assert.match(patchSql, /jsonb_set.*skinColor|array\[p_color_slot\]/, 'patch must store color in avatar_data via jsonb_set');

// --- Fresh install SQL also contains the RPC ---
assert.match(freshInstallSql, /create or replace function public\.purchase_avatar_color/, 'fresh install must include purchase_avatar_color');
assert.match(freshInstallSql, /grant execute on function public\.purchase_avatar_color/, 'fresh install must grant execute');

// --- index.html: pendingAvatar includes skinColor ---
assert.match(indexHtml, /pendingAvatar=\{head:'head_basic',acc:'acc_none',skinColor:null\}/, 'pendingAvatar must include skinColor:null');

// --- index.html: normalizeAvatarData returns skinColor ---
assert.match(indexHtml, /normalizeAvatarData/, 'normalizeAvatarData must exist');
assert.match(indexHtml, /skinColor.*avatarData.*skinColor|avatarData.*skinColor.*skinColor/s, 'normalizeAvatarData must handle skinColor field');
assert.match(indexHtml, /#\[0-9a-fA-F\]\{6\}/, 'normalizeAvatarData must validate hex color in index.html');

// --- index.html: _coloredSpriteStyle helper ---
assert.match(indexHtml, /function _coloredSpriteStyle/, '_coloredSpriteStyle must be defined');
assert.match(indexHtml, /mask-size/, '_coloredSpriteStyle must output mask-size');
assert.match(indexHtml, /mask-position/, '_coloredSpriteStyle must output mask-position');

// --- index.html: CSS classes ---
assert.match(indexHtml, /\.avatar-color-layer/, 'index.html must define .avatar-color-layer CSS class');
assert.match(indexHtml, /mask-image:url\('media\/avatar_faceshapes\.png'\)/, '.avatar-color-layer must reference avatar_faceshapes.png as mask');

// --- index.html: Farge tab in shop ---
assert.match(indexHtml, /setShopTab\('color'\)/, 'shop must include Farge tab calling setShopTab(color)');
assert.match(indexHtml, /Farge/, 'shop tabs must include Farge label');

// --- index.html: color preset swatches ---
assert.match(indexHtml, /_COLOR_PRESETS/, 'must define _COLOR_PRESETS');
assert.match(indexHtml, /_COLOR_COST=25/, 'color change cost must be 25 XP');

// --- index.html: purchaseAvatarColor function ---
assert.match(indexHtml, /async function purchaseAvatarColor/, 'must define purchaseAvatarColor');
assert.match(indexHtml, /purchase_avatar_color.*p_color_slot.*p_color|p_color_slot.*p_color.*purchase_avatar_color/s, 'purchaseAvatarColor must call RPC with correct params');

// --- index.html: updateColorPreview function ---
assert.match(indexHtml, /function updateColorPreview/, 'must define updateColorPreview');
assert.match(indexHtml, /color-avatar-preview/, 'color preview must target color-avatar-preview element');

// --- index.html: renderAvatarCircle uses avatar-color-layer when skinColor set ---
assert.match(indexHtml, /avatar-color-layer/, 'renderAvatarCircle must use avatar-color-layer');
assert.match(indexHtml, /normalized\.skinColor/, 'renderAvatarCircle must branch on normalized.skinColor');

// --- teacher.html: CSS class ---
assert.match(teacherHtml, /\.t-avatar-color-layer/, 'teacher.html must define .t-avatar-color-layer CSS class');
assert.match(teacherHtml, /mask-image:url\('\.\.\/\.\.\/media\/avatar_faceshapes\.png'\)/, 't-avatar-color-layer must reference faceshapes via correct relative path');

// --- teacher.html: _tColoredSpriteStyle helper ---
assert.match(teacherHtml, /function _tColoredSpriteStyle/, '_tColoredSpriteStyle must be defined in teacher.html');

// --- teacher.html: renderAvatarCircleT uses colored layer ---
assert.match(teacherHtml, /t-avatar-color-layer/, 'renderAvatarCircleT must use t-avatar-color-layer when skinColor is set');
assert.match(teacherHtml, /skinColor.*_tColoredSpriteStyle|_tColoredSpriteStyle.*skinColor/s, 'renderAvatarCircleT must call _tColoredSpriteStyle for skinColor');

console.log('avatar_color_changes: all assertions passed ✅');
