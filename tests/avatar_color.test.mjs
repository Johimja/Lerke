import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
function read(p) { return readFileSync(join(root, p), 'utf8'); }

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// --- SQL patch: function exists and grants access ---
assert.match(patchSql, /create or replace function public\.purchase_avatar_color/, 'patch: purchase_avatar_color must be defined');
assert.match(patchSql, /grant execute on function public\.purchase_avatar_color/, 'patch: must grant execute');
assert.match(patchSql, /p_color_slot not in \('headColor', 'accColor'\)/, 'patch: must validate slot');
assert.match(patchSql, /p_color !~ '\^#\[0-9a-fA-F\]\{6\}\$'/, 'patch: must validate hex color format');
assert.match(patchSql, /v_cost\s+int := 25/, 'patch: cost must be 25 XP');
assert.match(patchSql, /student_auth_links/, 'patch: must resolve student via student_auth_links');

// --- fresh install also has the RPC ---
assert.match(freshInstallSql, /create or replace function public\.purchase_avatar_color/, 'fresh install: purchase_avatar_color must be present');

// --- index.html: color constants ---
assert.match(indexHtml, /AVATAR_DEFAULT_HEAD_COLOR='#[0-9a-fA-F]{6}'/, 'index.html: must define AVATAR_DEFAULT_HEAD_COLOR');
assert.match(indexHtml, /AVATAR_DEFAULT_ACC_COLOR='#[0-9a-fA-F]{6}'/, 'index.html: must define AVATAR_DEFAULT_ACC_COLOR');

// --- index.html: pendingAvatar includes color keys ---
assert.match(indexHtml, /headColor:AVATAR_DEFAULT_HEAD_COLOR/, 'index.html: pendingAvatar must include headColor');
assert.match(indexHtml, /accColor:AVATAR_DEFAULT_ACC_COLOR/, 'index.html: pendingAvatar must include accColor');

// --- index.html: normalizeAvatarData preserves colors ---
assert.match(indexHtml, /headColor.*hexRe\.test.*AVATAR_DEFAULT_HEAD_COLOR/, 'index.html: normalizeAvatarData must handle headColor');
assert.match(indexHtml, /accColor.*hexRe\.test.*AVATAR_DEFAULT_ACC_COLOR/, 'index.html: normalizeAvatarData must handle accColor');

// --- index.html: colored mask CSS classes present ---
assert.match(indexHtml, /\.avatar-layer-c\{/, 'index.html: .avatar-layer-c CSS must be defined');
assert.match(indexHtml, /\.avatar-acc-layer-c\{/, 'index.html: .avatar-acc-layer-c CSS must be defined');
assert.match(indexHtml, /mask-image:url\('media\/avatar_faceshapes\.png'\)/, 'index.html: avatar-layer-c must use mask-image for faceshapes');
assert.match(indexHtml, /mask-image:url\('media\/avatar_head_accessories\.png'\)/, 'index.html: avatar-acc-layer-c must use mask-image for accessories');

// --- index.html: _maskSpriteStyle function ---
assert.match(indexHtml, /function _maskSpriteStyle\(col,row,size\)/, 'index.html: _maskSpriteStyle must be defined');
assert.match(indexHtml, /mask-size:/, 'index.html: _maskSpriteStyle must output mask-size');
assert.match(indexHtml, /-webkit-mask-size:/, 'index.html: _maskSpriteStyle must output -webkit-mask-size');

// --- index.html: renderAvatarCircle uses colored layers ---
assert.match(indexHtml, /avatar-layer-c.*_maskSpriteStyle.*background-color/, 'index.html: renderAvatarCircle must use avatar-layer-c with mask + background-color');
assert.match(indexHtml, /avatar-acc-layer-c.*_maskSpriteStyle.*background-color/, 'index.html: renderAvatarCircle must use avatar-acc-layer-c with mask + background-color');

// --- index.html: color tab in shop ---
assert.match(indexHtml, /setShopTab\('color'\)/, 'index.html: shop must have color tab');
assert.match(indexHtml, /function renderColorTab\(\)/, 'index.html: renderColorTab must be defined');
assert.match(indexHtml, /colorPreviewChange/, 'index.html: colorPreviewChange must be referenced');
assert.match(indexHtml, /async function purchaseAvatarColor\(slot\)/, 'index.html: purchaseAvatarColor must be defined');
assert.match(indexHtml, /purchase_avatar_color/, 'index.html: must call purchase_avatar_color RPC');

// --- index.html: color tab does not expose cost in buy button without auth check ---
assert.match(indexHtml, /Sett farge \(25 XP\)/, 'index.html: buy button must show 25 XP cost');

// --- teacher.html: colored mask CSS classes ---
assert.match(teacherHtml, /\.t-avatar-layer-c\{/, 'teacher.html: .t-avatar-layer-c CSS must be defined');
assert.match(teacherHtml, /\.t-avatar-acc-layer-c\{/, 'teacher.html: .t-avatar-acc-layer-c CSS must be defined');
assert.match(teacherHtml, /mask-image:url\('\.\.\/\.\.\/media\/avatar_faceshapes\.png'\)/, 'teacher.html: t-avatar-layer-c must use correct mask-image path');

// --- teacher.html: _tMaskSpriteStyle and colored renderAvatarCircleT ---
assert.match(teacherHtml, /function _tMaskSpriteStyle\(col,row,size\)/, 'teacher.html: _tMaskSpriteStyle must be defined');
assert.match(teacherHtml, /T_DEFAULT_HEAD_COLOR=/, 'teacher.html: must define T_DEFAULT_HEAD_COLOR');
assert.match(teacherHtml, /t-avatar-layer-c.*_tMaskSpriteStyle.*background-color/, 'teacher.html: renderAvatarCircleT must use colored mask layers');

console.log('avatar_color.test.mjs: all assertions passed ✅');
