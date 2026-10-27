// 번역 누락 검사: src 안의 t('…') 원문이 en·ja 사전에 모두 있는지, t() 로 감싸지 않은 한국어 문자열이 남았는지 본다.
// 사용: node scripts/check-i18n.mjs  (누락이 있으면 종료 코드 1)
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('../src/', import.meta.url).pathname;
const files = [];
(function walk(d) {
  for (const f of readdirSync(d)) {
    const p = join(d, f);
    if (statSync(p).isDirectory()) { if (!['i18n', 'demo'].includes(f) || f === 'demo') walk(p); }
    else if (/\.(ts|tsx)$/.test(f) && !p.includes('/i18n/')) files.push(p);
  }
})(root);

const dictKeys = (name) => {
  const src = ['core', 'work', 'admin'].map((a) => readFileSync(join(root, 'i18n', `${name}.${a}.ts`), 'utf8')).join('\n');
  const keys = new Set();
  for (const m of src.matchAll(/^\s*(['"])((?:\\.|(?!\1).)*)\1\s*:/gm)) keys.add(m[2].replace(/\\(['"\\])/g, '$1'));
  return keys;
};
const en = dictKeys('en'), ja = dictKeys('ja');

const hangul = /[가-힣]/;
const missing = { en: new Set(), ja: new Set() };
const raw = [];
for (const f of files) {
  const lines = readFileSync(f, 'utf8').split('\n');
  let inBlock = false;
  lines.forEach((line, i) => {
    if (inBlock) { if (line.includes('*/')) inBlock = false; return; }
    if (/^\s*\/\*/.test(line) && !line.includes('*/')) { inBlock = true; return; }
    const code = line.replace(/\/\/.*$/, '').replace(/\/\*.*?\*\//g, '').replace(/{\s*\/\*.*?\*\/\s*}/g, '');
    if (/^\s*(\*|\/\*)/.test(line)) return;
    let rest = code;
    for (const m of code.matchAll(/\btk?\(\s*(['"`])((?:\\.|(?!\1).)*)\1/g)) {
      const k = m[2].replace(/\\(['"`\\])/g, '$1');
      if (!en.has(k)) missing.en.add(k);
      if (!ja.has(k)) missing.ja.add(k);
      rest = rest.replace(m[0], '');
    }
    if (hangul.test(rest.replace(/\/\/.*$/, '')) && !/i18n-ignore/.test(line)) raw.push(`${f.replace(root, '')}:${i + 1}: ${line.trim()}`);
  });
}

// ── 데이터 라벨: 시연 데이터(fixtures.json)의 표시용 한국어 값이 data.en/ja 사전에 있는지 본다. (조합형 라벨은 tl() 규칙대로 풀어서 본다)
const dataKeysOf = (name) => {
  const src = readFileSync(join(root, 'i18n', `data.${name}.ts`), 'utf8');
  const keys = new Set();
  for (const m of src.matchAll(/^\s*("(?:\\.|[^"\\])*")\s*:/gm)) keys.add(JSON.parse(m[1]));
  return keys;
};
const dEn = dataKeysOf('en'), dJa = dataKeysOf('ja');
const dataMissing = new Set();
for (const k of dEn) if (!dJa.has(k)) dataMissing.add(`ja 에만 없음: ${k}`);
for (const k of dJa) if (!dEn.has(k)) dataMissing.add(`en 에만 없음: ${k}`);
const SEQ_FULL = '일련번호(행 대리키, 표준 외 물리 컬럼)';
const resolvable = (k) => {
  if (dEn.has(k) || en.has(k)) return true;
  if (k.endsWith(` ${SEQ_FULL}`)) return resolvable(k.slice(0, -SEQ_FULL.length - 1));
  if (k.endsWith(' 일련번호')) return resolvable(k.slice(0, -5));
  if (k.endsWith(' 참조')) return resolvable(k.slice(0, -3));
  const m = k.match(/^(.+?) — (.+)$/);
  return m ? resolvable(m[1]) && resolvable(m[2]) : false;
};
const LABEL_KEYS = new Set(['label_ko', 'title_ko', 'class_label', 'subject_label', 'property_label', 'object_label', 'business_group', 'definition_ko', 'label', 'dataset_title', 'action_label', 'from_title', 'to_title', 'target_label', 'parent_label', 'source_label', 'role_label', 'suggested_label', 'pipeline_label', 'relation_kind', 'range_label', 'trigger_label', 'dimension', 'display_name', 'equipment_name', 'operation_name', 'parameter_name', 'item_name', 'current_operation_name', 'customer_name', 'owner_dept', 'cause', 'text', 'message', 'decision_note', 'source']);
try {
  const fx = JSON.parse(readFileSync(join(root, 'demo', 'fixtures.json'), 'utf8'));
  (function walk(o, key) {
    if (Array.isArray(o)) o.forEach((v) => walk(v, key));
    else if (o && typeof o === 'object') for (const [k, v] of Object.entries(o)) walk(v, k);
    else if (typeof o === 'string' && hangul.test(o) && LABEL_KEYS.has(key) && !o.includes('\n') && !resolvable(o)) dataMissing.add(`${key}: ${o}`);
  })(fx, '');
} catch { /* fixtures 없으면 건너뜀 */ }
let bad = false;
if (dataMissing.size) { bad = true; console.log(`\n데이터 라벨 번역 없음 (${dataMissing.size}) — src/i18n/data.en.ts · data.ja.ts 에 추가:`); for (const k of dataMissing) console.log('  ' + k); }
for (const l of ['en', 'ja']) if (missing[l].size) { bad = true; console.log(`\n${l} 번역 없음 (${missing[l].size}):`); for (const k of missing[l]) console.log('  ' + JSON.stringify(k)); }
if (raw.length) { bad = true; console.log(`\nt() 로 감싸지 않은 한국어 (${raw.length}):`); raw.forEach((r) => console.log('  ' + r)); }
if (!bad) console.log('i18n OK');
process.exit(bad ? 1 : 0);
