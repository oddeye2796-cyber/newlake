/* 다국어(한국어·영어·일본어). 원문 한국어 문장을 그대로 키로 쓴다: t('홈') → 'Home'.
   번역이 없으면 한국어 원문을 보여 준다. {n} 같은 자리표시자는 vars 로 채운다.
   번역 사전은 영역별 파일(en.*.ts, ja.*.ts)로 나눠 두고 여기서 합친다.
   DB 에서 오는 값(사용자 이름, 데이터셋 설명, 규칙 근거 문장, DB 거절 메시지)은 번역하지 않는다. */
import { lsGet, lsSet } from '../storage';
import enCore from './en.core';
import jaCore from './ja.core';
import enWork from './en.work';
import jaWork from './ja.work';
import enAdmin from './en.admin';
import jaAdmin from './ja.admin';

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
