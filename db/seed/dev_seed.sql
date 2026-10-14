-- =============================================================================
-- 개발용 시드 — 화면 시연에 쓰는 사용자·역할·리스크 이벤트·승인 대기 1건
-- 95_sample_data.sql (ACME / HQ / P1 "고객 클레임 1건" 시나리오) 다음에 소유자 계정으로 적용한다.
-- 운영 DB 에는 넣지 않는다. 다시 실행해도 같은 결과.
-- 개체 IRI 규칙(개발): https://data.impix.co.kr/{회사}/{클래스}/{ID}
-- =============================================================================
INSERT INTO gov.app_user (user_id, display_name, email, personnel_id, enterprise_id) VALUES
 ('u-jung', '정품질', 'jung@acme.example', NULL,    'ACME'),
 ('u-kim',  '김품질', 'kim@acme.example',  'E1001', 'ACME'),
 ('u-lee',  '이생산', 'lee@acme.example',  'E2001', 'ACME'),
 ('u-park', '박이공', 'park@acme.example', NULL,    'ACME')
ON CONFLICT (user_id) DO UPDATE SET display_name = EXCLUDED.display_name, email = EXCLUDED.email,
  personnel_id = EXCLUDED.personnel_id, enterprise_id = EXCLUDED.enterprise_id, status = 'ACTIVE';

-- 정품질: P1 분석가(조회·제안). 김품질: 회사 전체 품질 엔지니어(승인자). 이생산: P1 생산관리자.
-- 박이공: 데이터가 없는 P2 공장 분석가 — 범위 밖 데이터가 안 보이는지 확인용.
INSERT INTO gov.role_assignment (user_id, role_id, enterprise_id, site_id, plant_id, granted_by) VALUES
 ('u-jung', 'analyst',            'ACME', 'HQ', 'P1', 'dev-seed'),
 ('u-kim',  'quality_engineer',   'ACME', NULL, NULL, 'dev-seed'),
 ('u-lee',  'production_manager', 'ACME', 'HQ', 'P1', 'dev-seed'),
 ('u-park', 'analyst',            'ACME', 'HQ', 'P2', 'dev-seed')
ON CONFLICT DO NOTHING;

-- 납기 리스크 1건 (rules/otd-risk 가 v_otd_risk_candidate 에서 만든 것과 같은 모양)
INSERT INTO sem.risk_event (event_id, event_class_iri, enterprise_id, site_id, plant_id, source_iri, affected_iris, risk_level, detail, derived_by)
VALUES ('00000000-0000-4000-8000-000000000731', 'https://ontology.impix.co.kr/arcon/OTDRiskEvent', 'ACME', 'HQ', 'P1',
        'https://data.impix.co.kr/ACME/lot/LOT-2026-0731',
        ARRAY['https://data.impix.co.kr/ACME/salesOrder/SO-5001', 'https://data.impix.co.kr/ACME/customer/C-77'],
        'CRITICAL',
        jsonb_build_object('lot_id', 'LOT-2026-0731', 'defect_rate_pct', 3.4, 'sales_order_id', 'SO-5001',
                           'customer_id', 'C-77', 'requested_delivery_date', current_date + 5,
                           'cause', 'EQ-07 존3 온도 규격 이탈 (262.4℃ > USL 255℃)'),
        'https://ontology.impix.co.kr/arcon/rules/otd-risk')
ON CONFLICT (event_id) DO NOTHING;

-- 로트 보류 승인 대기 (정책 otd-risk → 승인 역할 quality_engineer)
INSERT INTO gov.action_execution (execution_id, policy_id, risk_event_id, enterprise_id, site_id, plant_id, action_iri, target_iri,
                                  verb, noun, receiver_system, requested_by, rationale)
VALUES ('00000000-0000-4000-8000-0000000007a1', 'otd-risk', '00000000-0000-4000-8000-000000000731', 'ACME', 'HQ', 'P1',
        'https://ontology.impix.co.kr/arcon/HoldLot', 'https://data.impix.co.kr/ACME/lot/LOT-2026-0731',
        'Change', 'Lot', 'MES-A', 'agent:otd-risk',
        jsonb_build_object('rule', 'otd-risk', 'facts', jsonb_build_array(
            jsonb_build_object('tier', 'ASSERTED', 'text', 'LOT-2026-0731 → SO-5001 (한빛전자) 납기 D+5'),
            jsonb_build_object('tier', 'OBSERVED', 'text', 'EQ-07 존3 온도 262.4℃ (USL 255℃), 10:15·10:20 연속 이탈'),
            jsonb_build_object('tier', 'INFERRED', 'text', '불량률 3.4% > 기준 3% → 납기 리스크 CRITICAL'))))
ON CONFLICT (execution_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 관리 화면(데이터 관리) 시연용: 관리자, 파이프라인 실행 기록, 매핑, 품질 검증 결과
-- ---------------------------------------------------------------------------
INSERT INTO gov.app_user (user_id, display_name, email, enterprise_id) VALUES
 ('u-choi', '최관리', 'choi@acme.example', 'ACME')
ON CONFLICT (user_id) DO UPDATE SET display_name = EXCLUDED.display_name, status = 'ACTIVE';
INSERT INTO gov.role_assignment (user_id, role_id, enterprise_id, site_id, plant_id, granted_by) VALUES
 ('u-choi', 'admin',        'ACME', NULL, NULL, 'dev-seed'),
 ('u-choi', 'data_steward', 'ACME', NULL, NULL, 'dev-seed')
ON CONFLICT DO NOTHING;

INSERT INTO catalog.mapping (mapping_id, source_dataset_id, target_class_iri, kind, version_no, artifact_uri, status, approved_by, approved_at, f1_score) VALUES
 ('ksx9101/lot.rml.ttl@v3', 'raw.mes.lot_history', 'https://ontology.impix.co.kr/ksx9101/Lot', 'RML', 3,
  'git://mappings/ksx9101/lot.rml.ttl', 'APPROVED', 'u-choi', now() - interval '20 days', 0.962),
 ('ksx9101/trace.rml.ttl@v1', 'raw.eap07.trace', 'https://ontology.impix.co.kr/ksx9101/TraceParameter', 'RML', 1,
  'git://mappings/ksx9101/trace.rml.ttl', 'REVIEW', NULL, NULL, 0.881)
ON CONFLICT (mapping_id) DO NOTHING;

INSERT INTO catalog.job_run (run_id, pipeline_id, mapping_id, started_at, ended_at, status, rows_in, rows_out, rows_rejected, code_version, error_message, enterprise_id) VALUES
 ('00000000-0000-4000-8000-00000000a001', 'p-std-lot', 'ksx9101/lot.rml.ttl@v3', now() - interval '25 minutes', now() - interval '24 minutes', 'SUCCESS', 1240, 1240, 0, 'a1b2c3d', NULL, 'ACME'),
 ('00000000-0000-4000-8000-00000000a002', 'p-trace-promote', NULL, now() - interval '3 hours', NULL, 'RUNNING', 86400, 86398, 0, 'a1b2c3d', NULL, 'ACME'),
 ('00000000-0000-4000-8000-00000000a003', 'p-kg-materialize', 'ksx9101/lot.rml.ttl@v3', now() - interval '70 minutes', now() - interval '62 minutes', 'PARTIAL', 48210, 48190, 20, 'a1b2c3d', 'lot_state 코드 미등록 20건 (예: LOT-2026-0732 → "RELEASE")', 'ACME'),
 ('00000000-0000-4000-8000-00000000a004', 'p-kpi', NULL, (now() AT TIME ZONE 'Asia/Seoul')::date + time '02:00' - interval '9 hours', (now() AT TIME ZONE 'Asia/Seoul')::date + time '02:07' - interval '9 hours', 'SUCCESS', 3, 3, 0, 'a1b2c3d', NULL, 'ACME')
ON CONFLICT (run_id) DO NOTHING;

INSERT INTO catalog.quality_run (quality_run_id, job_run_id, dataset_id, executed_at, focus_count, violation_count, report_uri) VALUES
 ('00000000-0000-4000-8000-00000000b001', '00000000-0000-4000-8000-00000000a003', 'raw.mes.lot_history', now() - interval '62 minutes', 1250, 20, 's3://lake-quality/shacl/lot/latest.ttl')
ON CONFLICT (quality_run_id) DO NOTHING;
INSERT INTO catalog.quality_violation (quality_run_id, rule_id, focus_node, result_path, message, severity, status)
SELECT '00000000-0000-4000-8000-00000000b001', 'ksx-lot-structure', v.focus, 'ksx:lotState', v.msg, 'Violation', v.st
  FROM (VALUES ('https://data.impix.co.kr/ACME/lot/LOT-2026-0732', 'lotState "RELEASE" 가 공통코드 LotState 에 없음', 'OPEN'),
               ('https://data.impix.co.kr/ACME/lot/LOT-2026-0801', 'holdIndicator=true 인데 보류 사유 코드가 없음', 'ACK')) v(focus, msg, st)
 WHERE NOT EXISTS (SELECT 1 FROM catalog.quality_violation q WHERE q.quality_run_id = '00000000-0000-4000-8000-00000000b001' AND q.focus_node = v.focus);
UPDATE catalog.dataset SET quality_score = 98.40, quality_status = 'WARN', last_ingested_at = now() - interval '24 minutes'
 WHERE dataset_id = 'raw.mes.lot_history';

-- 데이터 이용 신청 1건 (권한·감사 화면의 승인 대기)
INSERT INTO gov.access_request (request_id, requester_id, dataset_id, purpose, requested_actions, period_from, period_to, enterprise_id)
VALUES ('00000000-0000-4000-8000-00000000c001', 'u-jung', 'raw.eap07.trace', 'EQ-07 존3 온도 이탈 원인 분석 (원본 1초 데이터 필요)',
        '{read,download}', current_date, current_date + 30, 'ACME')
ON CONFLICT (request_id) DO NOTHING;
