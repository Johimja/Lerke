import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dir = dirname(fileURLToPath(import.meta.url));
const indexHtml  = readFileSync(resolve(__dir, '../index.html'), 'utf8');
const teacherHtml = readFileSync(resolve(__dir, '../apps/bingo/teacher.html'), 'utf8');
const patchSql   = readFileSync(resolve(__dir, '../supabase/sql/archive/Patches/supabase_bingo_v21_avatar_colors_patch.sql'), 'utf8');
const freshSql   = readFileSync(resolve(__dir, '../supabase/sql/supabase_bingo_fresh_install_v18.sql'), 'utf8');

let passed = 0;
let failed = 0;

function assert(cond, label) {
  if (cond) { console.log(`  ✓ ${label}`); passed++; }
  else       { console.error(`  ✗ ${label}`); failed++; }
}

// -------------------------------------------------------
// SQL patch guards
// -------------------------------------------------------
console.log('\nSQL patch (v21):');

assert(patchSql.includes("purchase_avatar_color"), 'function purchase_avatar_color exists');
assert(patchSql.includes("v_color_change_cost constant integer := 25"), 'cost is 25 XP');
assert(patchSql.includes("p_color_slot not in ('skinColor')"), 'only skinColor slot is valid');
assert(patchSql.includes("^#[0-9a-fA-F]{6}$"), 'hex color regex validates format');
assert(patchSql.includes("coalesce(v_current_avatar, '{}'::jsonb) ||"), 'merges into existing avatar_data (not overwrites)');
assert(patchSql.includes("grant execute on function public.purchase_avatar_color"), 'grant to authenticated, anon');

// Cost must match frontend constant (25 XP)
const sqlCostMatch = patchSql.match(/v_color_change_cost constant integer := (\d+)/);
const sqlCost = sqlCostMatch ? parseInt(sqlCostMatch[1]) : -1;
assert(sqlCost === 25, `SQL cost = 25 (found ${sqlCost})`);

// -------------------------------------------------------
// Fresh install guards
// -------------------------------------------------------
console.log('\nFresh install SQL includes v21:');

assert(freshSql.includes('purchase_avatar_color'), 'purchase_avatar_color in fresh install');
assert(freshSql.includes('v21_avatar_colors_patch'), 'v21 patch marker in fresh install');

// -------------------------------------------------------
// index.html — normalizeAvatarData includes skinColor
// -------------------------------------------------------
console.log('\nindex.html — normalizeAvatarData:');

assert(indexHtml.includes("const skinColor=(avatarData&&avatarData.skinColor"), 'normalizeAvatarData reads skinColor');
assert(indexHtml.includes("return {head,acc,skinColor}"), 'normalizeAvatarData returns skinColor');
assert(indexHtml.includes("'#c8a882'"), 'default skinColor is #c8a882');

// -------------------------------------------------------
// index.html — pendingAvatar default
// -------------------------------------------------------
console.log('\nindex.html — pendingAvatar default:');

assert(/pendingAvatar=\{head:'head_basic',acc:'acc_none',skinColor:'#c8a882'\}/.test(indexHtml),
  'pendingAvatar default includes skinColor');

// -------------------------------------------------------
// index.html — CSS for skin layer
// -------------------------------------------------------
console.log('\nindex.html — CSS:');

assert(indexHtml.includes('.avatar-skin-layer{'), '.avatar-skin-layer CSS exists');
assert(indexHtml.includes('mask-image:url(\'media/avatar_faceshapes.png\')') ||
       indexHtml.includes('mask-image:url("media/avatar_faceshapes.png")'),
  '.avatar-skin-layer uses faceshapes.png as mask');
assert(indexHtml.includes('.avatar-color-swatches{'), '.avatar-color-swatches CSS exists');
assert(indexHtml.includes('.avatar-color-swatch{'), '.avatar-color-swatch CSS exists');
assert(indexHtml.includes('.avatar-color-save-btn{'), '.avatar-color-save-btn CSS exists');

// -------------------------------------------------------
// index.html — renderAvatarCircle uses skin layer
// -------------------------------------------------------
console.log('\nindex.html — renderAvatarCircle:');

assert(indexHtml.includes('_spriteMaskStyle(h.col,h.row,size)'), 'renderAvatarCircle uses _spriteMaskStyle');
assert(indexHtml.includes('avatar-skin-layer'), 'renderAvatarCircle outputs avatar-skin-layer span');
assert(!indexHtml.includes('"avatar-layer" style="${_spriteStyle(h.col'), 'renderAvatarCircle no longer uses plain avatar-layer for head');

// -------------------------------------------------------
// index.html — Farge tab
// -------------------------------------------------------
console.log('\nindex.html — Farge tab in shop:');

assert(indexHtml.includes("setShopTab('color')"), 'Farge tab triggers setShopTab color');
assert(indexHtml.includes("currentShopTab==='color'"), 'renderAvatarShop handles color tab');
assert(indexHtml.includes('avatar-color-preview'), 'color preview div is rendered');
assert(indexHtml.includes('avatar-color-save-btn'), 'save button is rendered');
assert(indexHtml.includes('type="color"'), 'native color picker input present');
assert(indexHtml.includes('previewSkinColor'), 'previewSkinColor function referenced');
assert(indexHtml.includes('purchaseAvatarColor'), 'purchaseAvatarColor function referenced');

// Confirm frontend cost literal matches SQL
const feCostMatch = indexHtml.match(/COLOR_XP_COST=(\d+)/);
const feCost = feCostMatch ? parseInt(feCostMatch[1]) : -1;
assert(feCost === sqlCost, `Frontend COLOR_XP_COST (${feCost}) matches SQL cost (${sqlCost})`);

// -------------------------------------------------------
// index.html — previewSkinColor targeted update (no full re-render)
// -------------------------------------------------------
console.log('\nindex.html — previewSkinColor function:');

assert(indexHtml.includes('function previewSkinColor(hex)'), 'previewSkinColor function exists');
assert(indexHtml.includes("getElementById('avatar-color-preview')"), 'targets preview element');
assert(indexHtml.includes("getElementById('avatar-color-save-btn')"), 'targets save button');
assert(indexHtml.includes("querySelectorAll('.avatar-color-swatch')"), 'updates swatch selection');

// -------------------------------------------------------
// index.html — purchaseAvatarColor function
// -------------------------------------------------------
console.log('\nindex.html — purchaseAvatarColor function:');

assert(indexHtml.includes('async function purchaseAvatarColor(colorHex)'), 'purchaseAvatarColor is async');
assert(indexHtml.includes("'purchase_avatar_color'"), 'calls purchase_avatar_color RPC');
assert(indexHtml.includes("p_color_slot:'skinColor'"), 'passes skinColor slot');
assert(indexHtml.includes('insufficient_xp'), 'handles insufficient_xp error');

// -------------------------------------------------------
// teacher.html — skin layer
// -------------------------------------------------------
console.log('\nteacher.html — skin layer:');

assert(teacherHtml.includes('.t-avatar-skin-layer{'), '.t-avatar-skin-layer CSS exists');
assert(teacherHtml.includes('mask-image:url(\'../../media/avatar_faceshapes.png\')') ||
       teacherHtml.includes('mask-image:url("../../media/avatar_faceshapes.png")'),
  '.t-avatar-skin-layer uses correct path for faceshapes.png');
assert(teacherHtml.includes('function _tSpriteMaskStyle('), '_tSpriteMaskStyle function exists');
assert(teacherHtml.includes('t-avatar-skin-layer'), 'renderAvatarCircleT uses t-avatar-skin-layer');
assert(teacherHtml.includes('avatarData.skinColor'), 'renderAvatarCircleT reads skinColor');

// -------------------------------------------------------
// Summary
// -------------------------------------------------------
console.log(`\n${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
