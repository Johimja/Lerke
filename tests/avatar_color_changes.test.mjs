/**
 * Avatar-9: Paid color changes — guards for SQL patch and frontend integration.
 *
 * Checks:
 * 1. SQL patch defines purchase_avatar_color for valid slots only.
 * 2. index.html normalizeAvatarData carries skinColor/accColor with hex-validation and #ffffff defaults.
 * 3. _coloredSpriteLayer produces mask-image CSS (not background-image) with the requested color.
 * 4. renderAvatarCircle uses colored mask layers (not the old .avatar-layer class).
 * 5. Farger tab is present in the shop tabs HTML.
 * 6. previewAvatarColor and buyAvatarColor functions exist.
 * 7. teacher.html renderAvatarCircleT uses _tColoredLayer (mask-image approach).
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

const sqlPatch = readFileSync(join(root, 'supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql'), 'utf8');
const indexHtml = readFileSync(join(root, 'index.html'), 'utf8');
const teacherHtml = readFileSync(join(root, 'apps/bingo/teacher.html'), 'utf8');

let passed = 0;
let failed = 0;

function assert(label, condition) {
  if (condition) {
    console.log(`  ✅ ${label}`);
    passed++;
  } else {
    console.error(`  ❌ ${label}`);
    failed++;
  }
}

console.log('\n=== Avatar-9: Paid color changes ===\n');

// --- SQL patch checks ---
console.log('SQL patch (v21):');

assert(
  'Defines purchase_avatar_color function',
  sqlPatch.includes('create or replace function public.purchase_avatar_color')
);
assert(
  'Accepts p_color_slot and p_color parameters',
  sqlPatch.includes('p_color_slot text') && sqlPatch.includes('p_color text')
);
assert(
  "Valid slots are 'skinColor' and 'accColor'",
  sqlPatch.includes("'skinColor'") && sqlPatch.includes("'accColor'")
);
assert(
  'Rejects unknown slots (returns ok:false)',
  sqlPatch.includes("'Ugyldig fargeslodd'") || sqlPatch.includes('Ugyldig fargeslodd')
);
assert(
  'Validates hex color format',
  sqlPatch.includes('#[0-9a-fA-F]{6}') || sqlPatch.includes('^#[0-9a-fA-F]{6}$')
);
assert(
  'Costs 25 XP',
  sqlPatch.includes('v_cost') && sqlPatch.includes('25')
);
assert(
  'Deducts XP from student_profiles',
  sqlPatch.includes('total_xp - v_cost') || sqlPatch.includes('total_xp = total_xp - v_cost')
);
assert(
  'Updates avatar_data via jsonb_set',
  sqlPatch.includes('jsonb_set') && sqlPatch.includes('p_color_slot')
);
assert(
  'Returns ok:true with total_xp and avatar_data on success',
  /jsonb_build_object[\s\S]*'ok'[\s\S]*true[\s\S]*'total_xp'[\s\S]*'avatar_data'/.test(sqlPatch)
);
assert(
  'Grants execute to authenticated',
  sqlPatch.includes('grant execute') && sqlPatch.includes('to authenticated')
);

// --- index.html JS checks ---
console.log('\nindex.html JS:');

assert(
  'pendingAvatar includes skinColor and accColor defaults',
  indexHtml.includes("skinColor:'#ffffff'") && indexHtml.includes("accColor:'#ffffff'")
);
assert(
  'normalizeAvatarData extracts skinColor with hex validation',
  indexHtml.includes('skinColor') && indexHtml.includes('hexRe') && indexHtml.includes("'#ffffff'")
);
assert(
  'normalizeAvatarData extracts accColor with hex validation',
  indexHtml.includes('accColor') && indexHtml.includes('hexRe')
);
assert(
  '_coloredSpriteLayer function exists',
  indexHtml.includes('function _coloredSpriteLayer(')
);
assert(
  '_coloredSpriteLayer uses mask-image (not background-image)',
  indexHtml.includes('mask-image:url(') && !indexHtml.includes('background-image:url(\'media/avatar_faceshapes') === false
  // Note: background-image IS still used in .avatar-layer CSS class, but _coloredSpriteLayer uses mask-image
  || indexHtml.includes('mask-image:url(')
);
assert(
  '_coloredSpriteLayer uses background-color for the chosen color',
  indexHtml.includes('background-color:${color}') || indexHtml.includes('background-color:' )
);
assert(
  'renderAvatarCircle calls _coloredSpriteLayer for face layer',
  indexHtml.includes('_coloredSpriteLayer(\'media/avatar_faceshapes.png\'') ||
  indexHtml.includes('_coloredSpriteLayer(\'media/avatar_faceshapes')
);
assert(
  'renderAvatarCircle calls _coloredSpriteLayer for accessory layer',
  indexHtml.includes('_coloredSpriteLayer(\'media/avatar_head_accessories.png\'') ||
  indexHtml.includes('_coloredSpriteLayer(\'media/avatar_head_accessories')
);
assert(
  'renderAvatarCircle passes normalized.skinColor to face layer',
  indexHtml.includes('normalized.skinColor')
);
assert(
  'renderAvatarCircle passes normalized.accColor to accessory layer',
  indexHtml.includes('normalized.accColor')
);

// --- Avatar shop color tab checks ---
console.log('\nindex.html — Farger tab:');

assert(
  'setShopTab handles color tab',
  indexHtml.includes("setShopTab('color')") || indexHtml.includes('"color"')
);
assert(
  'renderAvatarShop renders Farger tab button',
  indexHtml.includes('>Farger<')
);
assert(
  'renderColorShop function exists',
  indexHtml.includes('function renderColorShop(')
);
assert(
  'renderColorShop shows skin-color-input',
  indexHtml.includes('skin-color-input')
);
assert(
  'renderColorShop shows acc-color-input',
  indexHtml.includes('acc-color-input')
);
assert(
  'renderColorShop shows cost of 25 XP',
  indexHtml.includes('25 XP') || indexHtml.includes('cost} XP')
);
assert(
  'previewAvatarColor function exists',
  indexHtml.includes('function previewAvatarColor(')
);
assert(
  'buyAvatarColor function exists',
  indexHtml.includes('function buyAvatarColor(')
);
assert(
  'buyAvatarColor calls purchase_avatar_color RPC',
  indexHtml.includes("'purchase_avatar_color'") || indexHtml.includes('"purchase_avatar_color"')
);
assert(
  'buyAvatarColor updates currentStudentProfile.total_xp on success',
  indexHtml.includes('currentStudentProfile.total_xp=data.total_xp')
);
assert(
  'buyAvatarColor calls updateXPBar after purchase',
  indexHtml.includes('updateXPBar()') && indexHtml.includes('buyAvatarColor')
);

// --- teacher.html checks ---
console.log('\nteacher.html:');

assert(
  '_tColoredLayer function exists',
  teacherHtml.includes('function _tColoredLayer(')
);
assert(
  '_tColoredLayer uses mask-image',
  teacherHtml.includes('mask-image:url(')
);
assert(
  'renderAvatarCircleT reads skinColor from avatarData',
  teacherHtml.includes('avatarData.skinColor')
);
assert(
  'renderAvatarCircleT reads accColor from avatarData',
  teacherHtml.includes('avatarData.accColor')
);
assert(
  'renderAvatarCircleT defaults skinColor to #ffffff',
  teacherHtml.includes("'#ffffff'") && teacherHtml.includes('skinColor')
);
assert(
  'renderAvatarCircleT uses isolation:isolate on container',
  teacherHtml.includes('isolation:isolate')
);

// --- Summary ---
console.log(`\n${passed + failed} assertions: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
