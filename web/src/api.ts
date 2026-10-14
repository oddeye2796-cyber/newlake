// 모든 요청에 X-User-Id 헤더를 붙인다. 사용자 선택은 auth.tsx 가 관리한다.
let currentUser = 'u-jung';
export const setApiUser = (id: string) => { currentUser = id; };

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) { super(message); this.status = status; }
}

function detailText(d: unknown, status: number): string {
  if (typeof d === 'string') return d;
  if (Array.isArray(d)) return d.map((x) => (x && typeof x === 'object' && 'msg' in x ? String((x as { msg: unknown }).msg) : String(x))).join(', ');
  return `요청에 실패했어요 (${status})`;
}

async function call<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response;
  try {
    res = await fetch(path, { ...init, headers: { 'X-User-Id': currentUser, ...(init?.body ? { 'Content-Type': 'application/json' } : {}) } });
  } catch {
    throw new ApiError(0, 'API 서버에 연결할 수 없어요');
  }
  const text = await res.text();
  let body: unknown = null;
  try { body = text ? JSON.parse(text) : null; } catch { /* 본문이 JSON 이 아님 */ }
  if (!res.ok) {
    const d = body && typeof body === 'object' && 'detail' in body ? (body as { detail: unknown }).detail : null;
    throw new ApiError(res.status, detailText(d, res.status));
  }
  return body as T;
}

export const get = <T,>(path: string) => call<T>(path);
export const post = <T,>(path: string, data: unknown) => call<T>(path, { method: 'POST', body: JSON.stringify(data) });

/* ---------- 타입 ---------- */
export interface Me { user_id: string; display_name: string; enterprise_id: string; roles: string[]; site_ids: string | string[]; plant_ids: string | string[]; }
export interface RiskDetail { cause?: string; lot_id?: string; customer_id?: string; sales_order_id?: string; defect_rate_pct?: number; requested_delivery_date?: string; [k: string]: unknown }
export interface RiskEvent { event_id: string; risk_level: string; source_iri?: string; affected_iris?: string[]; detail: RiskDetail; detected_at: string; status: string }
export interface SpecOut { equipment_id?: string; parameter_id: string; parameter_name: string; event_date_time: string; parameter_value: number; lsl: number; usl: number; lot_id?: string; operation_id?: string }
export interface Home { risks: RiskEvent[]; pending_approvals: number; spec_outs: SpecOut[]; kpi: { yield_7d_pct: number | null; otd_pct: number | null; wip_lots: number; hold_lots: number } }
export type Kind = 'lot' | 'equipment' | 'order' | 'item' | 'customer';
export interface SearchHit { kind: Kind; id: string; label: string; sub: string | null }
export interface LotAction { execution_id: string; action_label: string; status: string; requested_by: string | null; approved_by: string | null; created_at: string }
export interface Lot {
  iri: string;
  lot: Record<string, string | number | boolean | null>;
  ancestors: { lot_id: string; depth: number }[];
  descendants: { lot_id: string; depth: number }[];
  spec_outs: SpecOut[];
  defects: { operation_id: string; defect_type_code: string | null; defect_type_detail_code: string | null; qty: number }[];
  orders: { sales_order_id: string; customer_id: string; customer_name: string | null; requested_delivery_date: string; item_quantity: number }[];
  risks: RiskEvent[];
  actions: LotAction[];
}
export interface EquipmentResp {
  equipment: Record<string, string | number | null>;
  parameters: { parameter_id: string; parameter_name: string; parameter_uom_code: string | null; lsl: number | null; usl: number | null }[];
  trace: { parameter_id: string; event_date_time: string; parameter_value: number; validation_result_code: string }[];
}
export interface YieldRow { perf_date: string; item_id: string; produced_qty: number; defect_qty: number; yield_pct: number }
export interface PpmRow { perf_date: string; operation_id: string; defect_type_code: string | null; defect_qty: number; produced_qty: number; ppm: number }
export interface UtilRow { equipment_id: string; perf_date: string; run_time: number; setup_time: number; time_util_pct: number; produced_qty: number; defect_qty: number }
export interface OtdOrder { sales_order_id: string; customer_id: string; item_id: string; requested_delivery_date: string; first_release_date: string | null; fulfilled_date: string | null; released_qty: number; ordered_qty: number; on_time: boolean | null }
export interface Otd { otd_pct: number | null; orders: OtdOrder[] }
export interface WipRow { current_operation_id: string; lot_state: string; lot_count: number; wip_qty: number; hold_lots: number }
export interface RiskRow { lot_id: string; production_order_id: string; defect_qty: number; defect_rate_pct: number; sales_order_id: string; customer_id: string; requested_delivery_date: string; risk_level: string }
export interface Fact { tier: 'ASSERTED' | 'OBSERVED' | 'INFERRED' | 'GENERATED' | 'LLM' | string; text: string }
export interface InboxRow {
  execution_id: string; policy_id: string | null; action_iri: string; action_label: string; target_iri: string; status: string;
  requested_by: string | null; approved_by: string | null; created_at: string; approver_role_id: string | null;
  rationale: { facts?: Fact[]; rule?: string; decision_note?: string; decided_at?: string } | null;
  risk_level: string | null; risk_detail: RiskDetail | null; can_decide: boolean;
}
export interface QueryResult { rows: Record<string, unknown>[]; row_count: number; truncated: boolean }

export const runQuery = (sql: string, question?: string) => post<QueryResult>('/api/agent/query', { sql, question });
