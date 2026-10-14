/* 미리보기 모드 (VITE_DEMO=1): 서버 없이 개발 DB 에서 녹화한 실제 API 응답으로 동작한다.
   GitHub Pages 배포용. 녹화는 tools/record_demo_fixtures.py. 승인은 김품질(u-kim)만 통과하는 서버 규칙을 흉내 낸다. */
import { ApiError, type Home, type InboxRow, type SearchHit } from '../api';
import { t } from '../i18n';

type Rec = [number, unknown];
type Fixtures = { get: Record<string, Rec>; query: Record<string, Rec> };
let FX: Fixtures | null = null;
const decided: Record<string, string> = {};
const APPROVERS = new Set(['u-kim']);       // 로트 보류 승인 역할(quality_engineer)
const STEWARDS = new Set(['u-choi']);       // 데이터 이용 신청 승인(admin·data_steward)
const clone = <T,>(x: T): T => JSON.parse(JSON.stringify(x));
function fail(status: number, detail: string): never { throw new ApiError(status, detail); }

export async function demoCall<T>(currentUser: string, path: string, init?: RequestInit): Promise<T> {
  FX ??= (await import('./fixtures.json')).default as unknown as Fixtures;

  await new Promise((r) => setTimeout(r, 120));
  const method = init?.method ?? 'GET';
  const body = init?.body ? JSON.parse(String(init.body)) : null;
  if (method === 'POST' && path === '/api/agent/query') {
    const rec = FX!.query[`${currentUser}|${body.sql}`];
    if (!rec) fail(400, t('미리보기에서는 추천 질문만 실행할 수 있어요. 실제 서버에서는 직접 쓴 SELECT 도 실행돼요.'));
    if (rec[0] !== 200) fail(rec[0], String((rec[1] as { detail?: string }).detail));
    return clone(rec[1]) as T;
  }
  const m = path.match(/^\/api\/inbox\/([^/]+)\/decision$/);
  if (method === 'POST' && m) {
    if (decided[m[1]]) fail(409, `이미 처리된 요청입니다 (상태 ${decided[m[1]]})`); // i18n-ignore: DB(gov.decide_action) 거절 문구를 그대로 흉내 낸다
    if (!APPROVERS.has(currentUser)) fail(409, `${currentUser} 에게 이 요청을 승인할 역할(quality_engineer)이 없습니다`); // i18n-ignore
    decided[m[1]] = body.approve ? 'APPROVED' : 'REJECTED';
    return { execution_id: m[1], status: decided[m[1]] } as T;
  }
  const a = path.match(/^\/api\/admin\/access\/([^/]+)\/decision$/);
  if (method === 'POST' && a) {
    if (decided[a[1]]) fail(409, `이미 처리된 신청입니다 (상태 ${decided[a[1]]})`); // i18n-ignore
    if (!STEWARDS.has(currentUser)) fail(409, `${currentUser} 은 이 데이터셋의 소유자·스튜어드가 아닙니다`); // i18n-ignore
    decided[a[1]] = body.approve ? 'APPROVED' : 'REJECTED';
    return { request_id: a[1], status: decided[a[1]] } as T;
  }
  let rec = FX!.get[`${currentUser}|${path}`];
  if (!rec && path.startsWith('/api/search?q=')) {
    const q = decodeURIComponent(path.slice(14)).toLowerCase();
    const all = new Map<string, SearchHit>();
    for (const p of ['LOT-', 'EQ-', 'SO-', 'ITM-', 'C-']) {
      const r = FX!.get[`${currentUser}|/api/search?q=${encodeURIComponent(p)}`];
      for (const h of ((r?.[1] as { results?: SearchHit[] })?.results ?? [])) all.set(h.kind + h.id, h);
    }
    const results = [...all.values()].filter((h) => h.id.toLowerCase().includes(q) || (h.label ?? '').toLowerCase().includes(q));
    rec = [200, { q, results }];
  }
  if (!rec) fail(404, t('미리보기에 담기지 않은 화면이에요'));
  if (rec[0] !== 200) fail(rec[0], String((rec[1] as { detail?: string }).detail));
  let data = clone(rec[1]);
  if (path.startsWith('/api/inbox')) {
    data = (data as InboxRow[]).map((r) => decided[r.execution_id] ? { ...r, status: decided[r.execution_id], can_decide: false, approved_by: currentUser } : r)
      .filter((r) => path.includes('ALL') || r.status === 'PROPOSED');
  }
  if (path === '/api/admin/access') {
    const d = data as { requests: { request_id: string; status: string; approver_id: string | null }[] };
    d.requests = d.requests.map((r) => decided[r.request_id] ? { ...r, status: decided[r.request_id], approver_id: currentUser } : r);
  }
  if (path === '/api/home') {
    const h = data as Home; h.pending_approvals = Math.max(0, h.pending_approvals - Object.keys(decided).length);
  }
  return data as T;
}
