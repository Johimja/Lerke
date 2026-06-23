import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const indexHtml = readFileSync(join(root, 'index.html'), 'utf8');
const patchSql = readFileSync(
  join(root, 'supabase/sql/archive/Patches/supabase_bingo_v20_avatar8_accessories_xp_patch.sql'),
  'utf8'
);
const freshInstallSql = readFileSync(
  join(root, 'supabase/sql/supabase_bingo_fresh_install_v18.sql'),
  'utf8'
);

// ── Extract ACCESSORY_CATALOGUE from index.html ───────────────────────────────

const catMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(catMatch, 'ACCESSORY_CATALOGUE must be defined in index.html');

const entries = [];
for (const m of catMatch[1].matchAll(/\{key:'([^']+)'[^}]*xp:(\d+)[^}]*\}/g)) {
  entries.push({ key: m[1], xp: parseInt(m[2], 10) });
}
assert.equal(entries.length, 20, 'ACCESSORY_CATALOGUE must have 20 entries');

// Free starters
const FREE_KEYS = ['acc_none', 'acc_headband', 'acc_bow'];
for (const key of FREE_KEYS) {
  const entry = entries.find(e => e.key === key);
  assert.ok(entry, `${key} must be in ACCESSORY_CATALOGUE`);
  assert.equal(entry.xp, 0, `${key} must be free (xp:0)`);
}

// Paid items must have xp > 0
const PAID_KEYS = [
  'acc_crown', 'acc_tophat', 'acc_cap', 'acc_graduation', 'acc_party_hat',
  'acc_viking', 'acc_cowboy', 'acc_beanie', 'acc_sombrero', 'acc_laurel',
  'acc_bandana', 'acc_witch_hat', 'acc_tiara', 'acc_chef_hat', 'acc_antlers',
  'acc_earmuffs', 'acc_bunny_ears',
];
for (const key of PAID_KEYS) {
  const entry = entries.find(e => e.key === key);
  assert.ok(entry, `${key} must be in ACCESSORY_CATALOGUE`);
  assert.ok(entry.xp > 0, `${key} must have xp > 0, got ${entry.xp}`);
}

// ── SQL patch must cover all paid acc_* keys ──────────────────────────────────

for (const key of PAID_KEYS) {
  assert.match(patchSql, new RegExp(`when '${key}'`), `patch SQL must include cost for ${key}`);
}

// Verify a few specific costs are consistent between index.html and patch SQL
const SPOT_CHECK = [
  { key: 'acc_crown',   xp: 200 },
  { key: 'acc_viking',  xp: 225 },
  { key: 'acc_beanie',  xp: 50  },
  { key: 'acc_tiara',   xp: 150 },
];
for (const { key, xp } of SPOT_CHECK) {
  const entry = entries.find(e => e.key === key);
  assert.equal(entry.xp, xp, `${key} must cost ${xp} XP in index.html`);
  assert.match(patchSql, new RegExp(`when '${key}'\\s+then ${xp}`), `${key} must cost ${xp} XP in patch SQL`);
}

// ── fresh_install_v18.sql must also include acc_* costs ───────────────────────
// (The final get_avatar_item_cost in the file overrides earlier versions)
// Find the last occurrence of get_avatar_item_cost
const lastIdx = freshInstallSql.lastIndexOf("create or replace function public.get_avatar_item_cost");
assert.ok(lastIdx !== -1, 'get_avatar_item_cost must exist in fresh_install_v18.sql');
const finalFn = freshInstallSql.slice(lastIdx);
for (const key of PAID_KEYS) {
  assert.match(finalFn, new RegExp(`when '${key}'`),
    `fresh_install_v18.sql final get_avatar_item_cost must include ${key}`);
}

// ── index.html shop tab includes 'Tilbehør' tab ──────────────────────────────
assert.match(indexHtml, /Tilbehør/, 'shop must have Tilbehør tab');
assert.match(indexHtml, /currentShopTab==='acc'/, 'shop must switch to acc catalogue');

// ── purchase_avatar_item RPC flow still references both catalogues ────────────
assert.match(indexHtml, /purchase_avatar_item/, 'purchaseAndEquipItem must call purchase_avatar_item RPC');

console.log('avatar_accessories_shop: all assertions passed ✅');
