import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import type { QualityRule, QualityViolation } from '../../api';
import { Pill, State } from '../../components/ui';
import { fmtTs } from '../../format';
import { useApi } from '../../useApi';
import { t } from '../../i18n';
import { Head, lastName, num, violStatus } from './common';

export default function Quality() {
  const { data, error, loading } = useApi<{ rules: QualityRule[]; violations: QualityViolation[] }>('/api/admin/quality');
  const [rule, setRule] = useState('ALL');
  const [st, setSt] = useState('ALL');
  useEffect(() => { document.title = `${t('품질 검증')} · ${t('뉴레이크')}`; }, []);
  const rules = data?.rules ?? [];
  const dims = useMemo(() => {
    const m = new Map<string, { f: number; v: number }>();
    rules.forEach((r) => { if (r.focus_count == null) return; const k = r.dimension ?? t('기타'), x = m.get(k) ?? { f: 0, v: 0 }; m.set(k, { f: x.f + r.focus_count, v: x.v + (r.violation_count ?? 0) }); });
    return [...m.entries()].map(([k, x]) => [k, x.f ? Math.round((1000 * (x.f - x.v)) / x.f) / 10 : null] as [string, number | null]);
  }, [rules]);
  const ruleName = (id: string) => rules.find((r) => r.rule_id === id)?.label_ko ?? id;
  const viol = (data?.violations ?? []).filter((v) => (rule === 'ALL' || v.rule_id === rule) && (st === 'ALL' || v.status === st));
  const open = (data?.violations ?? []).filter((v) => v.status === 'OPEN').length;
  return (
    <>
      <Head title={t('품질 검증')} lede={t('품질 규칙은 SHACL 셰이프로 정의하고, 레이크에 들어오는 배치마다 돌려요. 위반이 있는 배치는 시맨틱 존으로 올라가지 않아요.')} />
      <State loading={loading} error={error} />
      {data && <>
        <div className="grid g4">
          {dims.map(([n, v]) => (
            <div key={n} className="panel kpi"><span className="kl">{t('KS X 9101 {name} 차원', { name: n })}</span><span className="kv num">{v == null ? '—' : `${v}%`}</span>
              {v != null && <div className="bar" style={{ ['--bc' as string]: v < 99 ? 'var(--warn)' : 'var(--ok)' }}><i style={{ width: `${v}%` }} /></div>}</div>))}
          {dims.length === 0 && <div className="panel muted small">{t('실행된 규칙이 없어요.')}</div>}
        </div>
        <div className="grid g2" style={{ marginTop: 14 }}>
          <section className="panel"><header><h2>{t('규칙')}</h2><span className="small muted">catalog.quality_rule · {t('{n}개', { n: rules.length })}</span></header>
            <div className="tablewrap"><table><thead><tr><th>{t('규칙')}</th><th>{t('대상')}</th><th className="r">{t('적합률')}</th><th className="r">{t('위반')}</th></tr></thead><tbody>
              {rules.map((r) => (
                <tr key={r.rule_id} className={`click ${rule === r.rule_id ? 'sel' : ''}`} tabIndex={0} onClick={() => setRule(rule === r.rule_id ? 'ALL' : r.rule_id)} onKeyDown={(e) => { if (e.key === 'Enter') setRule(rule === r.rule_id ? 'ALL' : r.rule_id); }}>
                  <td>{r.label_ko}<div className="mono muted small">{r.shape_iri ? `ksx:${lastName(r.shape_iri)}` : r.rule_id} · {r.dimension ?? '—'} · {r.severity}{r.enabled ? '' : ` · ${t('꺼짐')}`}</div></td>
                  <td className="small">{r.class_label ?? r.target_dataset_id ?? '—'}{r.last_dataset_id && <div className="mono muted">{r.last_dataset_id}</div>}</td>
                  <td className="r num">{r.conformance_rate == null ? '—' : `${r.conformance_rate}%`}<div className="small muted">{t('기준 {v}%', { v: r.threshold ?? '—' })}</div></td>
                  <td className="r">{r.violation_count == null ? '—' : <Pill cls={r.violation_count === 0 ? 'p-ok' : (r.conformance_rate ?? 100) < (r.threshold ?? 0) ? 'p-crit' : 'p-warn'}>{num(r.violation_count)}</Pill>}
                    <div className="small muted">{fmtTs(r.last_run_at)}</div></td>
                </tr>))}
              {rules.length === 0 && <tr><td colSpan={4} className="muted">{t('등록된 규칙이 없어요.')}</td></tr>}
            </tbody></table></div>
            <p className="hint" style={{ marginTop: 8 }}>{t('규칙 행을 누르면 그 규칙의 위반만 모아 봐요.')}</p>
          </section>
          <section className="panel">
            <header><h2>{t('위반 상세')}</h2><Pill cls={open ? 'p-crit' : 'p-ok'}>{t('미처리 {n}건', { n: open })}</Pill></header>
            <div className="toolbar">
              {['ALL', 'OPEN', 'ACK', 'RESOLVED'].map((s) => <button key={s} className="chip" type="button" aria-pressed={st === s} onClick={() => setSt(s)}>{s === 'ALL' ? t('전체') : violStatus(s)![0]}</button>)}
              {rule !== 'ALL' && <button className="chip" type="button" onClick={() => setRule('ALL')}>{t('규칙 필터 해제 ✕')}</button>}
            </div>
            <div className="alerts">
              {viol.map((v) => {
                const [vs, vsc] = violStatus(v.status) || [v.status, 'p-line'];
                return (
                  <article key={v.violation_id} className="alert task" style={{ ['--sc' as string]: v.status === 'OPEN' ? 'var(--crit)' : v.status === 'ACK' ? 'var(--warn)' : 'var(--ok)' }}>
                    <span className="sev" />
                    <div><b>{lastName(v.focus_node)}{v.result_path ? ` · ${v.result_path}` : ''}</b><p>{v.message}</p>
                      <div className="meta"><Pill cls={vsc}>{vs}</Pill><Pill>{v.severity}</Pill><Pill>{ruleName(v.rule_id)}</Pill><Pill>{fmtTs(v.executed_at)}</Pill>{v.assignee_user_id && <Pill>{t('담당 {id}', { id: v.assignee_user_id })}</Pill>}</div></div>
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
