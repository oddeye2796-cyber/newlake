// 모든 요청에 X-User-Id 헤더를 붙인다. 사용자 선택은 auth.tsx 가 관리한다.
import { t } from './i18n';
let currentUser = 'u-jung';
export const setApiUser = (id: string) => { currentUser = id; };

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) { super(message); this.status = status; }
}

function detailText(d: unknown, status: number): string {
  if (typeof d === 'string') return d;
  if (Array.isArray(d)) return d.map((x) => (x && typeof x === 'object' && 'msg' in x ? String((x as { msg: unknown }).msg) : String(x))).join(', ');
  return t('요청에 실패했어요 ({status})', { status });
}

async function call<T>(path: string, init?: RequestInit): Promise<T> {
  if (import.meta.env.VITE_DEMO === '1') return (await import('./demo/demoApi')).demoCall<T>(currentUser, path, init);
  let res: Response;
  try {
    res = await fetch(path, { ...init, headers: { 'X-User-Id': currentUser, ...(init?.body ? { 'Content-Type': 'application/json' } : {}) } });
  } catch {
    throw new ApiError(0, t('API 서버에 연결할 수 없어요'));
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

/* ---------- 관리자(데이터 관리) 타입 ---------- */
export interface AdminZone { zone_id: string; label_ko: string; zone_order: number; datasets: number; records: number | null }
export interface AdminPipeline {
  pipeline_id: string; label_ko: string; from_zone: string; to_zone: string; engine: string; schedule_cron: string | null; enabled: boolean;
  last_status: string | null; last_started_at: string | null; last_ended_at: string | null; rows_in: number | null; rows_out: number | null; rows_rejected: number | null; error_message: string | null;
}
export interface AdminRisk { event_id: string; risk_level: string; source_iri?: string; detail: RiskDetail; detected_at: string; derived_by?: string }
export interface AdminOverview {
  counts: { datasets: number; classes: number; properties: number; open_violations: number; pending_access: number; open_risks: number };
  zones: AdminZone[]; pipelines: AdminPipeline[]; risks: AdminRisk[];
}
export interface AdminDatasetRow {
  dataset_id: string; title_ko: string; zone_id: string; represents_class_iri: string | null; class_label: string | null; source_system_id: string | null;
  location_uri: string | null; format: string | null; ingest_mode: string | null; record_count: number | null; last_ingested_at: string | null;
  quality_score: number | null; quality_status: string; sensitivity: string; tags: string[];
}
export interface AdminField {
  dataset_id: string; field_name: string; label_ko: string | null; data_type: string | null; is_pk: boolean; is_required: boolean;
  maps_to_property_iri: string | null; mapping_method: string | null; mapping_confidence: number | null; mapping_status: string | null; null_ratio: number | null; distinct_count: number | null;
}
export interface AdminLineageRef { dataset_id: string; pipeline_id: string | null; relation: string; field_map?: Record<string, string[]> | null }
export interface AdminMapping { mapping_id: string; source_dataset_id: string; target_class_iri: string; kind: string; version_no: number; artifact_uri: string | null; status: string; approved_by: string | null; approved_at: string | null; f1_score: number | null }
export interface AdminQualityRun { quality_run_id: string; executed_at: string; focus_count: number; violation_count: number; conformance_rate: number | null }
export interface AdminDatasetDetail {
  dataset: AdminDatasetRow & { description: string | null; schema_version: string | null; schedule_cron: string | null; size_bytes: number | null; pseudonymized: boolean; retention: string | null; owner_user_id: string | null; steward_user_id: string | null; source_label: string | null; system_type: string | null; updated_at: string };
  fields: AdminField[]; upstream: AdminLineageRef[]; downstream: AdminLineageRef[]; mappings: AdminMapping[]; quality_runs: AdminQualityRun[];
}
export interface AdminClassRow {
  class_iri: string; local_name: string; label_ko: string; label_en: string | null; business_group: string | null; parent_class_iri: string | null; standard_clause: string | null;
  physical_table: string | null; is_event: boolean; is_standard: boolean; datasets: number;
}
export interface AdminClassLink { property_iri: string; property_label: string; property_name: string; relation_kind: string | null; fk_columns: string | null; subject_class_iri: string; subject_label: string; object_class_iri: string; object_label: string }
export interface AdminClassDetail {
  class: AdminClassRow & { primary_key: string | null; definition_ko: string | null; version_id: string | null };
  links: AdminClassLink[]; datasets: { dataset_id: string; title_ko: string; zone_id: string }[];
  actions: { action_iri: string; label_ko: string; verb: string }[]; quality_rules: { rule_id: string; label_ko: string; dimension: string; severity: string }[];
}
export interface LineageEdge {
  edge_id: number; from_dataset_id: string; from_zone: string; from_title: string; to_dataset_id: string; to_zone: string; to_title: string;
  pipeline_id: string | null; pipeline_label: string | null; relation: string; field_map: Record<string, string[]> | null;
}
export interface QualityRule {
  rule_id: string; label_ko: string; dimension: string | null; target_class_iri: string | null; class_label: string | null; target_dataset_id: string | null; shape_iri: string | null;
  severity: string; threshold: number | null; enabled: boolean; last_dataset_id: string | null; last_run_at: string | null; focus_count: number | null; violation_count: number | null; conformance_rate: number | null;
}
export interface QualityViolation { violation_id: number; rule_id: string; focus_node: string; result_path: string | null; message: string; severity: string; status: string; assignee_user_id: string | null; dataset_id: string | null; executed_at: string }
export interface AccessRequest {
  request_id: string; requester_id: string; dataset_id: string; dataset_title: string | null; sensitivity: string; purpose: string; requested_actions: string[];
  period_from: string | null; period_to: string | null; status: string; approver_id: string | null; decided_at: string | null; decision_note: string | null; created_at: string;
}
export interface AdminRole { role_id: string; label_ko: string; description: string | null }
export interface RoleAssignment { user_id: string; display_name: string; status: string; role_id: string; role_label: string; site_id: string | null; plant_id: string | null; valid_until: string | null; granted_by: string | null; granted_at: string }
export interface AdminAccess { requests: AccessRequest[]; roles: AdminRole[]; assignments: RoleAssignment[] | null }
export interface AuditRow { occurred_at: string; user_id: string; channel: string; action: string; dataset_id: string | null; object_ref: string | null; query_text: string | null; row_count: number | null; result: string }

export const ADMIN_ROLES = ['admin', 'data_steward', 'data_engineer', 'ontology_manager'];
export const isAdminUser = (me: Me | null) => !!me && me.roles.some((r) => ADMIN_ROLES.includes(r));
