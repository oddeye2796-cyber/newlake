import { useEffect, useRef, useState, type FormEvent, type KeyboardEvent } from 'react';
import { ApiError, runQuery, type QueryResult } from '../../api';
import { PRESETS } from '../../askPresets';
import { DataTable } from '../../components/ui';
import { locale, t } from '../../i18n';
import { Head } from './common';

const samples = () => PRESETS.filter((p) => p.sql).map((p) => ({ id: p.id, title: p.question, sql: p.sql as string }));
const extra = () => [{ id: 'kpi-wip', title: t('진행 중 로트 현황 (mart 뷰)'), sql: 'SELECT * FROM mart.v_kpi_wip' }];

export default function Workbench() {
  const all = [...samples(), ...extra()];
  const [cur, setCur] = useState(all[0].id);
  const [sql, setSql] = useState(all[0].sql);
  const [res, setRes] = useState<QueryResult | null>(null);
  const [err, setErr] = useState<{ msg: string; raw?: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [ms, setMs] = useState<number | null>(null);
  const seq = useRef(0);
  useEffect(() => { document.title = `${t('질의 작업대')} · ${t('뉴레이크')}`; }, []);

  const run = (e?: FormEvent) => {
    e?.preventDefault();
    if (!sql.trim()) return;
    const my = ++seq.current, t0 = performance.now();
    setBusy(true); setErr(null);
    runQuery(sql)
      .then((r) => { if (my === seq.current) { setRes(r); setMs(Math.round(performance.now() - t0)); } })
      .catch((x: Error) => { if (my === seq.current) { setRes(null); setErr({ msg: x.message, raw: x instanceof ApiError && x.raw !== x.message ? x.raw : undefined }); setMs(null); } })
      .finally(() => { if (my === seq.current) setBusy(false); });
  };
  const key = (e: KeyboardEvent) => { if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') run(); };
  const load = (id: string) => { const s = all.find((x) => x.id === id)!; setCur(id); setSql(s.sql); setRes(null); setErr(null); setMs(null); };

  return (
    <>
      <Head title={t('질의 작업대')} lede={t('표준 존(ksx.*)과 활용 존(mart.*) 뷰에 SQL을 직접 던져 봐요. SELECT 한 문장만 실행되고, 내 권한 밖 데이터는 보이지 않아요.')} />
      <div className="qwrap">
        <section className="panel"><h3 style={{ marginBottom: 8 }}>{t('예시 질의')}</h3>
          <div className="saved">{all.map((s) => <button key={s.id} type="button" aria-current={s.id === cur} onClick={() => load(s.id)}><b>{s.title}</b><small>SQL</small></button>)}</div>
        </section>
        <section className="panel">
          <form onSubmit={run}>
            <label className="small muted" htmlFor="wb-sql">{t('SQL (실행: Ctrl+Enter). 연결: ksx.* / mart.* 뷰 · 역할별 행 단위 권한 적용')}</label>
            <textarea id="wb-sql" className="sql" style={{ minHeight: 280, marginTop: 6 }} value={sql} onChange={(e) => setSql(e.target.value)} onKeyDown={key} spellCheck={false} />
            <div className="toolbar" style={{ marginTop: 8 }}>
              <button className="btn primary" type="submit" disabled={busy}>{busy ? t('실행 중…') : t('실행')}</button>
              <button className="btn" type="button" onClick={() => load(cur)}>{t('예시로 되돌리기')}</button>
              {res && <span className="small">{t('{n}행', { n: res.row_count.toLocaleString(locale()) })}{res.truncated ? ` ${t('(일부만 표시)')}` : ''}{ms != null ? ` · ${ms}ms` : ''}</span>}
            </div>
          </form>
          {err && <div className="banner" role="alert">{err.msg}{err.raw && <div className="small mono" style={{ marginTop: 4, opacity: 0.75 }}>{t('원문: {raw}', { raw: err.raw })}</div>}</div>}
          {res && <div className="wb-res"><DataTable cols={res.rows[0] ? Object.keys(res.rows[0]) : []} rows={res.rows} /></div>}
          <p className="note">{t('SPARQL과 자연어 질의는 아직 연결되지 않았어요. 자연어는 질문하기 화면의 추천 질문을 써 주세요.')}</p>
        </section>
      </div>
    </>
  );
}
