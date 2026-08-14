// Tests for Avatar-9: paid skin color changes
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const indexSrc = fs.readFileSync(path.join(__dirname, '../index.html'), 'utf8');
const teacherSrc = fs.readFileSync(path.join(__dirname, '../apps/bingo/teacher.html'), 'utf8');
const sqlSrc = fs.readFileSync(
  path.join(__dirname, '../supabase/sql/archive/Patches/supabase_bingo_v21_avatar_skin_color_patch.sql'),
  'utf8'
);

let passed = 0;
let failed = 0;
function assert(cond, msg) {
  if (cond) { console.log('  ✓', msg); passed++; }
  else       { console.error('  ✗', msg); failed++; }
}

console.log('\nAvatar-9: skin color — SQL patch');

assert(sqlSrc.includes('purchase_avatar_color'), 'SQL defines purchase_avatar_color function');
assert(sqlSrc.includes("'skinColor'"), 'SQL allows skinColor slot');
assert(sqlSrc.includes('v_cost        int := 25'), 'SQL cost is 25 XP');
assert(sqlSrc.includes("'^#[0-9a-fA-F]{6}$'"), 'SQL validates hex color format');
assert(sqlSrc.includes('xp_to_level'), 'SQL returns level via xp_to_level');
assert(sqlSrc.includes("GRANT EXECUTE ON FUNCTION purchase_avatar_color"), 'SQL grants execute to authenticated');

console.log('\nAvatar-9: skin color — index.html CSS');

assert(indexSrc.includes('.avatar-skin-layer'), 'avatar-skin-layer CSS class present');
assert(indexSrc.includes('mask-image:url(\'media/avatar_faceshapes.png\')'), 'avatar-skin-layer uses face shapes as mask');
assert(indexSrc.includes('mask-repeat:no-repeat'), 'avatar-skin-layer mask does not repeat');
assert(indexSrc.includes('.color-swatch{'), 'color-swatch CSS present');
assert(indexSrc.includes('.color-swatches{'), 'color-swatches container CSS present');
assert(indexSrc.includes('.avatar-color-picker{'), 'avatar-color-picker CSS present');

console.log('\nAvatar-9: skin color — index.html JS');

assert(indexSrc.includes('COLOR_CHANGE_COST=25'), 'COLOR_CHANGE_COST constant is 25');
assert(indexSrc.includes('COLOR_PRESETS='), 'COLOR_PRESETS array defined');
assert(indexSrc.includes('pendingColorHex=null'), 'pendingColorHex variable initialized');
assert(indexSrc.includes('skinColor'), 'skinColor referenced in JS');
assert(indexSrc.includes('_skinLayerStyle'), '_skinLayerStyle helper defined');
assert(indexSrc.includes("purchase_avatar_color"), 'purchaseAvatarColor calls purchase_avatar_color RPC');
assert(indexSrc.includes('selectAvatarColor'), 'selectAvatarColor function present');
assert(indexSrc.includes('purchaseAvatarColor'), 'purchaseAvatarColor function present');
assert(indexSrc.includes('resetAvatarColor'), 'resetAvatarColor function present');

// normalizeAvatarData preserves skinColor
assert(indexSrc.includes("const skinColor=(avatarData&&typeof avatarData.skinColor"), 'normalizeAvatarData handles skinColor');
assert(indexSrc.includes('/^#[0-9a-f]{6}$/i.test(avatarData.skinColor)'), 'normalizeAvatarData validates skinColor format');

// renderAvatarCircle uses skin layer when color set
assert(indexSrc.includes('avatar-skin-layer') && indexSrc.includes('normalized.skinColor'), 'renderAvatarCircle uses skin layer when skinColor present');

// Farge tab in shop
assert(indexSrc.includes("onclick=\"setShopTab('color')\">Farge<"), 'Farge tab added to shop');
assert(indexSrc.includes("currentShopTab==='color'"), "Farge tab renders renderColorTab()");
assert(indexSrc.includes('renderColorTab'), 'renderColorTab function defined');

// setShopTab clears pending color when switching away
assert(indexSrc.includes("if(tab!=='color')pendingColorHex=null"), 'setShopTab clears pendingColorHex when leaving Farge tab');

console.log('\nAvatar-9: skin color — teacher.html');

assert(teacherSrc.includes('.t-avatar-skin-layer'), 't-avatar-skin-layer CSS class present');
assert(teacherSrc.includes("mask-image:url('../../media/avatar_faceshapes.png')"), 't-avatar-skin-layer uses correct path for face shapes mask');
assert(teacherSrc.includes('_tSkinLayerStyle'), '_tSkinLayerStyle helper defined in teacher.html');
assert(teacherSrc.includes('skinColor'), 'renderAvatarCircleT reads skinColor');
assert(teacherSrc.includes('t-avatar-skin-layer'), 'renderAvatarCircleT outputs skin layer');

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
