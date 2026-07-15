import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// --- SQL: purchase_avatar_color must exist in both SQL files ---
assert.ok(patchSql.includes('purchase_avatar_color'), 'patch SQL must define purchase_avatar_color');
assert.ok(freshInstallSql.includes('purchase_avatar_color'), 'fresh install SQL must include purchase_avatar_color');

// --- SQL: faceColor must be the only valid slot ---
assert.ok(patchSql.includes("array['faceColor']"), "patch SQL must use array['faceColor'] as valid slots");
assert.ok(freshInstallSql.includes("array['faceColor']"), "fresh install SQL must use array['faceColor'] as valid slots");

// --- SQL: cost must be 25 XP ---
assert.ok(patchSql.includes('v_cost        int    := 25'), 'patch SQL must set cost to 25 XP');
assert.ok(freshInstallSql.includes('v_cost        int    := 25'), 'fresh install SQL must set cost to 25 XP');

// --- SQL: hex validation regex must be present ---
assert.ok(patchSql.includes('#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})'), 'patch SQL must validate hex color');

// --- index.html: faceColor in normalizeAvatarData ---
assert.ok(
  indexHtml.includes('faceColor') && indexHtml.includes('normalizeAvatarData'),
  'index.html must handle faceColor in normalizeAvatarData'
);
assert.ok(
  indexHtml.match(/const faceColor=.*avatarData.*faceColor/),
  'normalizeAvatarData must extract faceColor from avatarData'
);

// --- index.html: pendingAvatar must include faceColor default ---
assert.ok(
  indexHtml.includes("pendingAvatar={head:'head_basic',acc:'acc_none',faceColor:null}"),
  'pendingAvatar must initialize faceColor:null'
);

// --- index.html: hslToHex and hexToHue functions ---
assert.ok(indexHtml.includes('function hslToHex('), 'index.html must define hslToHex');
assert.ok(indexHtml.includes('function hexToHue('), 'index.html must define hexToHue');

// --- index.html: _coloredLayerHtml for CSS mask tinting ---
assert.ok(indexHtml.includes('function _coloredLayerHtml('), 'index.html must define _coloredLayerHtml');
assert.ok(indexHtml.includes('mask-image'), 'index.html must use CSS mask-image for color tinting');

// --- index.html: purchaseAvatarColor function ---
assert.ok(indexHtml.includes('async function purchaseAvatarColor('), 'index.html must define purchaseAvatarColor');
assert.ok(
  indexHtml.includes("'purchase_avatar_color'"),
  'purchaseAvatarColor must call the purchase_avatar_color RPC'
);
assert.ok(
  indexHtml.includes("p_color_slot:'faceColor'"),
  'purchaseAvatarColor must use faceColor slot'
);

// --- index.html: onColorHueChange function ---
assert.ok(indexHtml.includes('function onColorHueChange('), 'index.html must define onColorHueChange');

// --- index.html: color tab in shop ---
assert.ok(
  indexHtml.includes("setShopTab('color')") && indexHtml.includes('Farge'),
  'index.html shop must have a Farge (color) tab'
);

// --- index.html: renderAvatarCircle accepts colorOverride parameter ---
assert.ok(
  indexHtml.includes('function renderAvatarCircle(avatarData,name,size,colorOverride)'),
  'renderAvatarCircle must accept colorOverride parameter'
);

// --- teacher.html: _coloredLayerHtmlT and faceColor support ---
assert.ok(
  teacherHtml.includes('function _coloredLayerHtmlT('),
  'teacher.html must define _coloredLayerHtmlT'
);
assert.ok(
  teacherHtml.includes('avatarData.faceColor'),
  'renderAvatarCircleT must read faceColor from avatarData'
);

console.log('avatar_color_changes.test.mjs: all assertions passed ✅');
