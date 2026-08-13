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

// --- pendingAvatar default includes skinColor ---
assert.ok(
  indexHtml.includes("pendingAvatar={head:'head_basic',acc:'acc_none',skinColor:null}"),
  'pendingAvatar default must include skinColor:null'
);

// --- normalizeAvatarData extracts skinColor ---
assert.ok(
  indexHtml.includes('skinColor=(avatarData&&/^#[0-9a-fA-F]{6}$/.test(avatarData.skinColor))?avatarData.skinColor:null'),
  'normalizeAvatarData must extract skinColor with hex validation'
);

// --- renderAvatarCircle uses avatar-color-layer when skinColor present ---
assert.ok(
  indexHtml.includes('avatar-color-layer'),
  'renderAvatarCircle must reference avatar-color-layer class'
);
assert.ok(
  indexHtml.includes('mask-image:url(\'media/avatar_faceshapes.png\')'),
  'index.html must have mask-image for avatar_faceshapes.png'
);

// --- Farge tab present in shop ---
assert.ok(
  indexHtml.includes("setShopTab('color')"),
  'renderAvatarShop must have Farge tab calling setShopTab(\'color\')'
);
assert.ok(
  indexHtml.includes('renderColorTab'),
  'renderColorTab function must exist in index.html'
);

// --- Color purchase function calls correct RPC ---
assert.ok(
  indexHtml.includes("'purchase_avatar_color'"),
  'purchaseAvatarColor must call purchase_avatar_color RPC'
);
assert.ok(
  indexHtml.includes("p_color_slot:'skinColor'"),
  'purchaseAvatarColor must pass p_color_slot:\'skinColor\''
);

// --- previewSkinColor live preview function exists ---
assert.ok(
  indexHtml.includes('function previewSkinColor('),
  'previewSkinColor function must exist'
);

// --- teacher.html color layer support ---
assert.ok(
  teacherHtml.includes('t-avatar-color-layer'),
  'teacher.html must have t-avatar-color-layer CSS class'
);
assert.ok(
  teacherHtml.includes("mask-image:url('../../media/avatar_faceshapes.png')"),
  'teacher.html must have mask-image for avatar_faceshapes.png'
);
assert.ok(
  teacherHtml.includes('/^#[0-9a-fA-F]{6}$/.test(avatarData.skinColor)'),
  'renderAvatarCircleT must validate skinColor hex before applying'
);

// --- SQL patch defines purchase_avatar_color ---
assert.ok(
  patchSql.includes('create or replace function public.purchase_avatar_color'),
  'v21 patch must define purchase_avatar_color'
);
assert.ok(
  patchSql.includes("array['skinColor']"),
  'v21 patch must list skinColor as valid slot'
);
assert.ok(
  patchSql.includes('v_cost     int := 25'),
  'v21 patch must set cost to 25 XP'
);
assert.ok(
  patchSql.includes("'^#[0-9a-fA-F]{6}$'"),
  'v21 patch must validate hex color format'
);

// --- Fresh install includes purchase_avatar_color ---
assert.ok(
  freshInstallSql.includes('create or replace function public.purchase_avatar_color'),
  'fresh install must include purchase_avatar_color'
);

console.log('avatar_color_purchase: all assertions passed ✓');
