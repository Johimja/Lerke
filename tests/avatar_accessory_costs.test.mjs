import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const sql = read('supabase/sql/supabase_bingo_v20_avatar_accessory_costs.sql');

assert.ok(existsSync(join(root, 'media/avatar_head_accessories.png')), 'accessory sheet must exist');

const catalogueMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(catalogueMatch, 'ACCESSORY_CATALOGUE must be defined in index.html');

const frontendCosts = {};
for (const itemMatch of catalogueMatch[1].matchAll(/key:'(acc_\w+)'[^}]*?xp:(\d+)/g)) {
  frontendCosts[itemMatch[1]] = Number(itemMatch[2]);
}
assert.equal(Object.keys(frontendCosts).length, 20, 'expected 20 accessory items in index.html catalogue');
assert.equal(frontendCosts.acc_none, 0, 'acc_none must be free');
assert.ok(Object.values(frontendCosts).some((xp) => xp > 0), 'at least one accessory must cost XP');

const sqlCosts = {};
for (const caseMatch of sql.matchAll(/when '(acc_\w+)'\s+then (\d+)/g)) {
  sqlCosts[caseMatch[1]] = Number(caseMatch[2]);
}
assert.deepEqual(sqlCosts, frontendCosts, 'SQL get_avatar_item_cost() must match index.html ACCESSORY_CATALOGUE xp values exactly');
