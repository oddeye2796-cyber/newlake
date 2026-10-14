import { CheckCircle2, Database, FileUp, Plug, RefreshCw } from 'lucide-react';
import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { get, post, postForm, type BatchDetail, type BatchRow, type Loaded, type SourceRow, type StdResult, type Target } from '../../api';
import { useAuth } from '../../auth';
import { Pill, State } from '../../components/ui';
import { fmtTs, n0 } from '../../format';
import { useApi } from '../../useApi';
import { t, tk } from '../../i18n';
import { Head } from './common';

const DEMO = import.meta.env.VITE_DEMO === '1';
type Tab = 'file' | 'db' | 'sources' | 'history';
const TABS: [Tab, string][] = [['file', tk('파일 올리기')], ['db', tk('DB에서 가져오기')], ['sources', tk('원천 관리')], ['history', tk('적재 기록')]];
const SYSTEM_TYPES = ['MES', 'ERP', 'QMS', 'WMS', 'PLM', 'SCADA', 'SECS_GEM', 'EDMS', 'SENSOR', 'FILE'];
const DB_KINDS = ['POSTGRESQL', 'MYSQL', 'MSSQL', 'ORACLE', 'FILE'];

const batchSt = (s: string): [string, string] => (({ LANDED: [t('원천 존에 있음'), 'p-warn'], STANDARDIZED: [t('표준 존 반영'), 'p-ok'], REJECTED: [t('전부 거부'), 'p-crit'], QUARANTINED: [t('격리'), 'p-crit'] } as Record<string, [string, string]>)[s] ?? [s, 'p-line']);
const connSt = (s: string | null): [string, string] => (({ OK: [t('연결됨'), 'p-ok'], FAILED: [t('연결 실패'), 'p-crit'], UNTESTED: [t('시험 전'), 'p-line'] } as Record<string, [string, string]>)[s ?? ''] ?? [t('파일 전용'), 'p-line']);
const cell = (v: unknown) => (v == null ? '' : typeof v === 'object' ? JSON.stringify(v) : String(v));

function Steps({ at }: { at: number }) {
  const names = [t('원천 고르기'), t('원천 존에 올리기'), t('열 맞추기'), t('표준 존에 넣기')];
  return <ol className="stepper ing" aria-label={t('진행 단계')}>{names.map((n, i) => <li key={n} className={`st ${i < at ? 'done' : i === at ? 'cur' : ''}`}><i />{n}</li>)}</ol>;
}

function SourcePick({ sources, value, onChange, filter }: { sources: SourceRow[]; value: string; onChange: (v: string) => void; filter?: (s: SourceRow) => boolean }) {
  const list = filter ? sources.filter(filter) : sources;
  return (
    <label className="fld"><span>{t('원천 시스템')}</span>
      <select className="input" value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">{t('원천을 고르세요')}</option>
        {list.map((s) => <option key={s.source_system_id} value={s.source_system_id}>{s.source_system_id} · {s.label_ko}</option>)}
      </select>
    </label>
  );
}

/** 원천 존에 올린 배치를 표준(KS X 9101) 표로 옮긴다. 열 대응은 서버가 이름·한글 설명으로 먼저 제안한다. */
function MapPanel({ batchId, onDone }: { batchId: string; onDone: () => void }) {
  const { toast } = useAuth();
  const targets = useApi<Target[]>('/api/admin/targets');
  const [table, setTable] = useState<string>('');
  const [detail, setDetail] = useState<BatchDetail | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [map, setMap] = useState<Record<string, string>>({});
  const [site, setSite] = useState('HQ');
  const [plant, setPlant] = useState('P1');
  const [busy, setBusy] = useState(false);
  const [res, setRes] = useState<StdResult | null>(null);

  useEffect(() => {
    setErr(null);
    get<BatchDetail>(`/api/admin/batches/${batchId}${table ? `?table=${encodeURIComponent(table)}` : ''}`)
      .then((d) => { setDetail(d); setMap(d.suggested_map); if (!table && d.suggested_table) setTable(d.suggested_table); })
      .catch((e: Error) => setErr(e.message));
  }, [batchId, table]);

  const tgt = useMemo(() => targets.data?.find((x) => x.table === table), [targets.data, table]);
  const used = new Set(Object.values(map).filter(Boolean));
  const missing = (tgt?.columns ?? []).filter((c) => (c.pk || c.required) && !used.has(c.name) && !['site_id', 'plant_id'].includes(c.name));
  const hasScope = (tgt?.columns ?? []).some((c) => c.name === 'site_id' || c.name === 'plant_id');

  const run = () => {
    setBusy(true); setErr(null);
    post<StdResult>(`/api/admin/batches/${batchId}/standardize`, { table, column_map: map, site_id: site.trim() || null, plant_id: plant.trim() || null })
      .then((r) => { setRes(r); toast(t('표준 존에 {n}행을 넣었어요.', { n: n0(r.rows_out) })); onDone(); })
      .catch((e: Error) => setErr(e.message)).finally(() => setBusy(false));
  };

  if (!detail) return <State loading={!err} error={err} />;
  const b = detail.batch;
  return (
    <section className="panel" style={{ marginTop: 14 }}>
      <header><h2>{t('열 맞추기')}</h2><span className="small muted mono">{b.dataset_id} · {t('{n}행', { n: n0(b.record_count) })}</span></header>
      <Steps at={res ? 4 : 2} />
      <h3 className="sub">{t('올린 데이터 미리보기')}</h3>
      <div className="tablewrap" style={{ maxHeight: 240, overflow: 'auto' }}><table><thead><tr>{detail.columns.map((c) => <th key={c}>{c}</th>)}</tr></thead><tbody>
        {detail.rows.map((r, i) => <tr key={i}>{detail.columns.map((c) => <td key={c} className="small">{cell(r[c])}</td>)}</tr>)}
      </tbody></table></div>

      <div className="formrow" style={{ marginTop: 14 }}>
        <label className="fld grow"><span>{t('넣을 표준 표')}</span>
          <select className="input" value={table} onChange={(e) => setTable(e.target.value)}>
            <option value="">{t('표를 고르세요')}</option>
            {(targets.data ?? []).map((x) => <option key={x.table} value={x.table}>{x.label_ko ? `${x.label_ko} · ksx.${x.table}` : `ksx.${x.table}`}</option>)}
          </select>
        </label>
        {hasScope && <>
          <label className="fld"><span>{t('기본 사업장')}</span><input className="input" value={site} onChange={(e) => setSite(e.target.value)} /></label>
          <label className="fld"><span>{t('기본 공장')}</span><input className="input" value={plant} onChange={(e) => setPlant(e.target.value)} /></label>
        </>}
      </div>
      {detail.suggested_table && <p className="note">{t('열 이름과 한글 설명을 보고 {table} 표와 {n}개 열을 먼저 짝지어 두었어요. 맞는지 확인해 주세요.', { table: `ksx.${detail.suggested_table}`, n: Object.keys(detail.suggested_map).length })}</p>}

      {tgt && <div className="tablewrap" style={{ marginTop: 10 }}><table className="maptbl"><thead><tr><th>{t('원천 열')}</th><th>{t('예시 값')}</th><th>{t('표준 열')}</th></tr></thead><tbody>
        {detail.columns.map((c) => (
          <tr key={c}><td className="mono">{c}</td><td className="small muted">{cell(detail.rows[0]?.[c])}</td>
            <td><select className="input" value={map[c] ?? ''} aria-label={t('{col} 의 표준 열', { col: c })} onChange={(e) => setMap((m) => ({ ...m, [c]: e.target.value }))}>
              <option value="">{t('— 넣지 않음 —')}</option>
              {tgt.columns.map((tc) => <option key={tc.name} value={tc.name} disabled={used.has(tc.name) && map[c] !== tc.name}>{tc.name}{tc.label_ko ? ` · ${tc.label_ko}` : ''}{tc.pk ? ` (${t('키')})` : tc.required ? ' *' : ''}</option>)}
            </select></td></tr>))}
      </tbody></table></div>}
      {missing.length > 0 && <p className="note">{t('아직 안 맞춘 필수 열: {cols}', { cols: missing.map((c) => c.name).join(', ') })}</p>}
      {err && <div className="banner" role="alert">{err}</div>}
      <div className="acts" style={{ marginTop: 12 }}>
        <button className="btn primary" type="button" disabled={busy || !table || used.size === 0 || DEMO} onClick={run}>{busy ? t('넣는 중…') : t('표준 존에 넣기')}</button>
      </div>

      {res && <div className="result" role="status">
        <div className="kv3">
          <div><span>{t('읽은 행')}</span><b className="num">{n0(res.rows_in)}</b></div>
          <div><span>{t('넣은 행')}</span><b className="num" style={{ color: 'var(--ok)' }}>{n0(res.rows_out)}</b></div>
          <div><span>{t('거부된 행')}</span><b className="num" style={{ color: res.rows_rejected ? 'var(--crit)' : undefined }}>{n0(res.rows_rejected)}</b></div>
        </div>
        {res.errors.length > 0 && <ul className="errs">{res.errors.map((e) => <li key={e.record_seq}><span className="mono">#{e.record_seq}</span> {e.error}</li>)}</ul>}
        <div className="acts">
          <Link className="btn" to={`/admin/catalog/${encodeURIComponent(b.dataset_id)}`}>{t('원천 데이터셋 보기')}</Link>
          {res.std_dataset_id && <Link className="btn" to={`/admin/catalog/${encodeURIComponent(res.std_dataset_id)}`}>{t('표준 데이터셋 보기')}</Link>}
          <Link className="btn" to="/admin/lineage">{t('계보')}</Link>
        </div>
      </div>}
    </section>
  );
}

function FileTab({ sources, onLoaded }: { sources: SourceRow[]; onLoaded: (l: Loaded) => void }) {
  const [src, setSrc] = useState('');
  const [entity, setEntity] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (!file || !src) return;
    const f = new FormData();
    f.append('file', file); f.append('source_system_id', src);
    if (entity.trim()) f.append('entity', entity.trim());
    setBusy(true); setErr(null);
    postForm<Loaded>('/api/admin/upload', f).then(onLoaded).catch((x: Error) => setErr(x.message)).finally(() => setBusy(false));
  };
  return (
    <form className="panel" onSubmit={submit}>
      <header><h2>{t('파일 올리기')}</h2><span className="small muted">{t('CSV·TSV·엑셀(.xlsx), 4MB·2만 행까지')}</span></header>
      <Steps at={file && src ? 1 : 0} />
      <div className="formrow">
        <SourcePick sources={sources} value={src} onChange={setSrc} />
        <label className="fld"><span>{t('엔터티 이름 (선택)')}</span><input className="input" placeholder={t('비우면 파일 이름')} value={entity} onChange={(e) => setEntity(e.target.value)} /></label>
      </div>
      <label className={`drop${file ? ' has' : ''}`}>
        <FileUp aria-hidden="true" />
        <span>{file ? `${file.name} · ${n0(Math.ceil(file.size / 1024))} KB` : t('여기를 눌러 파일을 고르세요')}</span>
        <input type="file" accept=".csv,.tsv,.txt,.xlsx,.xlsm" onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
      </label>
      <p className="note">{t('첫 줄은 열 이름이어야 해요. 원본은 원천 존에 그대로 남고, 다음 단계에서 표준 표로 옮겨요.')}</p>
      {err && <div className="banner" role="alert">{err}</div>}
      <div className="acts" style={{ marginTop: 12 }}><button className="btn primary" type="submit" disabled={busy || !file || !src}>{busy ? t('올리는 중…') : t('원천 존에 올리기')}</button></div>
    </form>
  );
}

function DbTab({ sources, onLoaded, goSources }: { sources: SourceRow[]; onLoaded: (l: Loaded) => void; goSources: () => void }) {
  const [src, setSrc] = useState('');
  const [pw, setPw] = useState('');
  const [tables, setTables] = useState<{ schema: string; name: string; kind: string }[] | null>(null);
  const [table, setTable] = useState('');
  const [limit, setLimit] = useState(1000);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const dbs = sources.filter((s) => s.db_kind && s.db_kind !== 'FILE');
  const test = () => {
    setBusy(true); setErr(null); setTables(null);
    post<{ ok: boolean; error: string | null; tables: { schema: string; name: string; kind: string }[] }>(`/api/admin/sources/${encodeURIComponent(src)}/test`, { password: pw })
      .then((r) => { if (r.ok) setTables(r.tables); else setErr(t('연결하지 못했어요: {msg}', { msg: r.error ?? '' })); })
      .catch((e: Error) => setErr(e.message)).finally(() => setBusy(false));
  };
  const load = () => {
    setBusy(true); setErr(null);
    post<Loaded>(`/api/admin/sources/${encodeURIComponent(src)}/import`, { password: pw, table, limit })
      .then(onLoaded).catch((e: Error) => setErr(e.message)).finally(() => setBusy(false));
  };
  return (
    <section className="panel">
      <header><h2>{t('DB에서 가져오기')}</h2><span className="small muted">{t('PostgreSQL 직접 연결 · 읽기 전용')}</span></header>
      <Steps at={tables ? 1 : 0} />
      {dbs.length === 0 ? <p className="muted small">{t('등록된 DB 원천이 없어요.')} <button className="linkbtn" type="button" onClick={goSources}>{t('원천 관리에서 등록하기')}</button></p> : <>
        <div className="formrow">
          <SourcePick sources={dbs} value={src} onChange={(v) => { setSrc(v); setTables(null); setTable(''); }} />
          <label className="fld"><span>{t('비밀번호')}</span><input className="input" type="password" autoComplete="off" value={pw} onChange={(e) => setPw(e.target.value)} /></label>
          <div className="fld"><span>&nbsp;</span><button className="btn" type="button" disabled={busy || !src} onClick={test}><Plug aria-hidden="true" /> {t('연결 시험')}</button></div>
        </div>
        <p className="note">{t('비밀번호는 이번 요청에만 쓰고 저장하지 않아요. 운영에서는 비밀 저장소 이름(secret_ref)으로 연결해요.')}</p>
        {tables && <div className="formrow" style={{ marginTop: 12 }}>
          <label className="fld grow"><span>{t('가져올 표 ({n}개)', { n: tables.length })}</span>
            <select className="input" value={table} onChange={(e) => setTable(e.target.value)}>
              <option value="">{t('표를 고르세요')}</option>
              {tables.map((x) => <option key={`${x.schema}.${x.name}`} value={`${x.schema}.${x.name}`}>{x.schema}.{x.name}{x.kind === 'view' ? ` (${t('뷰')})` : ''}</option>)}
            </select>
          </label>
          <label className="fld"><span>{t('최대 행 수')}</span><input className="input num" type="number" min={1} max={5000} value={limit} onChange={(e) => setLimit(Math.max(1, Math.min(5000, Number(e.target.value) || 1)))} /></label>
          <div className="fld"><span>&nbsp;</span><button className="btn primary" type="button" disabled={busy || !table} onClick={load}><Database aria-hidden="true" /> {t('원천 존에 가져오기')}</button></div>
        </div>}
      </>}
      {err && <div className="banner" role="alert">{err}</div>}
    </section>
  );
}

function SourcesTab({ sources, reload }: { sources: SourceRow[]; reload: () => void }) {
  const { toast } = useAuth();
  const [f, setF] = useState({ source_system_id: '', label: '', system_type: 'MES', db_kind: 'POSTGRESQL', host: '', port: '5432', database: '', username: '', owner_dept: '' });
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const isDb = f.db_kind !== 'FILE';
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const submit = (e: FormEvent) => {
    e.preventDefault();
    setBusy(true); setErr(null);
    post<{ source_system_id: string }>('/api/admin/sources', {
      source_system_id: f.source_system_id.trim(), label: f.label.trim(), system_type: f.system_type, db_kind: f.db_kind,
      owner_dept: f.owner_dept.trim() || null,
      ...(isDb ? { host: f.host.trim(), port: Number(f.port) || null, database: f.database.trim(), username: f.username.trim() || null } : {}),
    }).then((r) => { toast(t('원천 {id} 를 등록했어요.', { id: r.source_system_id })); reload(); })
      .catch((x: Error) => setErr(x.message)).finally(() => setBusy(false));
  };
  return (
    <div className="grid g2" style={{ alignItems: 'start' }}>
      <section className="panel"><header><h2>{t('등록된 원천')}</h2><span className="small muted">catalog.source_system</span></header>
        <div className="tablewrap"><table><thead><tr><th>{t('원천')}</th><th>{t('연결')}</th><th className="r">{t('데이터셋')}</th></tr></thead><tbody>
          {sources.map((s) => {
            const [st, stc] = connSt(s.db_kind && s.db_kind !== 'FILE' ? s.status : null);
            return <tr key={s.source_system_id}>
              <td>{s.label_ko}<div className="mono muted small">{s.source_system_id} · {s.system_type}</div></td>
              <td><Pill cls={stc}>{st}</Pill>{s.host && <div className="mono small muted" style={{ overflowWrap: 'anywhere' }}>{s.db_kind?.toLowerCase()}://{s.host}{s.port ? `:${s.port}` : ''}/{s.database_name}</div>}
                {s.last_error && <div className="small" style={{ color: 'var(--crit)' }}>{s.last_error}</div>}</td>
              <td className="r num">{s.datasets}{s.last_ingested_at && <div className="small muted">{fmtTs(s.last_ingested_at)}</div>}</td></tr>;
          })}
          {sources.length === 0 && <tr><td colSpan={3} className="muted">{t('등록된 원천이 없어요.')}</td></tr>}
        </tbody></table></div>
      </section>
      <form className="panel" onSubmit={submit}><header><h2>{t('새 원천 등록')}</h2></header>
        <div className="formgrid">
          <label className="fld"><span>{t('원천 ID')}</span><input className="input mono" required pattern="[A-Za-z0-9][A-Za-z0-9_\-]{1,49}" placeholder="MES-B" value={f.source_system_id} onChange={set('source_system_id')} /></label>
          <label className="fld"><span>{t('이름')}</span><input className="input" required placeholder={t('예: 2공장 MES')} value={f.label} onChange={set('label')} /></label>
          <label className="fld"><span>{t('시스템 종류')}</span><select className="input" value={f.system_type} onChange={set('system_type')}>{SYSTEM_TYPES.map((x) => <option key={x}>{x}</option>)}</select></label>
          <label className="fld"><span>{t('연결 방식')}</span><select className="input" value={f.db_kind} onChange={set('db_kind')}>{DB_KINDS.map((x) => <option key={x} value={x}>{x === 'FILE' ? t('파일만 올림') : x}</option>)}</select></label>
          {isDb && <>
            <label className="fld"><span>{t('호스트')}</span><input className="input mono" required value={f.host} onChange={set('host')} placeholder="db.example.co.kr" /></label>
            <label className="fld"><span>{t('포트')}</span><input className="input num" value={f.port} onChange={set('port')} /></label>
            <label className="fld"><span>{t('데이터베이스')}</span><input className="input mono" required value={f.database} onChange={set('database')} /></label>
            <label className="fld"><span>{t('사용자')}</span><input className="input mono" value={f.username} onChange={set('username')} autoComplete="off" /></label>
          </>}
          <label className="fld"><span>{t('담당 부서 (선택)')}</span><input className="input" value={f.owner_dept} onChange={set('owner_dept')} /></label>
        </div>
        {isDb && f.db_kind !== 'POSTGRESQL' && <p className="note">{t('{kind} 은 등록만 돼요. 지금 직접 가져오기는 PostgreSQL 만 되고, 다른 DB 는 CSV·엑셀로 내보내 올려 주세요.', { kind: f.db_kind })}</p>}
        {err && <div className="banner" role="alert">{err}</div>}
        <div className="acts" style={{ marginTop: 12 }}><button className="btn primary" type="submit" disabled={busy || DEMO}>{t('등록')}</button></div>
      </form>
    </div>
  );
}

function HistoryTab({ rows, open }: { rows: BatchRow[]; open: (id: string) => void }) {
  return (
    <section className="panel"><header><h2>{t('적재 기록')}</h2><span className="small muted">raw.ingest_batch</span></header>
      <div className="tablewrap"><table><thead><tr><th>{t('시각')}</th><th>{t('원천 · 데이터셋')}</th><th className="r">{t('행')}</th><th>{t('상태')}</th><th>{t('표준 존')}</th><th /></tr></thead><tbody>
        {rows.map((b) => {
          const [st, stc] = batchSt(b.status);
          return <tr key={b.batch_id}>
            <td className="num small">{fmtTs(b.received_at)}</td>
            <td>{b.file_name ?? b.source_entity}<div className="mono muted small">{b.source_system_id} · {b.dataset_id}</div></td>
            <td className="r num">{n0(b.record_count)}</td>
            <td><Pill cls={stc}>{st}</Pill></td>
            <td className="small">{b.std_table ? <><span className="mono">{b.std_table}</span><div className="muted">{t('넣음 {a} · 거부 {b}', { a: n0(b.std_rows_out), b: n0(b.std_rows_rejected) })}</div></> : '—'}</td>
            <td className="r"><button className="btn" type="button" onClick={() => open(b.batch_id)}>{b.status === 'LANDED' ? t('표준 존에 넣기') : t('다시 넣기')}</button></td></tr>;
        })}
        {rows.length === 0 && <tr><td colSpan={6} className="muted">{t('아직 올린 데이터가 없어요.')}</td></tr>}
      </tbody></table></div>
    </section>
  );
}

export default function Ingest() {
  const [tab, setTab] = useState<Tab>('file');
  const [batch, setBatch] = useState<string | null>(null);
  const [fresh, setFresh] = useState(false);
  const sources = useApi<SourceRow[]>('/api/admin/sources');
  const batches = useApi<BatchRow[]>(DEMO ? null : '/api/admin/batches');
  useEffect(() => { document.title = `${t('데이터 넣기')} · ${t('뉴레이크')}`; }, []);
  const loaded = (l: Loaded) => { setBatch(l.batch_id); setFresh(true); batches.reload(); };
  const open = (id: string) => { setBatch(id); setFresh(false); };
  return (
    <>
      <Head title={t('데이터 넣기')} lede={t('원천을 등록하고 파일이나 DB 표를 원천 존에 올린 뒤, 열을 맞춰 표준(KS X 9101) 표로 옮겨요.')}
        right={<button className="btn" type="button" onClick={() => { sources.reload(); batches.reload(); }}><RefreshCw aria-hidden="true" /> {t('새로 고침')}</button>} />
      {DEMO && <div className="note" role="note">{t('미리보기에서는 데이터를 넣을 수 없어요. 실제 서버(newlake.vercel.app)에서 해 보세요.')}</div>}
      <div className="tabs" role="tablist">
        {TABS.map(([k, l]) => <button key={k} role="tab" type="button" aria-selected={tab === k} onClick={() => { setTab(k); if (k !== 'history') setBatch(null); }}>{t(l)}</button>)}
      </div>
      <State loading={sources.loading && !sources.data} error={sources.error} />
      {sources.data && <>
        {tab === 'file' && <FileTab sources={sources.data} onLoaded={loaded} />}
        {tab === 'db' && <DbTab sources={sources.data} onLoaded={loaded} goSources={() => setTab('sources')} />}
        {tab === 'sources' && <SourcesTab sources={sources.data} reload={sources.reload} />}
        {tab === 'history' && <HistoryTab rows={batches.data ?? []} open={open} />}
      </>}
      {batch && <>
        {fresh && <p className="small" style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 6 }}><CheckCircle2 aria-hidden="true" style={{ width: 16, color: 'var(--ok)' }} />{t('원천 존에 올렸어요. 이제 표준 표의 열과 맞춰 주세요.')}</p>}
        <MapPanel key={batch} batchId={batch} onDone={() => { batches.reload(); sources.reload(); }} />
      </>}
    </>
  );
}
