// Tests for Avatar-9: paid color changes
import {readFileSync} from 'fs';
import {strict as assert} from 'assert';

const indexHtml = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const teacherHtml = readFileSync(new URL('../apps/bingo/teacher.html', import.meta.url), 'utf8');
const freshInstallSql = readFileSync(new URL('../supabase/sql/supabase_bingo_fresh_install_v18.sql', import.meta.url), 'utf8');
const patchSql = readFileSync(new URL('../supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql', import.meta.url), 'utf8');

// --- CSS mask approach ---

assert(
  indexHtml.includes('mask-image:url(\'media/avatar_faceshapes.png\')'),
  'index.html: .avatar-layer must use mask-image (not background-image) for coloring'
);
assert(
  indexHtml.includes('mask-image:url(\'media/avatar_head_accessories.png\')'),
  'index.html: .avatar-acc-layer must use mask-image for coloring'
);
assert(
  !indexHtml.includes('.avatar-layer{position:absolute;top:0;left:0;width:100%;height:100%;background-image'),
  'index.html: .avatar-layer must not use background-image approach'
);

assert(
  teacherHtml.includes("mask-image:url('../../media/avatar_faceshapes.png')"),
  'teacher.html: .t-avatar-layer must use mask-image'
);
assert(
  teacherHtml.includes("mask-image:url('../../media/avatar_head_accessories.png')"),
  'teacher.html: .t-avatar-acc-layer must use mask-image'
);

// --- pendingAvatar defaults include colors ---

assert(
  indexHtml.includes("pendingAvatar={head:'head_basic',acc:'acc_none',headColor:'#7c5230',accColor:'#f0c040'}"),
  'index.html: pendingAvatar default must include headColor and accColor'
);

// --- normalizeAvatarData extracts colors ---

assert(
  indexHtml.includes('headColor=_isValidHex') || indexHtml.includes("headColor=_isValidHex(avatarData&&avatarData.headColor)"),
  'index.html: normalizeAvatarData must extract headColor via _isValidHex'
);
assert(
  indexHtml.includes('_isValidHex'),
  'index.html: _isValidHex helper must be defined'
);

// --- Farger tab in shop ---

assert(
  indexHtml.includes("setShopTab('color')") && indexHtml.includes('Farger'),
  'index.html: avatar shop must have a Farger (color) tab'
);
assert(
  indexHtml.includes('applyColorChange'),
  'index.html: applyColorChange function must exist'
);
assert(
  indexHtml.includes("purchase_avatar_color"),
  'index.html: must call purchase_avatar_color RPC'
);

// --- Color slots ---

assert(
  indexHtml.includes("'headColor'") && indexHtml.includes("'accColor'"),
  'index.html: renderAvatarShop must reference headColor and accColor slots'
);

// --- SQL: patch file ---

assert(
  patchSql.includes('purchase_avatar_color'),
  'patch SQL must define purchase_avatar_color'
);
assert(
  patchSql.includes("'headColor'") && patchSql.includes("'accColor'"),
  'patch SQL must validate headColor and accColor slots'
);
assert(
  patchSql.includes('v_cost          int := 25'),
  'patch SQL: color change cost must be 25 XP'
);
assert(
  patchSql.includes("'^#[0-9a-fA-F]{6}$'"),
  'patch SQL must validate hex color format'
);
assert(
  patchSql.includes('already_same'),
  'patch SQL must return already_same when color is unchanged (no double charge)'
);

// --- SQL: fresh install includes v21 ---

assert(
  freshInstallSql.includes('purchase_avatar_color'),
  'fresh install SQL must include purchase_avatar_color from v21'
);

// --- teacher.html reads headColor/accColor from avatarData ---

assert(
  teacherHtml.includes('avatarData.headColor') && teacherHtml.includes('avatarData.accColor'),
  'teacher.html: renderAvatarCircleT must apply headColor and accColor from avatarData'
);

// --- background-color applied inline via mask approach ---

assert(
  indexHtml.includes(';background-color:${normalized.headColor}'),
  'index.html: renderAvatarCircle must apply headColor as background-color on the layer'
);
assert(
  indexHtml.includes(';background-color:${normalized.accColor}'),
  'index.html: renderAvatarCircle must apply accColor as background-color on acc layer'
);

console.log('avatar_color_changes.test.mjs: all assertions passed ✅');
