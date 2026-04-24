import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const indexHtml = readFileSync(join(root, 'index.html'), 'utf8');

function extractFunction(source, name) {
  const start = source.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  let depth = 0;
  let end = -1;
  for (let i = start; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}') {
      depth--;
      if (depth === 0) {
        end = i + 1;
        break;
      }
    }
  }
  assert.notEqual(end, -1, `${name} must have a complete function body`);
  return source.slice(start, end);
}

const renderStudentPortalState = extractFunction(indexHtml, 'renderStudentPortalState');
const renderStudents = extractFunction(indexHtml, 'renderStudents');
const revealStudentCode = extractFunction(indexHtml, 'revealStudentCode');

assert.doesNotMatch(
  renderStudentPortalState,
  /currentStudentProfile\.login_code/,
  'logged-in student card must not display the login code'
);

assert.match(
  renderStudents,
  /Vis kode/,
  'teacher class list should include an explicit code-only reveal action'
);

assert.match(
  renderStudents,
  /onclick="revealStudentCode\('\$\{student\.id\}'\)"/,
  'code reveal action must call revealStudentCode for the selected student'
);

assert.match(
  revealStudentCode,
  /student\.login_code\|\|student\.student_code/,
  'code reveal should use the stored login code and legacy fallback'
);

assert.match(
  revealStudentCode,
  /Innloggingskode:/,
  'code reveal should label the value as the login code'
);

assert.doesNotMatch(
  revealStudentCode,
  /PIN|pin/i,
  'code reveal must not expose or mention PIN'
);
