import { Fragment, useEffect, useMemo, useState, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { runQuery, type EquipmentResp, type Kind, type Lot, type Otd, type RiskRow, type SearchHit, type UtilRow } from '../api';
import { Chip, Pill, State } from '../components/ui';
import { TraceChart } from '../components/charts';
import { LOT_STATE, KIND_KO, daysLeft, dLabel, defectLabel, execPill, fmtDate, fmtTs, n0, pct, riskPill } from '../format';
import { pushRecent } from '../recent';
import { equipmentSpecOutSql, lotGenealogySql } from '../askPresets';
import { useApi } from '../useApi';
import { t, tl } from '../i18n';

/** '{이름}' 자리표시자를 노드로 바꿔 끼운다 (문장 안에 JSX 가 들어갈 때) */
const rich = (s: string, m: Record<string, ReactNode>): ReactNode[] => s.split(/(\{\w+\})/).map((p, i) => (/^\{\w+\}$/.test(p) && p.slice(1, -1) in m ? <Fragment key={i}>{m[p.slice(1, -1)]}</Fragment> : p));

function Shell({ kindLabel, id, name, pills, children }: { kindLabel: string; id: string; name: ReactNode; pills?: ReactNode; children: ReactNode }) {
  return (
    <div className="panel">
      <header>
        <div><span className="small muted">{kindLabel}</span><h2 style={{ fontSize: 20 }}>{id}</h2><div className="muted">{name}</div></div>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>{pills}</div>
      </header>
      {children}
    </div>
  );
}
const Facts = ({ rows }: { rows: [string, ReactNode][] }) => (
  <dl className="kv facts">{rows.filter(([, v]) => v != null && v !== '').map(([k, v]) => <Fragment key={k}><dt>{k}</dt><dd>{v}</dd></Fragment>)}</dl>
);
const Links = ({ groups }: { groups: [string, ReactNode[]][] }) => {
  const g = groups.filter(([, v]) => v.length);
  if (!g.length) return null;
  return <><h3 className="sub">{t('연결된 항목')}</h3><div className="links">{g.map(([k, vs]) => <div key={k}><span className="small muted">{k}</span><div>{vs}</div></div>)}</div></>;
};
const Source = ({ children }: { children: ReactNode }) => <details className="tech"><summary>{t('데이터 출처')}</summary><p className="small">{children}</p></details>;
const num = (v: unknown) => (typeof v === 'number' ? v : null);
const str = (v: unknown) => (v == null ? null : String(v));

/* ---------- 로트 ---------- */
export function LotPage({ id }: { id: string }) {
  const { data, error, loading } = useApi<Lot>(`/api/lots/${encodeURIComponent(id)}`);
  useEffect(() => { if (data) pushRecent({ kind: 'lot', id, label: String(data.lot.lot_name ?? '') }); }, [data, id]);
  if (!data) return <State loading={loading} error={error} />;
  const l = data.lot;
  const created = num(l.lot_created_quantity), defect = num(l.defect_quantity), made = num(l.produced_quantity);
  const rate = created && defect != null ? (defect / created) * 100 : null;
  const pending = data.actions.some((a) => a.status === 'PROPOSED');
  const held = l.hold_indicator === true;
  const stateKo = LOT_STATE[String(l.lot_state)] || String(l.lot_state ?? '—');
  const maxDefect = Math.max(1, ...data.defects.map((d) => d.qty));
  const equipIds = [...new Set(data.spec_outs.map((s) => s.equipment_id).filter((x): x is string => !!x))];
  const sql = lotGenealogySql(id);
  const topRisk = data.risks[0];
  return (
    <Shell kindLabel={t('로트')} id={id} name={tl(str(l.lot_name))}
      pills={<>
        <Pill cls={held ? 'p-warn' : 'p-line'}>{held ? t('보류') : stateKo}</Pill>
        {topRisk && <Pill cls={riskPill(topRisk.risk_level)[1]}>{t('납기 위험 {lv}', { lv: riskPill(topRisk.risk_level)[0] })}</Pill>}
        {pending && <Pill cls="p-warn">{t('승인 대기')}</Pill>}
      </>}>
      <Facts rows={[
        [t('품목'), l.item_id ? `${tl(String(l.item_name ?? ''))} (${l.item_id})` : null],
        [t('투입 수량'), created != null ? `${n0(created)} EA` : null],
        [t('생산 / 불량'), made != null || defect != null ? `${n0(made)} / ${n0(defect)}${rate != null ? ` (${t('불량률 {rate}%', { rate: rate.toFixed(2) })})` : ''}` : null],
        [t('현재 공정'), l.current_operation_id ? `${tl(String(l.current_operation_name ?? ''))} (${l.current_operation_id})` : null],
        [t('상태'), stateKo],
        [t('시작'), l.lot_started_date_time ? fmtTs(String(l.lot_started_date_time)) : null],
      ]} />
      {data.spec_outs.length > 0 && <>
        <h3 className="sub">{t('기준을 벗어난 설비 측정값')}</h3>
        <div className="tablewrap"><table><thead><tr><th>{t('설비')}</th><th>{t('항목')}</th><th>{t('시각')}</th><th className="r">{t('측정값')}</th><th className="r">{t('기준')}</th></tr></thead>
          <tbody>{data.spec_outs.map((s, i) => <tr key={i}><td className="mono">{s.equipment_id}</td><td>{tl(s.parameter_name)}</td><td className="num">{fmtTs(s.event_date_time)}</td><td className="r num down">{s.parameter_value}</td><td className="r num">{s.lsl}~{s.usl}</td></tr>)}</tbody></table></div>
      </>}
      {data.defects.length > 0 && <>
        <h3 className="sub">{t('불량 유형')}</h3>
        {data.defects.map((d, i) => <div className="drow" key={i}><span>{defectLabel(d.defect_type_code, d.defect_type_detail_code)}</span><div className="bar" style={{ ['--bc' as string]: 'var(--crit)' }}><i style={{ width: `${(d.qty / maxDefect) * 100}%` }} /></div><span className="num">{d.qty}</span></div>)}
      </>}
      {data.risks.length > 0 && <>
        <h3 className="sub">{t('납기 위험')}</h3>
        {data.risks.map((r) => <div key={r.event_id} style={{ marginBottom: 6 }}><Pill cls={riskPill(r.risk_level)[1]}>{riskPill(r.risk_level)[0]}</Pill> <span className="small">{tl(r.detail.cause)} · {t('{ts} 감지', { ts: fmtTs(r.detected_at) })}</span></div>)}
      </>}
      <Links groups={[
        [t('모로트'), data.ancestors.map((a) => <Chip key={a.lot_id} kind="lot" id={a.lot_id} />)],
        [t('분할 로트'), data.descendants.map((a) => <Chip key={a.lot_id} kind="lot" id={a.lot_id} />)],
        [t('생산지시'), l.production_order_id ? [<span key="po" className="lchip">{String(l.production_order_id)}</span>] : []],
        [t('주문'), data.orders.map((o) => <Chip key={o.sales_order_id} kind="order" id={o.sales_order_id} />)],
        [t('고객'), [...new Set(data.orders.map((o) => o.customer_id))].map((c) => <Chip key={c} kind="customer" id={c} />)],
        [t('설비'), equipIds.map((e) => <Chip key={e} kind="equipment" id={e} />)],
        [t('품목'), l.item_id ? [<Chip key="i" kind="item" id={String(l.item_id)} />] : []],
      ]} />
      {data.orders.length > 0 && <>
        <h3 className="sub">{t('연결된 주문')}</h3>
        <div className="tablewrap"><table><thead><tr><th>{t('주문')}</th><th>{t('고객')}</th><th className="r">{t('수량')}</th><th>{t('납기')}</th></tr></thead>
          <tbody>{data.orders.map((o) => { const d = daysLeft(o.requested_delivery_date); return <tr key={o.sales_order_id}><td className="mono"><Link to={`/find/order/${o.sales_order_id}`}>{o.sales_order_id}</Link></td><td>{tl(o.customer_name) ?? o.customer_id}</td><td className="r num">{n0(o.item_quantity)}</td><td className="num">{fmtDate(o.requested_delivery_date)} <span className="muted">{dLabel(d)}</span></td></tr>; })}</tbody></table></div>
      </>}
      <h3 className="sub">{t('조치 이력')}</h3>
      {data.actions.length === 0 ? <p className="muted small">{t('이 로트에 대한 조치 요청이 없어요.')}</p> :
        <div className="tlist">{data.actions.map((a) => { const [et, c] = execPill(a.status); return (
          <div className="row" key={a.execution_id}><span><b>{t(a.action_label)}</b> <span className="small muted">{t('요청 {who}', { who: a.requested_by ?? '—' })}{a.approved_by ? ` · ${t('결정 {who}', { who: a.approved_by })}` : ''} · {fmtTs(a.created_at)}</span></span><Pill cls={c}>{et}</Pill></div>); })}
          {pending && <p className="small muted">{rich(t('승인 대기 중인 요청은 {link}에서 처리해요.'), { link: <Link to="/inbox">{t('요청함')}</Link> })}</p>}</div>}
      <div className="acts" style={{ marginTop: 16 }}>
        {sql && <Link className="btn" to={`/ask?q=${encodeURIComponent(sql)}`}>{t('계보를 질의로 보기')}</Link>}
      </div>
      <Source>{rich(t('MES 로트 이력 · 표준 분류 {cls} · 수집 {ts}', { ts: fmtTs(String(l.lake_loaded_at ?? '')) }), { cls: <span className="mono">ksx:Lot</span> })}</Source>
    </Shell>
  );
}

/* ---------- 설비 ---------- */
export function EquipmentPage({ id }: { id: string }) {
  const [days, setDays] = useState(7);
  const { data, error, loading } = useApi<EquipmentResp>(`/api/equipment/${encodeURIComponent(id)}?days=${days}`);
  const util = useApi<UtilRow[]>('/api/kpi/utilization?days=30');
  const [lots, setLots] = useState<string[]>([]);
  useEffect(() => { if (data) pushRecent({ kind: 'equipment', id, label: String(data.equipment.equipment_name ?? '') }); }, [data, id]);
  useEffect(() => {
    const sql = equipmentSpecOutSql(id); if (!sql) return;
    runQuery(sql).then((r) => setLots([...new Set(r.rows.map((x) => String(x.lot_id ?? '')).filter(Boolean))])).catch(() => setLots([]));
  }, [id]);
  const myUtil = useMemo(() => (util.data || []).filter((u) => u.equipment_id === id).sort((a, b) => b.perf_date.localeCompare(a.perf_date)), [util.data, id]);
  if (!data) return <State loading={loading} error={error} />;
  const e = data.equipment;
  const outs = data.trace.filter((t) => t.validation_result_code !== 'NORMAL');
  const sql = equipmentSpecOutSql(id);
  return (
    <Shell kindLabel={t('설비')} id={id} name={tl(str(e.equipment_name))}
      pills={<Pill cls={outs.length ? 'p-crit' : 'p-ok'}>{outs.length ? t('기준 초과 이력') : t('정상')}</Pill>}>
      <Facts rows={[
        [t('공정'), e.operation_id ? `${tl(String(e.operation_name ?? ''))} (${e.operation_id})` : null],
        [t('감시 항목'), data.parameters.length ? data.parameters.map((p) => t('{name} (기준 {lsl}~{usl}{uom})', { name: tl(p.parameter_name), lsl: p.lsl ?? '—', usl: p.usl ?? '—', uom: p.parameter_uom_code ?? '' })).join(', ') : null],
        [t('최근 초과'), outs.length ? outs.map((o) => `${fmtTs(o.event_date_time).slice(5)} ${o.parameter_value}`).join(', ') : t('최근 {days}일 없음', { days })],
        [t('가동률'), myUtil[0] ? `${pct(myUtil[0].time_util_pct)} (${fmtDate(myUtil[0].perf_date)})` : null],
      ]} />
      <div className="daysel" style={{ marginTop: 10 }}>
        <span className="small muted">{t('조회 기간')}</span>
        {[1, 7, 30].map((d) => <button key={d} type="button" className="chip" aria-pressed={days === d} onClick={() => setDays(d)}>{d === 1 ? t('하루') : t('{n}일', { n: d })}</button>)}
      </div>
      {data.parameters.length === 0 && <p className="muted small">{t('등록된 감시 항목이 없어요.')}</p>}
      {data.parameters.map((p) => (
        <div key={p.parameter_id}>
          <h3 className="sub">{t('{name} 추이 · 최근 {days}일', { name: tl(p.parameter_name), days })}</h3>
          <TraceChart pts={data.trace.filter((t) => t.parameter_id === p.parameter_id).map((t) => ({ t: t.event_date_time, v: t.parameter_value }))} lsl={p.lsl} usl={p.usl} unit={p.parameter_uom_code ?? ''} name={p.parameter_name} />
        </div>
      ))}
      {lots.length > 0 && <p className="small muted">{t('기준을 벗어난 시각에 진행 중이던 로트:')} {lots.map((l) => <Chip key={l} kind="lot" id={l} />)}</p>}
      <div className="acts" style={{ marginTop: 16 }}>
        {sql && <Link className="btn" to={`/ask?q=${encodeURIComponent(sql)}`}>{t('기준 이탈 값을 질의로 보기')}</Link>}
      </div>
      <Source>{rich(t('설비 파라미터 이력(EAP), 설비 마스터 · 표준 분류 {a}, {b}'), { a: <span className="mono">ksx:Equipment</span>, b: <span className="mono">ksx:TraceParameter</span> })}</Source>
    </Shell>
  );
}

/* ---------- 주문 / 품목 / 고객 ---------- */
const useHit = (q: string | null | undefined) => {
  const r = useApi<{ results: SearchHit[] }>(q ? `/api/search?q=${encodeURIComponent(q)}` : null);
  return (id: string) => r.data?.results.find((x) => x.id === id) ?? null;
};

export function OrderPage({ id }: { id: string }) {
  const otd = useApi<Otd>('/api/kpi/otd');
  const risks = useApi<RiskRow[]>('/api/kpi/risks');
  const o = otd.data?.orders.find((x) => x.sales_order_id === id);
  const cust = useHit(o?.customer_id)(o?.customer_id ?? '');
  const item = useHit(o?.item_id)(o?.item_id ?? '');
  useEffect(() => { if (o) pushRecent({ kind: 'order', id, label: cust?.label ?? o.customer_id }); }, [o, id, cust]);
  if (!otd.data) return <State loading={otd.loading} error={otd.error} />;
  if (!o) return <div className="panel state err">{t('{kind} {id}을(를) 찾을 수 없거나 볼 수 있는 범위 밖이에요.', { kind: KIND_KO.order, id })}</div>;
  const myRisks = (risks.data || []).filter((r) => r.sales_order_id === id);
  const left = daysLeft(o.requested_delivery_date);
  const status: [string, string] = o.on_time === true ? [t('납기 내 출고'), 'p-ok'] : o.on_time === false ? [t('납기 초과'), 'p-crit']
    : myRisks.length ? [t('납기 위험'), 'p-crit'] : [t('진행 중'), 'p-line'];
  return (
    <Shell kindLabel={t('주문')} id={id} name={`${cust?.label ?? o.customer_id} · ${item?.label ?? o.item_id}`} pills={<Pill cls={status[1]}>{status[0]}</Pill>}>
      <Facts rows={[
        [t('고객'), `${cust?.label ?? ''} (${o.customer_id})`],
        [t('품목'), `${item?.label ?? ''} (${o.item_id})`],
        [t('주문 수량'), `${n0(o.ordered_qty)} EA`],
        [t('납기'), `${fmtDate(o.requested_delivery_date)}${o.on_time == null && left != null ? ` (${left >= 0 ? t('{n}일 남음', { n: left }) : t('{n}일 지남', { n: -left })})` : ''}`],
        [t('출고'), o.fulfilled_date ? `${fmtDate(o.fulfilled_date)} (${n0(o.released_qty)} EA)` : t('아직 출고 전 (출고 {n} EA)', { n: n0(o.released_qty) })],
        [t('위험 이유'), myRisks.length ? myRisks.map((r) => t('연결된 로트 {lot} 불량률 {rate}% (위험도 {lv})', { lot: r.lot_id, rate: r.defect_rate_pct, lv: riskPill(r.risk_level)[0] })).join(' / ') : null],
      ]} />
      <Links groups={[
        [t('로트'), myRisks.map((r) => <Chip key={r.lot_id} kind="lot" id={r.lot_id} />)],
        [t('고객'), [<Chip key="c" kind="customer" id={o.customer_id} />]],
        [t('품목'), [<Chip key="i" kind="item" id={o.item_id} />]],
      ]} />
      <Source>{rich(t('ERP 수주, 출하 실적 · 표준 분류 {cls} · 납기 준수 집계 {view}'), { cls: <span className="mono">ksx:SalesOrder</span>, view: <span className="mono">mart.v_kpi_otd</span> })}</Source>
    </Shell>
  );
}

export function SimplePage({ kind, id }: { kind: Kind; id: string }) {
  const search = useApi<{ results: SearchHit[] }>(`/api/search?q=${encodeURIComponent(id)}`);
  const otd = useApi<Otd>('/api/kpi/otd');
  const hit = search.data?.results.find((x) => x.kind === kind && x.id === id);
  useEffect(() => { if (hit) pushRecent({ kind, id, label: hit.label }); }, [hit, kind, id]);
  if (!search.data) return <State loading={search.loading} error={search.error} />;
  if (!hit) return <div className="panel state err">{t('{kind} {id}을(를) 찾을 수 없거나 볼 수 있는 범위 밖이에요.', { kind: KIND_KO[kind] ?? kind, id })}</div>;
  const orders = (otd.data?.orders || []).filter((x) => (kind === 'customer' ? x.customer_id === id : kind === 'item' ? x.item_id === id : false));
  return (
    <Shell kindLabel={KIND_KO[kind] ?? kind} id={id} name={tl(hit.label)}>
      <Facts rows={[[t('이름'), tl(hit.label)], [kind === 'item' ? t('단위') : t('비고'), tl(hit.sub)]]} />
      <Links groups={[[t('주문'), orders.map((x) => <Chip key={x.sales_order_id} kind="order" id={x.sales_order_id} />)]]} />
      <Source>{rich(t('MES·ERP 기준 정보 · 표준 분류 {cls}'), { cls: <span className="mono">{kind === 'item' ? 'ksx:ItemMaster' : 'ksx:CustomerPartyMaster'}</span> })}</Source>
    </Shell>
  );
}
