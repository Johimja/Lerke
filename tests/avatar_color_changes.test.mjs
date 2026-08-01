// Tests for Avatar-9: paid color changes
// Checks SQL patch structure, index.html color constants, color tab UI, and teacher.html sync.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import assert from 'assert';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');

const sqlPatch = fs.readFileSync(path.join(root, 'supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_changes_patch.sql'), 'utf8');
const freshInstall = fs.readFileSync(path.join(root, 'supabase/sql/supabase_bingo_fresh_install_v18.sql'), 'utf8');
const indexHtml = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const teacherHtml = fs.readFileSync(path.join(root, 'apps/bingo/teacher.html'), 'utf8');

// ── SQL patch ──────────────────────────────────────────────────────────────
assert(sqlPatch.includes('purchase_avatar_color'), 'SQL patch must define purchase_avatar_color');
assert(sqlPatch.includes("p_color_slot text"), 'SQL must accept p_color_slot parameter');
assert(sqlPatch.includes("p_color text"), 'SQL must accept p_color parameter');
assert(sqlPatch.includes("'skinColor','accColor'"), 'SQL must validate skinColor and accColor slots');
assert(sqlPatch.includes("'^#[0-9a-fA-F]{6}$'"), 'SQL must validate hex color format');
assert(sqlPatch.includes('v_cost         integer := 25'), 'Color change cost must be 25 XP');
assert(sqlPatch.includes("'Not enough XP'"), 'SQL must return error when XP is insufficient');
assert(sqlPatch.includes('total_xp - v_cost'), 'SQL must deduct XP on success');
assert(sqlPatch.includes("jsonb_build_object(p_color_slot, p_color)"), 'SQL must merge color into avatar_data');
assert(sqlPatch.includes("'ok',          true"), 'SQL must return ok:true on success');
assert(sqlPatch.includes("grant execute on function public.purchase_avatar_color"), 'SQL must grant execute to authenticated/anon');
console.log('SQL patch ✅');

// ── Fresh install contains v21 function ───────────────────────────────────
assert(freshInstall.includes('purchase_avatar_color'), 'Fresh install SQL must include purchase_avatar_color');
assert(freshInstall.includes('v21_avatar_color_changes_patch.sql'), 'Fresh install must reference v21 patch file name');
console.log('Fresh install sync ✅');

// ── index.html: color constants ───────────────────────────────────────────
assert(indexHtml.includes("AVATAR_DEFAULT_SKIN='#f5c09e'"), 'Must define AVATAR_DEFAULT_SKIN constant');
assert(indexHtml.includes("AVATAR_DEFAULT_ACC_COLOR='#d4a800'"), 'Must define AVATAR_DEFAULT_ACC_COLOR constant');
console.log('Color constants ✅');

// ── index.html: CSS mask approach for avatar layers ───────────────────────
assert(indexHtml.includes('mask-image:url(\'media/avatar_faceshapes.png\')'), 'Face layer must use CSS mask-image');
assert(indexHtml.includes('mask-image:url(\'media/avatar_head_accessories.png\')'), 'Accessory layer must use CSS mask-image');
assert(!indexHtml.match(/\.avatar-layer\{[^}]*background-image:url\('media\/avatar_faceshapes/), 'Face layer must NOT use background-image');
assert(!indexHtml.match(/\.avatar-acc-layer\{[^}]*background-image:url\('media\/avatar_head_accessories/), 'Accessory layer must NOT use background-image');
console.log('CSS mask approach ✅');

// ── index.html: _spriteStyle uses mask-size/mask-position ─────────────────
assert(indexHtml.includes('mask-size:${bsW}px'), '_spriteStyle must output mask-size');
assert(indexHtml.includes('mask-position:${-col*size}px'), '_spriteStyle must output mask-position');
assert(!indexHtml.includes('background-size:${bsW}px'), '_spriteStyle must not output background-size');
console.log('_spriteStyle uses mask-* ✅');

// ── index.html: normalizeAvatarData handles skinColor and accColor ─────────
assert(indexHtml.includes('skinColor') && indexHtml.includes('accColor'), 'normalizeAvatarData must handle skinColor and accColor');
assert(indexHtml.includes("const skinColor=(avatarData&&avatarData.skinColor&&/^#[0-9a-fA-F]{6}$/.test(avatarData.skinColor))?avatarData.skinColor:null"), 'normalizeAvatarData must validate skinColor hex');
console.log('normalizeAvatarData colors ✅');

// ── index.html: pendingAvatar includes color fields ────────────────────────
assert(indexHtml.includes("pendingAvatar={head:'head_basic',acc:'acc_none',skinColor:null,accColor:null}"), 'pendingAvatar must include skinColor and accColor fields');
console.log('pendingAvatar defaults ✅');

// ── index.html: "Farge" tab in shop UI ────────────────────────────────────
assert(indexHtml.includes("setShopTab('color')"), 'Shop must have Farge tab with color mode');
assert(indexHtml.includes('Farge'), 'Shop tabs must include Farge label');
assert(indexHtml.includes("color-picker-${s.slot}"), 'Color tab must render dynamic picker ids per slot');
assert(indexHtml.includes("applyAvatarColor('${s.slot}')"), 'Farge tab must call applyAvatarColor per slot');
assert(indexHtml.includes("slot:'skinColor'"), 'Color slots must include skinColor entry');
assert(indexHtml.includes("slot:'accColor'"), 'Color slots must include accColor entry');
assert(indexHtml.includes('Lagre −25 XP'), 'Farge tab must show save cost');
console.log('Farge shop tab ✅');

// ── index.html: purchaseAvatarColor function ──────────────────────────────
assert(indexHtml.includes('purchase_avatar_color'), 'index.html must call purchase_avatar_color RPC');
assert(indexHtml.includes('p_color_slot:slot'), 'RPC call must pass p_color_slot');
assert(indexHtml.includes('p_color:color'), 'RPC call must pass p_color');
assert(indexHtml.includes('Farge lagret! −25 XP'), 'Success message must mention 25 XP');
console.log('purchaseAvatarColor function ✅');

// ── index.html: renderAvatarCircle applies colors ─────────────────────────
assert(indexHtml.includes('const skinColor=normalized.skinColor||AVATAR_DEFAULT_SKIN'), 'renderAvatarCircle must use normalized skinColor');
assert(indexHtml.includes('const accColor=normalized.accColor||AVATAR_DEFAULT_ACC_COLOR'), 'renderAvatarCircle must use normalized accColor');
assert(indexHtml.includes('background-color:${skinColor}'), 'Face layer must inline background-color from skinColor');
assert(indexHtml.includes('background-color:${accColor}'), 'Accessory layer must inline background-color from accColor');
console.log('renderAvatarCircle applies colors ✅');

// ── teacher.html: mask approach ────────────────────────────────────────────
assert(teacherHtml.includes("mask-image:url('../../media/avatar_faceshapes.png')"), 'Teacher face layer must use mask-image');
assert(teacherHtml.includes("mask-image:url('../../media/avatar_head_accessories.png')"), 'Teacher acc layer must use mask-image');
assert(teacherHtml.includes('T_AVATAR_DEFAULT_SKIN'), 'Teacher must define T_AVATAR_DEFAULT_SKIN');
assert(teacherHtml.includes('T_AVATAR_DEFAULT_ACC_COLOR'), 'Teacher must define T_AVATAR_DEFAULT_ACC_COLOR');
console.log('teacher.html mask approach ✅');

// ── teacher.html: renderAvatarCircleT applies colors ─────────────────────
assert(teacherHtml.includes('skinColor') && teacherHtml.includes('accColor'), 'renderAvatarCircleT must handle skinColor and accColor');
assert(teacherHtml.includes('T_AVATAR_DEFAULT_SKIN'), 'Teacher renderer must fall back to T_AVATAR_DEFAULT_SKIN');
assert(teacherHtml.includes('T_AVATAR_DEFAULT_ACC_COLOR'), 'Teacher renderer must fall back to T_AVATAR_DEFAULT_ACC_COLOR');
console.log('renderAvatarCircleT applies colors ✅');

console.log('\nAll avatar_color_changes tests passed ✅');
