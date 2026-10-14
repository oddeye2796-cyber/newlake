import { Database, KeyRound, Network, ShieldAlert, Siren, type LucideIcon } from 'lucide-react';
import { useEffect } from 'react';
import { Link } from 'react-router-dom';
import type { AdminOverview } from '../../api';
import { Pill, State, Tier } from '../../components/ui';
import { daysLeft, fmtTs, n0, riskPill } from '../../format';
import { useApi } from '../../useApi';
import { Head, RUN_STATUS, ZONE_KO, lastName, num, zoneColor } from './common';

export default function Overview() {
  const { data, error, loading } = useApi<AdminOverview>('/api/admin/overview');
  useEffect(() => { document.title = '오늘의 레이크 · 뉴레이크'; }, []);
  const c = data?.counts;
  const tiles: [string, number | undefined, string, string, LucideIcon, string][] = [
    ['데이터셋', c?.datasets, '/admin/catalog', '카탈로그 보기', Database, 'var(--accent)'],
    ['온톨로지 클래스', c?.classes, '/admin/ontology', `속성 ${num(c?.properties)}개`, Network, 'var(--info)'],
    ['미처리 품질 위반', c?.open_violations, '/admin/quality', '품질 검증 보기', ShieldAlert, 'var(--warn)'],
    ['승인 대기 접근 요청', c?.pending_access, '/admin/access', '권한·감사 보기', KeyRound, 'var(--ok)'],
    ['열린 위험', c?.open_risks, '/admin', '규칙이 잡아낸 위험', Siren, 'var(--crit)'],
  ];
  return (
    <>
      <Head title="오늘의 레이크" lede="존별 적재 현황과 온톨로지 규칙이 잡아낸 위험을 한 화면에서 봅니다." />
      <State loading={loading} error={error} />
      {data && <>
        <div className="zones">
          {data.zones.map((z) => (
            <div key={z.zone_id} className="zone" style={{ ['--zc' as string]: zoneColor(z.zone_id) }}>
              <div className="zn">{z.label_ko}</div><div className="zv num">데이터셋 {num(z.datasets)}</div>
              <div className="zs">레코드 {z.records == null ? '집계 없음' : n0(z.records)}</div><span className="arrow" aria-hidden="true">›</span>
            </div>))}
        </div>
        <div className="grid g5" style={{ marginTop: 16 }}>
          {tiles.map(([l, v, to, s, Icon, color]) => (
            <Link key={l} className="kcard" to={to} style={{ ['--kc' as string]: color }}>
              <span className="ki" aria-hidden="true"><Icon /></span>
              <span className="kl">{l}</span><span className="kv num">{num(v)}</span><span className="kd">{s}</span>
            </Link>))}
        </div>
        <div className="grid g3" style={{ marginTop: 16, alignItems: 'start' }}>
          <section className="panel span2">
            <header><h2>규칙이 잡아낸 위험</h2><span className="small muted">열린 위험 {data.risks.length}건</span></header>
            <div className="alerts">
              {data.risks.length === 0 && <p className="muted small">열린 위험이 없어요.</p>}
              {data.risks.map((r) => {
                const x = r.detail, left = daysLeft(x.requested_delivery_date), [lv, lvc] = riskPill(r.risk_level);
                return (
                  <article key={r.event_id} className="alert task" style={{ ['--sc' as string]: 'var(--crit)' }}>
                    <span className="sev" />
                    <div>
                      <b>납기 위험 · 주문 {x.sales_order_id ?? '—'} ({x.customer_id ?? '—'}{left != null ? `, ${left >= 0 ? `${left}일 남음` : `${-left}일 지남`}` : ''})</b>
                      <p>로트 {x.lot_id ?? '—'} 불량률 {x.defect_rate_pct ?? '—'}%. {x.cause ?? ''}</p>
                      <div className="meta"><Pill cls={lvc}>위험도 {lv}</Pill><Tier t="INFERRED" />{r.derived_by && <Pill>규칙 {lastName(r.derived_by)}</Pill>}<Pill>{fmtTs(r.detected_at)}</Pill></div>
                    </div>
                    <div className="acts">{x.lot_id && <Link className="btn" to={`/find/lot/${x.lot_id}`}>로트 보기</Link>}<Link className="btn" to="/admin/lineage">계보</Link></div>
                  </article>);
              })}
            </div>
          </section>
          <section className="panel">
            <header><h2>파이프라인</h2><span className="small muted">{data.pipelines.length}개</span></header>
            <div className="tablewrap"><table><thead><tr><th>작업</th><th>상태</th></tr></thead><tbody>
              {data.pipelines.map((p) => {
                const [st, stc] = RUN_STATUS[p.last_status ?? ''] || [p.last_status ?? '실행 기록 없음', 'p-line'];
                return (
                  <tr key={p.pipeline_id}>
                    <td>{p.label_ko}<div className="small muted">{ZONE_KO[p.from_zone] ?? p.from_zone} → {ZONE_KO[p.to_zone] ?? p.to_zone} · {p.engine} · {p.schedule_cron ?? '수동'}{p.enabled ? '' : ' · 꺼짐'}</div></td>
                    <td><Pill cls={stc}>{st}</Pill>
                      <div className="small muted">{fmtTs(p.last_ended_at ?? p.last_started_at)}</div>
                      {p.rows_in != null && <div className="small muted num">입력 {n0(p.rows_in)} · 출력 {n0(p.rows_out)}{p.rows_rejected ? ` · 거부 ${n0(p.rows_rejected)}` : ''}</div>}
                      {p.error_message && <div className="small" style={{ color: 'var(--crit)' }}>{p.error_message}</div>}</td>
                  </tr>);
              })}
            </tbody></table></div>
          </section>
        </div>
      </>}
    </>
  );
}
