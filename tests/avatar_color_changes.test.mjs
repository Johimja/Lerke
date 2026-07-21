// Tests for Avatar-9: paid color changes
// Guards normalizeAvatarData skinColor handling and renderAvatarCircle mask usage.

import {readFileSync} from 'fs';
import assert from 'assert';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const teacherHtml = readFileSync(new URL('../apps/bingo/teacher.html', import.meta.url), 'utf8');

// ── 1. normalizeAvatarData extracts skinColor from valid avatar_data ──────────
{
  const match = html.match(/function normalizeAvatarData\(avatarData\)\{([\s\S]*?)return \{head,acc,skinColor\}/);
  assert.ok(match, 'normalizeAvatarData must return {head,acc,skinColor}');
}

// ── 2. Default white when skinColor is missing ─────────────────────────────────
{
  const match = html.match(/skinColor.*#ffffff/);
  assert.ok(match, 'normalizeAvatarData must default skinColor to #ffffff');
}

// ── 3. Hex color regex validation in normalizeAvatarData ──────────────────────
{
  const match = html.match(/\^#\[0-9a-fA-F\]\{6\}\$.*test.*avatarData.skinColor/);
  assert.ok(match, 'normalizeAvatarData must validate skinColor as hex6');
}

// ── 4. renderAvatarCircle uses mask-image (not background-image) for face layer
{
  const match = html.match(/_maskStyle\(h\.col,h\.row,size\).*background-color.*normalized\.skinColor/);
  assert.ok(match, 'renderAvatarCircle must use _maskStyle + background-color for face layer');
}

// ── 5. Accessory layer still uses _spriteStyle (not mask) ─────────────────────
{
  const match = html.match(/avatar-acc-layer.*_spriteStyle\(a\.col,a\.row,size\)/);
  assert.ok(match, 'Accessory layer must still use _spriteStyle (background-image)');
}

// ── 6. COLOR_PRESETS contains exactly 12 entries ─────────────────────────────
{
  const match = html.match(/const COLOR_PRESETS=\[([\s\S]*?)\];/);
  assert.ok(match, 'COLOR_PRESETS array must be defined');
  const hexes = [...match[1].matchAll(/hex:'(#[0-9a-fA-F]{6})'/g)];
  assert.strictEqual(hexes.length, 12, `COLOR_PRESETS must have 12 entries, got ${hexes.length}`);
  // First entry must be white
  assert.strictEqual(hexes[0][1].toLowerCase(), '#ffffff', 'First color preset must be white (#ffffff)');
}

// ── 7. purchaseAvatarColor calls purchase_avatar_color RPC ───────────────────
{
  const match = html.match(/purchase_avatar_color.*p_color_slot.*skinColor.*p_color/);
  assert.ok(match, 'purchaseAvatarColor must call purchase_avatar_color RPC with correct args');
}

// ── 8. Avatar shop has 3 tabs: Hode, Tilbehør, Farge ─────────────────────────
{
  const tabsMatch = html.match(/setShopTab\('color'\).*Farge/);
  assert.ok(tabsMatch, 'Shop must include a Farge tab');
  const headTab = html.match(/setShopTab\('head'\).*Hode/);
  assert.ok(headTab, 'Shop must include a Hode tab');
  const accTab = html.match(/setShopTab\('acc'\).*Tilbehør/);
  assert.ok(accTab, 'Shop must include a Tilbehør tab');
}

// ── 9. .avatar-layer CSS uses mask-image (not background-image) ───────────────
{
  const layerCss = html.match(/\.avatar-layer\{[^}]+\}/);
  assert.ok(layerCss, '.avatar-layer CSS must be present');
  assert.ok(!layerCss[0].includes('background-image'), '.avatar-layer must not use background-image');
  assert.ok(layerCss[0].includes('mask-image'), '.avatar-layer must use mask-image');
}

// ── 10. teacher.html: .t-avatar-layer uses mask-image ────────────────────────
{
  const layerCss = teacherHtml.match(/\.t-avatar-layer\{[^}]+\}/);
  assert.ok(layerCss, '.t-avatar-layer CSS must be present in teacher.html');
  assert.ok(!layerCss[0].includes('background-image'), '.t-avatar-layer must not use background-image');
  assert.ok(layerCss[0].includes('mask-image'), '.t-avatar-layer must use mask-image');
}

// ── 11. teacher.html: renderAvatarCircleT applies skinColor ──────────────────
{
  const match = teacherHtml.match(/_tMaskStyle\(h\.col,h\.row,size\).*background-color.*skinColor/);
  assert.ok(match, 'renderAvatarCircleT must use _tMaskStyle + background-color with skinColor');
}

// ── 12. pickAvatarColor validates hex before applying ────────────────────────
{
  const match = html.match(/function pickAvatarColor\(hex\)[\s\S]*?if\(!\//);
  assert.ok(match, 'pickAvatarColor must validate hex format before applying');
}

console.log('avatar_color_changes: all 12 assertions passed ✅');
