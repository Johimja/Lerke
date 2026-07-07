/**
 * Avatar-9: Paid color changes test suite
 *
 * Guards:
 * - COLOR_PALETTE is defined and contains exactly 12 entries including '#ffffff'
 * - COLOR_CHANGE_COST is 25
 * - Allowed slots are ['skinColor','accColor']
 * - pendingAvatar default includes skinColor and accColor
 * - normalizeAvatarData includes skinColor/accColor and defaults to '#ffffff'
 * - SQL patch defines purchase_avatar_color with correct cost and slot validation
 * - Fresh install SQL includes purchase_avatar_color
 * - CSS uses mask-image for avatar layers (not background-image)
 * - Teacher.html CSS also uses mask-image
 */

import fs from 'fs';
import path from 'path';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const indexHtml = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
const teacherHtml = fs.readFileSync(path.join(ROOT, 'apps/bingo/teacher.html'), 'utf8');
const patchSql = fs.readFileSync(
  path.join(ROOT, 'supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql'),
  'utf8'
);
const freshInstallSql = fs.readFileSync(
  path.join(ROOT, 'supabase/sql/supabase_bingo_fresh_install_v18.sql'),
  'utf8'
);

let pass = 0;
let fail = 0;

function assert(condition, label) {
  if (condition) {
    console.log(`  ✓ ${label}`);
    pass++;
  } else {
    console.error(`  ✗ ${label}`);
    fail++;
  }
}

// ── index.html checks ────────────────────────────────────────────────────────
console.log('\n[index.html — COLOR_PALETTE]');
assert(indexHtml.includes("const COLOR_PALETTE="), 'COLOR_PALETTE constant defined');
// Extract palette array
const paletteMatch = indexHtml.match(/const COLOR_PALETTE=\[([^\]]+)\]/);
assert(!!paletteMatch, 'COLOR_PALETTE array extractable');
if (paletteMatch) {
  const entries = paletteMatch[1].match(/'#[0-9a-fA-F]{6}'/g) || [];
  assert(entries.length === 12, `COLOR_PALETTE has 12 entries (got ${entries.length})`);
  assert(entries.includes("'#ffffff'"), "COLOR_PALETTE includes '#ffffff' (default/reset)");
}

console.log('\n[index.html — COLOR_CHANGE_COST]');
assert(indexHtml.includes('const COLOR_CHANGE_COST=25'), 'COLOR_CHANGE_COST is 25');

console.log('\n[index.html — pendingAvatar defaults]');
assert(
  indexHtml.includes("let pendingAvatar={head:'head_basic',acc:'acc_none',skinColor:'#ffffff',accColor:'#ffffff'}"),
  'pendingAvatar includes skinColor and accColor defaulting to #ffffff'
);

console.log('\n[index.html — normalizeAvatarData]');
assert(indexHtml.includes('skinColor'), 'normalizeAvatarData handles skinColor');
assert(indexHtml.includes('accColor'), 'normalizeAvatarData handles accColor');
assert(indexHtml.includes("const _HEX6=/^#[0-9a-fA-F]{6}$/"), '_HEX6 hex validator defined');

console.log('\n[index.html — shop tabs]');
assert(indexHtml.includes("setShopTab('color')"), 'Farge tab wired to setShopTab');
assert(indexHtml.includes("Farge"), 'Farge tab label present');
assert(indexHtml.includes('renderColorShopContent'), 'renderColorShopContent function referenced');

console.log('\n[index.html — purchaseAvatarColor]');
assert(indexHtml.includes("async function purchaseAvatarColor("), 'purchaseAvatarColor function defined');
assert(indexHtml.includes("'purchase_avatar_color'"), 'purchaseAvatarColor calls purchase_avatar_color RPC');
assert(indexHtml.includes('p_color_slot:slot'), 'purchaseAvatarColor passes p_color_slot');
assert(indexHtml.includes('p_color:color'), 'purchaseAvatarColor passes p_color');

console.log('\n[index.html — selectColorSwatch]');
assert(indexHtml.includes("function selectColorSwatch("), 'selectColorSwatch function defined');

console.log('\n[index.html — CSS mask (not background-image)]');
assert(
  indexHtml.includes("mask-image:url('media/avatar_faceshapes.png')"),
  '.avatar-layer uses mask-image for faceshapes'
);
assert(
  indexHtml.includes("mask-image:url('media/avatar_head_accessories.png')"),
  '.avatar-acc-layer uses mask-image for accessories'
);
assert(
  !indexHtml.match(/\.avatar-layer\{[^}]*background-image:url\('media\/avatar_faceshapes/),
  '.avatar-layer no longer uses background-image'
);

console.log('\n[index.html — renderAvatarCircle color pass-through]');
assert(
  indexHtml.includes('normalized.skinColor'),
  'renderAvatarCircle passes skinColor to head layer'
);
assert(
  indexHtml.includes('normalized.accColor'),
  'renderAvatarCircle passes accColor to accessory layer'
);

// ── teacher.html checks ──────────────────────────────────────────────────────
console.log('\n[teacher.html — CSS mask]');
assert(
  teacherHtml.includes("mask-image:url('../../media/avatar_faceshapes.png')"),
  '.t-avatar-layer uses mask-image'
);
assert(
  teacherHtml.includes("mask-image:url('../../media/avatar_head_accessories.png')"),
  '.t-avatar-acc-layer uses mask-image'
);
assert(
  !teacherHtml.match(/\.t-avatar-layer\{[^}]*background-image:/),
  '.t-avatar-layer no longer uses background-image'
);

console.log('\n[teacher.html — renderAvatarCircleT color pass-through]');
assert(teacherHtml.includes('skinColor'), 'renderAvatarCircleT reads skinColor from avatarData');
assert(teacherHtml.includes('accColor'), 'renderAvatarCircleT reads accColor from avatarData');
assert(teacherHtml.includes('_T_HEX6'), '_T_HEX6 hex validator defined in teacher.html');

// ── SQL patch checks ─────────────────────────────────────────────────────────
console.log('\n[SQL patch — purchase_avatar_color]');
assert(
  patchSql.includes('create or replace function public.purchase_avatar_color'),
  'purchase_avatar_color function defined'
);
assert(patchSql.includes("p_color_slot text"), 'takes p_color_slot param');
assert(patchSql.includes("p_color      text"), 'takes p_color param');
assert(patchSql.includes("v_cost        int     := 25"), 'cost is 25 XP');
assert(
  patchSql.includes("array['skinColor','accColor']"),
  "allowed slots are ['skinColor','accColor']"
);
assert(
  patchSql.includes("'^#[0-9a-fA-F]{6}$'"),
  'validates #rrggbb hex format'
);
assert(
  patchSql.includes("lower(p_color) = '#ffffff'"),
  'reset to white is free'
);
assert(
  patchSql.includes('total_xp - v_cost'),
  'XP deducted on non-white color change'
);
assert(
  patchSql.includes("grant execute on function public.purchase_avatar_color(text, text)"),
  'GRANT to authenticated/anon'
);

// ── fresh install SQL checks ─────────────────────────────────────────────────
console.log('\n[fresh install SQL — v21 included]');
assert(
  freshInstallSql.includes('create or replace function public.purchase_avatar_color'),
  'fresh install SQL includes purchase_avatar_color'
);
assert(
  freshInstallSql.includes('BEGIN FILE: supabase_bingo_v21_avatar_color_patch.sql'),
  'v21 section marked in fresh install'
);

// ── summary ──────────────────────────────────────────────────────────────────
console.log(`\n${'─'.repeat(50)}`);
console.log(`Results: ${pass} passed, ${fail} failed`);
if (fail > 0) process.exit(1);
