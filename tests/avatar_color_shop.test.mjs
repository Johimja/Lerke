/**
 * Avatar-9: paid color changes
 * Guards that the color shop, RPC reference, CSS mask approach, and
 * normalizeAvatarData all handle bodyColor correctly.
 */
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const indexHtml = readFileSync(resolve(__dirname, '../index.html'), 'utf8');
const teacherHtml = readFileSync(resolve(__dirname, '../apps/bingo/teacher.html'), 'utf8');
const sqlPatch = readFileSync(
  resolve(__dirname, '../supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql'),
  'utf8'
);
const freshInstall = readFileSync(
  resolve(__dirname, '../supabase/sql/supabase_bingo_fresh_install_v18.sql'),
  'utf8'
);

let passed = 0;
let failed = 0;
function assert(condition, msg) {
  if (condition) {
    console.log(`  ✅ ${msg}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${msg}`);
    failed++;
  }
}

console.log('\n=== Avatar-9: Paid Color Changes ===\n');

// --- SQL patch ---
console.log('SQL patch:');
assert(sqlPatch.includes('purchase_avatar_color'), 'patch defines purchase_avatar_color');
assert(sqlPatch.includes("p_color_slot not in ('body')"), 'patch validates slot');
assert(sqlPatch.includes("p_color !~ '^#[0-9a-fA-F]"), 'patch validates hex format');
assert(sqlPatch.includes("v_cost        integer := 25"), 'cost is 25 XP');
assert(sqlPatch.includes("'bodyColor'"), 'stores bodyColor in avatar_data JSONB');

// --- Fresh install ---
console.log('\nFresh install SQL:');
assert(freshInstall.includes('purchase_avatar_color'), 'fresh install includes purchase_avatar_color');

// --- CSS: mask-based rendering ---
console.log('\nindex.html CSS:');
assert(indexHtml.includes('mask-image:url(\'media/avatar_faceshapes.png\')'), '.avatar-layer uses mask-image');
assert(!indexHtml.includes('background-image:url(\'media/avatar_faceshapes.png\')'), '.avatar-layer no longer uses background-image');
assert(indexHtml.includes('mask-repeat:no-repeat'), '.avatar-layer sets mask-repeat');

// --- JS: pendingAvatar default ---
console.log('\nindex.html JS defaults:');
assert(indexHtml.includes("head:'head_basic',acc:'acc_none',bodyColor:'#ffffff'"), 'pendingAvatar includes bodyColor default');
assert(indexHtml.includes('_previewBodyColor=null'), '_previewBodyColor variable declared');

// --- JS: normalizeAvatarData ---
console.log('\nindex.html normalizeAvatarData:');
assert(indexHtml.includes('bodyColor'), 'normalizeAvatarData returns bodyColor');
assert(indexHtml.includes('/^#[0-9a-fA-F]{6}$/.test(rawColor)'), 'normalizeAvatarData validates hex format');

// --- JS: _headMaskStyle function ---
console.log('\nindex.html _headMaskStyle:');
assert(indexHtml.includes('function _headMaskStyle('), '_headMaskStyle function exists');
assert(indexHtml.includes('mask-size:'), '_headMaskStyle generates mask-size');
assert(indexHtml.includes('mask-position:'), '_headMaskStyle generates mask-position');

// --- JS: renderAvatarCircle uses mask style ---
console.log('\nindex.html renderAvatarCircle:');
assert(indexHtml.includes('_headMaskStyle(h.col,h.row,size,normalized.bodyColor)'), 'renderAvatarCircle passes bodyColor to mask style');

// --- JS: renderSingleSprite accepts color param ---
assert(indexHtml.includes('function renderSingleSprite(col,row,size,color)'), 'renderSingleSprite accepts color param');

// --- JS: shop tabs ---
console.log('\nindex.html shop UI:');
assert(indexHtml.includes("setShopTab('color')"), 'Farge tab added to shop');
assert(indexHtml.includes('renderColorTab()'), 'renderColorTab called');
assert(indexHtml.includes('COLOR_PRESETS'), 'color preset swatches defined');
assert(indexHtml.includes('color-swatch'), 'color-swatch class exists');

// --- JS: color purchase flow ---
console.log('\nindex.html color purchase flow:');
assert(indexHtml.includes('function buyAvatarColor()'), 'buyAvatarColor function exists');
assert(indexHtml.includes("'purchase_avatar_color'"), 'calls purchase_avatar_color RPC');
assert(indexHtml.includes('function previewBodyColor('), 'previewBodyColor preview function exists');

// --- teacher.html ---
console.log('\nteacher.html:');
assert(teacherHtml.includes('mask-image:url(\'../../media/avatar_faceshapes.png\')'), '.t-avatar-layer uses mask-image');
assert(!teacherHtml.includes("background-image:url('../../media/avatar_faceshapes.png')"), '.t-avatar-layer no longer uses background-image');
assert(teacherHtml.includes('function _tHeadMaskStyle('), '_tHeadMaskStyle function exists');
assert(teacherHtml.includes('_tHeadMaskStyle(h.col,h.row,size,bodyColor)'), 'renderAvatarCircleT uses mask style with bodyColor');
assert(teacherHtml.includes("'bodyColor'") || teacherHtml.includes('"bodyColor"') || teacherHtml.includes('bodyColor'), 'teacher reads bodyColor from avatarData');

console.log(`\n${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
