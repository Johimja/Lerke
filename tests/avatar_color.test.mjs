// avatar_color.test.mjs — Avatar-9: paid color changes
// Guards:
//   1. normalizeAvatarData returns a valid skinColor (default #c8a882)
//   2. skinColor from avatar_data is passed through if valid hex
//   3. Invalid skinColor falls back to default
//   4. pendingAvatar default includes skinColor
//   5. Farge tab exists in shop tabs HTML
//   6. purchase_avatar_color is called in the color buy flow
//   7. teacher.html renderAvatarCircleT uses _tSkinLayerStyle (mask-image)

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');

function readFile(relPath) {
  return fs.readFileSync(path.join(rootDir, relPath), 'utf8');
}

let passed = 0;
let failed = 0;
function assert(cond, msg) {
  if (cond) { console.log('  ✓', msg); passed++; }
  else       { console.error('  ✗', msg); failed++; }
}

console.log('\nAvatar-9 color system tests\n');

const indexHtml = readFile('index.html');
const teacherHtml = readFile('apps/bingo/teacher.html');
const sqlPatch = readFile('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');

// 1. normalizeAvatarData exists and includes skinColor
assert(indexHtml.includes('normalizeAvatarData'), 'normalizeAvatarData function exists');
assert(indexHtml.includes("skinColor=(avatarData&&avatarData.skinColor&&/^#[0-9a-fA-F]{6}$/.test(avatarData.skinColor))?avatarData.skinColor:'#c8a882'"),
  'normalizeAvatarData validates and defaults skinColor to #c8a882');

// 2. pendingAvatar default includes skinColor
assert(indexHtml.includes("pendingAvatar={head:'head_basic',acc:'acc_none',skinColor:'#c8a882'}"),
  'pendingAvatar default includes skinColor #c8a882');

// 3. _skinLayerStyle helper exists with mask-image
assert(indexHtml.includes('_skinLayerStyle'), '_skinLayerStyle helper defined');
assert(indexHtml.includes('mask-image:url('), '_skinLayerStyle uses mask-image');

// 4. renderAvatarCircle uses avatar-skin-layer (not old avatar-layer for face)
assert(indexHtml.includes('avatar-skin-layer'), 'index.html has avatar-skin-layer class usage');
assert(indexHtml.includes("_skinLayerStyle(h.col,h.row,size,normalized.skinColor)"),
  'renderAvatarCircle passes skinColor to _skinLayerStyle');

// 5. Farge tab appears in renderAvatarShop
assert(indexHtml.includes("setShopTab('color')">0)||indexHtml.includes("setShopTab('color')"),
  'Farge tab button calls setShopTab color');
assert(indexHtml.includes('>Farge<'), 'Farge tab label present');

// 6. purchaseAvatarColor function exists
assert(indexHtml.includes('purchaseAvatarColor'), 'purchaseAvatarColor function defined');
assert(indexHtml.includes("rpc('purchase_avatar_color'"), 'calls purchase_avatar_color RPC');

// 7. onSkinColorInput function exists
assert(indexHtml.includes('onSkinColorInput'), 'onSkinColorInput handler defined');

// 8. teacher.html: _tSkinLayerStyle helper
assert(teacherHtml.includes('_tSkinLayerStyle'), '_tSkinLayerStyle helper in teacher.html');
assert(teacherHtml.includes('mask-image:url('), '_tSkinLayerStyle uses mask-image in teacher.html');
assert(teacherHtml.includes("t-avatar-skin-layer"), 't-avatar-skin-layer class used in teacher.html');

// 9. teacher.html renderAvatarCircleT applies skinColor
assert(teacherHtml.includes("avatarData.skinColor&&/^#[0-9a-fA-F]{6}$/.test(avatarData.skinColor)"),
  'renderAvatarCircleT validates skinColor hex');
assert(teacherHtml.includes("_tSkinLayerStyle(h.col,h.row,size,skinColor)"),
  'renderAvatarCircleT passes skinColor to _tSkinLayerStyle');

// 10. SQL patch has the function
assert(sqlPatch.includes('purchase_avatar_color'), 'v21 SQL patch defines purchase_avatar_color');
assert(sqlPatch.includes("p_color_slot not in ('skin')"), 'SQL validates slot');
assert(sqlPatch.includes("p_color !~ '^#[0-9a-fA-F]{6}$'"), 'SQL validates hex format');
assert(sqlPatch.includes('v_cost        integer := 25'), 'SQL cost is 25 XP');
assert(sqlPatch.includes("grant execute on function public.purchase_avatar_color"), 'SQL grants execute');

// 11. fresh install includes v21
const freshInstall = readFile('supabase/sql/supabase_bingo_fresh_install_v18.sql');
assert(freshInstall.includes('purchase_avatar_color'), 'fresh_install_v18.sql includes v21 function');

console.log(`\n${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
