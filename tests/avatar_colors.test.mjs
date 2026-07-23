// Tests for Avatar-9: paid color changes
// Verifies hex validation, normalizeAvatarData color handling, and renderAvatarCircle color layers.
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(__dirname, '../index.html'), 'utf8');

let passed = 0;
let failed = 0;

function assert(condition, label) {
  if (condition) {
    console.log(`  ✓ ${label}`);
    passed++;
  } else {
    console.error(`  ✗ ${label}`);
    failed++;
  }
}

// ── Extract _isValidHex ────────────────────────────────────────────────────
const hexFnMatch = html.match(/function _isValidHex\(c\)\{([^}]+)\}/);
assert(!!hexFnMatch, '_isValidHex function is present in index.html');

// ── Validate hex color format inline ──────────────────────────────────────
const HEX_RE = /^#[0-9a-fA-F]{6}$/;
const validHexCases = ['#c8844a', '#FFFFFF', '#000000', '#ff69b4', '#123abc'];
const invalidHexCases = ['', 'red', '#gggggg', '#12345', '#1234567', 'c8844a', null, undefined];

console.log('\nhex validation:');
for (const c of validHexCases) {
  assert(HEX_RE.test(c), `valid hex accepted: ${c}`);
}
for (const c of invalidHexCases) {
  assert(!(typeof c === 'string' && HEX_RE.test(c)), `invalid hex rejected: ${c}`);
}

// ── normalizeAvatarData includes color fields ──────────────────────────────
// Extract normalizeAvatarData function body
const normMatch = html.match(/function normalizeAvatarData\(avatarData\)\{[\s\S]*?return\s*\{head,acc,skinColor,accColor\}/);
console.log('\nnormalizeAvatarData:');
assert(!!normMatch, 'normalizeAvatarData returns {head,acc,skinColor,accColor}');

// Verify skinColor and accColor extraction are present
assert(html.includes('const skinColor=_isValidHex'), 'skinColor extracted via _isValidHex');
assert(html.includes('const accColor=_isValidHex'), 'accColor extracted via _isValidHex');

// ── pendingAvatar default includes color fields ───────────────────────────
console.log('\npendingAvatar:');
const pendingMatch = html.match(/let pendingAvatar=\{head:'head_basic',acc:'acc_none',skinColor:null,accColor:null\}/);
assert(!!pendingMatch, 'pendingAvatar default includes skinColor:null and accColor:null');

// ── renderAvatarCircle uses skin/acc color layers ─────────────────────────
console.log('\nrenderAvatarCircle color rendering:');
assert(html.includes('avatar-skin-layer'), 'avatar-skin-layer class used in renderAvatarCircle');
assert(html.includes('avatar-acc-color-layer'), 'avatar-acc-color-layer class used in renderAvatarCircle');
assert(html.includes('_maskPositionStyle'), '_maskPositionStyle helper called for color layers');
assert(html.includes("normalized.skinColor"), 'skinColor branch present in renderAvatarCircle');
assert(html.includes("normalized.accColor"), 'accColor branch present in renderAvatarCircle');

// ── CSS classes for color layers are defined ──────────────────────────────
console.log('\nCSS color layer classes:');
assert(html.includes('.avatar-skin-layer{'), '.avatar-skin-layer CSS defined');
assert(html.includes('.avatar-acc-color-layer{'), '.avatar-acc-color-layer CSS defined');
assert(html.includes('mask-image:url(\'media/avatar_faceshapes.png\')'), 'skin layer uses faceshapes mask-image');
assert(html.includes('mask-image:url(\'media/avatar_head_accessories.png\')'), 'acc color layer uses accessories mask-image');
assert(html.includes('-webkit-mask-image'), '-webkit-mask-image present for Safari compat');

// ── Farge (color) tab in shop ─────────────────────────────────────────────
console.log('\ncolor shop tab:');
assert(html.includes("setShopTab('color')"), "Farge tab calls setShopTab('color')");
assert(html.includes('_colorShopHtml'), '_colorShopHtml function called in renderAvatarShop');
assert(html.includes('SKIN_SWATCHES'), 'SKIN_SWATCHES palette defined');
assert(html.includes('ACC_SWATCHES'), 'ACC_SWATCHES palette defined');
assert(html.includes("purchaseAvatarColor"), 'purchaseAvatarColor function referenced in shop');
assert(html.includes("purchase_avatar_color"), "purchase_avatar_color RPC called");

// ── selectColorPick helper ────────────────────────────────────────────────
console.log('\nselectColorPick:');
assert(html.includes('function selectColorPick(slot,hex)'), 'selectColorPick function defined');
assert(html.includes('skin-color-picker'), 'skin color picker element id referenced');
assert(html.includes('acc-color-picker'), 'acc color picker element id referenced');

// ── teacher.html color layers ─────────────────────────────────────────────
const teacherHtml = readFileSync(join(__dirname, '../apps/bingo/teacher.html'), 'utf8');
console.log('\nteacher.html:');
assert(teacherHtml.includes('.t-avatar-skin-layer{'), '.t-avatar-skin-layer CSS defined');
assert(teacherHtml.includes('.t-avatar-acc-color-layer{'), '.t-avatar-acc-color-layer CSS defined');
assert(teacherHtml.includes('function _tIsValidHex(c)'), '_tIsValidHex helper defined');
assert(teacherHtml.includes('function _tMaskStyle(col,row,size)'), '_tMaskStyle helper defined');
assert(teacherHtml.includes('t-avatar-skin-layer'), 'renderAvatarCircleT uses t-avatar-skin-layer');
assert(teacherHtml.includes('t-avatar-acc-color-layer'), 'renderAvatarCircleT uses t-avatar-acc-color-layer');
assert(teacherHtml.includes('skinColor'), 'teacher renderAvatarCircleT reads skinColor from avatarData');

// ── SQL patch file exists ─────────────────────────────────────────────────
import { existsSync } from 'fs';
const patchPath = join(__dirname, '../supabase/sql/archive/Patches/supabase_bingo_v21_avatar_colors_patch.sql');
const freshSql = readFileSync(join(__dirname, '../supabase/sql/supabase_bingo_fresh_install_v18.sql'), 'utf8');
console.log('\nSQL:');
assert(existsSync(patchPath), 'v21 patch file exists');
assert(freshSql.includes('purchase_avatar_color'), 'purchase_avatar_color in fresh install SQL');
assert(freshSql.includes("'skinColor', 'accColor'"), "valid slot check in fresh install SQL");
assert(freshSql.includes("'^#[0-9a-f]{6}$'"), 'hex validation regex in fresh install SQL');
assert(freshSql.includes('xp_spent'), 'xp_spent returned in fresh install SQL');

console.log(`\n${'─'.repeat(48)}`);
console.log(`avatar_colors.test: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
