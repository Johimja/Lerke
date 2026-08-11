// Tests for Avatar-9: paid color changes
// Guards normalizeAvatarData color defaults, pendingAvatar shape, UI presence, and purchaseAvatarColor existence.

import { readFileSync } from 'fs';
import { strict as assert } from 'assert';

const indexHtml = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const teacherHtml = readFileSync(new URL('../apps/bingo/teacher.html', import.meta.url), 'utf8');
const sqlPatch = readFileSync(new URL('../supabase/sql/archive/Patches/supabase_bingo_v21_avatar_colors_patch.sql', import.meta.url), 'utf8');

// ── normalizeAvatarData returns color defaults ──────────────────────────
assert.match(indexHtml, /skinColor.*avatarData.*&&.*avatarData\.skinColor.*'#d4b895'/,
  'normalizeAvatarData should return skinColor with default #d4b895');
assert.match(indexHtml, /accColor.*avatarData.*&&.*avatarData\.accColor.*'#ffffff'/,
  'normalizeAvatarData should return accColor with default #ffffff');

// ── pendingAvatar default includes color fields ─────────────────────────
assert.match(indexHtml, /let pendingAvatar=\{head:'head_basic',acc:'acc_none',skinColor:'#d4b895',accColor:'#ffffff'\}/,
  'pendingAvatar should include skinColor and accColor defaults');

// ── _spriteMaskStyle function exists ────────────────────────────────────
assert.match(indexHtml, /function _spriteMaskStyle\(/, '_spriteMaskStyle function must exist');
assert.match(indexHtml, /mask-image/, 'CSS mask-image must be used in _spriteMaskStyle');

// ── renderAvatarCircle uses mask approach ───────────────────────────────
assert.match(indexHtml, /_spriteMaskStyle.*avatar_faceshapes\.png.*normalized\.skinColor/,
  'renderAvatarCircle must use _spriteMaskStyle with skinColor for face layer');
assert.match(indexHtml, /_spriteMaskStyle.*avatar_head_accessories\.png.*normalized\.accColor/,
  'renderAvatarCircle must use _spriteMaskStyle with accColor for accessory layer');

// ── Teacher renderAvatarCircleT uses mask approach ──────────────────────
assert.match(teacherHtml, /function _tSpriteMaskStyle\(/, 'teacher must have _tSpriteMaskStyle');
assert.match(teacherHtml, /_tSpriteMaskStyle.*avatar_faceshapes\.png.*skinColor/,
  'renderAvatarCircleT must use _tSpriteMaskStyle with skinColor');

// ── "Farger" tab present in shop ────────────────────────────────────────
assert.match(indexHtml, /setShopTab\('colors'\).*Farger/,
  'Avatar shop must have a Farger (colors) tab');

// ── Color swatches defined ───────────────────────────────────────────────
assert.match(indexHtml, /const SKIN_SWATCHES=\[/, 'SKIN_SWATCHES constant must exist');
assert.match(indexHtml, /const ACC_SWATCHES=\[/, 'ACC_SWATCHES constant must exist');
assert.match(indexHtml, /#d4b895/, 'Default skin color swatch #d4b895 must be present');
assert.match(indexHtml, /#ffffff/, 'White accessory swatch must be present');

// ── purchaseAvatarColor function exists ─────────────────────────────────
assert.match(indexHtml, /async function purchaseAvatarColor\(slot\)/,
  'purchaseAvatarColor function must exist');
assert.match(indexHtml, /purchase_avatar_color.*p_color_slot.*p_color/,
  'purchaseAvatarColor must call purchase_avatar_color RPC');

// ── previewAvatarColor function exists ──────────────────────────────────
assert.match(indexHtml, /function previewAvatarColor\(slot,hex\)/,
  'previewAvatarColor function must exist for live preview');

// ── COLOR_COST is 25 XP ─────────────────────────────────────────────────
assert.match(indexHtml, /const COLOR_COST=25/, 'COLOR_COST must be 25');

// ── CSS: avatar-layer no longer has background-image in class definition ─
const avatarLayerCss = indexHtml.match(/\.avatar-layer\{[^}]+\}/);
assert.ok(avatarLayerCss, '.avatar-layer CSS class must exist');
assert.ok(!avatarLayerCss[0].includes('background-image'),
  '.avatar-layer CSS must not set background-image (it is set via inline mask style)');

// ── SQL: purchase_avatar_color validates slot and hex ───────────────────
assert.match(sqlPatch, /p_color_slot not in \('skin', 'acc'\)/,
  'SQL must validate slot values');
assert.match(sqlPatch, /\^#\[0-9a-fA-F\]\{6\}\$/,
  'SQL must validate #RRGGBB hex format');
assert.match(sqlPatch, /COLOR_COST\s+constant int := 25/,
  'SQL COLOR_COST must be 25');
assert.match(sqlPatch, /coalesce\(avatar_data, '\{\}'/,
  'SQL must handle NULL avatar_data with coalesce');
assert.match(sqlPatch, /skinColor.*accColor|accColor.*skinColor/i,
  'SQL must reference both skinColor and accColor key names');

// ── SQL: fresh install includes the new RPC ─────────────────────────────
const freshInstall = readFileSync(new URL('../supabase/sql/supabase_bingo_fresh_install_v18.sql', import.meta.url), 'utf8');
assert.match(freshInstall, /purchase_avatar_color/,
  'fresh install SQL must include purchase_avatar_color');
assert.match(freshInstall, /v21_avatar_colors/,
  'fresh install SQL must reference v21_avatar_colors patch');

console.log('avatar_color_purchase.test.mjs ✅ all assertions passed');
