import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import type { AdminClassDetail, AdminClassRow, AdminDatasetDetail, AdminDatasetRow } from '../../api';
import { Pill, State, Tier } from '../../components/ui';
import { fmtTs } from '../../format';
import { useApi } from '../../useApi';
import { Head, QSTATUS, SENS_KO, ZONES, ZONE_KO, ZoneChip, lastName, num } from './common';

type Tab = 'schema' | 'rel' | 'quality' | 'lineage';
const TABS: [Tab, string][] = [['schema', '스키마'], ['rel', '관계'], ['quality', '품질'], ['lineage', '계보']];

function Detail({ id, index }: { id: string; index: Map<string, AdminDatasetRow> }) {
  const { data, error, loading } = useApi<AdminDatasetDetail>(`/api/admin/datasets/${encodeURIComponent(id)}`);
  const [tab, setTab] = useState<Tab>('schema');
  const d = data?.dataset;
  const cls = d?.represents_class_iri ? lastName(d.represents_class_iri) : null;
  const rel = useApi<AdminClassDetail>(tab === 'rel' && cls ? `/api/admin/ontology/classes/${encodeURIComponent(cls)}` : null);
  if (!data || !d) return <section className="panel"><State loading={loading} error={error} /></section>;
  const [qs, qsc] = QSTATUS[d.quality_status] || [d.quality_status, 'p-line'];
  const run = data.quality_runs[0];
  const refTitle = (x: string) => index.get(x)?.title_ko ?? x;
  const refList = (rows: AdminDatasetDetail['upstream']) => rows.length === 0 ? <p className="small muted">기록 없음</p> : (
    <div className="rel">{rows.map((r) => (
      <Link key={r.dataset_id + (r.pipeline_id ?? '')} to={`/admin/catalog/${encodeURIComponent(r.dataset_id)}`} style={{ textDecoration: 'none', color: 'inherit', display: 'grid', gridTemplateColumns: 'minmax(0,1fr) auto', gap: 8, padding: '4px 6px' }}>
        <span>{refTitle(r.dataset_id)} <code className="mono muted">{r.dataset_id}</code>{r.pipeline_id && <span className="small muted"> · {r.pipeline_id}</span>}</span>
        {index.get(r.dataset_id) && <ZoneChip z={index.get(r.dataset_id)!.zone_id} />}
      </Link>))}</div>);
  return (
    <section className="panel">
      <header><div><h2>{d.title_ko}</h2><div className="mono muted">{d.dataset_id}</div></div><ZoneChip z={d.zone_id} /></header>
      <dl className="kv" style={{ marginBottom: 12 }}>
        <dt>표현 클래스</dt><dd>{cls ? <><Link to={`/admin/ontology/${cls}`}>ksx:{cls}</Link> · {d.class_label}</> : '—'}</dd>
        <dt>원천</dt><dd>{d.source_label ?? d.source_system_id ?? '—'}{d.ingest_mode ? ` · ${d.ingest_mode}` : ''}{d.schedule_cron ? ` · ${d.schedule_cron}` : ''}</dd>
        <dt>형식</dt><dd>{d.format ?? '—'} · 레코드 <span className="num">{num(d.record_count)}</span></dd>
        <dt>위치</dt><dd className="mono small">{d.location_uri ?? '—'}</dd>
        <dt>최근 적재</dt><dd>{fmtTs(d.last_ingested_at)}</dd>
        <dt>품질</dt><dd><Pill cls={qsc}>{qs}</Pill>{d.quality_score != null && <span className="num"> {d.quality_score}%</span>}</dd>
        <dt>민감도</dt><dd>{SENS_KO[d.sensitivity] ?? d.sensitivity}{d.pseudonymized ? ' · 가명처리' : ''}{d.retention ? ` · 보존 ${d.retention}` : ''}</dd>
        <dt>담당</dt><dd>소유 {d.owner_user_id ?? '—'} · 스튜어드 {d.steward_user_id ?? '—'}</dd>
        {d.description && <><dt>설명</dt><dd>{d.description}</dd></>}
      </dl>
      <div className="tabs" role="tablist">{TABS.map(([k, n]) => <button key={k} type="button" role="tab" aria-selected={tab === k} onClick={() => setTab(k)}>{n}</button>)}</div>
      {tab === 'schema' && <>
        {data.fields.length > 0 ? (
          <div className="tablewrap" style={{ maxHeight: 420, overflow: 'auto' }}><table><thead><tr><th>컬럼</th><th>타입</th><th>온톨로지 속성</th><th>매핑</th></tr></thead><tbody>
            {data.fields.map((f) => (
              <tr key={f.field_name}>
                <td><span className="mono">{f.field_name}</span>{f.is_pk && <> <Pill>PK</Pill></>}<div className="small muted">{f.label_ko ?? ''}{f.is_required ? ' · 필수' : ''}</div></td>
                <td className="mono small">{f.data_type ?? '—'}</td>
                <td className="mono small">{f.maps_to_property_iri ? `ksx:${lastName(f.maps_to_property_iri)}` : <span className="muted">레이크 메타</span>}</td>
                <td className="small">{f.mapping_method ?? '—'}{f.mapping_confidence != null ? ` · ${f.mapping_confidence}` : ''}{f.mapping_status ? ` · ${f.mapping_status}` : ''}</td>
              </tr>))}
          </tbody></table></div>
        ) : <p className="muted">컬럼 목록이 등록되지 않은 데이터셋이에요. {d.zone_id === 'RAW' ? '원천 포맷 그대로 보관하며 스키마는 매핑 버전에 기록돼요.' : d.zone_id === 'SEMANTIC' ? 'RDF 트리플 저장소라 클래스 구조는 온톨로지 화면에서 봐요.' : ''}</p>}
        {data.mappings.length > 0 && <>
          <h3 className="sub">매핑 버전</h3>
          <div className="tablewrap"><table><thead><tr><th>매핑</th><th>대상 클래스</th><th>상태</th><th className="r">F1</th></tr></thead><tbody>
            {data.mappings.map((m) => (
              <tr key={m.mapping_id}><td><span className="mono small">{m.mapping_id}</span><div className="small muted">{m.kind} v{m.version_no}</div></td><td className="mono small">ksx:{lastName(m.target_class_iri)}</td>
                <td><Pill cls={m.status === 'APPROVED' ? 'p-ok' : 'p-warn'}>{m.status}</Pill>{m.approved_by && <div className="small muted">{m.approved_by} · {fmtTs(m.approved_at)}</div>}</td><td className="r num">{m.f1_score ?? '—'}</td></tr>))}
          </tbody></table></div></>}
      </>}
      {tab === 'rel' && (!cls ? <p className="muted">이 데이터셋은 단일 클래스를 표현하지 않아요.</p> : <>
        <State loading={rel.loading} error={rel.error} />
        {rel.data && (() => {
          const out = rel.data.links.filter((l) => l.subject_class_iri === rel.data!.class.class_iri), inc = rel.data.links.filter((l) => l.object_class_iri === rel.data!.class.class_iri && l.subject_class_iri !== l.object_class_iri);
          const row = (l: typeof out[number], other: string, label: string, arrow: string, i: number) => (
            <Link key={`${arrow}${i}${l.property_iri}`} to={`/admin/ontology/${lastName(other)}`} style={{ textDecoration: 'none', color: 'inherit', display: 'grid', gridTemplateColumns: 'minmax(0,1fr) auto', gap: 8, padding: '4px 6px' }}>
              <span>{arrow} {label} <code className="mono muted">ksx:{l.property_name}</code></span><span className="small muted">{l.relation_kind}</span></Link>);
          return <><h3>나가는 관계 {out.length}</h3><div className="rel">{out.map((l, i) => row(l, l.object_class_iri, l.object_label, '→', i))}</div>
            <h3 style={{ marginTop: 12 }}>들어오는 관계 {inc.length}</h3><div className="rel">{inc.map((l, i) => row(l, l.subject_class_iri, l.subject_label, '←', i))}</div></>;
        })()}
      </>)}
      {tab === 'quality' && (!run && d.quality_status === 'UNKNOWN' ? <p className="muted">이 데이터셋에서 아직 품질 검증을 실행하지 않았어요.</p> : <>
        {run ? <>
          <dl className="kv"><dt>최근 실행</dt><dd>{fmtTs(run.executed_at)}</dd><dt>검사 대상</dt><dd className="num">{num(run.focus_count)}건</dd><dt>위반</dt><dd className="num">{num(run.violation_count)}건</dd>
            <dt>적합률</dt><dd className="num">{run.conformance_rate ?? '—'}%</dd></dl>
          {run.conformance_rate != null && <div className="bar" style={{ margin: '10px 0', ['--bc' as string]: run.conformance_rate < 99 ? 'var(--warn)' : 'var(--ok)' }}><i style={{ width: `${run.conformance_rate}%` }} /></div>}
          <Link className="btn" to="/admin/quality">품질 검증에서 보기</Link></> : <p className="muted">실행 기록이 없어요.</p>}
      </>)}
      {tab === 'lineage' && <>
        <h3>상류</h3>{refList(data.upstream)}<h3 style={{ marginTop: 12 }}>하류</h3>{refList(data.downstream)}
        {data.upstream.some((u) => u.field_map) && <p className="note">필드 단위 매핑 예시는 계보 화면에서 볼 수 있어요.</p>}
        <div style={{ marginTop: 12 }}><Link className="btn" to={`/admin/lineage?ds=${encodeURIComponent(d.dataset_id)}`}>계보 화면에서 열기</Link></div>
      </>}
      <p className="hint" style={{ marginTop: 10 }}>{d.tags.length ? `태그: ${d.tags.join(', ')} · ` : ''}갱신 {fmtTs(d.updated_at)} · <Tier t="ASSERTED" /></p>
    </section>
  );
}

export default function Catalog() {
  const { id } = useParams();
  const nav = useNavigate();
  const list = useApi<AdminDatasetRow[]>('/api/admin/datasets');
  const classes = useApi<AdminClassRow[]>('/api/admin/ontology/classes');
  const [q, setQ] = useState('');
  const [zone, setZone] = useState('ALL');
  const [grp, setGrp] = useState('ALL');
  useEffect(() => { document.title = '데이터 카탈로그 · 뉴레이크'; }, []);
  const index = useMemo(() => new Map((list.data ?? []).map((d) => [d.dataset_id, d])), [list.data]);
  const groupOf = useMemo(() => new Map((classes.data ?? []).map((c) => [c.class_iri, c.business_group ?? ''])), [classes.data]);
  const groups = useMemo(() => [...new Set([...groupOf.values()].filter(Boolean))].sort(), [groupOf]);
  const rows = useMemo(() => {
    const t = q.trim().toLowerCase();
    return (list.data ?? []).filter((d) => (zone === 'ALL' || d.zone_id === zone)
      && (grp === 'ALL' || (d.represents_class_iri && groupOf.get(d.represents_class_iri) === grp))
      && (!t || [d.dataset_id, d.title_ko, d.class_label, lastName(d.represents_class_iri)].join(' ').toLowerCase().includes(t)));
  }, [list.data, q, zone, grp, groupOf]);
  const sel = id ?? (index.has('std.lot') ? 'std.lot' : list.data?.[0]?.dataset_id);
  return (
    <>
      <Head title="데이터 카탈로그" lede="모든 데이터셋은 그것이 표현하는 온톨로지 클래스에 묶여 있어요. 클래스로 찾고, 스키마·관계·품질·계보를 한 자리에서 봅니다."
        right={list.data && <div className="small muted num">데이터셋 {list.data.length}</div>} />
      <div className="toolbar">
        <input className="input grow" type="search" placeholder="이름, 테이블, 클래스로 찾기 (예: 로트, trace, Lot)" value={q} onChange={(e) => setQ(e.target.value)} aria-label="데이터셋 검색" />
        <div role="group" aria-label="존" style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {['ALL', ...ZONES].map((z) => <button key={z} className="chip" type="button" aria-pressed={zone === z} onClick={() => setZone(z)}>{z === 'ALL' ? '전체' : ZONE_KO[z]}</button>)}
        </div>
        <select className="input" aria-label="업무영역" value={grp} onChange={(e) => setGrp(e.target.value)}>
          <option value="ALL">업무영역 전체</option>{groups.map((g) => <option key={g}>{g}</option>)}
        </select>
      </div>
      <State loading={list.loading} error={list.error} />
      {list.data && (
        <div className="split">
          <div className="tablewrap" style={{ maxHeight: 700, overflow: 'auto' }}><table><thead><tr><th>데이터셋</th><th>존</th><th>클래스</th><th className="r">레코드</th><th>품질</th></tr></thead><tbody>
            {rows.map((d) => {
              const [qs, qsc] = QSTATUS[d.quality_status] || [d.quality_status, 'p-line'];
              const go = () => nav(`/admin/catalog/${encodeURIComponent(d.dataset_id)}`);
              return (
                <tr key={d.dataset_id} className={`click ${d.dataset_id === sel ? 'sel' : ''}`} tabIndex={0} onClick={go} onKeyDown={(e) => { if (e.key === 'Enter') go(); }} aria-current={d.dataset_id === sel}>
                  <td><b>{d.title_ko}</b><div className="mono muted">{d.dataset_id}</div></td><td><ZoneChip z={d.zone_id} /></td>
                  <td className="mono">{d.represents_class_iri ? `ksx:${lastName(d.represents_class_iri)}` : '—'}</td><td className="r num">{num(d.record_count)}</td>
                  <td><Pill cls={qsc}>{qs}{d.quality_score != null ? ` ${d.quality_score}%` : ''}</Pill></td>
                </tr>);
            })}
            {rows.length === 0 && <tr><td colSpan={5} className="muted">조건에 맞는 데이터셋이 없어요.</td></tr>}
          </tbody></table></div>
          {sel ? <Detail key={sel} id={sel} index={index} /> : <section className="panel muted">왼쪽에서 데이터셋을 고르세요.</section>}
        </div>)}
    </>
  );
}
