-- =============================================================================
-- 예시 데이터 — "고객 클레임 1건" 시나리오 (반도체 후공정, ACME / HQ / P1)
-- 리플로우 오븐 EQ-07 온도 규격 이탈 → 진행 중 로트 LOT-2026-0731 불량 3.4% → 7일 내 납기 수주 리스크
-- 날짜는 current_date 기준 상대값이라 언제 적용해도 리스크 뷰가 살아 있다.
-- 적용 순서와 무관하게 커밋 시점에만 FK 를 검사(DEFERRABLE)하는 것도 함께 확인한다. 파일 전체가 한 트랜잭션(psql -1).
-- =============================================================================
-- 의도적으로 자식부터 넣는다 (FK 지연 검사 확인)
INSERT INTO ksx.lot (enterprise_id, site_id, plant_id, lot_id, lot_name, parent_lot_id, item_id, production_order_id, production_order_sequence,
                     current_operation_id, lot_state, hold_indicator, lot_created_quantity, produced_quantity, defect_quantity, lot_started_date_time) VALUES
 ('ACME','HQ','P1','LOT-2026-0730','A100 모로트',  NULL,            'ITM-A100','PO-1001',1,'OP-30','CLOSING',FALSE, 2000, 1990,  8, current_date - 4 + time '06:00'),
 ('ACME','HQ','P1','LOT-2026-0731','A100 분할로트','LOT-2026-0730', 'ITM-A100','PO-1001',1,'OP-40','START',FALSE, 1000,  980, 34, current_date - 2 + time '08:00'),
 ('ACME','HQ','P1','LOT-2026-0732','A100 분할로트','LOT-2026-0730', 'ITM-A100','PO-1001',1,'OP-40','RELEASE',FALSE,  990,  NULL, NULL, NULL),
 ('ACME','HQ','P1','LOT-2026-0801','B200 로트',    NULL,            'ITM-B200','PO-1002',1,'OP-20','START',TRUE,   500,  NULL, NULL, current_date - 1 + time '09:00');

INSERT INTO ksx.enterprise (enterprise_id, enterprise_name) VALUES ('ACME','에이크미 반도체');
INSERT INTO ksx.site  (enterprise_id, site_id, site_name) VALUES ('ACME','HQ','본사 사업장');
INSERT INTO ksx.plant (enterprise_id, site_id, plant_id, plant_name) VALUES ('ACME','HQ','P1','후공정 1공장');
INSERT INTO ksx.personnel (enterprise_id, site_id, plant_id, personnel_id, personnel_name) VALUES
 ('ACME','HQ','P1','E1001','김품질'), ('ACME','HQ','P1','E2001','이생산');
INSERT INTO ksx.customer_party_master (enterprise_id, site_id, plant_id, customer_id, customer_name) VALUES ('ACME','HQ','P1','C-77','한빛전자');
INSERT INTO ksx.item_master (enterprise_id, site_id, plant_id, item_id, item_name, item_uom_code, safety_stock) VALUES
 ('ACME','HQ','P1','ITM-A100','BGA 패키지 A100','EA', 5000), ('ACME','HQ','P1','ITM-B200','QFN 패키지 B200','EA', 2000);
INSERT INTO ksx.operation (enterprise_id, site_id, plant_id, operation_id, operation_name) VALUES
 ('ACME','HQ','P1','OP-20','다이 본딩'), ('ACME','HQ','P1','OP-30','와이어 본딩'), ('ACME','HQ','P1','OP-40','리플로우');
INSERT INTO ksx.equipment (enterprise_id, site_id, plant_id, equipment_id, equipment_name, operation_id) VALUES
 ('ACME','HQ','P1','EQ-07','리플로우 오븐 7호기','OP-40'), ('ACME','HQ','P1','EQ-03','와이어 본더 3호기','OP-30');
INSERT INTO ksx.equipment_parameter (enterprise_id, site_id, plant_id, parameter_id, parameter_name, parameter_uom_code, equipment_id, lsl, usl) VALUES
 ('ACME','HQ','P1','TEMP01','존3 온도','℃','EQ-07', 235, 255);
INSERT INTO ksx.sales_order (enterprise_id, site_id, plant_id, sales_order_id, sales_document_number, sales_document_sequence, customer_id,
                             sales_date, requested_delivery_date, item_id, item_quantity) VALUES
 ('ACME','HQ','P1','SO-5001','SD-5001',1,'C-77', current_date - 20, current_date + 5,  'ITM-A100', 2900),
 ('ACME','HQ','P1','SO-4990','SD-4990',1,'C-77', current_date - 40, current_date - 10, 'ITM-A100', 1000);
INSERT INTO ksx.production_order (enterprise_id, site_id, plant_id, production_order_id, production_order_sequence, item_id,
                                  production_order_quantity, sales_document_number, sales_document_sequence) VALUES
 ('ACME','HQ','P1','PO-1001',1,'ITM-A100', 1000, 'SD-5001', 1),
 ('ACME','HQ','P1','PO-1002',1,'ITM-B200',  500, NULL, NULL);
INSERT INTO ksx.operation_start (enterprise_id, site_id, plant_id, lot_id, operation_id, equipment_id, operation_start_time, personnel_id) VALUES
 ('ACME','HQ','P1','LOT-2026-0731','OP-40','EQ-07', current_date - 2 + time '10:00', 'E2001');
INSERT INTO ksx.operation_end (enterprise_id, site_id, plant_id, lot_id, operation_id, equipment_id, operation_end_time, produced_quantity, defect_quantity) VALUES
 ('ACME','HQ','P1','LOT-2026-0731','OP-40','EQ-07', current_date - 2 + time '11:30', 980, 34);
INSERT INTO ksx.trace_parameter (enterprise_id, site_id, plant_id, equipment_id, parameter_id, event_date_time, parameter_uom_code, parameter_value, validation_result_code) VALUES
 ('ACME','HQ','P1','EQ-07','TEMP01', current_date - 2 + time '10:15', '℃', 262.4, 'OUT_OF_SPEC'),
 ('ACME','HQ','P1','EQ-07','TEMP01', current_date - 2 + time '10:20', '℃', 259.8, 'OUT_OF_SPEC'),
 ('ACME','HQ','P1','EQ-07','TEMP01', current_date - 2 + time '10:40', '℃', 247.1, 'NORMAL');
INSERT INTO ksx.production_performance (enterprise_id, site_id, plant_id, production_performance_id, production_performance_sequence,
       production_order_id, production_order_sequence, item_id, produced_quantity, defect_quantity, operation_id, production_performance_date, lot_id) VALUES
 ('ACME','HQ','P1','PP-9001',1,'PO-1001',1,'ITM-A100', 980, 34,'OP-40', current_date - 2,'LOT-2026-0731'),
 ('ACME','HQ','P1','PP-8990',1,'PO-1001',1,'ITM-A100',1990,  8,'OP-30', current_date - 4,'LOT-2026-0730');
INSERT INTO ksx.production_performance_quality (enterprise_id, site_id, plant_id, production_performance_id, production_performance_sequence,
       production_order_id, production_order_sequence, item_id, operation_id, lot_id, defect_type_quantity, defect_type_code, defect_type_detail_code) VALUES
 ('ACME','HQ','P1','PP-9001',1,'PO-1001',1,'ITM-A100','OP-40','LOT-2026-0731', 22,'SOLDER','VOID'),
 ('ACME','HQ','P1','PP-9001',1,'PO-1001',1,'ITM-A100','OP-40','LOT-2026-0731', 12,'SOLDER','BRIDGE');
INSERT INTO ksx.product_release (enterprise_id, site_id, plant_id, product_release_id, product_release_sequence, sales_document_number, sales_document_sequence,
                                 inventory_transaction_date, item_id, sales_quantity, customer_id, lot_id) VALUES
 ('ACME','HQ','P1','PR-7001',1,'SD-4990',1, current_date - 12,'ITM-A100',1000,'C-77','LOT-2026-0730');

-- 카탈로그: 원천 시스템·원천 존 데이터셋·계보 예시
INSERT INTO catalog.source_system VALUES
 ('MES-A','후공정 MES','MES','JDBC',TRUE,'생산기술팀','ACME'),
 ('ERP-S','SAP ERP','ERP','REST',FALSE,'정보전략팀','ACME'),
 ('EAP-07','리플로우 EAP','SECS_GEM','KAFKA',FALSE,'설비기술팀','ACME');
INSERT INTO catalog.dataset (dataset_id, title_ko, zone_id, represents_class_iri, source_system_id, location_uri, format, ingest_mode, record_count, sensitivity, enterprise_id) VALUES
 ('raw.mes.lot_history','MES 로트 이력(원천)','RAW','https://ontology.impix.co.kr/ksx9101/Lot','MES-A','s3://lake-raw/mes-a/lot_history/','parquet','cdc', 1250000,'INTERNAL','ACME'),
 ('raw.eap07.trace','EQ-07 파라미터 원본','RAW','https://ontology.impix.co.kr/ksx9101/TraceParameter','EAP-07','s3://lake-raw/eap-07/trace/','parquet','stream', 86400000,'INTERNAL','ACME'),
 ('sem.abox.acme_hq_p1','ACME/HQ/P1 지식그래프','SEMANTIC',NULL,NULL,'sparql://fuseki/lake/graph/ACME/HQ/P1','rdf','derived', 48200000,'INTERNAL','ACME'),
 ('cur.kpi_process_ppm','공정 불량 PPM(일)','CURATED',NULL,NULL,'postgresql://lake/mart.v_kpi_process_ppm','table','derived',NULL,'INTERNAL',NULL);
INSERT INTO catalog.pipeline VALUES
 ('p-std-lot','MES 로트 → 표준 존','RAW','STANDARD','airflow','*/10 * * * *','u-de',TRUE),
 ('p-trace-promote','파라미터 원본 → 규격이탈 승격','RAW','STANDARD','kafka-streams',NULL,'u-de',TRUE),
 ('p-kg-materialize','표준 존 → KG 물질화(추론 대상)','STANDARD','SEMANTIC','morph-kgc','0 * * * *','u-onto',TRUE),
 ('p-kpi','KPI 마트','STANDARD','CURATED','dbt','0 2 * * *','u-de',TRUE);
INSERT INTO catalog.lineage_edge (from_dataset_id, to_dataset_id, pipeline_id, field_map) VALUES
 ('raw.mes.lot_history','std.lot','p-std-lot','{"lot_id":["LOT_NO"],"parent_lot_id":["MOTHER_LOT"]}'),
 ('raw.eap07.trace','std.trace_parameter','p-trace-promote',NULL),
 ('std.lot','sem.abox.acme_hq_p1','p-kg-materialize',NULL),
 ('std.trace_parameter','sem.abox.acme_hq_p1','p-kg-materialize',NULL),
 ('std.production_performance_quality','cur.kpi_process_ppm','p-kpi',NULL),
 ('std.production_performance','cur.kpi_process_ppm','p-kpi',NULL);
INSERT INTO catalog.quality_rule (rule_id, label_ko, dimension, target_class_iri, shape_iri, severity, threshold) VALUES
 ('ksx-lot-structure','로트 KS X 9101 적합성','구조','https://ontology.impix.co.kr/ksx9101/Lot','https://ontology.impix.co.kr/ksx9101/LotShape','Violation',99.0);
