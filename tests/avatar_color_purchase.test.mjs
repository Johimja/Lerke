// tests/avatar_color_purchase.test.mjs
// Guards for Avatar-9: paid color changes.
// Verifies: normalizeAvatarData handles baseColor, color tab is present,
// purchaseAvatarColor is wired, and the SQL patch file is consistent.

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

let failures = 0;
function assert(cond, msg) {
  if (!cond) { console.error('FAIL:', msg); failures++; }
  else { console.log('ok:', msg); }
}

// ── Read source files ────────────────────────────────────────────────────────
const indexHtml = readFileSync(join(root, 'index.html'), 'utf8');
const teacherHtml = readFileSync(join(root, 'apps/bingo/teacher.html'), 'utf8');
const patchSql = readFileSync(
  join(root, 'supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql'), 'utf8');
const freshInstall = readFileSync(
  join(root, 'supabase/sql/supabase_bingo_fresh_install_v18.sql'), 'utf8');

// ── SQL patch checks ─────────────────────────────────────────────────────────
assert(patchSql.includes('purchase_avatar_color'), 'patch: defines purchase_avatar_color');
assert(patchSql.includes("array['baseColor']"), "patch: allows slot 'baseColor'");
assert(patchSql.includes("v_cost         int  := 25"), 'patch: XP cost is 25');
assert(patchSql.includes("'^#[0-9a-fA-F]{6}$'"), 'patch: hex color validation');
assert(patchSql.includes("'Ikke nok XP'"), "patch: insufficient XP error");
assert(patchSql.includes('grant execute on function public.purchase_avatar_color'),
  'patch: grants execute to authenticated');

// Fresh install includes the v21 function
assert(freshInstall.includes('purchase_avatar_color'),
  'fresh_install: includes purchase_avatar_color');

// ── index.html checks ────────────────────────────────────────────────────────
// Default color constant
assert(indexHtml.includes("AVATAR_DEFAULT_COLOR='#c8b4e8'") ||
       indexHtml.includes('AVATAR_DEFAULT_COLOR="#c8b4e8"'),
  'index: AVATAR_DEFAULT_COLOR defined');

// pendingAvatar includes baseColor
assert(indexHtml.includes("baseColor:AVATAR_DEFAULT_COLOR") ||
       indexHtml.includes("baseColor: AVATAR_DEFAULT_COLOR"),
  'index: pendingAvatar default includes baseColor');

// normalizeAvatarData returns baseColor
assert(indexHtml.includes('normalizeAvatarData') && indexHtml.includes('baseColor'),
  'index: normalizeAvatarData handles baseColor');

// CSS color layer present
assert(indexHtml.includes('avatar-color-layer'),
  'index: .avatar-color-layer CSS class defined');
assert(indexHtml.includes('mask-image:url(') || indexHtml.includes("mask-image:url('"),
  'index: CSS mask-image used for color layer');

// _colorLayerStyle helper
assert(indexHtml.includes('_colorLayerStyle'),
  'index: _colorLayerStyle helper defined');

// renderAvatarCircle uses color layer (not plain white avatar-layer)
const renderCircleMatch = indexHtml.match(/function renderAvatarCircle[\s\S]{0,800}avatar-color-layer/);
assert(renderCircleMatch !== null,
  'index: renderAvatarCircle uses avatar-color-layer');

// Farge tab in shop
assert(indexHtml.includes("setShopTab('color')") && indexHtml.includes('>Farge<'),
  'index: Farge tab present in avatar shop');

// onColorInputChange function
assert(indexHtml.includes('function onColorInputChange'),
  'index: onColorInputChange defined');

// purchaseAvatarColor function
assert(indexHtml.includes('async function purchaseAvatarColor'),
  'index: purchaseAvatarColor defined');
assert(indexHtml.includes("purchase_avatar_color"),
  'index: purchaseAvatarColor calls supabase RPC purchase_avatar_color');
assert(indexHtml.includes("p_color_slot:'baseColor'") ||
       indexHtml.includes("p_color_slot: 'baseColor'"),
  'index: purchaseAvatarColor sends p_color_slot baseColor');

// Color picker input
assert(indexHtml.includes('type="color"') && indexHtml.includes('avatar-color-input'),
  'index: color input present in shop');

// ── teacher.html checks ──────────────────────────────────────────────────────
assert(teacherHtml.includes('t-avatar-color-layer'),
  'teacher: .t-avatar-color-layer CSS class defined');
assert(teacherHtml.includes('_tColorLayerStyle'),
  'teacher: _tColorLayerStyle helper defined');

const renderCircleTMatch = teacherHtml.match(/function renderAvatarCircleT[\s\S]{0,500}t-avatar-color-layer/);
assert(renderCircleTMatch !== null,
  'teacher: renderAvatarCircleT uses t-avatar-color-layer');

// teacher reads baseColor with hex validation
assert(teacherHtml.includes('baseColor') && teacherHtml.includes('#c8b4e8'),
  'teacher: renderAvatarCircleT uses baseColor with fallback');

// ── Summary ──────────────────────────────────────────────────────────────────
if (failures === 0) {
  console.log('\nAll avatar_color_purchase tests passed ✅');
} else {
  console.error(`\n${failures} test(s) FAILED ❌`);
  process.exit(1);
}
