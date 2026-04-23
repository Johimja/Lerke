import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const studentHtml = read('apps/bingo/student.html');
const teacherHtml = read('apps/bingo/teacher.html');
const reactionsSql = read('supabase/sql/archive/legacy-migrations/supabase_bingo_v8_reactions_speed.sql');

assert.match(reactionsSql, /create or replace function public\.send_bingo_reaction/i);
assert.match(reactionsSql, /create or replace function public\.get_draw_reactions/i);

assert.match(
  studentHtml,
  /rpc\('send_bingo_reaction',\s*\{\s*p_session_id:liveSessionId,\s*p_draw_index:/s,
  'student reaction submit must call send_bingo_reaction with session + draw index'
);
assert.match(studentHtml, /p_round_number:/, 'student reaction submit must include round number');
assert.match(studentHtml, /p_emoji:emoji/, 'student reaction submit must send the selected emoji');
assert.doesNotMatch(studentHtml, /rpc\('submit_bingo_reaction'/, 'student reaction submit must not call the stale submit_bingo_reaction RPC');

assert.match(teacherHtml, /rpc\('get_draw_reactions',/);
assert.match(teacherHtml, /reaction-feed/);
