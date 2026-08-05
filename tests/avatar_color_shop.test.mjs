import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// 1. SQL patch defines purchase_avatar_color
assert.ok(patchSql.includes('purchase_avatar_color'), 'patch SQL must define purchase_avatar_color');
assert.ok(patchSql.includes("p_color_slot not in ('head')"), 'patch SQL must validate slot');
assert.ok(patchSql.includes("'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$'"), 'patch SQL must validate hex color');
assert.ok(patchSql.includes('v_cost         integer := 25'), 'color cost must be 25 XP');
assert.ok(patchSql.includes("grant execute on function public.purchase_avatar_color"), 'must grant execute');

// 2. Fresh install includes purchase_avatar_color
assert.ok(freshInstallSql.includes('purchase_avatar_color'), 'fresh install must include purchase_avatar_color');

// 3. index.html: pendingAvatar includes headColor
assert.ok(indexHtml.includes("headColor:null"), 'pendingAvatar must default headColor to null');

// 4. index.html: normalizeAvatarData returns headColor
assert.ok(indexHtml.includes("headColor=(avatarData&&avatarData.headColor)||null"), 'normalizeAvatarData must extract headColor');

// 5. index.html: color tab present in shop
assert.ok(indexHtml.includes("setShopTab('color')"), 'shop must have a color tab');
assert.ok(indexHtml.includes('COLOR_PRESETS'), 'index.html must define COLOR_PRESETS');

// 6. index.html: purchaseAvatarColor function exists
assert.ok(indexHtml.includes('async function purchaseAvatarColor'), 'purchaseAvatarColor must be defined');
assert.ok(indexHtml.includes("purchase_avatar_color"), "purchaseAvatarColor must call supabase RPC 'purchase_avatar_color'");

// 7. index.html: resetAvatarColor exists (free)
assert.ok(indexHtml.includes('async function resetAvatarColor'), 'resetAvatarColor must be defined');

// 8. index.html: CSS mask tinting via avatar-color-fill
assert.ok(indexHtml.includes('avatar-color-fill'), 'index.html must have .avatar-color-fill CSS class');
assert.ok(indexHtml.includes('_colorMaskStyle'), '_colorMaskStyle helper must be present');
assert.ok(indexHtml.includes('mask-image'), 'mask-image must be used for color tinting');

// 9. teacher.html: t-avatar-color-fill CSS + _tColorMaskStyle
assert.ok(teacherHtml.includes('t-avatar-color-fill'), 'teacher.html must have .t-avatar-color-fill');
assert.ok(teacherHtml.includes('_tColorMaskStyle'), 'teacher.html must have _tColorMaskStyle helper');
assert.ok(teacherHtml.includes('avatarData.headColor'), 'teacher.html renderAvatarCircleT must read headColor');

// 10. pendingColorPreview is reset on sign-out
const signOutBlock = indexHtml.slice(indexHtml.indexOf('async function portalSignOut'));
assert.ok(signOutBlock.includes('pendingColorPreview=null'), 'portalSignOut must reset pendingColorPreview');

console.log('avatar_color_shop.test.mjs: all assertions passed ✓');
