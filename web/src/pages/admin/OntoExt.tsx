/* 온톨로지 확장 (CRUD 3차): 회사 확장 클래스·속성·관계 등록/수정/삭제, 버전 발행, 적재 때 쌓인 확장 제안 승인·반려.
   표준(ksx)은 읽기 전용. 쓰기는 서버(gov.*)가 역할을 다시 확인하고, 여기서는 버튼만 숨긴다. */
import { Check, Pencil, Plus, Trash2, Upload, X } from 'lucide-react';
import { useMemo, useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { del, post, put, type AdminClassRow, type ExtClass, type ExtLink, type ExtProperty, type ExtProposal, type Extensions } from '../../api';
import { useAuth } from '../../auth';
import { Pill, State } from '../../components/ui';
import { useApi } from '../../useApi';
import { t, tl, tle } from '../../i18n';
import { fmtTs } from '../../format';
import { lastName, num } from './common';
import { DEMO, hasRole } from './Steward';

const XSD = 'http://www.w3.org/2001/XMLSchema#';
const XSD_TYPES = ['string', 'decimal', 'integer', 'date', 'dateTime', 'boolean'];
const xsdName = (r: string | null) => (r && r.startsWith(XSD) ? r.slice(XSD.length) : r ? lastName(r) : '—');
const kindName = (k: string): string => ({ DATATYPE: t('값'), OBJECT: t('참조'), CODE: t('코드'), ANNOTATION: t('주석') } as Record<string, string>)[k] ?? k;
const vstatus = (s: string): [string, string] => ({ RELEASED: [t('발행됨'), 'p-ok'], DRAFT: [t('초안'), 'p-warn'], VALIDATED: [t('검증됨'), 'p-warn'], RETIRED: [t('지난 버전'), 'p-line'] } as Record<string, [string, string]>)[s] ?? [s, 'p-line'];

function useBusy() {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const run = <T,>(p: Promise<T>, ok: (r: T) => void) => { setBusy(true); setErr(null); p.then(ok).catch((x: Error) => setErr(x.message)).finally(() => setBusy(false)); };
  return { busy, err, run };
}

function ClassSelect({ value, onChange, classes, blank, required }: { value: string; onChange: (v: string) => void; classes: AdminClassRow[]; blank: string; required?: boolean }) {
  const groups = useMemo(() => { const m = new Map<string, AdminClassRow[]>(); classes.forEach((c) => { const g = c.business_group ?? t('기타'); m.set(g, [...(m.get(g) ?? []), c]); }); return [...m.entries()]; }, [classes]);
  return <select className="input" value={value} required={required} onChange={(e) => onChange(e.target.value)}>
    <option value="">{blank}</option>
    {groups.map(([g, cs]) => <optgroup key={g} label={tl(g)}>{cs.map((c) => <option key={c.class_iri} value={c.class_iri}>{tle(c.label_ko, c.label_en)} · {c.is_standard ? 'ksx' : 'arcon'}:{c.local_name}</option>)}</optgroup>)}
  </select>;
}

/* ── 확장 클래스 ────────────────────────────────────────────────────────── */
function ClassForm({ c, classes, onDone, onCancel }: { c: ExtClass | null; classes: AdminClassRow[]; onDone: () => void; onCancel: () => void }) {
  const { toast } = useAuth();
  const [f, setF] = useState({ local_name: c?.local_name ?? '', label_ko: c?.label_ko ?? '', label_en: c?.label_en ?? '', business_group: c?.business_group ?? '', parent_class_iri: c?.parent_class_iri ?? '', definition_ko: c?.definition_ko ?? '', is_event: c?.is_event ?? false });
  const { busy, err, run } = useBusy();
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const submit = (e: FormEvent) => {
    e.preventDefault();
    run(put(`/api/admin/ontology/ext/classes/${encodeURIComponent(f.local_name.trim())}`, { label_ko: f.label_ko.trim(), label_en: f.label_en.trim() || null, business_group: f.business_group.trim() || null,
      parent_class_iri: f.parent_class_iri || null, definition_ko: f.definition_ko.trim() || null, is_event: f.is_event }), () => { toast(t('확장 클래스를 저장했어요.')); onDone(); });
  };
  return (
    <form className="panel" onSubmit={submit} aria-label={c ? t('확장 클래스 수정') : t('확장 클래스 등록')}>
      <header><h2>{c ? t('확장 클래스 수정') : t('확장 클래스 등록')}</h2><span className="small muted mono">arcon:</span></header>
      <div className="formgrid">
        <label className="fld"><span>{t('영문 이름 (대문자로 시작, 예: CoilSpec)')}</span><input className="input mono" required pattern="[A-Z][A-Za-z0-9]{1,79}" value={f.local_name} disabled={!!c} onChange={set('local_name')} /></label>
        <label className="fld"><span>{t('한글 이름')}</span><input className="input" required maxLength={200} value={f.label_ko} onChange={set('label_ko')} /></label>
        <label className="fld"><span>{t('영문 표시 이름')}</span><input className="input" maxLength={200} value={f.label_en} onChange={set('label_en')} /></label>
        <label className="fld"><span>{t('업무영역')}</span><input className="input" maxLength={50} value={f.business_group} onChange={set('business_group')} placeholder={t('예: 구매, 생산, 품질')} /></label>
        <label className="fld"><span>{t('상위 클래스 (가장 가까운 표준 클래스)')}</span><ClassSelect value={f.parent_class_iri} onChange={(v) => setF((x) => ({ ...x, parent_class_iri: v }))} classes={classes} blank={t('없음')} /></label>
        <label className="fld" style={{ flexDirection: 'row', alignItems: 'center', gap: 8, alignSelf: 'end' }}><input type="checkbox" checked={f.is_event} onChange={(e) => setF((x) => ({ ...x, is_event: e.target.checked }))} /><span>{t('이벤트형 (시각이 있는 사건)')}</span></label>
        <label className="fld" style={{ gridColumn: '1 / -1' }}><span>{t('정의')}</span><textarea className="input" rows={2} maxLength={2000} value={f.definition_ko} onChange={set('definition_ko')} /></label>
      </div>
      <p className="note">{t('표준에 없는 개념만 회사 확장(arcon)으로 두세요. 표준 클래스를 상위로 잡으면 표준 속성과 질의를 그대로 물려받아요.')}</p>
      {err && <div className="banner" role="alert">{err}</div>}
      <div className="acts" style={{ marginTop: 10 }}><button className="btn" type="button" onClick={onCancel}>{t('취소')}</button><button className="btn primary" type="submit" disabled={busy || DEMO}>{busy ? t('저장 중…') : t('저장')}</button></div>
    </form>
  );
}

/* ── 확장 속성 ──────────────────────────────────────────────────────────── */
function PropertyForm({ p, classes, onDone, onCancel, preset }: { p: ExtProperty | null; classes: AdminClassRow[]; onDone: () => void; onCancel: () => void; preset?: Partial<{ domain_class_iri: string }> }) {
  const { toast } = useAuth();
  const [f, setF] = useState({ local_name: p?.local_name ?? '', kind: p?.kind ?? 'DATATYPE', label_ko: p?.label_ko ?? '', domain_class_iri: p?.domain_class_iri ?? preset?.domain_class_iri ?? '',
    range_iri: p ? (p.kind === 'OBJECT' ? p.range_iri ?? '' : xsdName(p.range_iri) === '—' ? 'string' : xsdName(p.range_iri) ?? 'string') : 'string', unit: p?.unit ?? '', code_scheme: p?.code_scheme ?? '', definition_ko: p?.definition_ko ?? '' });
  const { busy, err, run } = useBusy();
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const submit = (e: FormEvent) => {
    e.preventDefault();
    run(put(`/api/admin/ontology/ext/properties/${encodeURIComponent(f.local_name.trim())}`, { kind: f.kind, label_ko: f.label_ko.trim(), domain_class_iri: f.domain_class_iri, range_iri: f.range_iri || null,
      unit: f.unit.trim() || null, code_scheme: f.code_scheme.trim() || null, definition_ko: f.definition_ko.trim() || null }), () => { toast(t('확장 속성을 저장했어요.')); onDone(); });
  };
  return (
    <form className="panel" onSubmit={submit} aria-label={p ? t('확장 속성 수정') : t('확장 속성 등록')}>
      <header><h2>{p ? t('확장 속성 수정') : t('확장 속성 등록')}</h2><span className="small muted mono">arcon:</span></header>
      <div className="formgrid">
        <label className="fld"><span>{t('영문 이름 (소문자로 시작, 예: coilThickness)')}</span><input className="input mono" required pattern="[a-z][A-Za-z0-9]{1,79}" value={f.local_name} disabled={!!p} onChange={set('local_name')} /></label>
        <label className="fld"><span>{t('한글 이름')}</span><input className="input" required maxLength={200} value={f.label_ko} onChange={set('label_ko')} /></label>
        <label className="fld"><span>{t('붙는 클래스')}</span><ClassSelect value={f.domain_class_iri} onChange={(v) => setF((x) => ({ ...x, domain_class_iri: v }))} classes={classes} blank={t('클래스를 고르세요')} required /></label>
        <label className="fld"><span>{t('종류')}</span><select className="input" value={f.kind} onChange={(e) => setF((x) => ({ ...x, kind: e.target.value, range_iri: e.target.value === 'OBJECT' ? '' : 'string' }))}>
          <option value="DATATYPE">{t('값 (숫자·문자·날짜)')}</option><option value="OBJECT">{t('참조 (다른 클래스를 가리킴)')}</option><option value="CODE">{t('코드 (코드 체계의 값)')}</option></select></label>
        {f.kind === 'OBJECT'
          ? <label className="fld"><span>{t('가리키는 클래스')}</span><ClassSelect value={f.range_iri} onChange={(v) => setF((x) => ({ ...x, range_iri: v }))} classes={classes} blank={t('클래스를 고르세요')} required /></label>
          : <label className="fld"><span>{t('값 형')}</span><select className="input" value={f.range_iri} onChange={set('range_iri')}>{XSD_TYPES.map((x) => <option key={x} value={x}>xsd:{x}</option>)}</select></label>}
        <label className="fld"><span>{t('단위')}</span><input className="input" maxLength={30} value={f.unit} onChange={set('unit')} placeholder="mm, kg, KRW" /></label>
        {f.kind === 'CODE' && <label className="fld"><span>{t('코드 체계')}</span><input className="input" maxLength={200} value={f.code_scheme} onChange={set('code_scheme')} /></label>}
        <label className="fld" style={{ gridColumn: '1 / -1' }}><span>{t('정의')}</span><textarea className="input" rows={2} maxLength={2000} value={f.definition_ko} onChange={set('definition_ko')} /></label>
      </div>
      <p className="note">{t('참조 속성은 관계(링크)도 함께 만들어요. 값이 보관된 속성은 지울 수 없고, 이름을 바꾸려면 새로 만들어야 해요.')}</p>
      {err && <div className="banner" role="alert">{err}</div>}
      <div className="acts" style={{ marginTop: 10 }}><button className="btn" type="button" onClick={onCancel}>{t('취소')}</button><button className="btn primary" type="submit" disabled={busy || DEMO}>{busy ? t('저장 중…') : t('저장')}</button></div>
    </form>
  );
}

/* ── 확장 관계 ──────────────────────────────────────────────────────────── */
function LinkForm({ classes, props, onDone, onCancel }: { classes: AdminClassRow[]; props: ExtProperty[]; onDone: () => void; onCancel: () => void }) {
  const { toast } = useAuth();
  const [f, setF] = useState({ subject_class_iri: '', property_iri: '', object_class_iri: '', relation_kind: '확장 참조' }); // i18n-ignore: DB 값
  const { busy, err, run } = useBusy();
  const objs = props.filter((p) => p.kind === 'OBJECT');
  const submit = (e: FormEvent) => { e.preventDefault(); run(post('/api/admin/ontology/ext/links', f), () => { toast(t('관계를 저장했어요.')); onDone(); }); };
  return (
    <form className="panel" onSubmit={submit} aria-label={t('확장 관계 등록')}>
      <header><h2>{t('확장 관계 등록')}</h2></header>
      <div className="formgrid">
        <label className="fld"><span>{t('주어 클래스')}</span><ClassSelect value={f.subject_class_iri} onChange={(v) => setF((x) => ({ ...x, subject_class_iri: v }))} classes={classes} blank={t('클래스를 고르세요')} required /></label>
        <label className="fld"><span>{t('참조 속성')}</span><select className="input" required value={f.property_iri} onChange={(e) => setF((x) => ({ ...x, property_iri: e.target.value }))}><option value="">{t('속성을 고르세요')}</option>{objs.map((p) => <option key={p.property_iri} value={p.property_iri}>{tl(p.label_ko)} · arcon:{p.local_name}</option>)}</select></label>
        <label className="fld"><span>{t('목적어 클래스')}</span><ClassSelect value={f.object_class_iri} onChange={(v) => setF((x) => ({ ...x, object_class_iri: v }))} classes={classes} blank={t('클래스를 고르세요')} required /></label>
        <label className="fld"><span>{t('관계 종류')}</span><input className="input" maxLength={30} value={f.relation_kind} onChange={(e) => setF((x) => ({ ...x, relation_kind: e.target.value }))} /></label>
      </div>
      {objs.length === 0 && <p className="note">{t('참조 속성이 아직 없어요. 먼저 참조 종류의 확장 속성을 등록하세요.')}</p>}
      {err && <div className="banner" role="alert">{err}</div>}
      <div className="acts" style={{ marginTop: 10 }}><button className="btn" type="button" onClick={onCancel}>{t('취소')}</button><button className="btn primary" type="submit" disabled={busy || DEMO || objs.length === 0}>{busy ? t('저장 중…') : t('저장')}</button></div>
    </form>
  );
}

/* ── 버전 발행 ──────────────────────────────────────────────────────────── */
function PublishBox({ unpublished, onDone }: { unpublished: number; onDone: () => void }) {
  const { toast } = useAuth();
  const [info, setInfo] = useState('');
  const [note, setNote] = useState('');
  const { busy, err, run } = useBusy();
  const submit = (e: FormEvent) => { e.preventDefault(); run(post<{ version_id: string; classes: number; properties: number }>('/api/admin/ontology/versions/publish', { version_info: info.trim(), note: note.trim() || null }), (r) => { toast(t('{v} 버전을 발행했어요 (클래스 {a} · 속성 {b}).', { v: r.version_id, a: r.classes, b: r.properties })); setInfo(''); setNote(''); onDone(); }); };
  return (
    <form className="panel" onSubmit={submit} aria-label={t('온톨로지 버전 발행')}>
      <header><h2>{t('버전 발행')}</h2><span className="small muted">{unpublished > 0 ? t('아직 버전에 안 담긴 확장 {n}개', { n: unpublished }) : t('모든 확장이 발행됐어요')}</span></header>
      <div className="formrow">
        <label className="fld grow"><span>{t('버전 (예: 1.3)')}</span><input className="input mono" required maxLength={60} value={info} onChange={(e) => setInfo(e.target.value)} placeholder="1.3" /></label>
        <label className="fld grow"><span>{t('메모')}</span><input className="input" maxLength={500} value={note} onChange={(e) => setNote(e.target.value)} /></label>
        <button className="btn primary" type="submit" disabled={busy || DEMO || unpublished === 0} style={{ alignSelf: 'end' }}><Upload aria-hidden="true" /> {busy ? t('발행 중…') : t('발행')}</button>
      </div>
      <p className="note">{t('발행하면 버전이 없던 확장 클래스·속성에 arcon-{버전}-{날짜} 가 찍히고 이전 발행본은 지난 버전이 돼요. 확장을 고치면 다시 발행 대상이 돼요.')}</p>
      {err && <div className="banner" role="alert">{err}</div>}
    </form>
  );
}

/* ── 회사 확장 탭 ────────────────────────────────────────────────────────── */
export function ExtensionsTab({ classes }: { classes: AdminClassRow[] }) {
  const { me, toast } = useAuth();
  const ext = useApi<Extensions>('/api/admin/ontology/extensions');
  const canClass = hasRole(me, 'ontology_manager'), canProp = hasRole(me, 'ontology_manager', 'data_steward');
  const [mode, setMode] = useState<null | { kind: 'class'; c: ExtClass | null } | { kind: 'prop'; p: ExtProperty | null; domain?: string } | { kind: 'link' }>(null);
  const [err, setErr] = useState<string | null>(null);
  const reload = () => { setMode(null); ext.reload(); };
  const remove = (what: string, url: string, label: string) => { if (!window.confirm(t('{what} {label} 을(를) 지울까요?', { what, label }))) return; setErr(null); del(url).then(() => { toast(t('지웠어요.')); ext.reload(); }).catch((x: Error) => setErr(x.message)); };
  if (!ext.data) return <State loading={ext.loading} error={ext.error} />;
  const d = ext.data;
  // 방금 만든 확장 클래스도 고를 수 있게 표준 목록에 합친다
  const known = new Set(classes.map((c) => c.class_iri));
  const allClasses: AdminClassRow[] = [...classes, ...d.classes.filter((c) => !known.has(c.class_iri)).map((c) => ({ class_iri: c.class_iri, local_name: c.local_name, label_ko: c.label_ko, label_en: c.label_en, business_group: c.business_group, parent_class_iri: c.parent_class_iri, standard_clause: null, physical_table: null, is_event: c.is_event, is_standard: false, datasets: c.datasets }))];
  const vpill = (v: string | null) => v ? <span className="mono small muted">{v}</span> : <Pill cls="p-warn">{t('미발행')}</Pill>;
  return (
    <div className="stack">
      {mode?.kind === 'class' && <ClassForm c={mode.c} classes={allClasses} onDone={reload} onCancel={() => setMode(null)} />}
      {mode?.kind === 'prop' && <PropertyForm p={mode.p} classes={allClasses} preset={{ domain_class_iri: mode.domain ?? '' }} onDone={reload} onCancel={() => setMode(null)} />}
      {mode?.kind === 'link' && <LinkForm classes={allClasses} props={d.properties} onDone={reload} onCancel={() => setMode(null)} />}
      {err && <div className="banner" role="alert">{err}</div>}

      <section className="panel">
        <header><h2>{t('확장 클래스 {n}', { n: d.classes.length })}</h2><div className="acts">{canClass && <button className="btn" type="button" disabled={DEMO} onClick={() => setMode({ kind: 'class', c: null })}><Plus aria-hidden="true" /> {t('새 클래스')}</button>}</div></header>
        <div className="tablewrap"><table><thead><tr><th>{t('클래스')}</th><th>{t('상위')}</th><th>{t('업무영역')}</th><th className="r">{t('속성')}</th><th className="r">{t('데이터셋')}</th><th>{t('버전')}</th>{canClass && <th />}</tr></thead><tbody>
          {d.classes.map((c) => <tr key={c.class_iri}>
            <td><Link to={`/admin/ontology/${encodeURIComponent(c.local_name)}`}>{tle(c.label_ko, c.label_en)}</Link><div className="mono small muted">arcon:{c.local_name}{c.is_event ? ` · ${t('이벤트형')}` : ''}</div></td>
            <td className="small">{tl(c.parent_label) ?? '—'}</td><td className="small">{tl(c.business_group) ?? '—'}</td><td className="r num">{c.properties}</td><td className="r num">{c.datasets}</td><td>{vpill(c.version_id)}</td>
            {canClass && <td className="r" style={{ whiteSpace: 'nowrap' }}>
              <button className="btn icon" type="button" title={t('속성 추가')} aria-label={t('{name} 에 속성 추가', { name: tle(c.label_ko, c.label_en) })} disabled={DEMO} onClick={() => setMode({ kind: 'prop', p: null, domain: c.class_iri })}><Plus aria-hidden="true" /></button>{' '}
              <button className="btn icon" type="button" title={t('수정')} aria-label={t('{name} 수정', { name: tle(c.label_ko, c.label_en) })} disabled={DEMO} onClick={() => setMode({ kind: 'class', c })}><Pencil aria-hidden="true" /></button>{' '}
              <button className="btn icon" type="button" title={t('삭제')} aria-label={t('{name} 삭제', { name: tle(c.label_ko, c.label_en) })} disabled={DEMO} onClick={() => remove(t('확장 클래스'), `/api/admin/ontology/ext/classes/${encodeURIComponent(c.local_name)}`, c.label_ko)}><Trash2 aria-hidden="true" /></button></td>}
          </tr>)}
          {d.classes.length === 0 && <tr><td colSpan={7} className="muted">{t('아직 회사 확장 클래스가 없어요. 표준에 없는 개념이 생기면 여기서 등록해요.')}</td></tr>}
        </tbody></table></div>
      </section>

      <section className="panel">
        <header><h2>{t('확장 속성 {n}', { n: d.properties.length })}</h2><div className="acts">{canProp && <button className="btn" type="button" disabled={DEMO} onClick={() => setMode({ kind: 'prop', p: null })}><Plus aria-hidden="true" /> {t('새 속성')}</button>}</div></header>
        <div className="tablewrap"><table><thead><tr><th>{t('속성')}</th><th>{t('붙는 클래스')}</th><th>{t('종류 · 형')}</th><th className="r">{t('보관 값')}</th><th>{t('버전')}</th>{canProp && <th />}</tr></thead><tbody>
          {d.properties.map((p) => <tr key={p.property_iri}>
            <td>{tl(p.label_ko) ?? p.local_name}<div className="mono small muted">arcon:{p.local_name}</div></td>
            <td className="small">{tl(p.domain_label) ?? <span className="muted">{t('(표준 arcon 속성)')}</span>}</td>
            <td className="small">{kindName(p.kind)} · <span className="mono">{p.kind === 'OBJECT' ? (tl(p.range_label) ?? lastName(p.range_iri)) : `xsd:${xsdName(p.range_iri)}`}</span>{p.unit ? ` · ${p.unit}` : ''}</td>
            <td className="r num">{num(p.values_stored)}</td><td>{vpill(p.version_id)}</td>
            {canProp && <td className="r" style={{ whiteSpace: 'nowrap' }}>{p.domain_class_iri && <>
              <button className="btn icon" type="button" title={t('수정')} aria-label={t('{name} 수정', { name: p.local_name })} disabled={DEMO} onClick={() => setMode({ kind: 'prop', p })}><Pencil aria-hidden="true" /></button>{' '}
              <button className="btn icon" type="button" title={t('삭제')} aria-label={t('{name} 삭제', { name: p.local_name })} disabled={DEMO || p.values_stored > 0} onClick={() => remove(t('확장 속성'), `/api/admin/ontology/ext/properties/${encodeURIComponent(p.local_name)}`, p.local_name)}><Trash2 aria-hidden="true" /></button></>}</td>}
          </tr>)}
          {d.properties.length === 0 && <tr><td colSpan={6} className="muted">{t('확장 속성이 없어요.')}</td></tr>}
        </tbody></table></div>
        <p className="hint">{t('적재 때 표준 표에 자리가 없던 열은 ksx.extension_attribute 에 보관되고, 확장 제안 탭에서 승인하면 여기 속성으로 이어져요.')}</p>
      </section>

      <section className="panel">
        <header><h2>{t('확장 관계 {n}', { n: d.links.length })}</h2><div className="acts">{canClass && <button className="btn" type="button" disabled={DEMO} onClick={() => setMode({ kind: 'link' })}><Plus aria-hidden="true" /> {t('새 관계')}</button>}</div></header>
        <div className="tablewrap"><table><thead><tr><th>{t('주어')}</th><th>{t('속성')}</th><th>{t('목적어')}</th><th>{t('종류')}</th>{canClass && <th />}</tr></thead><tbody>
          {d.links.map((l: ExtLink) => <tr key={l.link_id}><td>{tl(l.subject_label)}</td><td className="mono small">arcon:{l.property_name}</td><td>{tl(l.object_label)}</td><td className="small">{tl(l.relation_kind) ?? '—'}</td>
            {canClass && <td className="r"><button className="btn icon" type="button" title={t('삭제')} aria-label={t('관계 {id} 삭제', { id: l.link_id })} disabled={DEMO} onClick={() => remove(t('확장 관계'), `/api/admin/ontology/ext/links/${l.link_id}`, `${l.subject_label} → ${l.object_label}`)}><Trash2 aria-hidden="true" /></button></td>}</tr>)}
          {d.links.length === 0 && <tr><td colSpan={5} className="muted">{t('확장 관계가 없어요. 참조 속성을 만들면 자동으로 생겨요.')}</td></tr>}
        </tbody></table></div>
      </section>

      {canClass && <PublishBox unpublished={d.unpublished} onDone={ext.reload} />}
      <section className="panel">
        <header><h2>{t('온톨로지 버전')}</h2><span className="small muted">onto.ontology_version</span></header>
        <div className="tablewrap"><table><thead><tr><th>{t('버전')}</th><th>{t('온톨로지')}</th><th>{t('상태')}</th><th className="r">{t('클래스 · 속성')}</th><th>{t('발행 시각')}</th>{canClass && <th />}</tr></thead><tbody>
          {d.versions.map((v) => { const [s, sc] = vstatus(v.status); const empty = v.classes + v.properties === 0 && v.ontology_iri.includes('/arcon'); return <tr key={v.version_id}><td className="mono small">{v.version_id}</td><td className="small">{v.ontology_iri.includes('/arcon') ? t('회사 확장 (arcon)') : t('표준 코어 (ksx9101)')}{v.source ? <div className="muted">{tl(v.source)}</div> : null}</td><td><Pill cls={sc}>{s}</Pill></td><td className="r num small">{v.classes} · {v.properties}</td><td className="num small">{fmtTs(v.released_at)}</td>
            {canClass && <td className="r">{empty && <button className="btn icon" type="button" title={t('빈 버전 삭제')} aria-label={t('{id} 삭제', { id: v.version_id })} disabled={DEMO} onClick={() => remove(t('빈 버전'), `/api/admin/ontology/versions/${encodeURIComponent(v.version_id)}`, v.version_id)}><Trash2 aria-hidden="true" /></button>}</td>}</tr>; })}
        </tbody></table></div>
        <p className="hint">{t('클래스·속성이 하나도 안 담긴 버전만 지울 수 있어요. 현재 발행본을 지우면 직전 발행본이 다시 현재 버전이 돼요.')}</p>
      </section>
    </div>
  );
}

/* ── 확장 제안 탭 ────────────────────────────────────────────────────────── */
function ProposalRow({ p, classes, canWrite, onDone }: { p: ExtProposal; classes: AdminClassRow[]; canWrite: boolean; onDone: () => void }) {
  const { toast } = useAuth();
  const [open, setOpen] = useState(false);
  const [f, setF] = useState({ kind: p.kind, local_name: p.suggested_local_name ?? '', label_ko: p.suggested_label ?? p.column_name, target_class_iri: p.target_class_iri ?? '', range_iri: xsdName(p.suggested_range_iri) === '—' ? 'string' : (p.kind === 'REF' ? '' : xsdName(p.suggested_range_iri) ?? 'string'), unit: p.unit ?? '' });
  const { busy, err, run } = useBusy();
  const decide = (accept: boolean) => run(post<{ status: string; result_iri?: string }>(`/api/admin/ontology/proposals/${p.proposal_id}/decide`, accept
    ? { accept: true, kind: f.kind, local_name: f.local_name.trim() || null, label_ko: f.label_ko.trim() || null, target_class_iri: f.target_class_iri || null, range_iri: f.range_iri || null, unit: f.unit.trim() || null }
    : { accept: false }), (r) => { toast(accept ? t('승인했어요: {iri}', { iri: lastName(r.result_iri ?? '') }) : t('반려했어요.')); onDone(); });
  const decided = p.status !== 'PROPOSED';
  const conf = p.confidence == null ? null : Math.round(p.confidence * 100);
  return (
    <>
      <tr>
        <td><b title={p.column_name}>{tl(p.column_name)}</b>{tl(p.column_name) !== p.column_name && <span className="small muted"> ({p.column_name})</span>}<div className="small muted">{tl(p.dataset_title) ?? p.dataset_id} → <span className="mono">{p.std_table ? `ksx.${p.std_table}` : '—'}</span></div>
          {p.sample_values?.length > 0 && <div className="small mono muted">{p.sample_values.slice(0, 3).map((v) => tl(String(v))).join(' · ')}</div>}</td>
        <td className="small">{p.matched_name ? <>{t('기존 속성에 잇기')}<div className="mono">arcon:{p.matched_name}</div></> : <>{p.kind === 'REF' ? t('참조 속성') : p.kind === 'CLASS' ? t('새 클래스') : t('새 속성')}<div className="mono">arcon:{p.suggested_local_name}</div></>}
          <div className="muted">{tl(p.target_label) ?? lastName(p.target_class_iri)}{p.kind !== 'CLASS' && p.suggested_range_iri ? ` · xsd:${xsdName(p.suggested_range_iri)}` : ''}{p.unit ? ` · ${p.unit}` : ''}</div></td>
        <td className="small">{tl(p.rationale)}{conf != null && <div className="muted">{t('신뢰도 {n}%', { n: conf })} · {t('{n}행 봄', { n: num(p.rows_seen) })}</div>}</td>
        <td>{decided ? <><Pill cls={p.status === 'ACCEPTED' ? 'p-ok' : 'p-line'}>{p.status === 'ACCEPTED' ? t('승인') : t('반려')}</Pill><div className="small muted">{p.decided_by} · {fmtTs(p.decided_at)}</div>{p.result_iri && <div className="small mono">arcon:{lastName(p.result_iri)}</div>}</>
          : canWrite ? <div className="acts" style={{ justifyContent: 'flex-start' }}>
            <button className="btn primary" type="button" disabled={busy || DEMO} onClick={() => decide(true)}><Check aria-hidden="true" /> {t('승인')}</button>
            <button className="btn" type="button" disabled={busy || DEMO} onClick={() => setOpen((o) => !o)}><Pencil aria-hidden="true" /> {t('고쳐서 승인')}</button>
            <button className="btn" type="button" disabled={busy || DEMO} onClick={() => decide(false)}><X aria-hidden="true" /> {t('반려')}</button></div> : <Pill cls="p-warn">{t('대기')}</Pill>}
          {err && <div className="small" style={{ color: 'var(--crit)' }}>{err}</div>}</td>
      </tr>
      {open && !decided && <tr><td colSpan={4}><div className="formgrid" style={{ padding: '4px 0 8px' }}>
        <label className="fld"><span>{t('종류')}</span><select className="input" value={f.kind} onChange={(e) => setF((x) => ({ ...x, kind: e.target.value, range_iri: e.target.value === 'REF' ? '' : x.range_iri || 'string' }))}><option value="PROPERTY">{t('새 속성 (값)')}</option><option value="REF">{t('참조 속성')}</option><option value="CLASS">{t('새 클래스')}</option></select></label>
        <label className="fld"><span>{t('영문 이름')}</span><input className="input mono" value={f.local_name} onChange={(e) => setF((x) => ({ ...x, local_name: e.target.value }))} /></label>
        <label className="fld"><span>{t('한글 이름')}</span><input className="input" value={f.label_ko} onChange={(e) => setF((x) => ({ ...x, label_ko: e.target.value }))} /></label>
        <label className="fld"><span>{f.kind === 'CLASS' ? t('상위 클래스') : t('붙는 클래스')}</span><ClassSelect value={f.target_class_iri} onChange={(v) => setF((x) => ({ ...x, target_class_iri: v }))} classes={classes} blank={t('클래스를 고르세요')} /></label>
        {f.kind === 'PROPERTY' && <label className="fld"><span>{t('값 형')}</span><select className="input" value={f.range_iri} onChange={(e) => setF((x) => ({ ...x, range_iri: e.target.value }))}>{XSD_TYPES.map((x) => <option key={x} value={x}>xsd:{x}</option>)}</select></label>}
        {f.kind === 'REF' && <label className="fld"><span>{t('가리키는 클래스')}</span><ClassSelect value={f.range_iri} onChange={(v) => setF((x) => ({ ...x, range_iri: v }))} classes={classes} blank={t('클래스를 고르세요')} /></label>}
        {f.kind !== 'CLASS' && <label className="fld"><span>{t('단위')}</span><input className="input" value={f.unit} onChange={(e) => setF((x) => ({ ...x, unit: e.target.value }))} /></label>}
        <div className="acts" style={{ gridColumn: '1 / -1' }}><button className="btn primary" type="button" disabled={busy || DEMO} onClick={() => decide(true)}><Check aria-hidden="true" /> {t('이대로 승인')}</button></div>
      </div></td></tr>}
    </>
  );
}

export function ProposalsTab({ classes }: { classes: AdminClassRow[] }) {
  const { me } = useAuth();
  const [all, setAll] = useState(false);
  const q = useApi<ExtProposal[]>(`/api/admin/ontology/proposals?status=${all ? 'ALL' : 'PROPOSED'}`);
  const canWrite = hasRole(me, 'ontology_manager', 'data_steward');
  return (
    <section className="panel">
      <header><h2>{t('확장 제안')}</h2><label className="small" style={{ display: 'flex', gap: 6, alignItems: 'center' }}><input type="checkbox" checked={all} onChange={(e) => setAll(e.target.checked)} />{t('결정한 것도 보기')}</label></header>
      <p className="note">{t('데이터 넣기에서 표준 표에 자리가 없던 열이에요. 값은 이미 확장 속성 보관소에 들어 있고, 승인하면 온톨로지 속성이 생겨 그 값에 이어져요. 다음 적재부터는 같은 열을 자동으로 이어요.')}</p>
      <State loading={q.loading} error={q.error} />
      {q.data && <div className="tablewrap"><table><thead><tr><th>{t('원천 열')}</th><th>{t('제안')}</th><th>{t('근거')}</th><th>{t('결정')}</th></tr></thead><tbody>
        {q.data.map((p) => <ProposalRow key={p.proposal_id} p={p} classes={classes} canWrite={canWrite} onDone={q.reload} />)}
        {q.data.length === 0 && <tr><td colSpan={4} className="muted">{all ? t('제안이 없어요.') : t('기다리는 제안이 없어요. 데이터 넣기에서 표준 표에 없는 열이 들어오면 여기 쌓여요.')}</td></tr>}
      </tbody></table></div>}
    </section>
  );
}
