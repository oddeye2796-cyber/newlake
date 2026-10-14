import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { TriangleAlert } from 'lucide-react';
import { post, type InboxRow } from '../api';
import { useAuth } from '../auth';
import { Pill, State, Tier, TierLegend } from '../components/ui';
import { execPill, fmtTs, iriId, iriKind, riskPill } from '../format';
import { useApi } from '../useApi';

type Tab = 'approve' | 'mine' | 'all';

const STEPS = ['탐지', '분석', '조치 제안', '승인 대기', '처리'];
// 실행 요청 상태 → 몇 번째 단계까지 왔는지 (IMPIX 사고 카드의 단계 표시)
function stepOf(status: string): number { return status === 'PROPOSED' ? 3 : 4; }
function Stepper({ status }: { status: string }) {
  const cur = stepOf(status);
  const label = (i: number) => (i === 4 && status === 'REJECTED' ? '반려' : i === 4 && status !== 'PROPOSED' ? '승인' : STEPS[i]);
  return (
    <ol className="stepper" aria-label="진행 단계">
      {STEPS.map((_, i) => (
        <li key={i} className={`st ${i < cur || (i === cur && status !== 'PROPOSED') ? (i === 4 && status === 'REJECTED' ? 'rej' : 'done') : i === cur ? 'cur' : ''}`}
          aria-current={i === cur ? 'step' : undefined}><i />{label(i)}</li>
      ))}
    </ol>
  );
}

function Card({ r, onDone }: { r: InboxRow; onDone: (msg: string) => void }) {
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const target = iriId(r.target_iri), kind = iriKind(r.target_iri);
  const [st, stc] = execPill(r.status);
  const [rl, rlc] = riskPill(r.risk_level);
  const facts = r.rationale?.facts || [];
  const decide = (approve: boolean) => {
    setBusy(true); setErr(null);
    post<{ status: string }>(`/api/inbox/${r.execution_id}/decision`, { approve, note: note.trim() || undefined })
      .then(() => onDone(approve ? `승인했어요. ${target} 보류가 처리돼요.` : `반려했어요. ${target} 보류 요청이 닫혔어요.`))
      .catch((e: Error) => setErr(e.message))
      .finally(() => setBusy(false));
  };
  const d = r.risk_detail;
  return (
    <div className="alert" style={{ ['--sc' as string]: r.status === 'PROPOSED' ? 'var(--warn)' : r.status === 'REJECTED' ? 'var(--line)' : 'var(--ok)' }}>
      <span className="sev" />
      <div>
        <b>{r.action_label} · {kind ? <Link to={`/find/${kind}/${target}`}>{target}</Link> : target}</b>
        <p>요청 {r.requested_by ?? '—'} · {fmtTs(r.created_at)}{d?.cause ? ` · 이유: ${d.cause}` : ''}{d?.sales_order_id ? ` · 주문 ${d.sales_order_id}` : ''}</p>
        <Stepper status={r.status} />
        {r.status === 'PROPOSED' && r.can_decide && <div className="yourtask"><TriangleAlert aria-hidden="true" />내 할 일: 근거를 확인하고 승인하거나 반려해 주세요</div>}
        <div className="meta"><Pill cls={stc}>{st}</Pill>{r.risk_level && <Pill cls={rlc}>위험도 {rl}</Pill>}
          {r.approved_by && <Pill>결정 {r.approved_by}</Pill>}
          {r.approver_role_id && r.status === 'PROPOSED' && <Pill>승인 권한: {r.approver_role_id}</Pill>}</div>
        {facts.length === 0 && <p className="small muted">기록된 근거 사실이 없어요.</p>}
        {facts.length > 0 && <details className="evd" open={r.status === 'PROPOSED'} style={{ marginTop: 8 }}><summary>근거 {facts.length}건 보기</summary>
          <ul className="evlist">{facts.map((f, i) => <li key={i}><Tier t={f.tier} /> {f.text}</li>)}</ul>
        </details>}
        {r.rationale?.decision_note && <p className="small">결정 메모: {r.rationale.decision_note}{r.rationale.decided_at ? ` (${fmtTs(r.rationale.decided_at)})` : ''}</p>}
        <details className="tech"><summary>기술 정보</summary><p className="small mono">{r.action_iri.replace('https://ontology.impix.co.kr/', '')} · 정책 {r.policy_id ?? '—'} · 실행 {r.execution_id}</p></details>
        {err && <div className="banner" role="alert">{err}</div>}
      </div>
      <div className="acts">
        {r.status === 'PROPOSED' && (
          <div className="decide">
            <input className="input" placeholder="메모 (선택)" value={note} onChange={(e) => setNote(e.target.value)} aria-label="결정 메모" />
            <div className="acts"><button className="btn primary" type="button" disabled={busy} onClick={() => decide(true)}>승인</button>
              <button className="btn" type="button" disabled={busy} onClick={() => decide(false)}>반려</button></div>
            {!r.can_decide && <span className="hint">내 권한으로는 승인할 수 없어요</span>}
          </div>
        )}
      </div>
    </div>
  );
}

export default function Inbox() {
  const { userId, refreshBadge, toast } = useAuth();
  const { data, error, loading, reload } = useApi<InboxRow[]>('/api/inbox?status=ALL');
  const [tab, setTab] = useState<Tab | null>(null);
  const rows = data || [];
  const approvable = useMemo(() => rows.filter((r) => r.status === 'PROPOSED' && r.can_decide), [rows]);
  const mine = useMemo(() => rows.filter((r) => r.requested_by === userId), [rows, userId]);
  const cur: Tab = tab ?? (approvable.length ? 'approve' : 'all');
  const list = cur === 'approve' ? approvable : cur === 'mine' ? mine : rows;
  const done = (m: string) => { toast(m); reload(); refreshBadge(); };

  return (
    <>
      <div className="head"><div><h1>요청함</h1><p className="lede">내 승인이 필요한 일과 내가 보낸 요청을 모아 봅니다. 모든 처리 내역은 감사 기록에 남아요.</p></div></div>
      <div className="tabs" role="tablist">
        <button type="button" role="tab" aria-selected={cur === 'approve'} onClick={() => setTab('approve')}>승인할 일{approvable.length > 0 && <> <span className="badge-n">{approvable.length}</span></>}</button>
        <button type="button" role="tab" aria-selected={cur === 'mine'} onClick={() => setTab('mine')}>내 요청</button>
        <button type="button" role="tab" aria-selected={cur === 'all'} onClick={() => setTab('all')}>전체</button>
      </div>
      <div className="chat">
        <div className="alerts">
          <State loading={loading} error={error} />
          {data && list.length === 0 && <div className="panel muted">{cur === 'approve' ? '내가 승인할 요청이 없어요.' : cur === 'mine' ? '내가 보낸 요청이 없어요.' : '요청이 없어요.'}</div>}
          {list.map((r) => <Card key={r.execution_id} r={r} onDone={done} />)}
        </div>
        <TierLegend />
      </div>
    </>
  );
}
