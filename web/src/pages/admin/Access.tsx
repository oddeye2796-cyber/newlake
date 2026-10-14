import { useEffect, useMemo, useState } from 'react';
import { post, type AccessRequest, type AdminAccess, type AuditRow } from '../../api';
import { useAuth } from '../../auth';
import { Pill, State } from '../../components/ui';
import { fmtTs } from '../../format';
import { useApi } from '../../useApi';
import { t } from '../../i18n';
import { Head, sensName } from './common';
import { AccessPoliciesTab, ActionPoliciesTab, RolesTab, UsersTab } from './AccessManage';

type Tab = 'requests' | 'users' | 'roles' | 'policies' | 'actions' | 'audit';

const actName = (a: string): string | undefined => ({ query: t('질의'), read: t('조회'), approve: t('승인'), reject: t('반려'), download: t('내려받기'), export: t('내보내기') } as Record<string, string>)[a];
const resName = (r: string): [string, string] | undefined => ({ OK: [t('성공'), 'p-line'], DENIED: [t('거부'), 'p-crit'], ERROR: [t('오류'), 'p-warn'] } as Record<string, [string, string]>)[r];
const reqSt = (s: string): [string, string, string] | undefined => ({ REQUESTED: [t('승인 대기'), 'p-warn', 'var(--warn)'], APPROVED: [t('승인됨'), 'p-ok', 'var(--ok)'], REJECTED: [t('반려됨'), 'p-line', 'var(--line)'] } as Record<string, [string, string, string]>)[s];

function Req({ r, onDone }: { r: AccessRequest; onDone: (m: string) => void }) {
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [st, stc, sc] = reqSt(r.status) || [r.status, 'p-line', 'var(--line)'];
  const decide = (approve: boolean) => {
    setBusy(true); setErr(null);
    post<{ status: string }>(`/api/admin/access/${r.request_id}/decision`, { approve, note: note.trim() || undefined })
      .then(() => onDone(approve ? t('승인했어요. {id} 님에게 알림이 가요.', { id: r.requester_id }) : t('반려했어요.')))
      .catch((e: Error) => setErr(e.message)).finally(() => setBusy(false));
  };
  return (
    <article className="alert task" style={{ ['--sc' as string]: sc }}>
      <span className="sev" />
      <div>
        <b>{r.requester_id} · {r.dataset_title ?? r.dataset_id}</b>
        <p>{r.purpose}</p>
        <div className="meta"><Pill cls={stc}>{st}</Pill><Pill>{r.dataset_id}</Pill><Pill>{sensName(r.sensitivity) ?? r.sensitivity}</Pill>
          {r.requested_actions.map((a) => <Pill key={a}>{a}</Pill>)}<Pill>{t('기간 {from} ~ {to}', { from: r.period_from ?? '—', to: r.period_to ?? '—' })}</Pill><Pill>{t('요청 {ts}', { ts: fmtTs(r.created_at) })}</Pill></div>
        {r.approver_id && <p className="small">{t('결정 {id}', { id: r.approver_id })} · {fmtTs(r.decided_at)}{r.decision_note ? ` · ${r.decision_note}` : ''}</p>}
        {err && <div className="banner" role="alert">{err}</div>}
      </div>
      <div className="acts">{r.status === 'REQUESTED' && (
        <div className="decide">
          <input className="input" placeholder={t('메모 (선택)')} value={note} onChange={(e) => setNote(e.target.value)} aria-label={t('결정 메모')} />
          <div className="acts"><button className="btn primary" type="button" disabled={busy} onClick={() => decide(true)}>{t('승인')}</button><button className="btn" type="button" disabled={busy} onClick={() => decide(false)}>{t('반려')}</button></div>
        </div>)}</div>
    </article>
  );
}

export default function Access() {
  const { toast, me } = useAuth();
  const isAdmin = !!me && me.roles.includes('admin');
  const acc = useApi<AdminAccess>('/api/admin/access');
  const [tab, setTab] = useState<Tab>('requests');
  const [action, setAction] = useState('');
  const [seen, setSeen] = useState<string[]>([]);
  const audit = useApi<AuditRow[]>(tab === 'audit' ? `/api/admin/audit?limit=100${action ? `&action=${encodeURIComponent(action)}` : ''}` : null);
  useEffect(() => { document.title = `${t('권한·감사')} · ${t('뉴레이크')}`; }, []);
  useEffect(() => { if (audit.data) setSeen((s) => [...new Set([...s, ...audit.data!.map((a) => a.action)])].sort()); }, [audit.data]);
  const d = acc.data;
  const pending = d?.requests.filter((r) => r.status === 'REQUESTED').length ?? 0;
  const counts = useMemo(() => { const m = new Map<string, number>(); (d?.assignments ?? []).forEach((a) => { if (a.status === 'ACTIVE') m.set(a.role_id, (m.get(a.role_id) ?? 0) + 1); }); return m; }, [d]);
  const done = (m: string) => { toast(m); acc.reload(); audit.reload(); };
  const TABS: [Tab, string, boolean][] = [['requests', t('접근 요청'), true], ['users', t('사용자'), isAdmin], ['roles', t('역할과 범위'), true],
    ['policies', t('접근 정책'), true], ['actions', t('조치 정책'), true], ['audit', t('감사 기록'), true]];
  return (
    <>
      <Head title={t('권한·감사')} lede={t('권한은 회사·사업장·공장 범위와 역할로 정해요. 모든 조회와 조치는 감사 기록으로 남아요.')} />
      <div className="tabs" role="tablist">
        {TABS.filter((x) => x[2]).map(([k, l]) => <button key={k} role="tab" type="button" aria-selected={tab === k} onClick={() => setTab(k)}>{l}{k === 'requests' && pending > 0 && <> <span className="badge-n">{pending}</span></>}</button>)}
      </div>
      <State loading={acc.loading && !d} error={acc.error} />
      {d && tab === 'requests' && <section className="panel"><header><h2>{t('접근 요청')}</h2><span className="small muted">{t('승인 대기 {n}건', { n: pending })}</span></header>
        <p className="small muted">{t('요청은 요청함에서 보내요. 데이터셋 소유자·스튜어드나 관리자가 여기서 승인·반려해요.')}</p>
        <div className="alerts">{d.requests.map((r) => <Req key={r.request_id} r={r} onDone={done} />)}{d.requests.length === 0 && <p className="muted small">{t('접근 요청이 없어요.')}</p>}</div>
      </section>}
      {d && tab === 'users' && isAdmin && <UsersTab canWrite={isAdmin} />}
      {d && tab === 'roles' && <>
        <section className="panel"><header><h2>{t('역할')}</h2><span className="small muted">gov.role · {t('역할 종류는 고정이에요')}</span></header>
          <div className="tablewrap"><table><thead><tr><th>{t('역할')}</th><th>{t('할 수 있는 일')}</th>{d.assignments && <th className="r">{t('배정')}</th>}</tr></thead><tbody>
            {d.roles.map((r) => <tr key={r.role_id}><td>{r.label_ko}<div className="mono muted small">{r.role_id}</div></td><td className="small">{r.description ?? '—'}</td>{d.assignments && <td className="r num">{counts.get(r.role_id) ?? 0}</td>}</tr>)}
          </tbody></table></div>
        </section>
        <div style={{ marginTop: 14 }}>
          {d.assignments ? <RolesTab roles={d.roles} assignments={d.assignments} reload={() => acc.reload()} />
            : <p className="note">{t('역할 배정 목록은 플랫폼 관리자(admin)에게만 보여요.')}</p>}
        </div>
      </>}
      {d && tab === 'policies' && <AccessPoliciesTab roles={d.roles} canWrite={isAdmin} />}
      {d && tab === 'actions' && <ActionPoliciesTab roles={d.roles} canWrite={isAdmin} />}
      {tab === 'audit' && <section className="panel">
        <header><h2>{t('감사 기록')}</h2><span className="small muted">gov.audit_log · {t('최근 100건')} · {t('고치거나 지울 수 없어요')}</span></header>
        <div className="toolbar" role="group" aria-label={t('행위 필터')}>
          {['', ...seen].map((a) => <button key={a || 'all'} className="chip" type="button" aria-pressed={action === a} onClick={() => setAction(a)}>{a ? actName(a) ?? a : t('전체')}</button>)}
        </div>
        <State loading={audit.loading && !audit.data} error={audit.error} />
        {audit.data && <div className="tablewrap" style={{ maxHeight: 560, overflow: 'auto' }}><table><thead><tr><th>{t('시각')}</th><th>{t('주체')}</th><th>{t('행위')}</th><th>{t('대상')}</th><th>{t('결과')}</th></tr></thead><tbody>
          {audit.data.map((a, i) => {
            const [rs, rc] = resName(a.result) || [a.result, 'p-line'];
            return <tr key={i}><td className="num small">{fmtTs(a.occurred_at)}</td><td>{a.user_id}<div className="small muted">{a.channel}</div></td><td>{actName(a.action) ?? a.action}</td>
              <td className="mono small" style={{ overflowWrap: 'anywhere' }}>{a.dataset_id ?? a.object_ref ?? a.query_text ?? '—'}{a.row_count != null && <span className="muted"> · {t('{n}행', { n: a.row_count })}</span>}</td><td><Pill cls={rc}>{rs}</Pill></td></tr>;
          })}
          {audit.data.length === 0 && <tr><td colSpan={5} className="muted">{t('기록이 없어요.')}</td></tr>}
        </tbody></table></div>}
      </section>}
    </>
  );
}
