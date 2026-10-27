import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { TIER, tierClass } from '../format';
import { t, tl } from '../i18n';

export const Tier = ({ t }: { t: string }) => <span className={`tier t-${tierClass(t)}`} title={t}>{TIER[t] || t}</span>;
export const Pill = ({ children, cls = 'p-line' }: { children: ReactNode; cls?: string }) => <span className={`pill ${cls}`}>{children}</span>;

export function State({ loading, error }: { loading: boolean; error: string | null }) {
  if (error) return <div className="state err" role="alert">{error}</div>;
  if (loading) return <div className="state">{t('불러오는 중이에요…')}</div>;
  return null;
}

export const EntLink = ({ kind, id, children }: { kind: string; id: string; children?: ReactNode }) => (
  <Link className="entlink" to={`/find/${kind}/${encodeURIComponent(id)}`}>{children ?? id}</Link>
);
export const Chip = ({ kind, id }: { kind: string; id: string }) => <Link className="lchip" to={`/find/${kind}/${encodeURIComponent(id)}`}>{id}</Link>;

export function TierLegend() {
  return (
    <aside className="panel">
      <h2 style={{ marginBottom: 8 }}>{t('근거 표시 읽는 법')}</h2>
      <div style={{ display: 'grid', gap: 8 }} className="small">
        <div><Tier t="ASSERTED" /> {t('품목·설비 기준값 같은 기준 정보')}</div>
        <div><Tier t="OBSERVED" /> {t('MES·ERP·설비가 남긴 실제 기록')}</div>
        <div><Tier t="INFERRED" /> {t('정해진 규칙으로 시스템이 판단한 것')}</div>
        <div><Tier t="GENERATED" /> {t('AI가 추정한 것. 사람이 확인하기 전')}</div>
      </div>
    </aside>
  );
}

export function DataTable({ cols, rows }: { cols: string[]; rows: Record<string, unknown>[] }) {
  if (!rows.length) return <p className="muted small">{t('결과가 없어요.')}</p>;
  return (
    <div className="tablewrap resbox"><table><thead><tr>{cols.map((c) => <th key={c}>{c}</th>)}</tr></thead>
      <tbody>{rows.map((r, i) => <tr key={i}>{cols.map((c) => <td key={c} className={typeof r[c] === 'number' ? 'num r' : ''}>{cell(r[c])}</td>)}</tr>)}</tbody></table></div>
  );
}
const cell = (v: unknown) => (v == null ? '—' : typeof v === 'object' ? JSON.stringify(v) : tl(String(v)));
