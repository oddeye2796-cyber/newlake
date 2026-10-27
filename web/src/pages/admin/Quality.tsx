import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Plus } from 'lucide-react';
import type { AdminClassRow, AdminDatasetRow, Person, QualityRule, QualityViolation, SemanticBlocker } from '../../api';
import { useAuth } from '../../auth';
import { Pill, State } from '../../components/ui';
import { fmtTs } from '../../format';
import { useApi } from '../../useApi';
import { t, tl } from '../../i18n';
import { Head, lastName, num, violStatus } from './common';
import { DEMO, RuleForm, RuleRowButtons, ViolationActions, dimName, hasRole } from './Steward';

export default function Quality() {
  const { me, toast } = useAuth();
  const { data, error, loading, reload } = useApi<{ rules: QualityRule[]; violations: QualityViolation[]; semantic_blocked?: SemanticBlocker[] }>('/api/admin/quality');
  const [rule, setRule] = useState('ALL');
  const [st, setSt] = useState('ALL');
  const canWrite = hasRole(me, 'quality_engineer', 'data_steward');
  const [form, setForm] = useState<QualityRule | null | 'new'>(null);
  const datasets = useApi<AdminDatasetRow[]>(form ? '/api/admin/datasets' : null);
  const classes = useApi<AdminClassRow[]>(form ? '/api/admin/ontology/classes' : null);
  const people = useApi<Person[]>(canWrite ? '/api/admin/people' : null);
  const done = (msg: string) => { toast(msg); setForm(null); reload(); };
  useEffect(() => { document.title = `${t('품질 검증')} · ${'ARCON'}`; }, []);
  const rules = data?.rules ?? [];
  const dims = useMemo(() => {
    const m = new Map<string, { f: number; v: number }>();
    rules.forEach((r) => { if (r.focus_count == null) return; const k = r.dimension ?? t('기타'), x = m.get(k) ?? { f: 0, v: 0 }; m.set(k, { f: x.f + r.focus_count, v: x.v + (r.violation_count ?? 0) }); });
    return [...m.entries()].map(([k, x]) => [k, x.f ? Math.round((1000 * (x.f - x.v)) / x.f) / 10 : null] as [string, number | null]);
  }, [rules]);
  const ruleName = (id: string) => tl(rules.find((r) => r.rule_id === id)?.label_ko) ?? id;
  const viol = (data?.violations ?? []).filter((v) => (rule === 'ALL' || v.rule_id === rule) && (st === 'ALL' || v.status === st));
  const open = (data?.violations ?? []).filter((v) => v.status === 'OPEN').length;
  return (
    <>
      <Head title={t('품질 검증')} lede={t('품질 규칙은 표준 존 표를 검사해요. 데이터를 넣을 때 자동으로 돌고, 바로 실행할 수도 있어요. 기준 적합률에 못 미친(부적합) 데이터셋은 시맨틱 존으로 올리는 파이프라인이 시작되지 않아요.')}
        right={canWrite && <button className="btn primary" type="button" disabled={DEMO} onClick={() => setForm('new')}><Plus aria-hidden="true" /> {t('새 규칙')}</button>} />
      <State loading={loading} error={error} />
      {data && form && <div style={{ marginBottom: 14 }}><RuleForm rule={form === 'new' ? null : form} datasets={datasets.data ?? []} classes={classes.data ?? []} onDone={() => done(t('규칙을 저장했어요.'))} onCancel={() => setForm(null)} /></div>}
      {data && <>
        {(data.semantic_blocked ?? []).length > 0 && <div className="banner" role="status" style={{ marginBottom: 14 }}>
          <b>{t('시맨틱 존 반영 보류')}</b> · {t('아래 데이터셋이 품질 부적합이라 시맨틱 존 파이프라인이 시작되지 않아요. 원천 데이터를 고쳐 다시 넣고 규칙을 다시 돌리면 풀려요.')}
          <ul className="evlist" style={{ marginTop: 6 }}>{(data.semantic_blocked ?? []).map((b) => (
            <li key={`${b.pipeline_id}/${b.dataset_id}`}><Link to={`/admin/catalog/${encodeURIComponent(b.dataset_id)}`}>{tl(b.dataset_title)}</Link> <span className="mono small muted">{b.dataset_id}</span>
              {b.quality_score != null && <> · {Math.round(b.quality_score * 10) / 10}%</>} → {tl(b.pipeline_label)}</li>))}</ul>
        </div>}
        <div className="grid g4">
          {dims.map(([n, v]) => (
            <div key={n} className="panel kpi"><span className="kl">{t('KS X 9101 {name} 차원', { name: dimName(n) })}</span><span className="kv num">{v == null ? '—' : `${v}%`}</span>
              {v != null && <div className="bar" style={{ ['--bc' as string]: v < 99 ? 'var(--warn)' : 'var(--ok)' }}><i style={{ width: `${v}%` }} /></div>}</div>))}
          {dims.length === 0 && <div className="panel muted small">{t('실행된 규칙이 없어요.')}</div>}
        </div>
        <div className="grid g2" style={{ marginTop: 14 }}>
          <section className="panel"><header><h2>{t('규칙')}</h2><span className="small muted">catalog.quality_rule · {t('{n}개', { n: rules.length })}</span></header>
            <div className="tablewrap"><table><thead><tr><th>{t('규칙')}</th><th>{t('대상')}</th><th className="r">{t('적합률')}</th><th className="r">{t('위반')}</th>{canWrite && <th />}</tr></thead><tbody>
              {rules.map((r) => (
                <tr key={r.rule_id} className={`click ${rule === r.rule_id ? 'sel' : ''}`} tabIndex={0} onClick={() => setRule(rule === r.rule_id ? 'ALL' : r.rule_id)} onKeyDown={(e) => { if (e.key === 'Enter') setRule(rule === r.rule_id ? 'ALL' : r.rule_id); }}>
                  <td style={{ minWidth: 170 }}>{tl(r.label_ko)}<div className="mono muted small">{r.shape_iri ? `ksx:${lastName(r.shape_iri)}` : r.rule_id} · {dimName(r.dimension)} · {r.severity}{r.sql_check ? ' · SQL' : ''}{r.enabled ? '' : ` · ${t('꺼짐')}`}</div></td>
                  <td className="small">{tl(r.class_label) ?? r.target_dataset_id ?? '—'}{r.last_dataset_id && <div className="mono muted">{r.last_dataset_id}</div>}</td>
                  <td className="r num">{r.conformance_rate == null ? '—' : `${Math.round(r.conformance_rate * 10) / 10}%`}<div className="small muted">{t('기준 {v}%', { v: r.threshold ?? '—' })}</div></td>
                  <td className="r">{r.violation_count == null ? '—' : <Pill cls={r.violation_count === 0 ? 'p-ok' : (r.conformance_rate ?? 100) < (r.threshold ?? 0) ? 'p-crit' : 'p-warn'}>{num(r.violation_count)}</Pill>}
                    <div className="small muted">{fmtTs(r.last_run_at)}</div></td>
                  {canWrite && <RuleRowButtons r={r} onEdit={() => setForm(r)} onDone={done} />}
                </tr>))}
              {rules.length === 0 && <tr><td colSpan={canWrite ? 5 : 4} className="muted">{t('등록된 규칙이 없어요.')}</td></tr>}
            </tbody></table></div>
            <p className="hint" style={{ marginTop: 8 }}>{t('규칙 행을 누르면 그 규칙의 위반만 모아 봐요.')}</p>
          </section>
          <section className="panel">
            <header><h2>{t('위반 상세')}</h2><Pill cls={open ? 'p-crit' : 'p-ok'}>{t('미처리 {n}건', { n: open })}</Pill></header>
            <div className="toolbar">
              {['ALL', 'OPEN', 'ACK', 'FIXED', 'WAIVED'].map((s) => <button key={s} className="chip" type="button" aria-pressed={st === s} onClick={() => setSt(s)}>{s === 'ALL' ? t('전체') : violStatus(s)![0]}</button>)}
              {rule !== 'ALL' && <button className="chip" type="button" onClick={() => setRule('ALL')}>{t('규칙 필터 해제 ✕')}</button>}
            </div>
            <div className="alerts">
              {viol.map((v) => {
                const [vs, vsc] = violStatus(v.status) || [v.status, 'p-line'];
                return (
                  <article key={v.violation_id} className="alert task" style={{ ['--sc' as string]: v.status === 'OPEN' ? 'var(--crit)' : v.status === 'ACK' ? 'var(--warn)' : v.status === 'WAIVED' ? 'var(--muted)' : 'var(--ok)' }}>
                    <span className="sev" />
                    <div><b>{lastName(v.focus_node)}{v.result_path ? ` · ${v.result_path}` : ''}</b><p>{tl(v.message)}</p>
                      <div className="meta"><Pill cls={vsc}>{vs}</Pill><Pill>{v.severity}</Pill><Pill>{ruleName(v.rule_id)}</Pill><Pill>{fmtTs(v.executed_at)}</Pill>{v.assignee_user_id && <Pill>{t('담당 {id}', { id: v.assignee_user_id })}</Pill>}</div>
                      {canWrite && <div className="acts" style={{ justifyContent: 'flex-start', marginTop: 8 }}><ViolationActions v={v} people={people.data ?? []} onDone={reload} /></div>}</div>
                    <div className="acts">{v.dataset_id && <Link className="btn" to={`/admin/catalog/${encodeURIComponent(v.dataset_id)}`}>{t('데이터셋')}</Link>}</div>
                  </article>);
              })}
              {viol.length === 0 && <p className="muted small">{t('조건에 맞는 위반이 없어요.')}</p>}
            </div>
          </section>
        </div>
      </>}
    </>
  );
}
