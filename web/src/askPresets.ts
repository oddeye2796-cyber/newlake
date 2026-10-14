import { t } from './i18n';

/* LLM 이 연결되기 전까지 "추천 질문"에 미리 연결해 둔 SQL.
   /api/agent/query 는 ksx.* / mart.* 뷰에 대한 단일 SELECT 만 받는다. */
export interface Preset {
  id: string;
  question: string;
  /** 질문 문장에서 이 프리셋을 고르는 키워드(자유 입력 매칭용) */
  match: RegExp;
  sql: string | null;
  /** sql 이 없을 때 보여 줄 안내 */
  unsupported?: string;
}

export const PRESETS: Preset[] = [
  {
    id: 'eq07-risk',
    get question() { return t('EQ-07 때문에 위험한 주문 있어?'); },
    match: /EQ-?07|위험|납기|risk|deliver|危険|納期/i, // i18n-ignore
    sql: `SELECT r.sales_order_id, r.customer_id, r.requested_delivery_date, r.lot_id,
       r.defect_qty, r.defect_rate_pct, r.risk_level,
       s.equipment_id, s.parameter_name,
       MAX(s.parameter_value) AS max_value, MAX(s.usl) AS usl,
       COUNT(*) AS spec_out_count
FROM mart.v_otd_risk_candidate r
JOIN mart.v_spec_out_lot s ON s.lot_id = r.lot_id
WHERE s.equipment_id = 'EQ-07'
GROUP BY r.sales_order_id, r.customer_id, r.requested_delivery_date, r.lot_id,
         r.defect_qty, r.defect_rate_pct, r.risk_level, s.equipment_id, s.parameter_name
ORDER BY r.requested_delivery_date`,
  },
  {
    id: 'genealogy',
    get question() { return t('LOT-2026-0731은 어느 모로트에서 나왔어?'); },
    match: /모로트|계보|어디서|parent|genealog|親ロット|系譜/i, // i18n-ignore
    sql: `SELECT lot_id, ancestor_lot_id AS parent_lot_id, depth, path
FROM mart.v_lot_genealogy
WHERE lot_id = 'LOT-2026-0731'
ORDER BY depth`,
  },
  {
    id: 'reflow-ppm',
    get question() { return t('이번 주 리플로우 불량은?'); },
    match: /불량|PPM|리플로우|defect|reflow|不良|リフロー/i, // i18n-ignore
    sql: `SELECT perf_date, operation_id, defect_type_code, defect_qty, produced_qty, ppm
FROM mart.v_kpi_process_ppm
WHERE operation_id = 'OP-40'
  AND perf_date >= CURRENT_DATE - 7
ORDER BY perf_date DESC`,
  },
  {
    id: 'spec-out',
    get question() { return t('기준을 벗어난 설비 측정값 보여줘'); },
    match: /기준|규격|이탈|측정|spec|out of|measure|規格|測定|基準/i, // i18n-ignore
    sql: `SELECT equipment_id, parameter_name, event_date_time, parameter_value, lsl, usl, lot_id, operation_id
FROM mart.v_spec_out_lot
ORDER BY event_date_time DESC
LIMIT 50`,
  },
  {
    id: 'wip',
    get question() { return t('공정별로 진행 중인 로트는 몇 개야?'); },
    match: /진행|WIP|재공|공정별|wip|in progress|operation|仕掛|工程/i, // i18n-ignore
    sql: `SELECT current_operation_id, lot_state, lot_count, wip_qty, hold_lots
FROM mart.v_kpi_wip
ORDER BY current_operation_id, lot_state`,
  },
  {
    id: 'otd',
    get question() { return t('납기 준수 현황은?'); },
    match: /준수|OTD|출고|on-time|deliver|納期/i, // i18n-ignore
    sql: `SELECT sales_order_id, customer_id, item_id, requested_delivery_date, fulfilled_date,
       ordered_qty, released_qty, on_time
FROM mart.v_kpi_otd
ORDER BY requested_delivery_date`,
  },
  {
    id: 'maint',
    get question() { return t('EQ-07 정비 이력 보여줘'); },
    match: /정비|보전|수리|maint|repair|保全|整備/i, // i18n-ignore
    sql: null,
    get unsupported() { return t('정비 이력은 아직 연결된 시스템이 없어서 답할 수 없어요. 설비보전 시스템(CMMS)을 연결하면 볼 수 있어요.'); },
  },
];

/** 홈/질문하기에 보여 줄 추천 질문 (홈은 앞 3개) */
export const SUGGESTED = PRESETS;

/** 자유 입력을 프리셋으로 연결. 질문 문장 그대로면 정확히, 아니면 키워드로. */
export function matchPreset(q: string): Preset | null {
  const s = q.trim();
  const exact = PRESETS.find((p) => p.question === s);
  if (exact) return exact;
  // 구체 항목(로트/설비)을 언급한 질문이 더 구체적이므로 정비·계보 같은 좁은 키워드를 먼저 본다.
  const order = ['maint', 'genealogy', 'eq07-risk', 'reflow-ppm', 'spec-out', 'wip', 'otd'];
  for (const id of order) { const p = PRESETS.find((x) => x.id === id)!; if (p.match.test(s)) return p; }
  return null;
}

export const looksLikeSql = (q: string) => /^\s*(select|with)\b/i.test(q);

/* 엔티티 화면에서 "질의로 보기" 링크에 쓰는 SQL. 식별자는 안전한 문자만 허용한다. */
const safeId = (id: string) => /^[A-Za-z0-9._-]+$/.test(id);
export const lotGenealogySql = (id: string) => (safeId(id)
  ? `SELECT lot_id, ancestor_lot_id AS parent_lot_id, depth, path\nFROM mart.v_lot_genealogy\nWHERE lot_id = '${id}'\nORDER BY depth` : null);
export const equipmentSpecOutSql = (id: string) => (safeId(id)
  ? `SELECT equipment_id, parameter_name, event_date_time, parameter_value, lsl, usl, lot_id\nFROM mart.v_spec_out_lot\nWHERE equipment_id = '${id}'\nORDER BY event_date_time DESC` : null);
export const specOutLotsSql = equipmentSpecOutSql;
