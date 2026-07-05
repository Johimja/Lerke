// Tests for Avatar-9: paid color changes
// Guards: normalizeAvatarData includes skinColor, renderAvatarCircle uses mask-based
// coloring, SKIN_COLOR_SWATCHES exists, color tab is rendered, SQL patch structure.

import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dir = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(resolve(__dir, '../index.html'), 'utf8');
const sqlPatch = readFileSync(
  resolve(__dir, '../supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql'),
  'utf8'
);
const freshInstall = readFileSync(
  resolve(__dir, '../supabase/sql/supabase_bingo_fresh_install_v18.sql'),
  'utf8'
);

let passed = 0;
let failed = 0;

function assert(cond, msg) {
  if (cond) {
    console.log(`  ✓ ${msg}`);
    passed++;
  } else {
    console.error(`  ✗ ${msg}`);
    failed++;
  }
}

// ── normalizeAvatarData ──────────────────────────────────────────────────────
console.log('\nnormalizeAvatarData:');
assert(html.includes("const skinColor=(avatarData&&avatarData.skinColor&&/^#[0-9a-fA-F]{6}$/.test(avatarData.skinColor))?avatarData.skinColor:'#f5c9a0'"),
  'normalizeAvatarData returns skinColor with hex validation and #f5c9a0 fallback');
assert(html.includes("return {head,acc,skinColor}"),
  'normalizeAvatarData return object includes skinColor');

// ── pendingAvatar default ────────────────────────────────────────────────────
console.log('\npendingAvatar default:');
assert(html.includes("let pendingAvatar={head:'head_basic',acc:'acc_none',skinColor:'#f5c9a0'}"),
  'pendingAvatar default includes skinColor:#f5c9a0');

// ── SKIN_COLOR_SWATCHES ──────────────────────────────────────────────────────
console.log('\nSKIN_COLOR_SWATCHES:');
assert(html.includes("const SKIN_COLOR_SWATCHES="), 'SKIN_COLOR_SWATCHES array defined');
assert(html.match(/SKIN_COLOR_SWATCHES=\[([^\]]+)\]/)?.[1].split(',').length === 8,
  'SKIN_COLOR_SWATCHES has 8 swatches');

// ── CSS: colored layer and color UI ─────────────────────────────────────────
console.log('\nCSS classes:');
assert(html.includes('.avatar-colored-layer{'),
  '.avatar-colored-layer CSS class defined');
assert(html.includes('mask-image:url(\'media/avatar_faceshapes.png\')'),
  '.avatar-colored-layer uses mask-image on avatar_faceshapes.png');
assert(html.includes('.avatar-color-swatches{'), '.avatar-color-swatches CSS defined');
assert(html.includes('.avatar-color-swatch{'), '.avatar-color-swatch CSS defined');
assert(html.includes('.avatar-color-swatch.selected{'), '.avatar-color-swatch.selected CSS defined');
assert(html.includes('.avatar-color-buy-btn{'), '.avatar-color-buy-btn CSS defined');

// ── _coloredLayerStyle function ──────────────────────────────────────────────
console.log('\n_coloredLayerStyle:');
assert(html.includes('function _coloredLayerStyle(col,row,size,color)'),
  '_coloredLayerStyle function exists');
assert(html.includes('background-color:${color}'),
  '_coloredLayerStyle sets background-color to the color argument');
assert(html.includes('mask-size:${sz}') && html.includes('-webkit-mask-size:${sz}'),
  '_coloredLayerStyle sets mask-size (with webkit prefix)');
assert(html.includes('mask-position:${pos}') && html.includes('-webkit-mask-position:${pos}'),
  '_coloredLayerStyle sets mask-position (with webkit prefix)');

// ── renderAvatarCircle uses colored layer ────────────────────────────────────
console.log('\nrenderAvatarCircle:');
assert(html.includes('avatar-colored-layer') && html.includes('_coloredLayerStyle(h.col,h.row,size,normalized.skinColor)'),
  'renderAvatarCircle uses .avatar-colored-layer with _coloredLayerStyle and skinColor');
assert(!html.match(/layers=`<span class="avatar-layer"/),
  'renderAvatarCircle no longer uses plain .avatar-layer for the face shape (uses colored layer instead)');

// ── renderAvatarShop: color tab ──────────────────────────────────────────────
console.log('\nrenderAvatarShop color tab:');
assert(html.includes("setShopTab('color')") && html.includes(">Farge<"),
  'renderAvatarShop has a Farge tab');
assert(html.includes("currentShopTab==='color'"),
  'renderAvatarShop checks for color tab active state');
assert(html.includes('_buildColorTabHtml(xp)'),
  'renderAvatarShop calls _buildColorTabHtml when color tab active');

// ── _buildColorTabHtml ───────────────────────────────────────────────────────
console.log('\n_buildColorTabHtml:');
assert(html.includes('function _buildColorTabHtml(xp)'), '_buildColorTabHtml function exists');
assert(html.includes('const COLOR_COST=25'), 'COLOR_COST is 25 XP');
assert(html.includes("id=\"skin-color-picker\""), 'color picker input element exists');
assert(html.includes("id=\"skin-color-buy-btn\""), 'buy button element exists');
assert(html.includes('confirmSkinColor()'), 'buy button calls confirmSkinColor');
assert(html.includes('previewSkinColor('), 'swatches call previewSkinColor');

// ── previewSkinColor ──────────────────────────────────────────────────────────
console.log('\npreviewSkinColor:');
assert(html.includes('function previewSkinColor(color)'), 'previewSkinColor function exists');
assert(html.includes('/^#[0-9a-fA-F]{6}$/') && html.includes('previewSkinColor'),
  'previewSkinColor validates hex format');
assert(html.includes('pendingAvatar={...pendingAvatar,skinColor:color}'),
  'previewSkinColor updates pendingAvatar.skinColor');
assert(html.includes('updateAvatarDisplay()'), 'previewSkinColor calls updateAvatarDisplay for live preview');

// ── purchaseAvatarColor ───────────────────────────────────────────────────────
console.log('\npurchaseAvatarColor:');
assert(html.includes('async function purchaseAvatarColor(slot,color)'),
  'purchaseAvatarColor async function exists');
assert(html.includes("supabaseClient.rpc('purchase_avatar_color',{p_color_slot:slot,p_color:color})"),
  'purchaseAvatarColor calls purchase_avatar_color RPC');
assert(html.includes('data.no_change'),
  'purchaseAvatarColor handles no_change (same color re-save, no XP charged)');
assert(html.includes("insufficient_xp") || html.includes('data.error'),
  'purchaseAvatarColor surfaces server error messages');
assert(html.includes("updateXPBar()") && html.includes("updateAvatarDisplay()"),
  'purchaseAvatarColor refreshes XP bar and avatar display on success');

// ── SQL patch ────────────────────────────────────────────────────────────────
console.log('\nSQL patch (v21):');
assert(sqlPatch.includes('purchase_avatar_color'),
  'v21 patch defines purchase_avatar_color function');
assert(sqlPatch.includes("v_cost         int := 25"),
  'cost is 25 XP in the SQL');
assert(sqlPatch.includes("v_allowed_slots text[] := array['skinColor']"),
  "only 'skinColor' slot is allowed in v21");
assert(sqlPatch.includes("'^#[0-9a-fA-F]{6}$'"),
  'SQL validates hex color format');
assert(sqlPatch.includes('no_change'),
  'SQL returns no_change when same color is already set (no XP charged)');
assert(sqlPatch.includes('insufficient_xp'),
  'SQL returns insufficient_xp error when XP < 25');
assert(sqlPatch.includes("grant execute on function public.purchase_avatar_color"),
  'SQL grants execute to authenticated and anon');

// ── fresh install SQL includes v21 ───────────────────────────────────────────
console.log('\nFresh install SQL:');
assert(freshInstall.includes('purchase_avatar_color'),
  'fresh install SQL includes purchase_avatar_color function');
assert(freshInstall.includes('v21_avatar_color'),
  'fresh install SQL includes v21 section marker');

// ── Summary ──────────────────────────────────────────────────────────────────
console.log(`\n${passed + failed} checks: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
