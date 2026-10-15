import { useEffect, useMemo } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import type { AdminDatasetDetail, AdminOverview, LineageEdge } from '../../api';
import { Pill, State, Tier } from '../../components/ui';
import { fmtTs, n0 } from '../../format';
import { useApi } from '../../useApi';
import { t } from '../../i18n';
import { Head, ZONES, ZoneChip, lastName, runStatus, zoneColor, zoneName } from './common';

interface Node { id: string; title: string; zone: string }
const clip = (s: string, n: number) => (s.length > n ? s.slice(0, n - 1) + '…' : s);

function reach(edges: LineageEdge[], start: string, dir: 'up' | 'down') {
  const seen = new Set<string>(), st = [start];
  while (st.length) { const x = st.pop()!; edges.forEach((e) => { const [a, b] = dir === 'up' ? [e.to_dataset_id, e.from_dataset_id] : [e.from_dataset_id, e.to_dataset_id]; if (a === x && !seen.has(b)) { seen.add(b); st.push(b); } }); }
  return seen;
}

function FieldRows({ e }: { e: LineageEdge }) {
  const { data } = useApi<AdminDatasetDetail>(`/api/admin/datasets/${encodeURIComponent(e.to_dataset_id)}`);
  const fm = e.field_map ?? {};
  return <>{Object.entries(fm).flatMap(([col, srcs]) => srcs.map((s) => {
    const prop = data?.fields.find((f) => f.field_name === col)?.maps_to_property_iri;
    return (
      <tr key={`${e.edge_id}-${col}-${s}`}>
        <td className="mono">{lastName(e.from_dataset_id)}.{s}</td><td className="mono">{lastName(e.to_dataset_id)}.{col}</td>
        <td className="mono">{prop ? `ksx:${lastName(prop)}` : '—'}</td><td><Tier t="ASSERTED" /></td>
      </tr>);
  }))}</>;
}

export default function Lineage() {
  const [sp, setSp] = useSearchParams();
  const { data, error, loading } = useApi<{ edges: LineageEdge[] }>('/api/admin/lineage');
  const ov = useApi<AdminOverview>('/api/admin/overview');
  useEffect(() => { document.title = `${t('계보')} · ${'ARCON'}`; }, []);
  const edges = useMemo(() => data?.edges ?? [], [data]);
  const nodes = useMemo(() => {
    const m = new Map<string, Node>();
    edges.forEach((e) => { m.set(e.from_dataset_id, { id: e.from_dataset_id, title: e.from_title, zone: e.from_zone }); m.set(e.to_dataset_id, { id: e.to_dataset_id, title: e.to_title, zone: e.to_zone }); });
    return m;
  }, [edges]);
  const want = sp.get('ds');
  const sel = want && nodes.has(want) ? want : nodes.has('std.lot') ? 'std.lot' : [...nodes.keys()][0];
  const pick = (id: string) => setSp({ ds: id });

  const W = 980, colX: Record<string, number> = { RAW: 110, STANDARD: 364, SEMANTIC: 618, CURATED: 870 }, nh = 44, gap = 14, bw = 196;
  const cols = Object.fromEntries(ZONES.map((z) => [z, [...nodes.values()].filter((n) => n.zone === z)])) as Record<string, Node[]>;
  const maxN = Math.max(1, ...Object.values(cols).map((a) => a.length));
  const H = 50 + maxN * (nh + gap);
  const P = new Map<string, { x: number; y: number }>();
  ZONES.forEach((z) => { const a = cols[z], tot = a.length * (nh + gap) - gap, y0 = 50 + (H - 50 - tot) / 2; a.forEach((n, i) => P.set(n.id, { x: colX[z], y: y0 + i * (nh + gap) + nh / 2 })); });
  const hi = useMemo(() => (sel ? new Set([sel, ...reach(edges, sel, 'up'), ...reach(edges, sel, 'down')]) : new Set<string>()), [edges, sel]);
  const selNode = sel ? nodes.get(sel) : undefined;
  const producing = edges.filter((e) => e.to_dataset_id === sel);
  const pipes = [...new Map(producing.filter((e) => e.pipeline_id).map((e) => [e.pipeline_id!, e])).values()];
  const withMap = edges.filter((e) => e.field_map && Object.keys(e.field_map).length);

  return (
    <>
      <Head title={t('계보')} lede={t('원천에서 활용까지 데이터가 어떤 작업과 매핑을 거쳐 왔는지 기록해요. 노드를 누르면 연결 경로와 작업 실행 정보를 봅니다.')} />
      <State loading={loading} error={error} />
      {data && edges.length === 0 && <div className="panel muted">{t('기록된 계보가 없어요.')}</div>}
      {edges.length > 0 && <>
        <section className="panel lineage"><div style={{ overflowX: 'auto' }}>
          <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label={t('데이터 계보 그래프')}>
            {ZONES.map((z) => <text key={z} className="lhead" x={colX[z]} y={22} textAnchor="middle" fill={zoneColor(z)}>{t('{zone} 존', { zone: zoneName(z) ?? z })}</text>)}
            {edges.map((e) => {
              const A = P.get(e.from_dataset_id)!, B = P.get(e.to_dataset_id)!, x1 = A.x + bw / 2, x2 = B.x - bw / 2, mx = (x1 + x2) / 2;
              const on = hi.has(e.from_dataset_id) && hi.has(e.to_dataset_id);
              return <path key={e.edge_id} className={`ledge ${on ? 'hi' : ''}`} d={`M${x1} ${A.y} C${mx} ${A.y} ${mx} ${B.y} ${x2} ${B.y}`}><title>{e.pipeline_label ?? e.pipeline_id}</title></path>;
            })}
            {[...nodes.values()].map((n) => {
              const p = P.get(n.id)!;
              return (
                <g key={n.id} className={`lnode ${n.id === sel ? 'sel' : ''}`} style={{ ['--zc' as string]: zoneColor(n.zone) }} tabIndex={0} role="button" aria-label={n.title} onClick={() => pick(n.id)} onKeyDown={(e) => { if (e.key === 'Enter') pick(n.id); }}>
                  <rect x={p.x - bw / 2} y={p.y - nh / 2} width={bw} height={nh} rx={6} opacity={hi.has(n.id) ? undefined : 0.55} />
                  <text x={p.x - bw / 2 + 10} y={p.y - 3}>{clip(n.title, 14)}</text><text className="sub" x={p.x - bw / 2 + 10} y={p.y + 12}>{clip(n.id, 30)}</text>
                </g>);
            })}
          </svg></div></section>
        <div className="grid g2" style={{ marginTop: 14 }}>
          <section className="panel">
            {selNode && <>
              <header><div><h2>{selNode.title}</h2><div className="mono muted">{selNode.id}</div></div><ZoneChip z={selNode.zone} /></header>
              {pipes.length === 0 ? <p className="muted">{t('원천 존 데이터셋이에요. 외부 시스템에서 들어오며 바뀌지 않아요.')}</p> : pipes.map((e) => {
                const p = ov.data?.pipelines.find((x) => x.pipeline_id === e.pipeline_id);
                const [st, stc] = runStatus(p?.last_status ?? '') || [p?.last_status ?? '—', 'p-line'];
                return (
                  <dl key={e.pipeline_id} className="kv" style={{ marginBottom: 10 }}>
                    <dt>{t('생성 작업')}</dt><dd>{e.pipeline_label ?? e.pipeline_id}</dd>
                    <dt>{t('입력')}</dt><dd>{producing.filter((x) => x.pipeline_id === e.pipeline_id).map((x) => x.from_title).join(', ')}</dd>
                    {p && <><dt>{t('엔진')}</dt><dd>{p.engine} · {p.schedule_cron ?? t('수동')}</dd><dt>{t('최근 실행')}</dt><dd><Pill cls={stc}>{st}</Pill> {fmtTs(p.last_ended_at ?? p.last_started_at)}</dd>
                      <dt>{t('처리량')}</dt><dd className="num">{t('입력 {a} · 출력 {b} · 거부 {c}', { a: n0(p.rows_in), b: n0(p.rows_out), c: n0(p.rows_rejected) })}</dd>
                      {p.error_message && <><dt>{t('오류')}</dt><dd style={{ color: 'var(--crit)' }}>{p.error_message}</dd></>}</>}
                  </dl>);
              })}
              <Link className="btn" to={`/admin/catalog/${encodeURIComponent(selNode.id)}`}>{t('카탈로그에서 열기')}</Link>
            </>}
          </section>
          <section className="panel">
            <header><h2>{t('필드 단위 계보 예시')}</h2><span className="small muted">catalog.lineage_edge.field_map</span></header>
            {withMap.length === 0 ? <p className="muted small">{t('필드 단위 매핑이 기록된 계보가 없어요.')}</p> : (
              <div className="tablewrap"><table><thead><tr><th>{t('원천 필드')}</th><th>{t('표준 컬럼')}</th><th>{t('온톨로지 속성')}</th><th>{t('등급')}</th></tr></thead><tbody>
                {withMap.map((e) => <FieldRows key={e.edge_id} e={e} />)}
              </tbody></table></div>)}
          </section>
        </div>
      </>}
    </>
  );
}
