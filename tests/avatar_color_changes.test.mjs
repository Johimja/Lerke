import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_changes_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// --- SQL patch sanity checks ---
assert.ok(patchSql.includes('purchase_avatar_color'), 'patch must define purchase_avatar_color');
assert.ok(patchSql.includes("p_color_slot text"), 'patch must accept p_color_slot');
assert.ok(patchSql.includes("p_color      text"), 'patch must accept p_color');
assert.ok(patchSql.includes("'skin'"), 'patch must validate skin slot');
assert.ok(patchSql.includes('#[0-9a-f]{6}'), 'patch must validate hex color format');
assert.ok(patchSql.includes('total_xp - v_cost'), 'patch must deduct XP');
assert.ok(patchSql.includes("|| 'Color'") || patchSql.includes("'Color'"), 'patch must build *Color slot key in avatar_data');
assert.ok(patchSql.includes('grant execute on function public.purchase_avatar_color'), 'patch must grant execute');

// --- Fresh install includes the function ---
assert.ok(freshInstallSql.includes('purchase_avatar_color'), 'fresh install must include purchase_avatar_color');
assert.ok(freshInstallSql.includes("grant execute on function public.purchase_avatar_color"), 'fresh install must grant execute');

// --- index.html: skinColor in normalizeAvatarData ---
assert.ok(indexHtml.includes('skinColor'), 'index.html must reference skinColor');
assert.ok(indexHtml.includes('normalizeAvatarData'), 'index.html must define normalizeAvatarData');
const normalizeMatch = indexHtml.match(/function normalizeAvatarData[\s\S]*?^}/m);
assert.ok(normalizeMatch, 'normalizeAvatarData must be found');
assert.ok(normalizeMatch[0].includes('skinColor'), 'normalizeAvatarData must handle skinColor');

// --- index.html: pendingAvatar default includes skinColor ---
assert.ok(indexHtml.includes("head:'head_basic',acc:'acc_none',skinColor:null"), 'pendingAvatar must include skinColor:null');

// --- index.html: _maskStyle helper exists ---
assert.ok(indexHtml.includes('function _maskStyle('), 'index.html must define _maskStyle');
assert.ok(indexHtml.includes('mask-image'), '_maskStyle must use CSS mask-image');
assert.ok(indexHtml.includes('-webkit-mask-image'), '_maskStyle must use -webkit- prefix');
assert.ok(indexHtml.includes('mask-size'), '_maskStyle must use mask-size');
assert.ok(indexHtml.includes('mask-position'), '_maskStyle must use mask-position');

// --- index.html: renderAvatarCircle uses mask when skinColor is set ---
const renderMatch = indexHtml.match(/function renderAvatarCircle[\s\S]*?^}/m);
assert.ok(renderMatch, 'renderAvatarCircle must be found');
assert.ok(renderMatch[0].includes('_maskStyle'), 'renderAvatarCircle must call _maskStyle for skinColor');
assert.ok(renderMatch[0].includes('normalized.skinColor'), 'renderAvatarCircle must check normalized.skinColor');

// --- index.html: color tab in renderAvatarShop ---
assert.ok(indexHtml.includes("setShopTab('color')"), 'index.html must have a color tab');
assert.ok(indexHtml.includes("Farger"), 'index.html must label the Farger tab');
assert.ok(indexHtml.includes("avatar-skin-color-picker"), 'index.html must have skin color picker');

// --- index.html: previewSkinColor function ---
assert.ok(indexHtml.includes('function previewSkinColor('), 'index.html must define previewSkinColor');

// --- index.html: saveAvatarColor function ---
assert.ok(indexHtml.includes('async function saveAvatarColor('), 'index.html must define saveAvatarColor');
assert.ok(indexHtml.includes("purchase_avatar_color"), 'saveAvatarColor must call purchase_avatar_color RPC');
assert.ok(indexHtml.includes('p_color_slot:slot'), 'saveAvatarColor must pass p_color_slot');
assert.ok(indexHtml.includes('p_color:color'), 'saveAvatarColor must pass p_color');

// --- teacher.html: _tMaskStyle helper ---
assert.ok(teacherHtml.includes('function _tMaskStyle('), 'teacher.html must define _tMaskStyle');
assert.ok(teacherHtml.includes('mask-image'), 'teacher.html _tMaskStyle must use mask-image');

// --- teacher.html: renderAvatarCircleT uses mask when skinColor set ---
const teacherRenderMatch = teacherHtml.match(/function renderAvatarCircleT[\s\S]*?^}/m);
assert.ok(teacherRenderMatch, 'renderAvatarCircleT must be found');
assert.ok(teacherRenderMatch[0].includes('skinColor'), 'renderAvatarCircleT must handle skinColor');
assert.ok(teacherRenderMatch[0].includes('_tMaskStyle'), 'renderAvatarCircleT must call _tMaskStyle');

console.log('avatar_color_changes: all assertions passed ✓');
