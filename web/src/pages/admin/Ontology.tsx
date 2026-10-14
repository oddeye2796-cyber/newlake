import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import type { AdminClassDetail, AdminClassLink, AdminClassRow } from '../../api';
import { Pill, State } from '../../components/ui';
import { useApi } from '../../useApi';
import { t } from '../../i18n';
import { Head, ZoneChip, lastName, num } from './common';

const IGNORE = ['Enterprise', 'Site', 'Plant', 'Personnel'];
const clip = (s: string, n: number) => (s.length > n ? s.slice(0, n - 1) + '…' : s);

function Graph({ d, labels, onPick }: { d: AdminClassDetail; labels: Map<string, AdminClassRow>; onPick: (n: string) => void }) {
  const me = d.class.class_iri;
  const nb = new Map<string, { iri: string; out: string[]; in: string[] }>();
  const slot = (iri: string) => { let e = nb.get(iri); if (!e) { e = { iri, out: [], in: [] }; nb.set(iri, e); } return e; };
  const self: AdminClassLink[] = [];
  d.links.forEach((l: AdminClassLink) => {
    if (l.subject_class_iri === me && l.object_class_iri === me) self.push(l);
    else if (l.subject_class_iri === me) slot(l.object_class_iri).out.push(l.property_name);
    else if (l.object_class_iri === me) slot(l.subject_class_iri).in.push(l.property_name);
  });
  const all = [...nb.values()];
  const hidden = all.filter((e) => IGNORE.includes(lastName(e.iri)) && !e.in.length).length;
  const list = all.filter((e) => !(IGNORE.includes(lastName(e.iri)) && !e.in.length)).sort((a, b) => b.out.length + b.in.length - (a.out.length + a.in.length));
  const R = list.filter((e) => e.out.length), L = list.filter((e) => !e.out.length);
  const more = Math.max(0, R.length - 10) + Math.max(0, L.length - 10);
  const Rs = R.slice(0, 10), Ls = L.slice(0, 10);
  const rowH = 46, W = 640, H = Math.max(Rs.length, Ls.length, 3) * rowH + 30, cx = W / 2, cy = H / 2;
  const place = (arr: typeof list, x: number) => arr.map((e, i) => ({ e, x, y: cy + (i - (arr.length - 1) / 2) * rowH }));
  const pos = [...place(Ls, 82), ...place(Rs, W - 82)];
  const box = (x: number, y: number, t: string, s: string, cls: string, key: string, w = 150, onClick?: () => void) => (
    <g key={key} className={`gnode ${cls}`} tabIndex={onClick ? 0 : undefined} role={onClick ? 'button' : undefined} aria-label={t} onClick={onClick} onKeyDown={(e) => { if (e.key === 'Enter') onClick?.(); }}>
      <rect x={x - w / 2} y={y - 18} width={w} height={36} rx={6} /><text x={x} y={y - 2} textAnchor="middle">{clip(t, 11)}</text><text className="sub" x={x} y={y + 12} textAnchor="middle">{clip(s, 22)}</text></g>);
  return (
    <div className="graphbox">
      <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label={t('{name} 주변 관계 그래프', { name: d.class.label_ko })}>
        <defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="var(--muted)" /></marker></defs>
        {pos.map((p) => {
          const isOut = p.e.out.length > 0, nx = isOut ? p.x - 75 : p.x + 75, ccx = isOut ? cx + 70 : cx - 70, mx = (nx + ccx) / 2;
          const dd = `M${isOut ? ccx : nx} ${isOut ? cy : p.y} C${mx} ${isOut ? cy : p.y} ${mx} ${isOut ? p.y : cy} ${isOut ? nx : ccx} ${isOut ? p.y : cy}`;
          const tot = p.e.out.length + p.e.in.length;
          return <g key={p.e.iri}><path className={`gedge ${isOut ? '' : 'in'}`} d={dd} markerEnd="url(#ah)" />
            <text className="glabel" x={isOut ? nx - 6 : nx + 6} y={p.y - 6} textAnchor={isOut ? 'end' : 'start'}>{clip((p.e.out[0] || p.e.in[0]), 24)}{tot > 1 ? ` +${tot - 1}` : ''}</text></g>;
        })}
        {pos.map((p) => { const n = lastName(p.e.iri), c = labels.get(n); return box(p.x, p.y, c?.label_ko ?? n, c?.physical_table ?? n, '', p.e.iri, 150, c ? () => onPick(n) : undefined); })}
        {box(cx, cy, d.class.label_ko, `ksx:${d.class.local_name}`, 'center', 'center', 140)}
      </svg>
      <p className="note">{hidden ? `${t('회사·사업장·공장·사원 같은 기본 참조 {n}개는 생략했어요.', { n: hidden })} ` : ''}{more ? `${t('관계가 많아 양쪽 10개씩만 그렸어요(외 {n}개).', { n: more })} ` : ''}{self.length ? t('자기 참조: {list}.', { list: self.map((l) => `ksx:${l.property_name}`).join(', ') }) : ''}</p>
    </div>
  );
}

function Detail({ d, labels, onPick }: { d: AdminClassDetail; labels: Map<string, AdminClassRow>; onPick: (n: string) => void }) {
  const c = d.class, me = c.class_iri;
  const out = d.links.filter((l) => l.subject_class_iri === me), inc = d.links.filter((l) => l.object_class_iri === me && l.subject_class_iri !== me);
  const parent = c.parent_class_iri ? lastName(c.parent_class_iri) : null;
  const rel = (l: AdminClassLink, other: string, lab: string, a: string, i: number) => (
    <button key={`${a}${i}${l.property_iri}`} type="button" onClick={() => onPick(lastName(other))}><span>{a} {lab} <code>ksx:{l.property_name}</code></span><span className="small muted">{l.relation_kind}</span></button>);
  return (
    <section className="panel detail">
      <header><div><h2>{c.label_ko}</h2><div className="mono muted">ksx:{c.local_name}</div></div><span><Pill>{c.is_event ? t('이벤트형') : t('개체형')}</Pill> {!c.is_standard && <Pill cls="p-warn">{t('확장')}</Pill>}</span></header>
      <p style={{ margin: '0 0 12px' }}>{c.definition_ko ?? t('정의가 등록되지 않았어요.')}</p>
      <dl className="kv"><dt>{t('업무영역')}</dt><dd>{c.business_group ?? '—'}</dd><dt>{t('상위 클래스')}</dt><dd>{parent ? (labels.has(parent) ? <button type="button" className="reset" onClick={() => onPick(parent)}>{labels.get(parent)!.label_ko} (ksx:{parent})</button> : parent) : '—'}</dd>
        <dt>{t('표준 조항')}</dt><dd>KS X 9101-1 {c.standard_clause ?? '—'}</dd><dt>{t('물리 테이블')}</dt><dd className="mono">{c.physical_table ? `ksx.${c.physical_table}` : '—'}</dd>
        <dt>{t('식별자')}</dt><dd className="mono small">{c.primary_key ?? '—'}</dd><dt>{t('온톨로지 버전')}</dt><dd className="mono small">{c.version_id ?? '—'}</dd></dl>
      <h3 style={{ marginTop: 14 }}>{t('데이터셋 {n}', { n: d.datasets.length })}</h3>
      {d.datasets.length === 0 ? <p className="small muted">{t('이 클래스를 표현하는 데이터셋이 없어요.')}</p> : <div className="rel">{d.datasets.map((x) => (
        <Link key={x.dataset_id} to={`/admin/catalog/${encodeURIComponent(x.dataset_id)}`} style={{ textDecoration: 'none', color: 'inherit', display: 'grid', gridTemplateColumns: 'minmax(0,1fr) auto', gap: 8, padding: '4px 6px' }}>
          <span>{x.title_ko} <code className="mono muted">{x.dataset_id}</code></span><ZoneChip z={x.zone_id} /></Link>))}</div>}
      {d.actions.length > 0 && <><h3 style={{ marginTop: 14 }}>{t('이 클래스에 거는 조치')}</h3><ul className="evlist">{d.actions.map((a) => <li key={a.action_iri}><b>{a.label_ko}</b> <span className="mono muted">{lastName(a.action_iri)} · {a.verb}</span></li>)}</ul></>}
      {d.quality_rules.length > 0 && <><h3 style={{ marginTop: 14 }}>{t('품질 규칙')}</h3><ul className="evlist">{d.quality_rules.map((r) => <li key={r.rule_id}><Link to="/admin/quality">{r.label_ko}</Link> <Pill>{r.dimension}</Pill> <span className="small muted">{r.severity}</span></li>)}</ul></>}
      <h3 style={{ marginTop: 14 }}>{t('관계 ({out} 나감 · {inc} 들어옴)', { out: out.length, inc: inc.length })}</h3>
      <div className="rel">{out.map((l, i) => rel(l, l.object_class_iri, l.object_label, '→', i))}{inc.map((l, i) => rel(l, l.subject_class_iri, l.subject_label, '←', i))}</div>
    </section>
  );
}

export default function Ontology() {
  const { name = 'Lot' } = useParams();
  const nav = useNavigate();
  const list = useApi<AdminClassRow[]>('/api/admin/ontology/classes');
  const det = useApi<AdminClassDetail>(`/api/admin/ontology/classes/${encodeURIComponent(name)}`);
  const [q, setQ] = useState('');
  useEffect(() => { document.title = `${t('온톨로지')} · ${t('뉴레이크')}`; }, []);
  const labels = useMemo(() => new Map((list.data ?? []).map((c) => [c.local_name, c])), [list.data]);
  const groups = useMemo(() => {
    const needle = q.trim().toLowerCase(), m = new Map<string, AdminClassRow[]>();
    (list.data ?? []).filter((c) => !needle || `${c.label_ko} ${c.local_name} ${c.physical_table ?? ''}`.toLowerCase().includes(needle)).forEach((c) => { const g = c.business_group ?? t('기타'); m.set(g, [...(m.get(g) ?? []), c]); });
    return [...m.entries()];
  }, [list.data, q]);
  const pick = (n: string) => nav(`/admin/ontology/${encodeURIComponent(n)}`);
  const curGroup = labels.get(name)?.business_group ?? t('기타');
  return (
    <>
      <Head title={t('온톨로지')} lede={t('KS X 9101-1을 OWL로 옮긴 표준 코어예요. 클래스를 고르면 1단계 이웃과 관계를 보여 줍니다.')}
        right={list.data && <div className="small muted num">{t('클래스 {a} · 표현 데이터셋 {b}', { a: num(list.data.length), b: num(list.data.reduce((a, c) => a + c.datasets, 0)) })}</div>} />
      <State loading={list.loading} error={list.error} />
      {list.data && (
        <div className="onto">
          <section className="panel tree" aria-label={t('클래스 목록')}>
            <input className="input" type="search" placeholder={t('클래스 찾기')} value={q} onChange={(e) => setQ(e.target.value)} style={{ width: '100%', marginBottom: 8 }} aria-label={t('클래스 검색')} />
            {groups.map(([g, cs]) => (
              <details key={g + (q ? 'q' : '')} open={!!q || g === curGroup}>
                <summary>{g}<span>{cs.length}</span></summary>
                {cs.map((c) => <button key={c.local_name} type="button" aria-current={c.local_name === name} onClick={() => pick(c.local_name)}>{c.label_ko}<small>{c.local_name}</small></button>)}
              </details>))}
            {groups.length === 0 && <p className="small muted">{t('찾는 클래스가 없어요.')}</p>}
          </section>
          <section className="panel">
            <header><h2>{det.data ? `${det.data.class.label_ko} · ksx:${det.data.class.local_name}` : name}</h2><span className="small muted">{t('왼쪽: 이 클래스를 참조 · 오른쪽: 이 클래스가 참조')}</span></header>
            <State loading={det.loading} error={det.error} />
            {det.data && <Graph d={det.data} labels={labels} onPick={pick} />}
          </section>
          {det.data && <Detail d={det.data} labels={labels} onPick={pick} />}
        </div>)}
    </>
  );
}
