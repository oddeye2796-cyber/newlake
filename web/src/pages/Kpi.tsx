import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { runQuery, type Otd, type PpmRow, type RiskRow, type UtilRow, type WipRow, type YieldRow } from '../api';
import { Spark } from '../components/charts';
import { Pill, State } from '../components/ui';
import { LOT_STATE, daysLeft, dLabel, fmtDate, n0, pct, riskPill } from '../format';
import { t } from '../i18n';
import { useApi } from '../useApi';

const byDate = <T extends { perf_date: string }>(rows: T[]) => {
  const m = new Map<string, T[]>(); rows.forEach((r) => m.set(r.perf_date, [...(m.get(r.perf_date) || []), r]));
  return [...m.entries()].sort((a, b) => a[0].localeCompare(b[0]));
};
const sum = (xs: number[]) => xs.reduce((a, b) => a + b, 0);

export default function Kpi() {
  const nav = useNavigate();
  const yld = useApi<YieldRow[]>('/api/kpi/yield');
  const ppm = useApi<PpmRow[]>('/api/kpi/ppm');
  const util = useApi<UtilRow[]>('/api/kpi/utilization?days=30');
  const otd = useApi<Otd>('/api/kpi/otd');
  const wip = useApi<WipRow[]>('/api/kpi/wip');
  const risks = useApi<RiskRow[]>('/api/kpi/risks');
  const [opName, setOpName] = useState<Record<string, string>>({});
  useEffect(() => { runQuery('SELECT operation_id, operation_name FROM ksx.operation').then((r) => setOpName(Object.fromEntries(r.rows.map((x) => [String(x.operation_id), String(x.operation_name)])))).catch(() => undefined); }, []);

  const yieldSeries = useMemo(() => byDate(yld.data || []).map(([d, rs]) => ({ d, v: (1 - sum(rs.map((r) => r.defect_qty)) / (sum(rs.map((r) => r.produced_qty)) || 1)) * 100 })), [yld.data]);
  const ppmSeries = useMemo(() => byDate(ppm.data || []).map(([d, rs]) => ({ d, v: (sum(rs.map((r) => r.defect_qty)) / (sum(rs.map((r) => r.produced_qty)) || 1)) * 1e6 })), [ppm.data]);
  const utilSeries = useMemo(() => byDate(util.data || []).map(([d, rs]) => ({ d, v: sum(rs.map((r) => r.time_util_pct)) / rs.length })), [util.data]);
  const opRows = useMemo(() => {
    const m = new Map<string, { produced: number; defect: number }>();
    (ppm.data || []).forEach((r) => { const c = m.get(r.operation_id) || { produced: 0, defect: 0 }; c.produced += r.produced_qty; c.defect += r.defect_qty; m.set(r.operation_id, c); });
    return [...m.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([op, c]) => ({ op, ...c, ppm: (c.defect / (c.produced || 1)) * 1e6 }));
  }, [ppm.data]);

  const last = <T extends { v: number }>(s: T[]) => (s.length ? s[s.length - 1].v : null);
  const delta = (s: { v: number }[], d: number, unit: string) => (s.length >= 2 ? `${s[s.length - 1].v >= s[s.length - 2].v ? '▲' : '▼'} ${Math.abs(s[s.length - 1].v - s[s.length - 2].v).toFixed(d)}${unit}` : t('비교할 이전 값 없음'));
  const trend = (s: { v: number }[], goodUp: boolean) => (s.length < 2 ? 'var(--muted)' : (s[s.length - 1].v >= s[s.length - 2].v) === goodUp ? 'var(--ok)' : 'var(--crit)');
  const tiles = [
    { l: t('양품률'), v: pct(last(yieldSeries), 2), d: delta(yieldSeries, 2, '%p'), s: yieldSeries.map((x) => x.v), c: trend(yieldSeries, true), ref: yieldSeries.at(-1)?.d },
    { l: t('불량 PPM'), v: last(ppmSeries) == null ? '—' : `${n0(last(ppmSeries))} PPM`, d: delta(ppmSeries, 0, ''), s: ppmSeries.map((x) => x.v), c: trend(ppmSeries, false), ref: ppmSeries.at(-1)?.d },
    { l: t('납기 준수'), v: pct(otd.data?.otd_pct), d: t('출고 완료 주문 기준'), s: [], c: 'var(--ok)', ref: undefined },
    { l: t('설비 가동률'), v: pct(last(utilSeries)), d: utilSeries.length ? delta(utilSeries, 1, '%p') : t('최근 30일 데이터 없음'), s: utilSeries.map((x) => x.v), c: trend(utilSeries, true), ref: utilSeries.at(-1)?.d },
  ];
  const orders = [...(otd.data?.orders || [])].sort((a, b) => a.requested_delivery_date.localeCompare(b.requested_delivery_date));
  const riskOrders = new Set((risks.data || []).map((r) => r.sales_order_id));
  const err = yld.error || ppm.error || otd.error || wip.error;

  return (
    <>
      <div className="head"><div><h1>{t('공장 현황')}</h1><p className="lede">{t('공정별로 어디가 평소와 다른지 봅니다. 숫자를 누르면 관련 항목으로 이동해요.')}</p></div>
        <div className="small muted">{yieldSeries.length ? t('{d} 기준 · {n}일 추이', { d: yieldSeries[yieldSeries.length - 1].d, n: yieldSeries.length }) : ''}</div></div>
      <State loading={yld.loading && ppm.loading} error={err} />
      <div className="grid g4">
        {tiles.map((k) => (
          <div className="panel kpi" key={k.l}>
            <span className="kl">{k.l}</span><span className="kv num">{k.v}</span>
            <span className="kd">{k.d}{k.ref ? <span className="muted"> · {fmtDate(k.ref)}</span> : null}</span>
            <Spark vals={k.s} color={k.c} />
          </div>
        ))}
      </div>
      <div className="grid g2" style={{ marginTop: 14 }}>
        <section className="panel"><header><h2>{t('공정별')}</h2></header>
          <div className="tablewrap"><table><thead><tr><th>{t('공정')}</th><th className="r">{t('생산')}</th><th className="r">{t('불량')}</th><th className="r">{t('불량 PPM')}</th></tr></thead><tbody>
            {opRows.map((r) => <tr key={r.op}><td><b>{opName[r.op] ?? r.op}</b><div className="small muted mono">{r.op}</div></td><td className="r num">{n0(r.produced)}</td><td className="r num">{n0(r.defect)}</td><td className="r num">{n0(r.ppm)}</td></tr>)}
            {opRows.length === 0 && <tr><td colSpan={4} className="muted">{t('집계된 실적이 없어요.')}</td></tr>}
          </tbody></table></div></section>
        <section className="panel"><header><h2>{t('진행 중인 로트')}</h2></header>
          <div className="tablewrap"><table><thead><tr><th>{t('공정')}</th><th>{t('상태')}</th><th className="r">{t('로트')}</th><th className="r">{t('수량')}</th><th className="r">{t('보류')}</th></tr></thead><tbody>
            {(wip.data || []).map((r, i) => <tr key={i}><td><b>{opName[r.current_operation_id] ?? r.current_operation_id}</b></td><td>{LOT_STATE[r.lot_state] ?? r.lot_state}</td><td className="r num">{r.lot_count}</td><td className="r num">{n0(r.wip_qty)}</td><td className="r num">{r.hold_lots ? <Pill cls="p-warn">{r.hold_lots}</Pill> : 0}</td></tr>)}
            {wip.data?.length === 0 && <tr><td colSpan={5} className="muted">{t('진행 중인 로트가 없어요.')}</td></tr>}
          </tbody></table></div></section>
      </div>
      <div className="grid g2" style={{ marginTop: 14 }}>
        <section className="panel"><header><h2>{t('납기가 가까운 주문')}</h2></header>
          <div className="tablewrap"><table><thead><tr><th>{t('주문')}</th><th>{t('고객 · 품목')}</th><th>{t('납기')}</th><th></th></tr></thead><tbody>
            {orders.map((o) => { const risk = riskOrders.has(o.sales_order_id); const d = daysLeft(o.requested_delivery_date);
              const st: [string, string] = o.on_time === true ? [t('납기 내'), 'p-ok'] : o.on_time === false ? [t('초과'), 'p-crit'] : risk ? [t('위험'), 'p-crit'] : [t('진행 중'), 'p-line'];
              return <tr key={o.sales_order_id} className="click" onClick={() => nav(`/find/order/${o.sales_order_id}`)}><td className="mono">{o.sales_order_id}</td><td>{o.customer_id}<div className="small muted">{o.item_id} {n0(o.ordered_qty)}</div></td><td className="num">{fmtDate(o.requested_delivery_date)}{o.on_time == null && <div className="small muted">{dLabel(d)}</div>}</td><td><Pill cls={st[1]}>{st[0]}</Pill></td></tr>; })}
            {orders.length === 0 && <tr><td colSpan={4} className="muted">{t('주문이 없어요.')}</td></tr>}
          </tbody></table></div></section>
        <section className="panel"><header><h2>{t('납기 위험 로트')}</h2></header>
          <div className="tablewrap"><table><thead><tr><th>{t('로트')}</th><th>{t('주문')}</th><th className="r">{t('불량률')}</th><th></th></tr></thead><tbody>
            {(risks.data || []).map((r) => <tr key={r.lot_id} className="click" onClick={() => nav(`/find/lot/${r.lot_id}`)}><td className="mono">{r.lot_id}</td><td className="mono">{r.sales_order_id}<div className="small muted">{t('납기 {date}', { date: fmtDate(r.requested_delivery_date) })}</div></td><td className="r num">{r.defect_rate_pct}%</td><td><Pill cls={riskPill(r.risk_level)[1]}>{riskPill(r.risk_level)[0]}</Pill></td></tr>)}
            {risks.data?.length === 0 && <tr><td colSpan={4} className="muted">{t('납기 위험 로트가 없어요.')}</td></tr>}
          </tbody></table></div></section>
      </div>
    </>
  );
}
