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
