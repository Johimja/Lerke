import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml        = read('index.html');
const teacherHtml      = read('apps/bingo/teacher.html');
const patchSql         = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_colors_patch.sql');
const freshInstallSql  = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// SQL patch defines purchase_avatar_color
assert.ok(patchSql.includes('create or replace function public.purchase_avatar_color'), 'v21 patch must define purchase_avatar_color');
assert.ok(patchSql.includes("p_color_slot text"), 'purchase_avatar_color must accept p_color_slot');
assert.ok(patchSql.includes("p_color      text"), 'purchase_avatar_color must accept p_color');
assert.ok(patchSql.includes("'skinColor'"), 'v21 patch must validate skinColor slot');
assert.ok(patchSql.includes("'^#[0-9A-Fa-f]{6}$'"), 'v21 patch must validate hex color format');
assert.ok(patchSql.includes('v_cost        int := 25'), 'color change must cost 25 XP');
assert.ok(patchSql.includes('grant execute on function public.purchase_avatar_color'), 'purchase_avatar_color must be granted');

// Fresh install includes purchase_avatar_color
assert.ok(freshInstallSql.includes('purchase_avatar_color'), 'fresh install must include purchase_avatar_color');

// index.html: selectedPreviewColor variable
assert.ok(indexHtml.includes('let selectedPreviewColor=null'), 'index.html must define selectedPreviewColor');

// index.html: AVATAR_COLOR_PRESETS and AVATAR_COLOR_COST
assert.ok(indexHtml.includes('const AVATAR_COLOR_PRESETS='), 'index.html must define AVATAR_COLOR_PRESETS');
assert.ok(indexHtml.includes('const AVATAR_COLOR_COST=25'), 'index.html must set AVATAR_COLOR_COST to 25');

// index.html: Farge tab in renderAvatarShop
assert.ok(indexHtml.includes("setShopTab('color')"), 'index.html must have Farge tab');
assert.ok(indexHtml.includes('renderColorTabBody'), 'index.html must call renderColorTabBody');

// index.html: purchaseAvatarColor function calls the RPC
assert.ok(indexHtml.includes('async function purchaseAvatarColor'), 'index.html must define purchaseAvatarColor');
assert.ok(indexHtml.includes("'purchase_avatar_color'"), 'purchaseAvatarColor must call purchase_avatar_color RPC');
assert.ok(indexHtml.includes("p_color_slot:'skinColor'"), 'purchaseAvatarColor must pass skinColor slot');

// index.html: selectPreviewColor function
assert.ok(indexHtml.includes('function selectPreviewColor'), 'index.html must define selectPreviewColor');

// index.html: normalizeAvatarData returns skinColor
assert.ok(indexHtml.includes('const skinColor=(avatarData&&typeof avatarData.skinColor'), 'normalizeAvatarData must extract skinColor');

// index.html: renderAvatarCircle uses CSS mask for skinColor
assert.ok(indexHtml.includes('_skinMaskStyle'), 'index.html must define _skinMaskStyle helper');
assert.ok(indexHtml.includes('mask-image:url('), 'renderAvatarCircle must use CSS mask-image for skinColor tinting');

// index.html: pendingAvatar includes skinColor
assert.ok(indexHtml.includes("let pendingAvatar={head:'head_basic',acc:'acc_none',skinColor:null}"), 'pendingAvatar must include skinColor:null');

// teacher.html: renderAvatarCircleT applies skinColor
assert.ok(teacherHtml.includes('_tSkinMaskStyle'), 'teacher.html must define _tSkinMaskStyle helper');
assert.ok(teacherHtml.includes('skinColor'), 'renderAvatarCircleT must handle skinColor');

console.log('avatar_colors.test.mjs: all assertions passed ✅');
