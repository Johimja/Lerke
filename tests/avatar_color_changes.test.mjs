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

// SQL patch correctness
assert.match(patchSql, /create or replace function public\.purchase_avatar_color/, 'patch must define purchase_avatar_color');
assert.match(patchSql, /p_color_slot text/, 'patch must have p_color_slot param');
assert.match(patchSql, /p_color\s+text/, 'patch must have p_color param');
assert.match(patchSql, /skinColor/, 'patch must validate skinColor slot');
assert.match(patchSql, /\^\#\[0-9a-fA-F\]\{6\}\$/, 'patch must validate #rrggbb hex format');
assert.match(patchSql, /v_cost\s+integer := 25/, 'patch XP cost must be 25');
assert.match(patchSql, /grant execute on function public\.purchase_avatar_color/, 'patch must grant execute');

// fresh install includes v21
assert.match(freshInstallSql, /purchase_avatar_color/, 'fresh install must include purchase_avatar_color');
assert.match(freshInstallSql, /v_cost\s+integer := 25/, 'fresh install cost must be 25');

// index.html constants
assert.match(indexHtml, /const COLOR_CHANGE_COST\s*=\s*25/, 'index.html must define COLOR_CHANGE_COST=25');
assert.match(indexHtml, /const SKIN_PALETTE\s*=\s*\[/, 'index.html must define SKIN_PALETTE');

// normalizeAvatarData returns skinColor
assert.match(indexHtml, /const skinColor=\(typeof rawColor==='string'/, 'normalizeAvatarData must extract skinColor');

// pendingAvatar includes skinColor
assert.match(indexHtml, /let pendingAvatar=\{head:'head_basic',acc:'acc_none',skinColor:null\}/, 'pendingAvatar must include skinColor:null');

// purchaseAvatarColor function
assert.match(indexHtml, /async function purchaseAvatarColor/, 'index.html must define purchaseAvatarColor');
assert.match(indexHtml, /rpc\('purchase_avatar_color'/, 'index.html must call purchase_avatar_color RPC');

// Free reset path in purchaseAvatarColor (colorHex===null branch)
const purchaseFnMatch = indexHtml.match(/async function purchaseAvatarColor\(colorHex\)\{[\s\S]*?^async function /m);
assert.ok(purchaseFnMatch, 'purchaseAvatarColor function must be present');
assert.match(purchaseFnMatch[0], /colorHex===null/, 'purchaseAvatarColor must handle null (free reset)');

// CSS mask tinting in renderAvatarCircle
assert.match(indexHtml, /mask-image:url\('media\/avatar_faceshapes\.png'\)/, 'renderAvatarCircle must apply CSS mask for skin color');
assert.match(indexHtml, /avatar-color-layer/, 'index.html must have avatar-color-layer CSS class');

// Color tab present in shop
assert.match(indexHtml, /setShopTab\('color'\)/, 'index.html must have color tab in shop');
assert.match(indexHtml, /function renderColorShopHtml/, 'index.html must define renderColorShopHtml');
assert.match(indexHtml, /function selectColorSwatch/, 'index.html must define selectColorSwatch');
assert.match(indexHtml, /function colorPickerChange/, 'index.html must define colorPickerChange');

// pendingColorHex synced from profile on login
assert.match(indexHtml, /pendingColorHex=pendingAvatar\.skinColor/, 'renderStudentPortalState must sync pendingColorHex');

// teacher.html color tinting
assert.match(teacherHtml, /t-avatar-color-layer/, 'teacher.html must have t-avatar-color-layer CSS class');
assert.match(teacherHtml, /mask-image:url\('\.\.\/\.\.\/media\/avatar_faceshapes\.png'\)/, 'teacher.html renderAvatarCircleT must apply CSS mask');
assert.match(teacherHtml, /typeof rawColor==='string'/, 'teacher.html must validate skinColor before tinting');

console.log('All avatar color change tests passed! ✓');
