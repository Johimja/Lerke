import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessories_xp.sql');
const freshInstall = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// ── Accessory spritesheet exists ────────────────────────────────────────────
assert.ok(
  existsSync(join(root, 'media/avatar_head_accessories.png')),
  'media/avatar_head_accessories.png must exist'
);

// ── ACCESSORY_CATALOGUE has 20 items ────────────────────────────────────────
const catalogueMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(catalogueMatch, 'ACCESSORY_CATALOGUE must exist in index.html');
const accEntries = (catalogueMatch[1].match(/key:'acc_/g) || []).length;
assert.equal(accEntries, 20, 'ACCESSORY_CATALOGUE must have 20 items');

// ── acc_none is free, others have XP costs > 0 ──────────────────────────────
assert.match(indexHtml, /\{key:'acc_none'.*?xp:0\}/, 'acc_none must have xp:0');
const paidItems = [
  'acc_crown', 'acc_tophat', 'acc_viking', 'acc_witch_hat',
  'acc_headband', 'acc_beanie', 'acc_graduation',
];
for (const key of paidItems) {
  const m = indexHtml.match(new RegExp(`key:'${key}'.*?xp:(\\d+)`));
  assert.ok(m, `${key} must be in ACCESSORY_CATALOGUE`);
  assert.ok(parseInt(m[1]) > 0, `${key} must have xp > 0 (got ${m && m[1]})`);
}

// ── Crown costs 250 XP, witch_hat costs 300 XP ──────────────────────────────
const crownMatch = indexHtml.match(/key:'acc_crown'.*?xp:(\d+)/);
assert.ok(crownMatch, 'acc_crown must be in catalogue');
assert.equal(parseInt(crownMatch[1]), 250, 'acc_crown must cost 250 XP');

const witchMatch = indexHtml.match(/key:'acc_witch_hat'.*?xp:(\d+)/);
assert.ok(witchMatch, 'acc_witch_hat must be in catalogue');
assert.equal(parseInt(witchMatch[1]), 300, 'acc_witch_hat must cost 300 XP');

// ── Shop tabs show Hode and Tilbehør ─────────────────────────────────────────
assert.match(indexHtml, /Tilbehør/, 'shop must have Tilbehør tab');
assert.match(indexHtml, /setShopTab\('acc'\)/, 'setShopTab must handle acc tab');

// ── SQL patch exists and includes acc_* costs ────────────────────────────────
assert.match(patchSql, /when 'acc_none'\s+then 0/, 'patch: acc_none must be free');
assert.match(patchSql, /when 'acc_crown'\s+then 250/, 'patch: acc_crown must cost 250');
assert.match(patchSql, /when 'acc_witch_hat'\s+then 300/, 'patch: acc_witch_hat must cost 300');
assert.match(patchSql, /when 'acc_headband'\s+then 50/, 'patch: acc_headband must cost 50');
assert.match(patchSql, /when 'head_basic'\s+then 0/, 'patch: face shapes must still be present');

// ── Fresh install SQL is in sync ──────────────────────────────────────────────
assert.match(freshInstall, /when 'acc_crown'\s+then 250/, 'fresh install must include acc_crown cost');
assert.match(freshInstall, /when 'acc_witch_hat'\s+then 300/, 'fresh install must include acc_witch_hat cost');

console.log('avatar_accessories_shop: all assertions passed ✅');
