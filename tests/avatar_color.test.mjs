// Tests for Avatar-9: paid color changes
// Checks CSS mask approach, color tab UI, normalizeAvatarData, and SQL patch integrity.

import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dir = dirname(fileURLToPath(import.meta.url));
const indexHtml = readFileSync(resolve(__dir, '../index.html'), 'utf8');
const teacherHtml = readFileSync(resolve(__dir, '../apps/bingo/teacher.html'), 'utf8');
const sqlPatch = readFileSync(resolve(__dir, '../supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql'), 'utf8');
const freshInstall = readFileSync(resolve(__dir, '../supabase/sql/supabase_bingo_fresh_install_v18.sql'), 'utf8');

let passed = 0;
let failed = 0;
function assert(condition, label) {
  if (condition) { console.log(`  ✓ ${label}`); passed++; }
  else           { console.error(`  ✗ ${label}`); failed++; }
}

console.log('\nAvatar-9 color tests — index.html CSS');
assert(indexHtml.includes('mask-image:url(\'media/avatar_faceshapes.png\')'), '.avatar-layer uses mask-image');
assert(indexHtml.includes('-webkit-mask-image:url(\'media/avatar_faceshapes.png\')'), '.avatar-layer has webkit-mask-image prefix');
assert(!indexHtml.match(/\.avatar-layer\{[^}]*background-image:url\('media\/avatar_faceshapes/), '.avatar-layer no longer uses background-image');
assert(indexHtml.includes('background-color:white'), '.avatar-layer has default white background-color');
assert(indexHtml.includes('background-image:url(\'media/avatar_head_accessories.png\')'), '.avatar-acc-layer still uses background-image (accessories unchanged)');

console.log('\nAvatar-9 color tests — index.html JS functions');
assert(indexHtml.includes('function _headStyle('), '_headStyle function defined');
assert(indexHtml.includes('function _accStyle('), '_accStyle function defined');
assert(indexHtml.includes('function _spriteDims('), '_spriteDims helper defined');
assert(!indexHtml.includes('function _spriteStyle('), 'old _spriteStyle removed');
assert(indexHtml.includes('headColor'), 'headColor referenced in index.html');
assert(indexHtml.includes('normalizeAvatarData'), 'normalizeAvatarData still present');
assert(indexHtml.includes("avatarData.headColor&&/^#[0-9a-f]{6}$/i.test(avatarData.headColor)"), 'normalizeAvatarData validates headColor hex');
assert(indexHtml.includes("function avatarColorPickerInput("), 'avatarColorPickerInput function defined');
assert(indexHtml.includes("async function purchaseAvatarColor("), 'purchaseAvatarColor function defined');
assert(indexHtml.includes("purchase_avatar_color"), 'RPC purchase_avatar_color called from JS');

console.log('\nAvatar-9 color tests — index.html shop UI');
assert(indexHtml.includes("setShopTab('color')"), 'Farge tab button wired');
assert(indexHtml.includes("Farge"), 'Farge tab label present');
assert(indexHtml.includes('avatar-color-tab'), 'avatar-color-tab container rendered');
assert(indexHtml.includes('avatar-color-picker'), 'color picker input rendered');
assert(indexHtml.includes('25 XP'), 'color change cost 25 XP shown');
assert(indexHtml.includes('Hodepeltefarge'), 'label "Hodepeltefarge" present');

console.log('\nAvatar-9 color tests — teacher.html');
assert(teacherHtml.includes('mask-image:url(\'../../media/avatar_faceshapes.png\')'), '.t-avatar-layer uses mask-image');
assert(teacherHtml.includes('-webkit-mask-image:url(\'../../media/avatar_faceshapes.png\')'), '.t-avatar-layer has webkit prefix');
assert(teacherHtml.includes('function _tHeadStyle('), '_tHeadStyle defined in teacher.html');
assert(teacherHtml.includes('function _tAccStyle('), '_tAccStyle defined in teacher.html');
assert(!teacherHtml.includes('function _tSpriteStyle('), 'old _tSpriteStyle removed');
assert(teacherHtml.includes('avatarData.headColor'), 'renderAvatarCircleT reads headColor');

console.log('\nAvatar-9 color tests — SQL patch');
assert(sqlPatch.includes('purchase_avatar_color'), 'RPC purchase_avatar_color defined in patch');
assert(sqlPatch.includes("'headColor'"), 'headColor slot validated in SQL');
assert(sqlPatch.includes("'^#[0-9a-f]{6}$'"), 'hex color regex validated in SQL');
assert(sqlPatch.includes('v_cost          integer := 25'), 'cost is 25 XP in patch');
assert(sqlPatch.includes('grant execute on function public.purchase_avatar_color'), 'grant execute on RPC');

console.log('\nAvatar-9 color tests — fresh install sync');
assert(freshInstall.includes('purchase_avatar_color'), 'purchase_avatar_color in fresh install');
assert(freshInstall.includes("v_cost          integer := 25"), 'cost matches in fresh install');

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
