// Tests for Avatar-9: paid color changes
// Guards the purchase_avatar_color RPC contract and frontend color rendering logic.

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';

const __dir = path.dirname(fileURLToPath(import.meta.url));
const indexHtml = readFileSync(path.join(__dir, '../index.html'), 'utf8');
const teacherHtml = readFileSync(path.join(__dir, '../apps/bingo/teacher.html'), 'utf8');
const sqlPatch = readFileSync(
  path.join(__dir, '../supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql'),
  'utf8'
);
const freshInstall = readFileSync(
  path.join(__dir, '../supabase/sql/supabase_bingo_fresh_install_v18.sql'),
  'utf8'
);

let passed = 0;
let failed = 0;

function assert(condition, msg) {
  if (condition) {
    console.log(`  ✓ ${msg}`);
    passed++;
  } else {
    console.error(`  ✗ ${msg}`);
    failed++;
  }
}

console.log('\n=== Avatar-9 color purchase tests ===\n');

// SQL patch guards
console.log('SQL patch:');
assert(sqlPatch.includes('purchase_avatar_color'), 'patch defines purchase_avatar_color function');
assert(sqlPatch.includes("'skinColor'"), 'patch includes skinColor slot validation');
assert(sqlPatch.includes("'^#[0-9a-fA-F]{6}$'"), 'patch validates hex color format');
assert(sqlPatch.includes('v_cost constant integer := 25'), 'patch sets cost to 25 XP');
assert(sqlPatch.includes('total_xp - v_cost'), 'patch deducts XP');
assert(sqlPatch.includes('v_avatar_data || jsonb_build_object'), 'patch merges color into avatar_data');
assert(sqlPatch.includes("grant execute on function public.purchase_avatar_color"), 'patch grants execute to authenticated');

// Fresh install includes v21
console.log('\nFresh install SQL:');
assert(freshInstall.includes('purchase_avatar_color'), 'fresh install includes purchase_avatar_color');
assert(freshInstall.includes('v21_avatar_color'), 'fresh install references v21 migration name');

// index.html guards
console.log('\nindex.html:');
assert(indexHtml.includes('skinColor'), 'index.html has skinColor in normalizeAvatarData or pendingAvatar');
assert(indexHtml.includes('_tintedSpriteStyle'), 'index.html defines _tintedSpriteStyle function');
assert(indexHtml.includes('mask-image'), 'index.html uses CSS mask-image for tinting');
assert(indexHtml.includes("setShopTab('color')"), 'index.html has Farge tab');
assert(indexHtml.includes('purchaseColor'), 'index.html defines purchaseColor function');
assert(indexHtml.includes('previewColor'), 'index.html defines previewColor function');
assert(indexHtml.includes('saveColorChange'), 'index.html defines saveColorChange function');
assert(indexHtml.includes('pendingColorPick'), 'index.html tracks pending color pick');
assert(indexHtml.includes('purchase_avatar_color'), 'index.html calls purchase_avatar_color RPC');
assert(indexHtml.includes('avatar-color-swatches'), 'index.html has color swatch grid CSS class');
assert(indexHtml.includes('25 XP'), 'index.html shows 25 XP cost in color tab');

// pendingAvatar default includes skinColor
assert(
  indexHtml.includes("skinColor:'#ffffff'") || indexHtml.includes('skinColor: \'#ffffff\''),
  'pendingAvatar defaults skinColor to #ffffff'
);

// normalizeAvatarData includes skinColor validation
assert(
  indexHtml.includes('skinColor') && indexHtml.includes('#[0-9a-fA-F]{6}'),
  'normalizeAvatarData validates skinColor as hex'
);

// teacher.html guards
console.log('\nteacher.html:');
assert(teacherHtml.includes('_tTintedSpriteStyle'), 'teacher.html defines _tTintedSpriteStyle');
assert(teacherHtml.includes('skinColor'), 'teacher.html respects skinColor in renderAvatarCircleT');
assert(teacherHtml.includes('mask-image'), 'teacher.html uses CSS mask for tinting');

console.log(`\n${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
