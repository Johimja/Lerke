// tests/avatar_color_shop.test.mjs
// Guards for Avatar-9: paid color changes
// - normalizeAvatarData returns correct color defaults and accepts valid hex colors
// - _coloredLayerStyle generates mask-based CSS for colored layers
// - Color slot validation (only 'skinColor' and 'accColor' are valid)
// - Fresh install SQL includes purchase_avatar_color function

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');

let pass = 0;
let fail = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  ✓ ${message}`);
    pass++;
  } else {
    console.error(`  ✗ ${message}`);
    fail++;
  }
}

// --- Read index.html ---
const indexHtml = fs.readFileSync(path.join(root, 'index.html'), 'utf8');

console.log('\n=== Avatar color shop: index.html checks ===');

assert(
  indexHtml.includes("normalizeAvatarData"),
  'normalizeAvatarData function exists'
);

assert(
  indexHtml.includes("skinColor:'#D4A574'") || indexHtml.includes("skinColor: '#D4A574'"),
  'pendingAvatar default includes skinColor #D4A574'
);

assert(
  indexHtml.includes("accColor:'#8B6BB5'") || indexHtml.includes("accColor: '#8B6BB5'"),
  'pendingAvatar default includes accColor #8B6BB5'
);

assert(
  indexHtml.includes("_HEX_RE=/^#[0-9a-fA-F]{6}$/"),
  '_HEX_RE hex validation regex defined'
);

assert(
  indexHtml.includes("_coloredLayerStyle"),
  '_coloredLayerStyle function defined'
);

assert(
  indexHtml.includes("mask-image:url"),
  '_coloredLayerStyle uses CSS mask-image for tinting'
);

assert(
  indexHtml.includes("purchase_avatar_color"),
  'purchase_avatar_color RPC call present'
);

assert(
  indexHtml.includes("saveAvatarColor"),
  'saveAvatarColor function defined'
);

assert(
  indexHtml.includes("previewAvatarColor"),
  'previewAvatarColor function defined'
);

assert(
  indexHtml.includes("setShopTab('color')"),
  'Farge tab registered in shop tabs'
);

assert(
  indexHtml.includes("'Farge'") || indexHtml.includes(">Farge<"),
  'Farge tab label present'
);

assert(
  indexHtml.includes("_renderColorTab"),
  '_renderColorTab helper function defined'
);

// Color slots rendered
assert(
  indexHtml.includes("Hudfarge"),
  'Hudfarge (skin color) slot label present'
);

assert(
  indexHtml.includes("Tilbehørsfarge"),
  'Tilbehørsfarge (accessory color) slot label present'
);

assert(
  indexHtml.includes("25 XP") && indexHtml.includes("Farge"),
  'Color change XP cost (25 XP) mentioned in shop'
);

// renderAvatarCircle uses colored layers (mask approach)
assert(
  indexHtml.includes("_coloredLayerStyle(h.col,h.row,size,'media/avatar_faceshapes.png',normalized.skinColor)"),
  'renderAvatarCircle applies skinColor to face layer via _coloredLayerStyle'
);

assert(
  indexHtml.includes("_coloredLayerStyle(a.col,a.row,size,'media/avatar_head_accessories.png',normalized.accColor)"),
  'renderAvatarCircle applies accColor to accessory layer via _coloredLayerStyle'
);

// normalizeAvatarData validates hex
const normalizeMatch = indexHtml.match(/function normalizeAvatarData\(avatarData\)\{[\s\S]*?return \{head,acc,skinColor,accColor\}/);
assert(
  normalizeMatch !== null,
  'normalizeAvatarData returns {head,acc,skinColor,accColor}'
);

// --- Read teacher.html ---
const teacherHtml = fs.readFileSync(path.join(root, 'apps/bingo/teacher.html'), 'utf8');

console.log('\n=== Avatar color shop: teacher.html checks ===');

assert(
  teacherHtml.includes("_tColoredLayerStyle"),
  '_tColoredLayerStyle helper defined in teacher.html'
);

assert(
  teacherHtml.includes("_T_HEX_RE"),
  '_T_HEX_RE hex validation regex defined in teacher.html'
);

assert(
  teacherHtml.includes("skinColor") && teacherHtml.includes("accColor"),
  'teacher.html renderAvatarCircleT reads skinColor and accColor from avatarData'
);

assert(
  teacherHtml.includes("'../../media/avatar_faceshapes.png',skinColor"),
  'teacher.html applies skinColor to face layer with correct sheet path'
);

assert(
  teacherHtml.includes("'../../media/avatar_head_accessories.png',accColor"),
  'teacher.html applies accColor to accessory layer with correct sheet path'
);

// --- Read SQL patch ---
const patchPath = path.join(root, 'supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');

console.log('\n=== Avatar color shop: SQL patch checks ===');

assert(
  fs.existsSync(patchPath),
  'v21 SQL patch file exists'
);

const patchSql = fs.readFileSync(patchPath, 'utf8');

assert(
  patchSql.includes("purchase_avatar_color"),
  'SQL patch defines purchase_avatar_color function'
);

assert(
  patchSql.includes("p_color_slot not in ('skinColor','accColor')"),
  'SQL patch validates color slot (only skinColor, accColor allowed)'
);

assert(
  patchSql.includes("p_color !~ '^#[0-9a-fA-F]{6}$'"),
  'SQL patch validates hex color format'
);

assert(
  patchSql.includes("v_cost        integer := 25"),
  'SQL patch sets color change cost to 25 XP'
);

assert(
  patchSql.includes("total_xp - v_cost"),
  'SQL patch deducts XP on color save'
);

assert(
  patchSql.includes("jsonb_build_object(p_color_slot, p_color)"),
  'SQL patch merges color into avatar_data JSONB'
);

assert(
  patchSql.includes("grant execute on function public.purchase_avatar_color(text,text) to authenticated"),
  'SQL patch grants execute to authenticated users'
);

// --- Fresh install SQL ---
const freshInstall = fs.readFileSync(
  path.join(root, 'supabase/sql/supabase_bingo_fresh_install_v18.sql'),
  'utf8'
);

console.log('\n=== Avatar color shop: fresh install SQL checks ===');

assert(
  freshInstall.includes("purchase_avatar_color"),
  'Fresh install SQL includes purchase_avatar_color function'
);

assert(
  freshInstall.includes("v21_avatar_color_patch"),
  'Fresh install SQL includes v21 patch section marker'
);

// --- Summary ---
console.log(`\n=== Results: ${pass} passed, ${fail} failed ===\n`);
if (fail > 0) process.exit(1);
