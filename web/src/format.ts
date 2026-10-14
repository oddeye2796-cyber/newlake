/* 표시용 헬퍼. API 시각은 KST 벽시계 시각(타임존 없음)이라 변환 없이 그대로 보여 준다. */
import { locale, t, tk } from './i18n';

/** 값을 읽을 때마다 현재 언어로 번역하는 표 (모듈 로드 시점이 아니라 화면을 그릴 때 번역된다) */
function lazy<T>(src: Record<string, () => T>): Record<string, T> {
  return new Proxy(src, { get: (o, k) => (typeof k === 'string' && k in o ? o[k]() : undefined) }) as unknown as Record<string, T>;
}
const tr = (o: Record<string, string>) => lazy(Object.fromEntries(Object.entries(o).map(([k, v]) => [k, () => t(v)])));
const trp = (o: Record<string, [string, string]>) => lazy(Object.fromEntries(Object.entries(o).map(([k, [v, c]]) => [k, () => [t(v), c] as [string, string]])));
export const TIER = tr({ ASSERTED: tk('기준 정보'), OBSERVED: tk('시스템 기록'), INFERRED: tk('자동 판단'), GENERATED: tk('AI 추정'), LLM: tk('AI 추정') });
export const tierClass = (t: string) => (t === 'LLM' ? 'GENERATED' : t);

/** 2026-10-12T10:15:00 / 2026-10-14T13:53:08.99+09:00 -> 2026-10-12 10:15 (값 그대로, 변환 없음) */
export function fmtTs(s: string | null | undefined): string {
  if (!s) return '—';
  const m = /^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})/.exec(s);
  return m ? `${m[1]} ${m[2]}` : s;
}
export const fmtDate = (s: string | null | undefined) => (s ? s.slice(0, 10) : '—');
export const fmtTime = (s: string) => (/[T ](\d{2}:\d{2})/.exec(s) || [])[1] || s;

export const n0 = (v: number | null | undefined) => (v == null ? '—' : Math.round(v).toLocaleString(locale()));
export const pct = (v: number | null | undefined, d = 1) => (v == null ? '—' : `${v.toFixed(d)}%`);

/** 오늘(브라우저 날짜) 기준 남은 일수. 날짜 문자열끼리만 비교한다. */
export function daysLeft(date: string | null | undefined): number | null {
  if (!date) return null;
  const [y, m, d] = date.slice(0, 10).split('-').map(Number);
  const t = new Date(); const a = Date.UTC(y, m - 1, d); const b = Date.UTC(t.getFullYear(), t.getMonth(), t.getDate());
  return Math.round((a - b) / 86400000);
}
export const dLabel = (n: number | null) => (n == null ? '' : n === 0 ? 'D-day' : n > 0 ? `D-${n}` : `D+${-n}`);

export const RISK = trp({
  CRITICAL: [tk('매우 높음'), 'p-crit'], HIGH: [tk('높음'), 'p-crit'], MEDIUM: [tk('보통'), 'p-warn'], LOW: [tk('낮음'), 'p-line'],
});
export const riskPill = (lv: string | null | undefined): [string, string] => (lv && RISK[lv]) || [lv || '—', 'p-line'];

export const EXEC_STATUS = trp({
  PROPOSED: [tk('승인 대기'), 'p-warn'], APPROVED: [tk('승인됨'), 'p-ok'], REJECTED: [tk('반려됨'), 'p-line'], SENT: [tk('MES 전송됨'), 'p-ok'],
  ACKNOWLEDGED: [tk('MES 반영 완료'), 'p-ok'], FAILED: [tk('실패'), 'p-crit'], SUPPRESSED: [tk('보류 중단'), 'p-line'],
});
export const execPill = (s: string): [string, string] => EXEC_STATUS[s] || [s, 'p-line'];

export const LOT_STATE = tr({ START: tk('진행 중'), RELEASE: tk('작업 대기'), END: tk('완료'), COMPLETE: tk('완료'), HOLD: tk('보류') });
export const KIND_KO = tr({ lot: tk('로트'), equipment: tk('설비'), order: tk('주문'), item: tk('품목'), customer: tk('고객') });

/** IRI 마지막 조각 (…/lot/LOT-2026-0731 -> LOT-2026-0731) */
export const iriId = (iri: string) => decodeURIComponent(iri.split('/').pop() || iri);
export const iriKind = (iri: string): string => ({ lot: 'lot', equipment: 'equipment', salesOrder: 'order', customer: 'customer', item: 'item' } as Record<string, string>)[iri.split('/').slice(-2)[0]] || '';

export const DEFECT_KO = tr({ VOID: tk('솔더 보이드'), BRIDGE: tk('솔더 브리지'), SOLDER: tk('솔더') });
export const defectLabel = (typ: string | null, d: string | null) => (d && DEFECT_KO[d]) || [typ, d].filter(Boolean).join(' · ') || t('불량');
