// Avatar-9: paid color changes — test suite
// Guards:
// 1. .avatar-layer in index.html uses mask-image (not background-image) for the face layer
// 2. .t-avatar-layer in teacher.html uses mask-image (not background-image)
// 3. normalizeAvatarData handles skinColor (via parsing index.html)
// 4. DEFAULT_SKIN_COLOR and SKIN_COLOR_PALETTE are defined
// 5. purchase_avatar_color RPC exists in SQL patch and fresh install
// 6. SKIN_COLOR_PALETTE includes DEFAULT_SKIN_COLOR

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');

let pass = 0;
let fail = 0;

function assert(cond, msg) {
  if (cond) {
    console.log(`  ✓ ${msg}`);
    pass++;
  } else {
    console.error(`  ✗ ${msg}`);
    fail++;
  }
}

const indexHtml = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const teacherHtml = fs.readFileSync(path.join(root, 'apps/bingo/teacher.html'), 'utf8');
const sqlPatch = fs.readFileSync(path.join(root, 'supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql'), 'utf8');
const freshInstall = fs.readFileSync(path.join(root, 'supabase/sql/supabase_bingo_fresh_install_v18.sql'), 'utf8');

console.log('\n=== Avatar-9: Color system — index.html CSS ===');

assert(
  indexHtml.includes('mask-image:url(\'media/avatar_faceshapes.png\')'),
  '.avatar-layer uses CSS mask-image for face layer'
);
assert(
  !(/\.avatar-layer\{[^}]*background-image:url\('media\/avatar_faceshapes\.png'\)/.test(indexHtml)),
  '.avatar-layer does NOT use background-image for face layer'
);
assert(
  indexHtml.includes('avatar-acc-layer') && indexHtml.includes('background-image:url(\'media/avatar_head_accessories.png\')'),
  '.avatar-acc-layer still uses background-image (accessory stays white)'
);
assert(
  indexHtml.includes('.color-swatch-grid'),
  'color swatch grid CSS exists'
);
assert(
  indexHtml.includes('.color-swatch'),
  'color swatch CSS exists'
);

console.log('\n=== Avatar-9: Color constants and palette ===');

assert(
  indexHtml.includes("const DEFAULT_SKIN_COLOR='#c8a87a'"),
  'DEFAULT_SKIN_COLOR defined'
);
assert(
  indexHtml.includes('const SKIN_COLOR_PALETTE='),
  'SKIN_COLOR_PALETTE defined'
);
assert(
  indexHtml.includes("'#c8a87a'") && indexHtml.indexOf('SKIN_COLOR_PALETTE') < indexHtml.indexOf("'#c8a87a'") + 200,
  'SKIN_COLOR_PALETTE includes DEFAULT_SKIN_COLOR (#c8a87a)'
);

console.log('\n=== Avatar-9: normalizeAvatarData includes skinColor ===');

assert(
  indexHtml.includes('skinColor') && indexHtml.includes('normalizeAvatarData'),
  'normalizeAvatarData exists'
);
assert(
  /normalizeAvatarData[\s\S]{0,300}skinColor/.test(indexHtml),
  'normalizeAvatarData handles skinColor field'
);
assert(
  /skinColor.*#\[0-9a-fA-F\]/.test(indexHtml),
  'skinColor validated with hex regex in normalizeAvatarData'
);

console.log('\n=== Avatar-9: pendingAvatar default includes skinColor ===');

assert(
  indexHtml.includes("pendingAvatar={head:'head_basic',acc:'acc_none',skinColor:null}"),
  'pendingAvatar default includes skinColor:null'
);

console.log('\n=== Avatar-9: _faceLayerStyle function ===');

assert(
  indexHtml.includes('function _faceLayerStyle('),
  '_faceLayerStyle function defined'
);
assert(
  indexHtml.includes('mask-size') && indexHtml.includes('mask-position'),
  '_faceLayerStyle generates mask-size and mask-position'
);
assert(
  indexHtml.includes('background-color:${c}') || indexHtml.includes('background-color:${'),
  '_faceLayerStyle sets background-color from color param'
);

console.log('\n=== Avatar-9: renderAvatarCircle uses _faceLayerStyle ===');

assert(
  indexHtml.includes('_faceLayerStyle(h.col,h.row,size,normalized.skinColor)'),
  'renderAvatarCircle uses _faceLayerStyle with skinColor'
);

console.log('\n=== Avatar-9: Color shop tab ===');

assert(
  indexHtml.includes("setShopTab('color')") && indexHtml.includes('Farge'),
  'Farge tab added to shop'
);
assert(
  indexHtml.includes('function renderColorTab('),
  'renderColorTab function exists'
);
assert(
  indexHtml.includes('function swatchClick('),
  'swatchClick function exists'
);
assert(
  indexHtml.includes('function applyCustomColor('),
  'applyCustomColor function exists'
);
assert(
  indexHtml.includes('function purchaseAvatarColor('),
  'purchaseAvatarColor function exists'
);
assert(
  indexHtml.includes("'purchase_avatar_color'"),
  'purchaseAvatarColor calls purchase_avatar_color RPC'
);

console.log('\n=== Avatar-9: renderSingleSprite passes skin color ===');

assert(
  indexHtml.includes('renderSingleSprite(item.col,item.row,52,skinColor)'),
  'renderSingleSprite called with skinColor in shop grid'
);

console.log('\n=== Avatar-9: teacher.html CSS ===');

assert(
  teacherHtml.includes("mask-image:url('../../media/avatar_faceshapes.png')"),
  '.t-avatar-layer uses CSS mask-image'
);
assert(
  !(/\.t-avatar-layer\{[^}]*background-image:url\('\.\.\/\.\.\/media\/avatar_faceshapes\.png'\)/.test(teacherHtml)),
  '.t-avatar-layer does NOT use background-image for face layer'
);

console.log('\n=== Avatar-9: teacher.html renderAvatarCircleT uses skinColor ===');

assert(
  teacherHtml.includes('function _tFaceLayerStyle('),
  '_tFaceLayerStyle defined in teacher.html'
);
assert(
  teacherHtml.includes('DEFAULT_SKIN_COLOR_T'),
  'DEFAULT_SKIN_COLOR_T defined in teacher.html'
);
assert(
  teacherHtml.includes('_tFaceLayerStyle(h.col,h.row,size,skinColor)'),
  'renderAvatarCircleT uses _tFaceLayerStyle with skinColor'
);

console.log('\n=== Avatar-9: SQL patch v21 ===');

assert(
  sqlPatch.includes('purchase_avatar_color'),
  'SQL patch defines purchase_avatar_color'
);
assert(
  sqlPatch.includes("p_color_slot not in ('skinColor')"),
  'SQL patch validates slot = skinColor'
);
assert(
  sqlPatch.includes("p_color !~ '^#[0-9a-fA-F]{6}$'"),
  'SQL patch validates hex color format'
);
assert(
  sqlPatch.includes('v_cost        int := 25'),
  'SQL patch costs 25 XP'
);
assert(
  sqlPatch.includes("v_avatar_data := v_avatar_data || jsonb_build_object(p_color_slot, p_color)"),
  'SQL patch merges color into avatar_data'
);
assert(
  sqlPatch.includes('grant execute on function public.purchase_avatar_color(text, text)'),
  'SQL patch grants execute to authenticated/anon'
);

console.log('\n=== Avatar-9: fresh install SQL includes v21 ===');

assert(
  freshInstall.includes('purchase_avatar_color'),
  'Fresh install SQL includes purchase_avatar_color'
);

console.log(`\n${pass} passed, ${fail} failed`);
if (fail > 0) process.exit(1);
