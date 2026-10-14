import { Fragment, useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { useLocation } from 'react-router-dom';
import { runQuery, type QueryResult } from '../api';
import { DataTable, TierLegend } from '../components/ui';
import { t, locale } from '../i18n';
import { PRESETS, SUGGESTED, looksLikeSql, matchPreset, type Preset } from '../askPresets';

/** '{이름}' 자리표시자를 노드로 바꿔 끼운다 (문장 안에 JSX 가 들어갈 때) */
const rich = (s: string, m: Record<string, ReactNode>): ReactNode[] => s.split(/(\{\w+\})/).map((p, i) => (/^\{\w+\}$/.test(p) && p.slice(1, -1) in m ? <Fragment key={i}>{m[p.slice(1, -1)]}</Fragment> : p));

interface Turn {
  id: number;
  q: string;
  mode: 'preset' | 'sql' | 'none';
  sql?: string;
  note?: string;
  loading?: boolean;
  result?: QueryResult;
  error?: string;
}

export default function Ask() {
  const loc = useLocation();
  const [turns, setTurns] = useState<Turn[]>([]);
  const [text, setText] = useState('');
  const [sqlText, setSqlText] = useState('SELECT * FROM mart.v_kpi_wip');
  const seq = useRef(0);
  const handled = useRef('');
  const endRef = useRef<HTMLDivElement>(null);

  const patch = (id: number, p: Partial<Turn>) => setTurns((ts) => ts.map((x) => (x.id === id ? { ...x, ...p } : x)));

  const exec = (id: number, sql: string, question?: string) => {
    runQuery(sql, question).then((result) => patch(id, { loading: false, result })).catch((e: Error) => patch(id, { loading: false, error: e.message }));
  };

  const ask = (q: string, preset?: Preset | null) => {
    const question = q.trim(); if (!question) return;
    const id = ++seq.current;
    if (looksLikeSql(question)) {
      setTurns((ts) => [...ts, { id, q: question, mode: 'sql', sql: question, loading: true }]);
      exec(id, question);
      return;
    }
    const p = preset ?? matchPreset(question);
    if (!p) {
      setTurns((ts) => [...ts, { id, q: question, mode: 'none' }]);
    } else if (!p.sql) {
      setTurns((ts) => [...ts, { id, q: question, mode: 'preset', note: p.unsupported }]);
    } else {
      setTurns((ts) => [...ts, { id, q: question, mode: 'preset', sql: p.sql!, loading: true }]);
      exec(id, p.sql, question);
    }
  };

  // 홈에서 넘어온 ?q= / ?p= 처리 (StrictMode 중복 실행 방지)
  useEffect(() => {
    if (handled.current === loc.search) return;
    handled.current = loc.search;
    const sp = new URLSearchParams(loc.search);
    const pid = sp.get('p'), q = sp.get('q');
    if (pid) { const p = PRESETS.find((x) => x.id === pid); if (p) ask(p.question, p); }
    else if (q) ask(q);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loc.search]);

  useEffect(() => { endRef.current?.scrollIntoView?.({ block: 'nearest' }); }, [turns.length]);

  const submit = (e: FormEvent) => { e.preventDefault(); ask(text); setText(''); };
  const submitSql = (e: FormEvent) => { e.preventDefault(); ask(sqlText); };

  return (
    <>
      <div className="head"><div><h1>{t('질문하기')}</h1>
        <p className="lede">{t('평소 말로 물어보세요. 답마다 어떤 기록을 근거로 했는지 함께 보여 드려요.')}</p></div></div>
      <div className="chat">
        <section className="panel">
          <p className="preset-note" role="note"><b>{t('준비된 질의로 답하는 중이에요.')}</b> {t('아직 LLM이 연결되지 않아서 질문을 직접 이해하지 못해요. 추천 질문을 누르면 미리 만들어 둔 SQL을 실행해 그 결과를 보여 드려요. SQL을 직접 입력해도 돼요.')}</p>
          <div className="msgs" id="msgs">
            {turns.length === 0 && <div className="msg bot"><p>{t('아래 추천 질문을 눌러 보세요. 실행한 SQL과 결과 표를 함께 보여 드려요.')}</p></div>}
            {turns.map((tn) => (
              <div key={tn.id} style={{ display: 'contents' }}>
                <div className="msg user">{tn.q}</div>
                <div className="msg bot">
                  {tn.mode === 'none' && <p>{rich(t('지금은 LLM이 연결되지 않아 준비된 질문에만 답할 수 있어요. 아래 추천 질문을 누르거나 {kw} 문을 직접 입력해 주세요.'), { kw: <b>SELECT</b> })}</p>}
                  {tn.mode === 'preset' && tn.note && <p>{tn.note}</p>}
                  {tn.sql && <>
                    <p className="small muted">{tn.mode === 'preset' ? t('이 질문에 미리 연결해 둔 질의를 실행했어요. (준비된 질의 · LLM 연결 전)') : t('입력한 SQL을 그대로 실행했어요.')}</p>
                    <details className="evd" open><summary>{t('실행한 SQL')}</summary><pre className="code">{tn.sql}</pre></details>
                    {tn.loading && <p className="muted small">{t('실행 중이에요…')}</p>}
                    {tn.error && <div className="banner" role="alert">{tn.error}</div>}
                    {tn.result && <>
                      <p className="small"><b>{t('{n}행', { n: tn.result.row_count.toLocaleString(locale()) })}</b>{tn.result.truncated && <span className="muted"> · {t('결과가 길어서 일부만 보여 드려요')}</span>}</p>
                      <DataTable cols={tn.result.rows[0] ? Object.keys(tn.result.rows[0]) : []} rows={tn.result.rows} />
                    </>}
                  </>}
                </div>
              </div>
            ))}
            <div ref={endRef} />
          </div>
          <form className="composer" onSubmit={submit}>
            <input className="input grow" value={text} onChange={(e) => setText(e.target.value)} placeholder={t('질문을 입력하세요 (SELECT 로 시작하면 SQL로 실행해요)')} autoComplete="off" aria-label={t('질문 입력')} />
            <button className="btn primary" type="submit">{t('보내기')}</button>
          </form>
          <div className="suggest">{SUGGESTED.map((s) => <button key={s.id} className="chip" type="button" onClick={() => ask(s.question, s)}>{s.question}</button>)}</div>
          <details className="tech" style={{ marginTop: 16 }}><summary>{t('SQL 직접 입력')}</summary>
            <form onSubmit={submitSql} style={{ marginTop: 8 }}>
              <textarea className="sql" value={sqlText} onChange={(e) => setSqlText(e.target.value)} spellCheck={false} aria-label="SQL" />
              <div className="acts" style={{ justifyContent: 'flex-start', marginTop: 6 }}>
                <button className="btn primary" type="submit">{t('실행')}</button>
                <span className="hint">{t('ksx.* / mart.* 에 대한 SELECT 한 문장만 실행돼요. 권한 밖 데이터는 보이지 않아요.')}</span>
              </div>
            </form>
          </details>
        </section>
        <div style={{ display: 'grid', gap: 14 }}>
          <TierLegend />
          <p className="note" style={{ margin: 0 }}>{t('지금 보이는 결과에는 AI 추정이 없어요. 모두 미리 만든 SQL이 데이터를 조회한 값이에요. LLM이 연결되면 질문을 이해하고 문장을 쓰는 데만 쓰고, 숫자는 계속 기록과 규칙으로 계산해요.')}</p>
        </div>
      </div>
    </>
  );
}
