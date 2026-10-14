import type { ReactNode } from 'react';
import { useAuth } from '../../auth';
import { isAdminUser } from '../../api';
import { State } from '../../components/ui';
import { useApi } from '../../useApi';

export const ZONES = ['RAW', 'STANDARD', 'SEMANTIC', 'CURATED'] as const;
export const ZONE_KO: Record<string, string> = { RAW: '원천', STANDARD: '표준', SEMANTIC: '시맨틱', CURATED: '활용' };
export const zoneColor = (z: string) => ({ RAW: 'var(--z-raw)', STANDARD: 'var(--z-std)', SEMANTIC: 'var(--z-sem)', CURATED: 'var(--z-cur)' } as Record<string, string>)[z] || 'var(--muted)';
export const ZoneChip = ({ z }: { z: string }) => <span className="zchip" style={{ ['--zc' as string]: zoneColor(z) }}>{ZONE_KO[z] || z}</span>;

export const SENS_KO: Record<string, string> = { PUBLIC: '공개', INTERNAL: '내부', CONFIDENTIAL: '기밀', RESTRICTED: '제한' };
export const QSTATUS: Record<string, [string, string]> = { PASS: ['적합', 'p-ok'], WARN: ['주의', 'p-warn'], FAIL: ['부적합', 'p-crit'], UNKNOWN: ['미측정', 'p-line'] };
export const RUN_STATUS: Record<string, [string, string]> = { SUCCESS: ['성공', 'p-ok'], RUNNING: ['실행 중', 'p-warn'], PARTIAL: ['일부 실패', 'p-warn'], FAILED: ['실패', 'p-crit'] };
export const VIOL_STATUS: Record<string, [string, string]> = { OPEN: ['미처리', 'p-crit'], ACK: ['확인함', 'p-warn'], RESOLVED: ['해결', 'p-ok'], WAIVED: ['예외 처리', 'p-line'] };
export const lastName = (iri: string | null | undefined) => (iri ? decodeURIComponent(iri.split('/').pop() || iri) : '—');
export const num = (v: number | null | undefined) => (v == null ? '—' : v.toLocaleString('ko-KR'));

/** 관리 역할이 없으면 서버의 403 안내문을 그대로 보여 준다. */
export function AdminOnly({ children }: { children: ReactNode }) {
  const { me } = useAuth();
  const denied = !!me && !isAdminUser(me);
  const probe = useApi<unknown>(denied ? '/api/admin/overview' : null);
  if (!me) return <State loading error={null} />;
  if (denied) return <><div className="head"><h1>데이터 관리</h1></div><State loading={probe.loading} error={probe.error ?? (probe.loading ? null : '이 화면을 볼 권한이 없어요')} /></>;
  return <>{children}</>;
}

export const Head = ({ title, lede, right }: { title: string; lede: string; right?: ReactNode }) => (
  <div className="head"><div><h1>{title}</h1><p className="lede">{lede}</p></div>{right}</div>
);
