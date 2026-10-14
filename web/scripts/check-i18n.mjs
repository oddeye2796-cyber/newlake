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
let bad = false;
for (const l of ['en', 'ja']) if (missing[l].size) { bad = true; console.log(`\n${l} 번역 없음 (${missing[l].size}):`); for (const k of missing[l]) console.log('  ' + JSON.stringify(k)); }
if (raw.length) { bad = true; console.log(`\nt() 로 감싸지 않은 한국어 (${raw.length}):`); raw.forEach((r) => console.log('  ' + r)); }
if (!bad) console.log('i18n OK');
process.exit(bad ? 1 : 0);
