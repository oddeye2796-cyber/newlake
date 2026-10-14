-- =============================================================================
-- 액션 정의·실행 정책 시드 — 클래스·속성 레지스트리(90_seed_ontology.sql) 다음에 적용
-- onto.action.target_class_iri, gov.action_policy.trigger_class_iri 가 onto.class 를 FK 로 가리키므로 순서가 중요하다 (리뷰 F16).
-- 재실행해도 같은 결과(upsert).
-- =============================================================================
INSERT INTO onto.action VALUES
 ('https://ontology.impix.co.kr/arcon/HoldLot', '로트 보류', 'Change', 'https://ontology.impix.co.kr/ksx9101/Lot', 'https://ontology.impix.co.kr/ksx9101/holdIndicator', 'https://ontology.impix.co.kr/ksx9101/LotShape', '25'),
 ('https://ontology.impix.co.kr/arcon/StopEquipment', '설비 정지', 'Change', 'https://ontology.impix.co.kr/ksx9101/EquipmentState', NULL, NULL, '33'),
 ('https://ontology.impix.co.kr/arcon/CreateMaintenanceRequest', '정비 요청 생성', 'Process', 'https://ontology.impix.co.kr/arcon/MaintenanceRequest', NULL, NULL, NULL),
 ('https://ontology.impix.co.kr/arcon/NotifyEngineer', '엔지니어 알림', 'Notify', 'https://ontology.impix.co.kr/ksx9101/Personnel', NULL, NULL, NULL),
 ('https://ontology.impix.co.kr/arcon/IssueCorrectiveAction', '시정조치 요청', 'Process', 'https://ontology.impix.co.kr/ksx9101/CorrectiveActionRequest', NULL, NULL, '20')
ON CONFLICT (action_iri) DO UPDATE SET label_ko = EXCLUDED.label_ko, verb = EXCLUDED.verb, target_class_iri = EXCLUDED.target_class_iri,
  sets_property_iri = EXCLUDED.sets_property_iri, precondition_shape = EXCLUDED.precondition_shape, scenario_ref = EXCLUDED.scenario_ref;

INSERT INTO gov.action_policy (policy_id, trigger_class_iri, condition, action_iri, mode, approver_role_id, notify_role_ids) VALUES
 ('otd-risk',  'https://ontology.impix.co.kr/arcon/OTDRiskEvent', '{"riskLevel":["HIGH","CRITICAL"],"dueWithinDays":7}',
  'https://ontology.impix.co.kr/arcon/HoldLot', 'approval', 'quality_engineer', '{production_manager}'),
 ('spec-out',  'https://ontology.impix.co.kr/arcon/SpecOutEvent', '{"consecutive":3}',
  'https://ontology.impix.co.kr/arcon/NotifyEngineer', 'auto', NULL, '{quality_engineer}')
ON CONFLICT (policy_id) DO UPDATE SET trigger_class_iri = EXCLUDED.trigger_class_iri, condition = EXCLUDED.condition,
  action_iri = EXCLUDED.action_iri, mode = EXCLUDED.mode, approver_role_id = EXCLUDED.approver_role_id, notify_role_ids = EXCLUDED.notify_role_ids;
