/* 다국어(한국어·영어·일본어). 원문 한국어 문장을 그대로 키로 쓴다: t('홈') → 'Home'.
   번역이 없으면 한국어 원문을 보여 준다. {n} 같은 자리표시자는 vars 로 채운다.
   번역 사전은 영역별 파일(en.*.ts, ja.*.ts)로 나눠 두고 여기서 합친다.
   DB 에서 오는 값 중 표준 라벨(클래스·속성·컬럼 이름, 데이터셋·파이프라인·규칙 이름, 위험 원인 문장 등)은 tl() 로 번역한다(data.*.ts).
   사용자가 직접 입력한 값과 DB 거절 메시지는 번역하지 않는다. */
import { lsGet, lsSet } from '../storage';
import enCore from './en.core';
import jaCore from './ja.core';
import enWork from './en.work';
import jaWork from './ja.work';
import enAdmin from './en.admin';
import jaAdmin from './ja.admin';
import dataEn from './data.en';
import dataJa from './data.ja';
import phys from './physical';
import { glossTranslate } from './glossary';

export type Lang = 'ko' | 'en' | 'ja';
export const LANGS: { id: Lang; label: string; short: string }[] = [
  { id: 'ko', label: '한국어', short: '한' },
  { id: 'en', label: 'English', short: 'EN' },
  { id: 'ja', label: '日本語', short: '日' },
];
export type Dict = Record<string, string>;

const DICTS: Record<Exclude<Lang, 'ko'>, Dict> = {
  en: { ...enCore, ...enWork, ...enAdmin },
  ja: { ...jaCore, ...jaWork, ...jaAdmin },
};
const KEY = 'newlake.lang';

function initialLang(): Lang {
  const v = lsGet(KEY);
  if (v === 'ko' || v === 'en' || v === 'ja') return v;
  const nav = typeof navigator !== 'undefined' ? navigator.language.toLowerCase() : 'ko';
  return nav.startsWith('ja') ? 'ja' : nav.startsWith('ko') ? 'ko' : nav.startsWith('en') ? 'en' : 'ko';
}

let current: Lang = initialLang();
if (typeof document !== 'undefined') document.documentElement.lang = current;

export const getLang = () => current;
export function setLang(l: Lang) {
  current = l;
  lsSet(KEY, l);
  if (typeof document !== 'undefined') document.documentElement.lang = l;
}

/** 원문(한국어)을 현재 언어로. vars 의 {이름} 을 채운다. */
export function t(ko: string, vars?: Record<string, string | number>): string {
  const s = current === 'ko' ? ko : DICTS[current][ko] ?? ko;
  return vars ? s.replace(/\{(\w+)\}/g, (m, k) => (k in vars ? String(vars[k]) : m)) : s;
}

/** 번역할 원문 표시만 한다(값은 그대로). 모듈 수준 표에 쓰고, 화면에 낼 때 t() 로 번역한다. 검사 스크립트가 이 원문도 사전에서 찾는다. */
export const tk = (ko: string) => ko;

/** 숫자·날짜 서식용 로캘 */
export const locale = () => ({ ko: 'ko-KR', en: 'en-US', ja: 'ja-JP' }[current]);

/** 검사용: 사전에 있는 모든 키 */
export const dictKeys = (l: Exclude<Lang, 'ko'>) => Object.keys(DICTS[l]);

const DATA: Record<Exclude<Lang, 'ko'>, Dict> = { en: dataEn, ja: dataJa };

/* 조합형 라벨: 'X 일련번호', 'X 참조', 'X — 정의' 는 X 를 번역해 이어 붙인다. */
const SEQ_FULL = '일련번호(행 대리키, 표준 외 물리 컬럼)';
const AFFIX: Record<Exclude<Lang, 'ko'>, { seqFull: string; seq: string; ref: string }> = {
  en: { seqFull: 'serial no. (row surrogate key, non-standard physical column)', seq: 'serial no.', ref: 'reference' },
  ja: { seqFull: '通し番号（行の代理キー、標準外の物理カラム）', seq: '通し番号', ref: '参照' },
};

/** DB 에서 온 한국어 라벨(클래스·속성·컬럼·데이터셋·파이프라인 이름 등)을 현재 언어로. 사전에 없으면 원문 그대로. */
export function tl(ko: string): string;
export function tl(ko: string | null | undefined): string | undefined;
export function tl(ko: string | null | undefined): string | undefined {
  if (!ko || current === 'ko') return ko ?? undefined;
  const hit = DATA[current][ko] ?? DICTS[current][ko];
  if (hit !== undefined) return hit;
  const a = AFFIX[current];
  let m: RegExpMatchArray | null;
  if (ko.endsWith(` ${SEQ_FULL}`)) return `${tl(ko.slice(0, -SEQ_FULL.length - 1))} ${a.seqFull}`;
  if (ko.endsWith(' 일련번호')) return `${tl(ko.slice(0, -5))} ${a.seq}`;
  if (ko.endsWith(' 참조')) return `${tl(ko.slice(0, -3))} ${current === 'en' ? `(${a.ref})` : a.ref}`;
  const msg = tlMessage(ko);
  if (msg !== undefined) return msg;
  if ((m = ko.match(/^(.+?) — (.+)$/))) return `${tl(m[1])} — ${tl(m[2])}`;
  return glossTranslate(ko, current);
}

/** 품질 검사식이 값을 이어 붙여 만드는 위반 메시지(숫자·이름이 섞여 사전에 통째로 못 넣는 문장) */
const num = (v: string) => (/^-?\d+\.\d+$/.test(v) ? String(Number(v)) : v);
const none = () => (current === 'en' ? 'none' : 'なし');
function tlMessage(ko: string): string | undefined {
  const en = current === 'en';
  let m: RegExpMatchArray | null;
  if ((m = ko.match(/^발주 수량이 0 이하: (.+)$/))) { const v = m[1] === '없음' ? none() : num(m[1]); return en ? `PO quantity is 0 or less: ${v}` : `発注数量が 0 以下: ${v}`; }
  if ((m = ko.match(/^품목 (.+) 이 품목 마스터에 없음$/))) return en ? `Item ${m[1]} is not in the item master` : `品目 ${m[1]} が品目マスタにありません`;
  if ((m = ko.match(/^(.+) 재고 (-?[\d.]+) < 안전재고 (-?[\d.]+)$/))) return en ? `${tl(m[1])} stock ${num(m[2])} < safety stock ${num(m[3])}` : `${tl(m[1])} 在庫 ${num(m[2])} < 安全在庫 ${num(m[3])}`;
  if ((m = ko.match(/^불량 (-?[\d.]+) > 생산 (-?[\d.]+)$/))) return en ? `Defects ${num(m[1])} > produced ${num(m[2])}` : `不良 ${num(m[1])} > 生産 ${num(m[2])}`;
  if ((m = ko.match(/^lotState "(.+)" 가 공통코드 LotState 에 없음$/))) return en ? `lotState "${m[1]}" is not in the LotState common code` : `lotState "${m[1]}" が共通コード LotState にありません`;
  if ((m = ko.match(/^(.+) — (\d{4}-\d\d-\d\d) 검사에서 발견, 원천 수정 후 해소$/))) return en ? `${tl(m[1])} — found in the ${m[2]} check, resolved after fixing the source` : `${tl(m[1])} — ${m[2]} の検査で検出、ソース修正後に解消`;
  return undefined;
}

/** 물리 이름(테이블·데이터셋 ID·컬럼명)을 표준 라벨로 번역한다. 사전에 없는 이름은 undefined. */
export const pn = (name: string | null | undefined): string | undefined => (name && phys[name] ? tl(phys[name]) : undefined);

/** 검사용: 데이터 라벨 사전에 있는 모든 키 */
export const dataKeys = (l: Exclude<Lang, 'ko'>) => Object.keys(DATA[l]);

/** 한국어 라벨 + 영어 라벨 컬럼이 같이 오는 값(확장 클래스 등): 영어에서는 등록된 영어 라벨을 먼저 쓴다. */
export const tle = (ko: string, en?: string | null): string => (current === 'en' && en ? en : tl(ko));
