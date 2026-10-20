/* 스튜어드십 CRUD 조각: 데이터셋 메타 수정·삭제, 필드 수정·매핑 승인/반려, 매핑 버전 상태, 품질 규칙 폼·바로 실행, 위반 처리, 위험 닫기, 파이프라인 켜기/끄기.
   카탈로그·품질·오늘의 레이크 화면이 가져다 쓴다. 쓰기 권한은 서버(gov.require_role)가 다시 확인하고, 여기서는 버튼만 숨긴다. */
import { Check, Pencil, Play, Trash2, X } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { del, post, put, type AdminDatasetDetail, type AdminField, type AdminMapping, type AdminPipeline, type AdminRisk, type Me, type OntoProperty, type Person, type QualityRule, type QualityRunResult, type QualityViolation } from '../../api';
import { useAuth } from '../../auth';
import { Pill } from '../../components/ui';
import { useApi } from '../../useApi';
import { t } from '../../i18n';
import { lastName, sensName, violStatus } from './common';

export const DEMO = import.meta.env.VITE_DEMO === '1';
export const hasRole = (me: Me | null, ...roles: string[]) => !!me && (me.roles.includes('admin') || roles.some((r) => me.roles.includes(r)));
export const SENSITIVITIES = ['PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'PERSONAL'];
const DIMENSIONS = ['완전성', '유일성', '유효성', '일관성', '정확성', '구조', '값', '관계', '의미']; // i18n-ignore: DB 값(catalog.quality_rule.dimension)
const SEVERITIES = ['Info', 'Warning', 'Violation'];
const sevName = (s: string): string => ({ Info: t('정보'), Warning: t('주의'), Violation: t('위반') } as Record<string, string>)[s] ?? s;
export const dimName = (d: string | null): string => (d ? ({ 완전성: t('완전성'), 유일성: t('유일성'), 유효성: t('유효성'), 일관성: t('일관성'), 정확성: t('정확성'), 구조: t('구조'), 값: t('값'), 관계: t('관계'), 의미: t('의미') } as Record<string, string>)[d] ?? d : '—'); // i18n-ignore: DB 값이 키

function useBusy() {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const run = <T,>(p: Promise<T>, ok: (r: T) => void) => { setBusy(true); setErr(null); p.then(ok).catch((x: Error) => setErr(x.message)).finally(() => setBusy(false)); };
  return { busy, err, setErr, run };
}

export function PeopleSelect({ value, onChange, blank, people }: { value: string; onChange: (v: string) => void; blank: string; people: Person[] }) {
  return <select className="input" value={value} onChange={(e) => onChange(e.target.value)}>
    <option value="">{blank}</option>{people.map((p) => <option key={p.user_id} value={p.user_id}>{p.display_name} · {p.user_id}</option>)}
  </select>;
}

/* ── 데이터셋 메타 ─────────────────────────────────────────────────────── */
export function DatasetForm({ d, onDone, onCancel }: { d: AdminDatasetDetail['dataset']; onDone: () => void; onCancel: () => void }) {
  const { toast } = useAuth();
  const people = useApi<Person[]>('/api/admin/people');
  const [f, setF] = useState({ title_ko: d.title_ko, description: d.description ?? '', sensitivity: d.sensitivity, pseudonymized: d.pseudonymized, retention: d.retention ?? '',
    owner_user_id: d.owner_user_id ?? '', steward_user_id: d.steward_user_id ?? '', tags: d.tags.join(', ') });
  const { busy, err, run } = useBusy();
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const submit = (e: FormEvent) => {
    e.preventDefault();
    run(put(`/api/admin/datasets/${encodeURIComponent(d.dataset_id)}`, { ...f, retention: f.retention.trim() || null, owner_user_id: f.owner_user_id || null, steward_user_id: f.steward_user_id || null,
      description: f.description.trim() || null, tags: f.tags.split(',').map((x) => x.trim()).filter(Boolean) }), () => { toast(t('데이터셋 정보를 저장했어요.')); onDone(); });
  };
  return (
    <form className="panel" onSubmit={submit} aria-label={t('데이터셋 정보 수정')}>
      <header><h2>{t('데이터셋 정보 수정')}</h2><span className="small muted mono">{d.dataset_id}</span></header>
      <div className="formgrid">
        <label className="fld"><span>{t('제목')}</span><input className="input" required maxLength={200} value={f.title_ko} onChange={set('title_ko')} /></label>
        <label className="fld"><span>{t('민감도')}</span><select className="input" value={f.sensitivity} onChange={set('sensitivity')}>{SENSITIVITIES.map((s) => <option key={s} value={s}>{sensName(s) ?? s}</option>)}</select></label>
        <label className="fld" style={{ gridColumn: '1 / -1' }}><span>{t('설명')}</span><textarea className="input" rows={2} maxLength={2000} value={f.description} onChange={set('description')} /></label>
        <label className="fld"><span>{t('소유자')}</span><PeopleSelect value={f.owner_user_id} onChange={(v) => setF((x) => ({ ...x, owner_user_id: v }))} blank={t('없음')} people={people.data ?? []} /></label>
        <label className="fld"><span>{t('스튜어드')}</span><PeopleSelect value={f.steward_user_id} onChange={(v) => setF((x) => ({ ...x, steward_user_id: v }))} blank={t('없음')} people={people.data ?? []} /></label>
        <label className="fld"><span>{t('보존 기간 (예: 5 years, 90 days)')}</span><input className="input mono" value={f.retention} onChange={set('retention')} placeholder="5 years" /></label>
        <label className="fld"><span>{t('태그 (쉼표로 구분)')}</span><input className="input" value={f.tags} onChange={set('tags')} placeholder="mes, lot" /></label>
        <label className="fld" style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}><input type="checkbox" checked={f.pseudonymized} onChange={(e) => setF((x) => ({ ...x, pseudonymized: e.target.checked }))} /><span>{t('가명처리된 데이터')}</span></label>
      </div>
      <p className="note">{t('제목·설명·민감도·담당은 카탈로그 메타예요. 데이터 자체는 데이터 넣기로 다시 올려 바꿔요.')}</p>
      {err && <div className="banner" role="alert">{err}</div>}
      <div className="acts" style={{ marginTop: 12 }}><button className="btn primary" type="submit" disabled={busy || DEMO}>{t('저장')}</button><button className="btn" type="button" onClick={onCancel}>{t('취소')}</button></div>
    </form>);
}

export function DatasetDeleteButton({ id, zone, onDone }: { id: string; zone: string; onDone: () => void }) {
  const { toast } = useAuth();
  const { busy, err, run } = useBusy();
  if (zone !== 'RAW') return null;
  const go = () => { if (!window.confirm(t('데이터셋 {id} 를 카탈로그에서 지울까요? 이 데이터셋의 계보·매핑 기록도 함께 지워져요. 적재 배치가 남아 있으면 거절돼요.', { id }))) return; run(del(`/api/admin/datasets/${encodeURIComponent(id)}`), () => { toast(t('데이터셋 {id} 를 지웠어요.', { id })); onDone(); }); };
  return <><button className="btn danger" type="button" disabled={busy || DEMO} onClick={go}><Trash2 aria-hidden="true" /> {t('삭제')}</button>{err && <div className="banner" role="alert">{err}</div>}</>;
}

/* ── 필드 ───────────────────────────────────────────────────────────────── */
export function FieldRow({ f, canWrite, props, onSaved }: { f: AdminField; canWrite: boolean; props: OntoProperty[]; onSaved: () => void }) {
  const { toast } = useAuth();
  const [edit, setEdit] = useState(false);
  const [x, setX] = useState({ label_ko: f.label_ko ?? '', description: f.description ?? '', is_pii: f.is_pii, maps_to_property_iri: f.maps_to_property_iri ?? '' });
  const { busy, err, run } = useBusy();
  const url = `/api/admin/datasets/${encodeURIComponent(f.dataset_id)}/fields/${encodeURIComponent(f.field_name)}`;
  const save = (decision: 'ACCEPT' | 'REJECT' | null) => run(put(url, { ...x, maps_to_property_iri: x.maps_to_property_iri || null, decision }), () => {
    toast(decision === 'ACCEPT' ? t('{f} 매핑을 승인했어요.', { f: f.field_name }) : decision === 'REJECT' ? t('{f} 매핑을 반려했어요.', { f: f.field_name }) : t('{f} 를 저장했어요.', { f: f.field_name })); setEdit(false); onSaved(); });
  const pending = f.maps_to_property_iri && f.mapping_status !== 'APPROVED';
  if (!edit) return (
    <tr>
      <td><span className="mono">{f.field_name}</span>{f.is_pk && <> <Pill>PK</Pill></>}{f.is_pii && <> <Pill cls="p-warn">{t('개인정보')}</Pill></>}<div className="small muted">{f.label_ko ?? ''}{f.is_required ? ` · ${t('필수')}` : ''}{f.description ? ` · ${f.description}` : ''}</div></td>
      <td className="mono small">{f.data_type ?? '—'}</td>
      <td className="mono small">{f.maps_to_property_iri ? `ksx:${lastName(f.maps_to_property_iri)}` : <span className="muted">{t('레이크 메타')}</span>}</td>
      <td className="small">{f.mapping_method ?? '—'}{f.mapping_confidence != null ? ` · ${f.mapping_confidence}` : ''}{f.mapping_status ? ` · ${f.mapping_status}` : ''}</td>
      {canWrite && <td className="r" style={{ whiteSpace: 'nowrap' }}>
        {pending && <><button className="btn icon" type="button" title={t('매핑 승인')} aria-label={t('{f} 매핑 승인', { f: f.field_name })} disabled={busy || DEMO} onClick={() => save('ACCEPT')}><Check aria-hidden="true" /></button>
          <button className="btn icon" type="button" title={t('매핑 반려')} aria-label={t('{f} 매핑 반려', { f: f.field_name })} disabled={busy || DEMO} onClick={() => save('REJECT')}><X aria-hidden="true" /></button></>}
        <button className="btn icon" type="button" title={t('수정')} aria-label={t('{id} 수정', { id: f.field_name })} disabled={DEMO} onClick={() => setEdit(true)}><Pencil aria-hidden="true" /></button>
        {err && <div className="small" style={{ color: 'var(--crit)' }}>{err}</div>}
      </td>}
    </tr>);
  return (
    <tr>
      <td colSpan={5}>
        <div className="formgrid" style={{ padding: '4px 0' }}>
          <label className="fld"><span>{t('컬럼')} <code className="mono">{f.field_name}</code> · {t('한글 이름')}</span><input className="input" value={x.label_ko} onChange={(e) => setX({ ...x, label_ko: e.target.value })} /></label>
          <label className="fld"><span>{t('온톨로지 속성')}</span><select className="input mono" value={x.maps_to_property_iri} onChange={(e) => setX({ ...x, maps_to_property_iri: e.target.value })}>
            <option value="">{t('(없음 · 레이크 메타)')}</option>{props.map((p) => <option key={p.property_iri} value={p.property_iri}>ksx:{p.local_name}{p.label_ko ? ` · ${p.label_ko}` : ''}</option>)}</select></label>
          <label className="fld"><span>{t('설명')}</span><input className="input" value={x.description} onChange={(e) => setX({ ...x, description: e.target.value })} /></label>
          <label className="fld" style={{ flexDirection: 'row', alignItems: 'center', gap: 8, alignSelf: 'end' }}><input type="checkbox" checked={x.is_pii} onChange={(e) => setX({ ...x, is_pii: e.target.checked })} /><span>{t('개인정보 항목')}</span></label>
        </div>
        {err && <div className="banner" role="alert">{err}</div>}
        <div className="acts" style={{ marginTop: 8 }}><button className="btn primary" type="button" disabled={busy || DEMO} onClick={() => save(null)}>{t('저장')}</button><button className="btn" type="button" onClick={() => setEdit(false)}>{t('취소')}</button></div>
      </td>
    </tr>);
}

/* ── 매핑 버전 상태 ────────────────────────────────────────────────────── */
export function MappingButtons({ m, onDone }: { m: AdminMapping; onDone: () => void }) {
  const { toast } = useAuth();
  const { busy, err, run } = useBusy();
  const set = (status: string) => run(post('/api/admin/mappings/status', { mapping_id: m.mapping_id, status }), () => { toast(t('매핑 상태를 {s} 로 바꿨어요.', { s: status })); onDone(); });
  return <div className="acts" style={{ justifyContent: 'flex-start', marginTop: 4 }}>
    {m.status !== 'APPROVED' && <button className="btn" type="button" disabled={busy || DEMO} onClick={() => set('APPROVED')}>{t('승인')}</button>}
    {m.status === 'APPROVED' && <button className="btn" type="button" disabled={busy || DEMO} onClick={() => set('REVIEW')}>{t('검토로 되돌리기')}</button>}
    {m.status !== 'RETIRED' && <button className="btn" type="button" disabled={busy || DEMO} onClick={() => set('RETIRED')}>{t('폐기')}</button>}
    {err && <span className="small" style={{ color: 'var(--crit)' }}>{err}</span>}
  </div>;
}

/* ── 품질 규칙 ─────────────────────────────────────────────────────────── */
export function RuleForm({ rule, datasets, classes, onDone, onCancel }: { rule: QualityRule | null; datasets: { dataset_id: string; title_ko: string }[]; classes: { class_iri: string; label_ko: string }[]; onDone: () => void; onCancel: () => void }) {
  const { toast } = useAuth();
  const blank = { rule_id: '', label_ko: '', dimension: '완전성', target_kind: 'dataset', target_class_iri: '', target_dataset_id: '', shape_iri: '', sql_check: '', severity: 'Violation', threshold: '', enabled: true }; // i18n-ignore
  const [f, setF] = useState(rule ? { rule_id: rule.rule_id, label_ko: rule.label_ko, dimension: rule.dimension ?? '완전성', target_kind: rule.target_class_iri ? 'class' : 'dataset', target_class_iri: rule.target_class_iri ?? '', // i18n-ignore
    target_dataset_id: rule.target_dataset_id ?? '', shape_iri: rule.shape_iri ?? '', sql_check: rule.sql_check ?? '', severity: rule.severity, threshold: rule.threshold == null ? '' : String(rule.threshold), enabled: rule.enabled } : blank);
  const { busy, err, run } = useBusy();
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const submit = (e: FormEvent) => {
    e.preventDefault();
    run(put(`/api/admin/quality/rules/${encodeURIComponent(f.rule_id.trim())}`, { label_ko: f.label_ko.trim(), dimension: f.dimension, target_class_iri: f.target_kind === 'class' ? f.target_class_iri || null : null,
      target_dataset_id: f.target_kind === 'dataset' ? f.target_dataset_id || null : null, shape_iri: f.shape_iri.trim() || null, sql_check: f.sql_check.trim() || null, severity: f.severity,
      threshold: f.threshold === '' ? null : Number(f.threshold), enabled: f.enabled }), () => { toast(t('규칙 {id} 를 저장했어요.', { id: f.rule_id.trim() })); onDone(); });
  };
  return (
    <form className="panel" onSubmit={submit} aria-label={rule ? t('규칙 수정') : t('새 품질 규칙')}>
      <header><h2>{rule ? t('규칙 수정') : t('새 품질 규칙')}</h2>{rule && <span className="small muted mono">{rule.rule_id}</span>}</header>
      <div className="formgrid">
        <label className="fld"><span>{t('규칙 ID')}</span><input className="input mono" required readOnly={!!rule} pattern="[A-Za-z0-9][A-Za-z0-9._\-]{1,99}" placeholder="lot-qty-positive" value={f.rule_id} onChange={set('rule_id')} /></label>
        <label className="fld"><span>{t('규칙 이름')}</span><input className="input" required maxLength={200} value={f.label_ko} onChange={set('label_ko')} /></label>
        <label className="fld"><span>{t('차원')}</span><select className="input" value={f.dimension} onChange={set('dimension')}>{DIMENSIONS.map((d) => <option key={d} value={d}>{dimName(d)}</option>)}</select></label>
        <label className="fld"><span>{t('심각도')}</span><select className="input" value={f.severity} onChange={set('severity')}>{SEVERITIES.map((s) => <option key={s} value={s}>{sevName(s)}</option>)}</select></label>
        <label className="fld"><span>{t('대상 종류')}</span><select className="input" value={f.target_kind} onChange={set('target_kind')}><option value="dataset">{t('데이터셋')}</option><option value="class">{t('클래스')}</option></select></label>
        {f.target_kind === 'dataset'
          ? <label className="fld"><span>{t('대상 데이터셋')}</span><select className="input" required value={f.target_dataset_id} onChange={set('target_dataset_id')}><option value="">{t('데이터셋을 고르세요')}</option>{datasets.map((d) => <option key={d.dataset_id} value={d.dataset_id}>{d.title_ko} · {d.dataset_id}</option>)}</select></label>
          : <label className="fld"><span>{t('대상 클래스')}</span><select className="input" required value={f.target_class_iri} onChange={set('target_class_iri')}><option value="">{t('클래스를 고르세요')}</option>{classes.map((c) => <option key={c.class_iri} value={c.class_iri}>{c.label_ko} · ksx:{lastName(c.class_iri)}</option>)}</select></label>}
        <label className="fld"><span>{t('기준 적합률 % (비우면 없음)')}</span><input className="input num" type="number" min={0} max={100} step="0.1" value={f.threshold} onChange={set('threshold')} /></label>
        <label className="fld"><span>{t('SHACL 셰이프 IRI (선택)')}</span><input className="input mono" value={f.shape_iri} onChange={set('shape_iri')} /></label>
        <label className="fld" style={{ gridColumn: '1 / -1' }}><span>{t('검사식 (SELECT · 위반 행을 돌려줘요. 열: focus_node, result_path, message)')}</span>
          <textarea className="input mono" rows={4} spellCheck={false} value={f.sql_check} onChange={set('sql_check')} placeholder="SELECT lot_id AS focus_node, 'lot_created_quantity' AS result_path, '수량이 0 이하' AS message FROM ksx.lot WHERE lot_created_quantity <= 0" /></label>{/* i18n-ignore: SQL 예시 */}
        <label className="fld" style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}><input type="checkbox" checked={f.enabled} onChange={(e) => setF((x) => ({ ...x, enabled: e.target.checked }))} /><span>{t('켜 두기')}</span></label>
      </div>
      <p className="note">{t('검사식은 읽기 전용 계정(lake_agent)으로 내 범위 안에서만 실행돼요. 검사식이 없는 규칙(SHACL)은 배치 파이프라인이 돌려요.')}</p>
      {err && <div className="banner" role="alert">{err}</div>}
      <div className="acts" style={{ marginTop: 12 }}><button className="btn primary" type="submit" disabled={busy || DEMO}>{rule ? t('저장') : t('등록')}</button><button className="btn" type="button" onClick={onCancel}>{t('취소')}</button></div>
    </form>);
}

export function RuleRowButtons({ r, onEdit, onDone }: { r: QualityRule; onEdit: () => void; onDone: (msg: string) => void }) {
  const { busy, err, run } = useBusy();
  const runNow = () => run(post<QualityRunResult>(`/api/admin/quality/rules/${encodeURIComponent(r.rule_id)}/run`, {}), (x) =>
    onDone(t('{id} 실행: 대상 {f}건, 위반 {v}건, 적합률 {rate}%', { id: r.rule_id, f: x.focus_count, v: x.violation_count, rate: x.conformance_rate == null ? '—' : Math.round(x.conformance_rate * 10) / 10 })
      + (x.new_violations == null ? '' : ` · ${t('새 위반 {n} · 이어짐 {k} · 자동 해결 {a}', { n: x.new_violations, k: x.carried_violations ?? 0, a: x.auto_resolved ?? 0 })}`)));
  const remove = () => { if (!window.confirm(t('규칙 {id} 를 지울까요? 위반 기록이 있으면 거절돼요.', { id: r.rule_id }))) return; run(del(`/api/admin/quality/rules/${encodeURIComponent(r.rule_id)}`), () => onDone(t('규칙 {id} 를 지웠어요.', { id: r.rule_id }))); };
  return <td className="r" style={{ whiteSpace: 'nowrap' }} onClick={(e) => e.stopPropagation()}>
    {r.sql_check && <button className="btn icon" type="button" title={t('바로 실행')} aria-label={t('{id} 바로 실행', { id: r.rule_id })} disabled={busy || DEMO} onClick={runNow}><Play aria-hidden="true" /></button>}
    <button className="btn icon" type="button" title={t('수정')} aria-label={t('{id} 수정', { id: r.rule_id })} disabled={DEMO} onClick={onEdit}><Pencil aria-hidden="true" /></button>
    <button className="btn icon" type="button" title={t('삭제')} aria-label={t('{id} 삭제', { id: r.rule_id })} disabled={busy || DEMO} onClick={remove}><Trash2 aria-hidden="true" /></button>
    {err && <div className="small" style={{ color: 'var(--crit)', whiteSpace: 'normal', maxWidth: 240 }}>{err}</div>}
  </td>;
}

/* ── 위반 처리 ─────────────────────────────────────────────────────────── */
export function ViolationActions({ v, people, onDone }: { v: QualityViolation; people: Person[]; onDone: () => void }) {
  const { toast } = useAuth();
  const { busy, err, run } = useBusy();
  const set = (status: string, assignee: string | null = v.assignee_user_id) => run(put(`/api/admin/quality/violations/${v.violation_id}`, { status, assignee_user_id: assignee }), () => { toast(t('위반 #{id} 를 {s} 로 바꿨어요.', { id: v.violation_id, s: violStatus(status)?.[0] ?? status })); onDone(); });
  return <>
    <select className="input" aria-label={t('담당자')} value={v.assignee_user_id ?? ''} disabled={busy || DEMO} onChange={(e) => set(v.status, e.target.value || null)}>
      <option value="">{t('담당자 없음')}</option>{people.map((p) => <option key={p.user_id} value={p.user_id}>{p.display_name}</option>)}</select>
    {v.status === 'OPEN' && <button className="btn" type="button" disabled={busy || DEMO} onClick={() => set('ACK')}>{t('확인함')}</button>}
    {v.status !== 'FIXED' && <button className="btn primary" type="button" disabled={busy || DEMO} onClick={() => set('FIXED')}>{t('해결')}</button>}
    {v.status === 'OPEN' && <button className="btn" type="button" disabled={busy || DEMO} onClick={() => set('WAIVED')}>{t('예외 처리')}</button>}
    {v.status !== 'OPEN' && <button className="btn" type="button" disabled={busy || DEMO} onClick={() => set('OPEN')}>{t('다시 열기')}</button>}
    {err && <span className="small" style={{ color: 'var(--crit)' }}>{err}</span>}
  </>;
}

/* ── 위험 닫기 ─────────────────────────────────────────────────────────── */
export function RiskActions({ r, onDone }: { r: AdminRisk; onDone: () => void }) {
  const { toast } = useAuth();
  const { busy, err, run } = useBusy();
  const set = (status: string) => run(post(`/api/admin/risks/${r.event_id}/status`, { status }), () => { toast(status === 'CLOSED' ? t('위험을 닫았어요.') : t('위험 알림을 억제했어요.')); onDone(); });
  return <>
    <button className="btn" type="button" disabled={busy || DEMO} onClick={() => set('CLOSED')}>{t('닫기')}</button>
    <button className="btn" type="button" disabled={busy || DEMO} onClick={() => set('SUPPRESSED')}>{t('억제')}</button>
    {err && <span className="small" style={{ color: 'var(--crit)' }}>{err}</span>}
  </>;
}

/* ── 파이프라인 ────────────────────────────────────────────────────────── */
export function PipelineEditor({ p, people, onDone }: { p: AdminPipeline; people: Person[]; onDone: () => void }) {
  const { toast } = useAuth();
  const [edit, setEdit] = useState(false);
  const [f, setF] = useState({ owner_user_id: p.owner_user_id ?? '', schedule_cron: p.schedule_cron ?? '' });
  const { busy, err, run } = useBusy();
  const save = (enabled: boolean, extra = f) => run(put(`/api/admin/pipelines/${encodeURIComponent(p.pipeline_id)}`, { enabled, owner_user_id: extra.owner_user_id || null, schedule_cron: extra.schedule_cron.trim() || null }),
    () => { toast(enabled === p.enabled ? t('파이프라인 {id} 를 저장했어요.', { id: p.pipeline_id }) : enabled ? t('파이프라인 {id} 를 켰어요.', { id: p.pipeline_id }) : t('파이프라인 {id} 를 껐어요.', { id: p.pipeline_id })); setEdit(false); onDone(); });
  return <div style={{ marginTop: 4 }}>
    {!edit ? <div className="acts" style={{ justifyContent: 'flex-start' }}>
      <button className="btn" type="button" disabled={busy || DEMO} onClick={() => save(!p.enabled)}>{p.enabled ? t('끄기') : t('켜기')}</button>
      <button className="btn icon" type="button" title={t('수정')} aria-label={t('{id} 수정', { id: p.pipeline_id })} disabled={DEMO} onClick={() => setEdit(true)}><Pencil aria-hidden="true" /></button>
    </div> : <div className="formgrid" style={{ gridTemplateColumns: 'minmax(0,1fr)' }}>
      <label className="fld"><span>{t('주기 (cron 다섯 칸, 비우면 수동)')}</span><input className="input mono" value={f.schedule_cron} placeholder="*/10 * * * *" onChange={(e) => setF({ ...f, schedule_cron: e.target.value })} /></label>
      <label className="fld"><span>{t('담당자')}</span><PeopleSelect value={f.owner_user_id} onChange={(v) => setF({ ...f, owner_user_id: v })} blank={t('없음')} people={people} /></label>
      <div className="acts"><button className="btn primary" type="button" disabled={busy || DEMO} onClick={() => save(p.enabled)}>{t('저장')}</button><button className="btn" type="button" onClick={() => setEdit(false)}>{t('취소')}</button></div>
    </div>}
    {err && <div className="small" style={{ color: 'var(--crit)' }}>{err}</div>}
  </div>;
}
