import type { ReactNode } from 'react';
import { useAuth } from '../../auth';
import { isAdminUser } from '../../api';
import { State } from '../../components/ui';
import { useApi } from '../../useApi';
import { locale, t } from '../../i18n';

export const ZONES = ['RAW', 'STANDARD', 'SEMANTIC', 'CURATED'] as const;
export const zoneName = (z: string): string | undefined => ({ RAW: t('원천'), STANDARD: t('표준'), SEMANTIC: t('시맨틱'), CURATED: t('활용') } as Record<string, string>)[z];
export const zoneColor = (z: string) => ({ RAW: 'var(--z-raw)', STANDARD: 'var(--z-std)', SEMANTIC: 'var(--z-sem)', CURATED: 'var(--z-cur)' } as Record<string, string>)[z] || 'var(--muted)';
export const ZoneChip = ({ z }: { z: string }) => <span className="zchip" style={{ ['--zc' as string]: zoneColor(z) }}>{zoneName(z) || z}</span>;

export const sensName = (s: string): string | undefined => ({ PUBLIC: t('공개'), INTERNAL: t('내부'), CONFIDENTIAL: t('기밀'), RESTRICTED: t('제한') } as Record<string, string>)[s];
export const qstatus = (s: string): [string, string] | undefined => ({ PASS: [t('적합'), 'p-ok'], WARN: [t('주의'), 'p-warn'], FAIL: [t('부적합'), 'p-crit'], UNKNOWN: [t('미측정'), 'p-line'] } as Record<string, [string, string]>)[s];
export const runStatus = (s: string): [string, string] | undefined => ({ SUCCESS: [t('성공'), 'p-ok'], RUNNING: [t('실행 중'), 'p-warn'], PARTIAL: [t('일부 실패'), 'p-warn'], FAILED: [t('실패'), 'p-crit'] } as Record<string, [string, string]>)[s];
export const violStatus = (s: string): [string, string] | undefined => ({ OPEN: [t('미처리'), 'p-crit'], ACK: [t('확인함'), 'p-warn'], RESOLVED: [t('해결'), 'p-ok'], WAIVED: [t('예외 처리'), 'p-line'] } as Record<string, [string, string]>)[s];
export const lastName = (iri: string | null | undefined) => (iri ? decodeURIComponent(iri.split('/').pop() || iri) : '—');
export const num = (v: number | null | undefined) => (v == null ? '—' : v.toLocaleString(locale()));

/** 관리 역할이 없으면 서버의 403 안내문을 그대로 보여 준다. */
export function AdminOnly({ children }: { children: ReactNode }) {
  const { me } = useAuth();
  const denied = !!me && !isAdminUser(me);
  const probe = useApi<unknown>(denied ? '/api/admin/overview' : null);
  if (!me) return <State loading error={null} />;
  if (denied) return <><div className="head"><h1>{t('데이터 관리')}</h1></div><State loading={probe.loading} error={probe.error ?? (probe.loading ? null : t(t('이 화면을 볼 권한이 없어요')))} /></>;
  return <>{children}</>;
}

export const Head = ({ title, lede, right }: { title: string; lede: string; right?: ReactNode }) => (
  <div className="head"><div><h1>{title}</h1><p className="lede">{lede}</p></div>{right}</div>
);
