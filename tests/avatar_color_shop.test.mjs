// Tests for Avatar-9: paid color changes
// Guards: COLOR_SWATCHES in index.html, purchase_avatar_color SQL in patch and fresh install,
// normalizeAvatarData handling colors, Farger tab presence.

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dir = dirname(fileURLToPath(import.meta.url));
const root = join(__dir, '..');

const indexHtml = readFileSync(join(root, 'index.html'), 'utf8');
const freshSql = readFileSync(join(root, 'supabase/sql/supabase_bingo_fresh_install_v18.sql'), 'utf8');
const patchSql = readFileSync(join(root, 'supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql'), 'utf8');

let pass = 0, fail = 0;
function assert(cond, msg) {
  if (cond) { console.log('  ✓', msg); pass++; }
  else { console.error('  ✗', msg); fail++; }
}

console.log('\n=== Avatar Color Shop (Avatar-9) ===\n');

// --- COLOR_SWATCHES ---
console.log('COLOR_SWATCHES:');
assert(indexHtml.includes("const COLOR_SWATCHES=["), 'COLOR_SWATCHES constant defined');
assert(indexHtml.includes("{hex:'#ffffff',label:'Standard'}"), 'White (#ffffff) is first swatch');
assert((indexHtml.match(/\{hex:'#/g)||[]).length >= 12, 'At least 12 color swatches defined');
assert(indexHtml.includes('const COLOR_CHANGE_COST=25'), 'COLOR_CHANGE_COST=25 defined');

// --- normalizeAvatarData includes colors ---
console.log('\nnormalizeAvatarData:');
assert(indexHtml.includes("skinColor=/^#[0-9a-f]{6}$/i.test(") || indexHtml.includes("skinColor="), 'normalizeAvatarData handles skinColor');
assert(indexHtml.includes("accColor="), 'normalizeAvatarData handles accColor');

// --- pendingAvatar default includes colors ---
console.log('\npendingAvatar default:');
assert(indexHtml.includes("skinColor:'#ffffff'"), 'pendingAvatar includes skinColor default');
assert(indexHtml.includes("accColor:'#ffffff'"), 'pendingAvatar includes accColor default');

// --- Farger tab ---
console.log('\nFarger tab:');
assert(indexHtml.includes("setShopTab('color')"), 'setShopTab color call exists');
assert(indexHtml.includes(">Farger<"), 'Farger tab label present');
assert(indexHtml.includes('_colorShopContent'), '_colorShopContent function present');
assert(indexHtml.includes('pickAvatarColor'), 'pickAvatarColor function present');

// --- CSS colored layers ---
console.log('\nCSS mask layers:');
assert(indexHtml.includes('.avatar-color-layer{'), '.avatar-color-layer CSS defined');
assert(indexHtml.includes('.avatar-acc-color-layer{'), '.avatar-acc-color-layer CSS defined');
assert(indexHtml.includes('mask-image:url(\'media/avatar_faceshapes.png\')'), 'Face shape mask-image set');
assert(indexHtml.includes('mask-image:url(\'media/avatar_head_accessories.png\')'), 'Accessory mask-image set');
assert(indexHtml.includes('_coloredSpriteStyle'), '_coloredSpriteStyle function present');

// --- renderAvatarCircle uses colored layers when skinColor set ---
console.log('\nrenderAvatarCircle color support:');
assert(indexHtml.includes('avatar-color-layer'), 'avatar-color-layer used in renderAvatarCircle');
assert(indexHtml.includes('avatar-acc-color-layer'), 'avatar-acc-color-layer used in renderAvatarCircle');

// --- purchase_avatar_color in SQL patch ---
console.log('\nSQL patch (v21):');
assert(patchSql.includes('create or replace function public.purchase_avatar_color'), 'purchase_avatar_color defined in v21 patch');
assert(patchSql.includes("'skinColor','accColor'") || patchSql.includes("'skinColor'"), 'skinColor slot validated in patch');
assert(patchSql.includes("'^#[0-9a-fA-F]{6}$'"), 'Hex color regex validated in patch');
assert(patchSql.includes('v_cost integer := 25'), 'Color cost is 25 XP in patch');
assert(patchSql.includes("'#ffffff'"), 'White is free in patch');
assert(patchSql.includes('grant execute on function public.purchase_avatar_color'), 'Grant execute in patch');

// --- purchase_avatar_color in fresh install ---
console.log('\nFresh install SQL:');
assert(freshSql.includes('purchase_avatar_color'), 'purchase_avatar_color in fresh install');
assert(freshSql.includes('v21_avatar_color_patch'), 'v21 marker in fresh install');

// --- teacher.html colored layers ---
const teacherHtml = readFileSync(join(root, 'apps/bingo/teacher.html'), 'utf8');
console.log('\nteacher.html color support:');
assert(teacherHtml.includes('.t-avatar-color-layer{'), '.t-avatar-color-layer CSS in teacher.html');
assert(teacherHtml.includes('.t-avatar-acc-color-layer{'), '.t-avatar-acc-color-layer CSS in teacher.html');
assert(teacherHtml.includes('_tColoredStyle'), '_tColoredStyle function in teacher.html');
assert(teacherHtml.includes('t-avatar-color-layer'), 't-avatar-color-layer used in renderAvatarCircleT');

// --- pickAvatarColor calls purchase_avatar_color RPC ---
console.log('\npickAvatarColor RPC call:');
assert(indexHtml.includes("'purchase_avatar_color'"), 'pickAvatarColor calls purchase_avatar_color RPC');
assert(indexHtml.includes('p_color_slot:slot') || indexHtml.includes('p_color_slot'), 'p_color_slot param used');
assert(indexHtml.includes('p_color:color') || indexHtml.includes('p_color'), 'p_color param used');

console.log(`\n${pass} passed, ${fail} failed\n`);
if (fail > 0) process.exit(1);
