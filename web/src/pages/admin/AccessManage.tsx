/* 권한·감사 화면의 관리 탭: 사용자, 역할 배정·범위, 접근 정책, 조치 정책.
   목록(표 + 행마다 수정·삭제)과 오른쪽 폼(등록·수정 겸용)으로, 데이터 넣기의 원천 관리와 같은 틀. 쓰기는 admin 만. */
import { Pencil, Trash2 } from 'lucide-react';
import { useMemo, useState, type FormEvent } from 'react';
import { del, post, put, type AccessPolicy, type ActionPolicy, type AdminClassRow, type AdminRole, type AdminUser, type CatalogDataset, type OntoAction, type RoleAssignment, type Scopes } from '../../api';
import { useAuth } from '../../auth';
import { Pill } from '../../components/ui';
import { fmtTs } from '../../format';
import { useApi } from '../../useApi';
import { t, tl } from '../../i18n';
import { lastName, sensName } from './common';

const DEMO = import.meta.env.VITE_DEMO === '1';
const ACTIONS = ['read', 'query', 'download', 'export'];
const actLabel = (a: string): string => ({ read: t('조회'), query: t('질의'), download: t('내려받기'), export: t('내보내기') } as Record<string, string>)[a] ?? a;
const userSt = (s: string): [string, string] => (({ ACTIVE: [t('사용 중'), 'p-ok'], LOCKED: [t('잠김'), 'p-warn'], RETIRED: [t('퇴직'), 'p-line'] } as Record<string, [string, string]>)[s] ?? [s, 'p-line']);
const modeName = (m: string): string => ({ auto: t('자동 실행'), approval: t('승인 후 실행'), notify: t('알림만') } as Record<string, string>)[m] ?? m;

function RowBtns({ id, onEdit, onDel }: { id: string; onEdit: () => void; onDel?: () => void }) {
  return <td className="r" style={{ whiteSpace: 'nowrap' }}>
    <button className="btn icon" type="button" title={t('수정')} aria-label={t('{id} 수정', { id })} disabled={DEMO} onClick={onEdit}><Pencil aria-hidden="true" /></button>
    {onDel && <button className="btn icon" type="button" title={t('삭제')} aria-label={t('{id} 삭제', { id })} disabled={DEMO} onClick={onDel}><Trash2 aria-hidden="true" /></button>}
  </td>;
}

/* ── 사용자 ─────────────────────────────────────────────────────────────── */
export function UsersTab({ canWrite }: { canWrite: boolean }) {
  const { toast } = useAuth();
  const users = useApi<AdminUser[]>('/api/admin/users');
  const blank = { user_id: '', display_name: '', email: '', personnel_id: '', status: 'ACTIVE' };
  const [f, setF] = useState(blank);
  const [editing, setEditing] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const edit = (u: AdminUser) => { setEditing(u.user_id); setErr(null); setF({ user_id: u.user_id, display_name: u.display_name, email: u.email ?? '', personnel_id: u.personnel_id ?? '', status: u.status }); };
  const cancel = () => { setEditing(null); setF(blank); setErr(null); };
  const submit = (e: FormEvent) => {
    e.preventDefault(); setBusy(true); setErr(null);
    const id = (editing ?? f.user_id).trim();
    put<{ user_id: string }>(`/api/admin/users/${encodeURIComponent(id)}`, { display_name: f.display_name.trim(), email: f.email.trim() || null, personnel_id: f.personnel_id.trim() || null, status: f.status })
      .then(() => { toast(editing ? t('사용자 {id} 를 고쳤어요.', { id }) : t('사용자 {id} 를 등록했어요.', { id })); cancel(); users.reload(); })
      .catch((x: Error) => setErr(x.message)).finally(() => setBusy(false));
  };
  const lock = (u: AdminUser, status: string) => {
    if (!window.confirm(status === 'RETIRED' ? t('{id} 를 퇴직 처리할까요? 더는 들어올 수 없어요.', { id: u.user_id }) : t('{id} 를 잠글까요? 풀 때까지 들어올 수 없어요.', { id: u.user_id }))) return;
    put(`/api/admin/users/${encodeURIComponent(u.user_id)}`, { display_name: u.display_name, email: u.email, personnel_id: u.personnel_id, status })
      .then(() => { toast(t('{id} 상태를 바꿨어요.', { id: u.user_id })); users.reload(); }).catch((x: Error) => setErr(x.message));
  };
  return (
    <div className="grid g2" style={{ alignItems: 'start' }}>
      <section className="panel"><header><h2>{t('사용자')}</h2><span className="small muted">gov.app_user · {t('{n}명', { n: users.data?.length ?? 0 })}</span></header>
        {users.error && <div className="banner" role="alert">{users.error}</div>}
        <div className="tablewrap"><table><thead><tr><th>{t('사용자')}</th><th>{t('역할')}</th><th>{t('상태')}</th>{canWrite && <th />}</tr></thead><tbody>
          {(users.data ?? []).map((u) => { const [st, stc] = userSt(u.status); return <tr key={u.user_id}>
            <td>{tl(u.display_name)}<div className="mono muted small">{u.user_id}{u.email ? ` · ${u.email}` : ''}{u.personnel_id ? ` · ${u.personnel_id}` : ''}</div></td>
            <td className="small">{u.roles.length ? u.roles.join(', ') : <span className="muted">{t('역할 없음')}</span>}</td>
            <td><Pill cls={stc}>{st}</Pill></td>
            {canWrite && <td className="r" style={{ whiteSpace: 'nowrap' }}>
              <button className="btn icon" type="button" title={t('수정')} aria-label={t('{id} 수정', { id: u.user_id })} disabled={DEMO} onClick={() => edit(u)}><Pencil aria-hidden="true" /></button>
              {u.status === 'ACTIVE' ? <button className="btn" type="button" disabled={DEMO} onClick={() => lock(u, 'LOCKED')}>{t('잠금')}</button>
                : <button className="btn" type="button" disabled={DEMO} onClick={() => lock(u, 'ACTIVE')}>{t('풀기')}</button>}
            </td>}
          </tr>; })}
        </tbody></table></div>
      </section>
      {canWrite && <form className="panel" onSubmit={submit}><header><h2>{editing ? t('사용자 수정') : t('새 사용자')}</h2>{editing && <span className="small muted mono">{editing}</span>}</header>
        <div className="formgrid">
          <label className="fld"><span>{t('사용자 ID')}</span><input className="input mono" required readOnly={!!editing} pattern="[a-z0-9][a-z0-9._\-]{1,49}" placeholder="u-hong" value={f.user_id} onChange={set('user_id')} /></label>
          <label className="fld"><span>{t('이름')}</span><input className="input" required value={f.display_name} onChange={set('display_name')} /></label>
          <label className="fld"><span>{t('메일 (선택)')}</span><input className="input mono" type="email" value={f.email} onChange={set('email')} /></label>
          <label className="fld"><span>{t('사번 (선택)')}</span><input className="input mono" value={f.personnel_id} onChange={set('personnel_id')} /></label>
          <label className="fld"><span>{t('상태')}</span><select className="input" value={f.status} onChange={set('status')}>{['ACTIVE', 'LOCKED', 'RETIRED'].map((s) => <option key={s} value={s}>{userSt(s)[0]}</option>)}</select></label>
        </div>
        <p className="note">{t('OIDC 연동 전까지는 여기서 등록한 ID 로 들어와요. 역할은 역할 배정 탭에서 줘요.')}</p>
        {err && <div className="banner" role="alert">{err}</div>}
        <div className="acts" style={{ marginTop: 12 }}><button className="btn primary" type="submit" disabled={busy || DEMO}>{editing ? t('저장') : t('등록')}</button>
          {editing && <button className="btn" type="button" onClick={cancel}>{t('취소')}</button>}</div>
      </form>}
    </div>
  );
}

/* ── 역할 배정·범위 ────────────────────────────────────────────────────── */
export function RolesTab({ roles, assignments, reload }: { roles: AdminRole[]; assignments: RoleAssignment[]; reload: () => void }) {
  const { toast } = useAuth();
  const scopes = useApi<Scopes>('/api/admin/scopes');
  const users = useApi<AdminUser[]>('/api/admin/users');
  const [f, setF] = useState({ user_id: '', role_id: 'viewer', site_id: '', plant_id: '', valid_until: '' });
  const [createScope, setCreateScope] = useState(true);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value, ...(k === 'site_id' ? { plant_id: '' } : {}) }));
  const plants = useMemo(() => (scopes.data?.plants ?? []).filter((p) => p.site_id === f.site_id), [scopes.data, f.site_id]);
  const rows = assignments.filter((a) => a.role_id);
  const submit = (e: FormEvent) => {
    e.preventDefault(); setBusy(true); setErr(null);
    post<{ ok: boolean; site_created?: boolean; plant_created?: boolean }>('/api/admin/roles/grant', { user_id: f.user_id.trim(), role_id: f.role_id, site_id: f.site_id.trim() || null, plant_id: f.plant_id.trim() || null, valid_until: f.valid_until || null, create_scope: createScope })
      .then((r) => { toast(t('{user} 에게 {role} 역할을 줬어요.', { user: f.user_id.trim(), role: f.role_id }) + (r.site_created || r.plant_created ? ' ' + t('(사업장·공장을 새로 등록했어요)') : '')); reload(); scopes.reload(); })
      .catch((x: Error) => setErr(x.message)).finally(() => setBusy(false));
  };
  const edit = (a: RoleAssignment) => { setErr(null); setF({ user_id: a.user_id, role_id: a.role_id, site_id: a.site_id ?? '', plant_id: a.plant_id ?? '', valid_until: a.valid_until ?? '' }); };
  const revoke = (a: RoleAssignment) => {
    if (!window.confirm(t('{user} 의 {role} 역할({scope})을 뺄까요?', { user: a.user_id, role: tl(a.role_label), scope: a.site_id ? `${a.site_id}${a.plant_id ? '/' + a.plant_id : ''}` : t('전사') }))) return;
    setErr(null);
    post('/api/admin/roles/revoke', { user_id: a.user_id, role_id: a.role_id, site_id: a.site_id, plant_id: a.plant_id })
      .then(() => { toast(t('역할을 뺐어요.')); reload(); }).catch((x: Error) => setErr(x.message));
  };
  return (
    <div className="grid g2" style={{ alignItems: 'start' }}>
      <section className="panel"><header><h2>{t('역할 배정')}</h2><span className="small muted">gov.role_assignment · {t('{n}건', { n: rows.length })}</span></header>
        <div className="tablewrap"><table><thead><tr><th>{t('사용자')}</th><th>{t('역할')}</th><th>{t('범위')}</th><th>{t('상태')}</th><th /></tr></thead><tbody>
          {rows.map((a, i) => (
            <tr key={i}><td>{tl(a.display_name)}<div className="mono muted small">{a.user_id}</div></td><td>{tl(a.role_label)}<div className="mono muted small">{a.role_id}</div></td>
              <td className="mono small">{a.site_id ?? t('전사')}{a.plant_id ? ` / ${a.plant_id}` : ''}</td>
              <td><Pill cls={a.status === 'ACTIVE' ? 'p-ok' : 'p-line'}>{a.status === 'ACTIVE' ? t('유효') : a.status}</Pill>{a.valid_until && <div className="small muted">~ {a.valid_until}</div>}</td>
              <RowBtns id={`${a.user_id} ${a.role_id}`} onEdit={() => edit(a)} onDel={() => revoke(a)} /></tr>))}
          {rows.length === 0 && <tr><td colSpan={5} className="muted">{t('배정된 역할이 없어요.')}</td></tr>}
        </tbody></table></div>
      </section>
      <form className="panel" onSubmit={submit}><header><h2>{t('역할 주기')}</h2></header>
        <div className="formgrid">
          <label className="fld"><span>{t('사용자')}</span><input className="input mono" required list="grant-users" placeholder={t('사용자 ID 입력 (목록에서 골라도 돼요)')} value={f.user_id} onChange={set('user_id')} />
            <datalist id="grant-users">{(users.data ?? []).map((u) => <option key={u.user_id} value={u.user_id}>{tl(u.display_name)}</option>)}</datalist></label>
          <label className="fld"><span>{t('역할')}</span><select className="input" value={f.role_id} onChange={set('role_id')}>{roles.map((r) => <option key={r.role_id} value={r.role_id}>{tl(r.label_ko)} · {r.role_id}</option>)}</select></label>
          <label className="fld"><span>{t('사업장 (비우면 전사)')}</span><input className="input mono" list="grant-sites" maxLength={50} placeholder={t('전사')} value={f.site_id} onChange={set('site_id')} />
            <datalist id="grant-sites">{(scopes.data?.sites ?? []).map((s) => <option key={s.site_id} value={s.site_id}>{tl(s.site_name) ?? ''}</option>)}</datalist></label>
          <label className="fld"><span>{t('공장 (비우면 사업장 전체)')}</span><input className="input mono" list="grant-plants" maxLength={50} disabled={!f.site_id.trim()} placeholder={t('사업장 전체')} value={f.plant_id} onChange={set('plant_id')} />
            <datalist id="grant-plants">{plants.map((p) => <option key={p.plant_id} value={p.plant_id}>{tl(p.plant_name) ?? ''}</option>)}</datalist></label>
          <label className="fld"><span>{t('만료일 (선택)')}</span><input className="input" type="date" value={f.valid_until} onChange={set('valid_until')} /></label>
        </div>
        <label className="small" style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 8 }}>
          <input type="checkbox" checked={createScope} onChange={(e) => setCreateScope(e.target.checked)} />
          {t('입력한 사업장·공장이 마스터에 없으면 새로 등록하기')}</label>
        <p className="note">{t('사용자·사업장·공장은 직접 입력해요 (목록은 참고용). 같은 사용자·역할·범위가 이미 있으면 만료일만 바뀌어요. 범위는 행 단위 권한(RLS)에 바로 반영돼요.')}</p>
        {err && <div className="banner" role="alert">{err}</div>}
        <div className="acts" style={{ marginTop: 12 }}><button className="btn primary" type="submit" disabled={busy || DEMO || !f.user_id.trim()}>{t('역할 주기')}</button></div>
      </form>
    </div>
  );
}

/* ── 접근 정책 ─────────────────────────────────────────────────────────── */
export function AccessPoliciesTab({ roles, canWrite }: { roles: AdminRole[]; canWrite: boolean }) {
  const { toast } = useAuth();
  const list = useApi<AccessPolicy[]>('/api/admin/access-policies');
  const classes = useApi<AdminClassRow[]>(canWrite ? '/api/admin/ontology/classes' : null);
  const datasets = useApi<CatalogDataset[]>(canWrite ? '/api/catalog/datasets' : null);
  const blank = { policy_id: '', role_id: 'analyst', target: 'class', target_class_iri: '', target_dataset_id: '', max_sensitivity: 'INTERNAL', actions: ['read'] as string[], requires_approval: false };
  const [f, setF] = useState(blank);
  const [editing, setEditing] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const toggleAct = (a: string) => setF((x) => ({ ...x, actions: x.actions.includes(a) ? x.actions.filter((y) => y !== a) : [...x.actions, a] }));
  const edit = (p: AccessPolicy) => { setEditing(p.policy_id); setErr(null); setF({ policy_id: p.policy_id, role_id: p.role_id, target: p.target_class_iri ? 'class' : 'dataset', target_class_iri: p.target_class_iri ?? '', target_dataset_id: p.target_dataset_id ?? '', max_sensitivity: p.max_sensitivity, actions: p.actions, requires_approval: p.requires_approval }); };
  const cancel = () => { setEditing(null); setF(blank); setErr(null); };
  const submit = (e: FormEvent) => {
    e.preventDefault(); setBusy(true); setErr(null);
    const id = (editing ?? f.policy_id).trim();
    put(`/api/admin/access-policies/${encodeURIComponent(id)}`, { role_id: f.role_id, target_class_iri: f.target === 'class' ? f.target_class_iri || null : null, target_dataset_id: f.target === 'dataset' ? f.target_dataset_id || null : null, max_sensitivity: f.max_sensitivity, actions: f.actions, requires_approval: f.requires_approval })
      .then(() => { toast(t('정책 {id} 를 저장했어요.', { id })); cancel(); list.reload(); }).catch((x: Error) => setErr(x.message)).finally(() => setBusy(false));
  };
  const remove = (p: AccessPolicy) => {
    if (!window.confirm(t('정책 {id} 를 지울까요?', { id: p.policy_id }))) return;
    del(`/api/admin/access-policies/${encodeURIComponent(p.policy_id)}`).then(() => { toast(t('정책 {id} 를 지웠어요.', { id: p.policy_id })); if (editing === p.policy_id) cancel(); list.reload(); }).catch((x: Error) => setErr(x.message));
  };
  return (
    <div className="grid g2" style={{ alignItems: 'start' }}>
      <section className="panel"><header><h2>{t('접근 정책')}</h2><span className="small muted">gov.access_policy</span></header>
        <p className="small muted">{t('역할이 어떤 클래스·데이터셋을 어느 민감도까지, 어떤 행위로 쓸 수 있는지 정해요. 승인 필요를 켜면 접근 요청을 거쳐야 해요.')}</p>
        {list.error && <div className="banner" role="alert">{list.error}</div>}
        <div className="tablewrap"><table><thead><tr><th>{t('정책')}</th><th>{t('역할')}</th><th>{t('대상')}</th><th>{t('허용')}</th>{canWrite && <th />}</tr></thead><tbody>
          {(list.data ?? []).map((p) => <tr key={p.policy_id}>
            <td className="mono small">{p.policy_id}</td><td>{tl(p.role_label)}</td>
            <td className="small">{p.target_class_iri ? <>{tl(p.class_label) ?? lastName(p.target_class_iri)} <span className="mono muted">ksx:{lastName(p.target_class_iri)}</span></> : <>{tl(p.dataset_title) ?? p.target_dataset_id} <span className="mono muted">{p.target_dataset_id}</span></>}</td>
            <td className="small">{p.actions.map(actLabel).join(', ')} · {t('{s}까지', { s: sensName(p.max_sensitivity) ?? p.max_sensitivity })}{p.requires_approval && <> <Pill cls="p-warn">{t('승인 필요')}</Pill></>}</td>
            {canWrite && <RowBtns id={p.policy_id} onEdit={() => edit(p)} onDel={() => remove(p)} />}
          </tr>)}
          {list.data?.length === 0 && <tr><td colSpan={5} className="muted">{t('정책이 없어요. 정책이 없으면 역할의 기본 범위(RLS)만 적용돼요.')}</td></tr>}
        </tbody></table></div>
      </section>
      {canWrite && <form className="panel" onSubmit={submit}><header><h2>{editing ? t('정책 수정') : t('새 접근 정책')}</h2>{editing && <span className="small muted mono">{editing}</span>}</header>
        <div className="formgrid">
          <label className="fld"><span>{t('정책 ID')}</span><input className="input mono" required readOnly={!!editing} pattern="[A-Za-z0-9][A-Za-z0-9._\-]{1,99}" placeholder="analyst-lot-read" value={f.policy_id} onChange={set('policy_id')} /></label>
          <label className="fld"><span>{t('역할')}</span><select className="input" value={f.role_id} onChange={set('role_id')}>{roles.map((r) => <option key={r.role_id} value={r.role_id}>{tl(r.label_ko)} · {r.role_id}</option>)}</select></label>
          <label className="fld"><span>{t('대상 종류')}</span><select className="input" value={f.target} onChange={set('target')}><option value="class">{t('온톨로지 클래스')}</option><option value="dataset">{t('데이터셋')}</option></select></label>
          {f.target === 'class'
            ? <label className="fld"><span>{t('클래스')}</span><select className="input" required value={f.target_class_iri} onChange={set('target_class_iri')}><option value="">{t('클래스를 고르세요')}</option>{(classes.data ?? []).map((c) => <option key={c.class_iri} value={c.class_iri}>{tl(c.label_ko)} · {c.local_name}</option>)}</select></label>
            : <label className="fld"><span>{t('데이터셋')}</span><select className="input" required value={f.target_dataset_id} onChange={set('target_dataset_id')}><option value="">{t('데이터셋을 고르세요')}</option>{(datasets.data ?? []).map((d) => <option key={d.dataset_id} value={d.dataset_id}>{tl(d.title_ko)} · {d.dataset_id}</option>)}</select></label>}
          <label className="fld"><span>{t('민감도 상한')}</span><select className="input" value={f.max_sensitivity} onChange={set('max_sensitivity')}>{['PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'PERSONAL'].map((s) => <option key={s} value={s}>{sensName(s) ?? s}</option>)}</select></label>
          <div className="fld"><span>{t('허용 행위')}</span><div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', paddingTop: 6 }}>
            {ACTIONS.map((a) => <label key={a} className="small" style={{ display: 'flex', gap: 4, alignItems: 'center', color: 'var(--ink)', fontWeight: 400 }}><input type="checkbox" checked={f.actions.includes(a)} onChange={() => toggleAct(a)} />{actLabel(a)}</label>)}</div></div>
        </div>
        <label className="small" style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 10 }}><input type="checkbox" checked={f.requires_approval} onChange={(e) => setF((x) => ({ ...x, requires_approval: e.target.checked }))} />{t('쓰기 전에 접근 요청 승인이 필요해요')}</label>
        {err && <div className="banner" role="alert">{err}</div>}
        <div className="acts" style={{ marginTop: 12 }}><button className="btn primary" type="submit" disabled={busy || DEMO || f.actions.length === 0}>{editing ? t('저장') : t('등록')}</button>
          {editing && <button className="btn" type="button" onClick={cancel}>{t('취소')}</button>}</div>
      </form>}
    </div>
  );
}

/* ── 조치 정책 ─────────────────────────────────────────────────────────── */
export function ActionPoliciesTab({ roles, canWrite }: { roles: AdminRole[]; canWrite: boolean }) {
  const { toast } = useAuth();
  const list = useApi<ActionPolicy[]>('/api/admin/action-policies');
  const classes = useApi<AdminClassRow[]>(canWrite ? '/api/admin/ontology/classes' : null);
  const actions = useApi<OntoAction[]>(canWrite ? '/api/admin/ontology/actions' : null);
  const blank = { policy_id: '', trigger_class_iri: '', condition: '{}', action_iri: '', mode: 'approval', approver_role_id: 'quality_engineer', notify_role_ids: [] as string[], suppress_minutes: '240', enabled: true };
  const [f, setF] = useState(blank);
  const [editing, setEditing] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const toggleRole = (r: string) => setF((x) => ({ ...x, notify_role_ids: x.notify_role_ids.includes(r) ? x.notify_role_ids.filter((y) => y !== r) : [...x.notify_role_ids, r] }));
  const edit = (p: ActionPolicy) => { setEditing(p.policy_id); setErr(null); setF({ policy_id: p.policy_id, trigger_class_iri: p.trigger_class_iri, condition: JSON.stringify(p.condition), action_iri: p.action_iri, mode: p.mode, approver_role_id: p.approver_role_id ?? '', notify_role_ids: p.notify_role_ids, suppress_minutes: String(p.suppress_minutes), enabled: p.enabled }); };
  const cancel = () => { setEditing(null); setF(blank); setErr(null); };
  const save = (id: string, body: Record<string, unknown>, msg: string) => {
    setBusy(true); setErr(null);
    return put(`/api/admin/action-policies/${encodeURIComponent(id)}`, body).then(() => { toast(msg); list.reload(); }).catch((x: Error) => setErr(x.message)).finally(() => setBusy(false));
  };
  const submit = (e: FormEvent) => {
    e.preventDefault();
    let cond: unknown;
    try { cond = JSON.parse(f.condition || '{}'); } catch { setErr(t('조건은 JSON 객체여야 해요. 예: {"risk_level": "HIGH"}')); return; }
    const id = (editing ?? f.policy_id).trim();
    void save(id, { trigger_class_iri: f.trigger_class_iri, condition: cond, action_iri: f.action_iri, mode: f.mode, approver_role_id: f.mode === 'approval' ? f.approver_role_id || null : null, notify_role_ids: f.notify_role_ids, suppress_minutes: Number(f.suppress_minutes) || 0, enabled: f.enabled }, t('정책 {id} 를 저장했어요.', { id })).then(() => cancel());
  };
  const toggle = (p: ActionPolicy) => save(p.policy_id, { trigger_class_iri: p.trigger_class_iri, condition: p.condition, action_iri: p.action_iri, mode: p.mode, approver_role_id: p.approver_role_id, notify_role_ids: p.notify_role_ids, suppress_minutes: p.suppress_minutes, enabled: !p.enabled }, p.enabled ? t('정책 {id} 를 껐어요.', { id: p.policy_id }) : t('정책 {id} 를 켰어요.', { id: p.policy_id }));
  const remove = (p: ActionPolicy) => {
    if (!window.confirm(t('정책 {id} 를 지울까요?', { id: p.policy_id }))) return;
    del(`/api/admin/action-policies/${encodeURIComponent(p.policy_id)}`).then(() => { toast(t('정책 {id} 를 지웠어요.', { id: p.policy_id })); if (editing === p.policy_id) cancel(); list.reload(); }).catch((x: Error) => setErr(x.message));
  };
  return (
    <div className="grid g2" style={{ alignItems: 'start' }}>
      <section className="panel"><header><h2>{t('조치 정책')}</h2><span className="small muted">gov.action_policy</span></header>
        <p className="small muted">{t('온톨로지 규칙이 위험을 잡으면 어떤 조치를 자동으로 할지, 승인을 거칠지, 알림만 보낼지 정해요.')}</p>
        {list.error && <div className="banner" role="alert">{list.error}</div>}
        <div className="tablewrap"><table><thead><tr><th>{t('정책')}</th><th>{t('계기 → 조치')}</th><th>{t('방식')}</th><th>{t('상태')}</th>{canWrite && <th />}</tr></thead><tbody>
          {(list.data ?? []).map((p) => <tr key={p.policy_id}>
            <td className="mono small" style={{ whiteSpace: 'nowrap' }}>{p.policy_id}<div className="muted">{t('실행 {n}건', { n: p.executions })}</div></td>
            <td className="small">{tl(p.trigger_label) ?? lastName(p.trigger_class_iri)} → <b>{tl(p.action_label) ?? lastName(p.action_iri)}</b>{Object.keys(p.condition).length > 0 && <div className="mono muted">{JSON.stringify(p.condition)}</div>}</td>
            <td className="small">{modeName(p.mode)}{p.approver_role_id && <div className="muted">{t('승인자 {r}', { r: p.approver_role_id })}</div>}{p.notify_role_ids.length > 0 && <div className="muted">{t('알림 {r}', { r: p.notify_role_ids.join(', ') })}</div>}</td>
            <td style={{ whiteSpace: 'nowrap' }}><Pill cls={p.enabled ? 'p-ok' : 'p-line'}>{p.enabled ? t('켜짐') : t('꺼짐')}</Pill>{canWrite && <> <button className="btn" type="button" disabled={DEMO || busy} onClick={() => void toggle(p)}>{p.enabled ? t('끄기') : t('켜기')}</button></>}<div className="small muted">{t('{m}분 억제', { m: p.suppress_minutes })}</div></td>
            {canWrite && <td className="r" style={{ whiteSpace: 'nowrap' }}>
              <button className="btn icon" type="button" title={t('수정')} aria-label={t('{id} 수정', { id: p.policy_id })} disabled={DEMO} onClick={() => edit(p)}><Pencil aria-hidden="true" /></button>
              <button className="btn icon" type="button" title={t('삭제')} aria-label={t('{id} 삭제', { id: p.policy_id })} disabled={DEMO || p.executions > 0} onClick={() => remove(p)}><Trash2 aria-hidden="true" /></button>
            </td>}
          </tr>)}
          {list.data?.length === 0 && <tr><td colSpan={5} className="muted">{t('조치 정책이 없어요.')}</td></tr>}
        </tbody></table></div>
      </section>
      {canWrite && <form className="panel" onSubmit={submit}><header><h2>{editing ? t('정책 수정') : t('새 조치 정책')}</h2>{editing && <span className="small muted mono">{editing}</span>}</header>
        <div className="formgrid">
          <label className="fld"><span>{t('정책 ID')}</span><input className="input mono" required readOnly={!!editing} pattern="[A-Za-z0-9][A-Za-z0-9._\-]{1,99}" placeholder="spec-out-hold" value={f.policy_id} onChange={set('policy_id')} /></label>
          <label className="fld"><span>{t('계기 클래스 (이벤트)')}</span><select className="input" required value={f.trigger_class_iri} onChange={set('trigger_class_iri')}><option value="">{t('클래스를 고르세요')}</option>{(classes.data ?? []).filter((c) => c.is_event || !c.is_standard).map((c) => <option key={c.class_iri} value={c.class_iri}>{tl(c.label_ko)} · {c.local_name}</option>)}</select></label>
          <label className="fld"><span>{t('조치')}</span><select className="input" required value={f.action_iri} onChange={set('action_iri')}><option value="">{t('조치를 고르세요')}</option>{(actions.data ?? []).map((a) => <option key={a.action_iri} value={a.action_iri}>{tl(a.label_ko)}</option>)}</select></label>
          <label className="fld"><span>{t('방식')}</span><select className="input" value={f.mode} onChange={set('mode')}>{['approval', 'auto', 'notify'].map((m) => <option key={m} value={m}>{modeName(m)}</option>)}</select></label>
          {f.mode === 'approval' && <label className="fld"><span>{t('승인자 역할')}</span><select className="input" value={f.approver_role_id} onChange={set('approver_role_id')}>{roles.map((r) => <option key={r.role_id} value={r.role_id}>{tl(r.label_ko)}</option>)}</select></label>}
          <label className="fld"><span>{t('같은 대상 억제 시간 (분)')}</span><input className="input num" type="number" min={0} value={f.suppress_minutes} onChange={set('suppress_minutes')} /></label>
          <label className="fld" style={{ gridColumn: '1 / -1' }}><span>{t('조건 (JSON)')}</span><input className="input mono" value={f.condition} onChange={set('condition')} placeholder='{"risk_level": "HIGH"}' /></label>
          <div className="fld" style={{ gridColumn: '1 / -1' }}><span>{t('알림 역할')}</span><div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', paddingTop: 6 }}>
            {roles.map((r) => <label key={r.role_id} className="small" style={{ display: 'flex', gap: 4, alignItems: 'center', color: 'var(--ink)', fontWeight: 400 }}><input type="checkbox" checked={f.notify_role_ids.includes(r.role_id)} onChange={() => toggleRole(r.role_id)} />{tl(r.label_ko)}</label>)}</div></div>
        </div>
        <label className="small" style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 10 }}><input type="checkbox" checked={f.enabled} onChange={(e) => setF((x) => ({ ...x, enabled: e.target.checked }))} />{t('켜 두기')}</label>
        {err && <div className="banner" role="alert">{err}</div>}
        <div className="acts" style={{ marginTop: 12 }}><button className="btn primary" type="submit" disabled={busy || DEMO}>{editing ? t('저장') : t('등록')}</button>
          {editing && <button className="btn" type="button" onClick={cancel}>{t('취소')}</button>}</div>
      </form>}
    </div>
  );
}

/* ── 내 접근 요청 (요청함에서 씀) ─────────────────────────────────────── */
export function MyAccessRequests({ requests, reload }: { requests: import('../../api').MyAccessRequest[]; reload: () => void }) {
  const { toast } = useAuth();
  const datasets = useApi<CatalogDataset[]>('/api/catalog/datasets');
  const today = new Date().toISOString().slice(0, 10);
  const [f, setF] = useState({ dataset_id: '', purpose: '', actions: ['read'] as string[], period_from: today, period_to: '' });
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const toggleAct = (a: string) => setF((x) => ({ ...x, actions: x.actions.includes(a) ? x.actions.filter((y) => y !== a) : [...x.actions, a] }));
  const st = (s: string): [string, string] => (({ REQUESTED: [t('승인 대기'), 'p-warn'], APPROVED: [t('승인됨'), 'p-ok'], REJECTED: [t('반려됨'), 'p-crit'], CANCELLED: [t('취소함'), 'p-line'], EXPIRED: [t('만료'), 'p-line'], REVOKED: [t('회수됨'), 'p-line'] } as Record<string, [string, string]>)[s] ?? [s, 'p-line']);
  const submit = (e: FormEvent) => {
    e.preventDefault(); setBusy(true); setErr(null);
    post('/api/access-requests', { dataset_id: f.dataset_id, purpose: f.purpose.trim(), actions: f.actions, period_from: f.period_from, period_to: f.period_to })
      .then(() => { toast(t('접근 요청을 보냈어요. 데이터셋 담당자가 승인하면 알려 드려요.')); setF((x) => ({ ...x, dataset_id: '', purpose: '' })); reload(); })
      .catch((x: Error) => setErr(x.message)).finally(() => setBusy(false));
  };
  const cancel = (r: { request_id: string; dataset_id: string }) => {
    if (!window.confirm(t('{ds} 접근 요청을 취소할까요?', { ds: r.dataset_id }))) return;
    del(`/api/access-requests/${r.request_id}`).then(() => { toast(t('요청을 취소했어요.')); reload(); }).catch((x: Error) => setErr(x.message));
  };
  return (
    <div className="grid g2" style={{ alignItems: 'start' }}>
      <section className="panel"><header><h2>{t('내 접근 요청')}</h2><span className="small muted">gov.access_request</span></header>
        <div className="tablewrap"><table><thead><tr><th>{t('데이터셋')}</th><th>{t('목적')}</th><th>{t('상태')}</th><th /></tr></thead><tbody>
          {requests.map((r) => { const [s, sc] = st(r.status); return <tr key={r.request_id}>
            <td>{tl(r.dataset_title) ?? r.dataset_id}<div className="mono muted small">{r.dataset_id} · {r.requested_actions.map(actLabel).join(', ')} · {r.period_from} ~ {r.period_to}</div></td>
            <td className="small">{tl(r.purpose)}{r.decision_note && <div className="muted">{t('결정 메모: {note}', { note: tl(r.decision_note) })}</div>}</td>
            <td><Pill cls={sc}>{s}</Pill><div className="small muted">{fmtTs(r.decided_at ?? r.created_at)}</div></td>
            <td className="r">{(r.status === 'REQUESTED' || r.status === 'APPROVED') && <button className="btn" type="button" disabled={DEMO} onClick={() => cancel(r)}>{t('취소')}</button>}</td></tr>; })}
          {requests.length === 0 && <tr><td colSpan={4} className="muted">{t('보낸 접근 요청이 없어요.')}</td></tr>}
        </tbody></table></div>
      </section>
      <form className="panel" onSubmit={submit}><header><h2>{t('접근 요청하기')}</h2></header>
        <div className="formgrid">
          <label className="fld" style={{ gridColumn: '1 / -1' }}><span>{t('데이터셋')}</span><select className="input" required value={f.dataset_id} onChange={set('dataset_id')}>
            <option value="">{t('데이터셋을 고르세요')}</option>{(datasets.data ?? []).map((d) => <option key={d.dataset_id} value={d.dataset_id}>{tl(d.title_ko)} · {d.dataset_id} ({sensName(d.sensitivity) ?? d.sensitivity})</option>)}</select></label>
          <label className="fld" style={{ gridColumn: '1 / -1' }}><span>{t('목적')}</span><input className="input" required minLength={5} placeholder={t('예: 10월 수율 분석 보고서 작성')} value={f.purpose} onChange={set('purpose')} /></label>
          <label className="fld"><span>{t('시작일')}</span><input className="input" type="date" required value={f.period_from} onChange={set('period_from')} /></label>
          <label className="fld"><span>{t('종료일')}</span><input className="input" type="date" required value={f.period_to} onChange={set('period_to')} /></label>
          <div className="fld" style={{ gridColumn: '1 / -1' }}><span>{t('요청 행위')}</span><div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', paddingTop: 6 }}>
            {ACTIONS.map((a) => <label key={a} className="small" style={{ display: 'flex', gap: 4, alignItems: 'center', color: 'var(--ink)', fontWeight: 400 }}><input type="checkbox" checked={f.actions.includes(a)} onChange={() => toggleAct(a)} />{actLabel(a)}</label>)}</div></div>
        </div>
        {err && <div className="banner" role="alert">{err}</div>}
        <div className="acts" style={{ marginTop: 12 }}><button className="btn primary" type="submit" disabled={busy || DEMO || f.actions.length === 0}>{t('요청 보내기')}</button></div>
      </form>
    </div>
  );
}
