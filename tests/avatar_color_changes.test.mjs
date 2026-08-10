import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_changes_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// SQL: RPC exists in both files
assert.ok(patchSql.includes('purchase_avatar_color'), 'v21 patch must define purchase_avatar_color');
assert.ok(freshInstallSql.includes('purchase_avatar_color'), 'fresh install must include purchase_avatar_color');

// SQL: cost is 25 XP in both files
for (const [label, sql] of [['patch', patchSql], ['fresh install', freshInstallSql]]) {
  assert.ok(sql.match(/v_cost\s+integer\s*:=\s*25/), `${label}: COLOR_COST must be 25`);
  assert.ok(sql.includes("p_color_slot not in ('skinColor')"), `${label}: must validate slot`);
  assert.ok(sql.match(/p_color.*\^#\[0-9a-fA-F\]\{6\}\$/), `${label}: must validate hex format`);
  assert.ok(sql.includes('jsonb_build_object(p_color_slot, v_hex)'), `${label}: must patch avatar_data`);
}

// index.html: COLOR_COST constant
const colorCostMatch = indexHtml.match(/const COLOR_COST=(\d+)/);
assert.ok(colorCostMatch, 'index.html must define COLOR_COST');
assert.equal(Number(colorCostMatch[1]), 25, 'COLOR_COST must be 25');

// index.html: COLOR_PRESETS palette with 10 entries
const presetsMatch = indexHtml.match(/const COLOR_PRESETS=\[([\s\S]*?)\];/);
assert.ok(presetsMatch, 'index.html must define COLOR_PRESETS');
const hexMatches = presetsMatch[1].match(/hex:'#[0-9a-fA-F]{6}'/g) || [];
assert.equal(hexMatches.length, 10, 'COLOR_PRESETS must have 10 color entries');

// index.html: pendingAvatar default includes skinColor
assert.ok(indexHtml.includes("skinColor:'#ffffff'"), 'pendingAvatar default must include skinColor');

// index.html: pendingColor variable
assert.ok(indexHtml.includes('let pendingColor=null'), 'index.html must declare pendingColor');

// index.html: normalizeAvatarData handles skinColor
assert.ok(indexHtml.includes('skinColor'), 'normalizeAvatarData must handle skinColor');
assert.ok(indexHtml.match(/skinColor.*#ffffff/), 'normalizeAvatarData must default skinColor to #ffffff');

// index.html: _faceColorStyle helper using mask-image
assert.ok(indexHtml.includes('_faceColorStyle'), 'index.html must define _faceColorStyle');
assert.ok(indexHtml.includes('mask-image'), 'index.html must use mask-image for color tinting');
assert.ok(indexHtml.includes("url('media/avatar_faceshapes.png')") ||
          indexHtml.includes('mask-image:url'), 'index.html must reference faceshapes in mask');

// index.html: renderAvatarCircle uses _faceColorStyle
assert.ok(indexHtml.includes('_faceColorStyle(h.col,h.row,size,normalized.skinColor)'),
  'renderAvatarCircle must pass skinColor to _faceColorStyle');

// index.html: Farge tab in shop tabs
assert.ok(indexHtml.includes("setShopTab('color')") && indexHtml.includes('Farge'),
  'index.html must have a Farge tab in the avatar shop');

// index.html: renderColorTab and related functions
assert.ok(indexHtml.includes('function renderColorTab'), 'index.html must define renderColorTab');
assert.ok(indexHtml.includes('function setPreviewColor'), 'index.html must define setPreviewColor');
assert.ok(indexHtml.includes('function purchaseAndEquipColor'), 'index.html must define purchaseAndEquipColor');

// index.html: purchaseAndEquipColor calls the correct RPC
assert.ok(indexHtml.includes("'purchase_avatar_color'") &&
          indexHtml.includes("p_color_slot:'skinColor'"),
  'purchaseAndEquipColor must call purchase_avatar_color RPC with skinColor slot');

// index.html: setShopTab resets pendingColor when leaving color tab
assert.ok(indexHtml.includes("if(tab!=='color') pendingColor=null"),
  'setShopTab must reset pendingColor when leaving the color tab');

// teacher.html: _tFaceColorStyle helper
assert.ok(teacherHtml.includes('_tFaceColorStyle'), 'teacher.html must define _tFaceColorStyle');
assert.ok(teacherHtml.includes("url('../../media/avatar_faceshapes.png')") ||
          teacherHtml.includes('mask-image'), 'teacher.html must use mask-image for skinColor');

// teacher.html: renderAvatarCircleT reads skinColor from avatarData
assert.ok(teacherHtml.includes('_tFaceColorStyle(h.col,h.row,size,skinColor)'),
  'renderAvatarCircleT must pass skinColor to _tFaceColorStyle');

console.log('avatar_color_changes: all assertions passed ✓');
