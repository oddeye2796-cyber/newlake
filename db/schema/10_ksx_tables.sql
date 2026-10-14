-- =============================================================================
-- 표준 존(StandardZone) · KS X 9101-1:2025 v1.0 — 70 테이블
-- 생성: tools/gen_schema.py (원천: 테이블정의서 DDL 시트). 수기 편집 금지.
-- 각 테이블 끝에 레이크 기술 컬럼 5개를 덧붙인다(계보·적재·검증 상태).
-- =============================================================================
SET client_min_messages = warning;

-- KS X 9101-1:2025 v1.0 테이블정의서 DDL 시트 원문 (PostgreSQL 참고). FK는 관계목록 참조

CREATE TABLE ksx.site ( -- 사업장 (표 12)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    site_name VARCHAR(200), -- 사업장명
    business_registration_number VARCHAR(50), -- 사업자등록번호
    dial_number VARCHAR(30), -- 전화번호
    postal_code VARCHAR(10), -- 우편번호
    base_address VARCHAR(1000), -- 기본주소
    detail_address VARCHAR(1000), -- 상세주소
    use_indicator BOOLEAN, -- 사용여부
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_site PRIMARY KEY (enterprise_id, site_id)
);

CREATE TABLE ksx.plant ( -- 공장 (표 13)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    plant_name VARCHAR(200), -- 공장명
    dial_number VARCHAR(30), -- 전화번호
    country_id VARCHAR(30), -- 국가식별자
    postal_code VARCHAR(10), -- 우편번호
    base_address VARCHAR(1000), -- 기본주소
    detail_address VARCHAR(1000), -- 상세주소
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_plant PRIMARY KEY (enterprise_id, plant_id)
);

CREATE TABLE ksx.department ( -- 부서 (표 14)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    department_id VARCHAR(50) NOT NULL, -- 부서식별자
    department_name VARCHAR(200), -- 부서명
    parent_department_id VARCHAR(50), -- 상위부서식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_department PRIMARY KEY (enterprise_id, department_id)
);

CREATE TABLE ksx.personnel ( -- 사원 (표 15)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    personnel_id VARCHAR(50) NOT NULL, -- 사원식별자
    personnel_name VARCHAR(200), -- 사원명
    department_id VARCHAR(50), -- 부서식별자
    employment_status_type VARCHAR(30), -- 재직유형
    person_in_charge_email VARCHAR(255), -- 담당자이메일명
    person_in_charge_dial_number VARCHAR(30), -- 담당자전화번호
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_personnel PRIMARY KEY (enterprise_id, personnel_id)
);

CREATE TABLE ksx.customer_party_master ( -- 고객사 (표 16)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    customer_id VARCHAR(50) NOT NULL, -- 고객사식별자
    customer_name VARCHAR(200), -- 고객사명
    business_registration_number VARCHAR(50), -- 사업자등록번호
    representative_name VARCHAR(200), -- 대표자명
    country_id VARCHAR(30), -- 국가식별자
    postal_code VARCHAR(10), -- 우편번호
    base_address VARCHAR(1000), -- 기본주소
    detail_address VARCHAR(1000), -- 상세주소
    dial_number VARCHAR(30), -- 전화번호
    fax_number VARCHAR(30), -- 팩스번호
    use_indicator BOOLEAN, -- 사용여부
    person_in_charge_name VARCHAR(200), -- 담당자명
    person_in_charge_email VARCHAR(255), -- 담당자이메일명
    person_in_charge_dial_number VARCHAR(30), -- 담당자전화번호
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_customer_party_master PRIMARY KEY (enterprise_id, customer_id)
);

CREATE TABLE ksx.vendor_party_master ( -- 공급사 (표 17)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    vendor_id VARCHAR(50) NOT NULL, -- 공급사식별자
    vendor_name VARCHAR(200), -- 공급사명
    business_registration_number VARCHAR(50), -- 사업자등록번호
    representative_name VARCHAR(200), -- 대표자명
    country_id VARCHAR(30), -- 국가식별자
    postal_code VARCHAR(10), -- 우편번호
    base_address VARCHAR(1000), -- 기본주소
    detail_address VARCHAR(1000), -- 상세주소
    dial_number VARCHAR(30), -- 전화번호
    fax_number VARCHAR(30), -- 팩스번호
    use_indicator BOOLEAN, -- 사용여부
    person_in_charge_name VARCHAR(200), -- 담당자명
    person_in_charge_email VARCHAR(255), -- 담당자이메일명
    person_in_charge_dial_number VARCHAR(30), -- 담당자전화번호
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_vendor_party_master PRIMARY KEY (enterprise_id, vendor_id)
);

CREATE TABLE ksx.common_code_master ( -- 공통코드정보 (표 18)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    common_code_id VARCHAR(50) NOT NULL, -- 공통코드식별자
    common_code_name VARCHAR(200), -- 공통코드명
    common_code_group VARCHAR(30) NOT NULL, -- 공통코드그룹
    parent_common_code_group VARCHAR(50), -- 상위공통코드그룹
    parent_common_code_id VARCHAR(50), -- 상위공통코드식별자
    common_code_sequence INTEGER, -- 표시순번
    use_indicator BOOLEAN, -- 사용여부
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_common_code_master PRIMARY KEY (enterprise_id, common_code_group, common_code_id)
);

CREATE TABLE ksx.work_calendar ( -- 달력 (표 19)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    calendar_id VARCHAR(50) NOT NULL, -- 달력식별자
    calendar_type VARCHAR(30), -- 달력유형
    calendar_date DATE, -- 달력일자
    day_of_week VARCHAR(30), -- 요일
    week_of_year INTEGER, -- 주수
    day_of_year INTEGER, -- 총누계일수
    schedule_type VARCHAR(30), -- 근무일유형
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_work_calendar PRIMARY KEY (enterprise_id, calendar_id)
);

CREATE TABLE ksx.uom_group ( -- 단위그룹 (표 20)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    uom_group_id VARCHAR(50) NOT NULL, -- 단위그룹식별자
    uom_group_name VARCHAR(200), -- 단위그룹명
    uom_code VARCHAR(20) NOT NULL, -- 단위코드
    uom_code_name VARCHAR(200), -- 단위코드명
    use_indicator BOOLEAN, -- 사용여부
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_uom_group PRIMARY KEY (enterprise_id, uom_group_id, uom_code)
);

CREATE TABLE ksx.item_master ( -- 품목마스터 (표 21)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    item_id VARCHAR(50) NOT NULL, -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    item_type VARCHAR(30), -- 품목유형
    phantom_indicator BOOLEAN, -- 가상품목여부
    item_large_class VARCHAR(30), -- 품목대분류
    item_medium_class VARCHAR(30), -- 품목중분류
    item_small_class VARCHAR(30), -- 품목소분류
    model_name VARCHAR(200), -- 모델명
    item_specification VARCHAR(1000), -- 품목사양
    item_detail_specification VARCHAR(1000), -- 품목상세사양
    use_indicator BOOLEAN, -- 사용여부
    country_of_origin VARCHAR(255), -- 원산국가
    place_of_origin VARCHAR(255), -- 원산지역
    item_uom_code VARCHAR(20), -- 기준단위코드
    weight NUMERIC(18,6), -- 중량
    net_weight NUMERIC(18,6), -- 순중량
    weight_uom_code VARCHAR(20), -- 중량단위코드
    volume NUMERIC(18,6), -- 부피
    volume_uom_code VARCHAR(20), -- 부피단위코드
    length NUMERIC(18,6), -- 길이
    width NUMERIC(18,6), -- 너비
    height NUMERIC(18,6), -- 높이
    dimension_uom_code VARCHAR(20), -- 치수단위코드
    valid_end_date DATE, -- 유효종료일
    drawing_number VARCHAR(50), -- 도면번호
    lot_control_indicator BOOLEAN, -- 로트사용여부
    purchase_lead_time INTERVAL, -- 구매리드타임
    production_lead_time INTERVAL, -- 생산리드타임
    lot_size NUMERIC(18,6), -- 로트사이즈
    main_customer_id VARCHAR(50), -- 주요 고객사식별자
    main_vendor_id VARCHAR(50), -- 주요 공급사식별자
    safety_stock NUMERIC(18,6), -- 안전재고
    maximum_stock_level NUMERIC(18,6), -- 최대재고수준
    receipt_warehouse_id VARCHAR(50), -- 입고창고식별자
    issue_warehouse_id VARCHAR(50), -- 출고창고식별자
    abc_class VARCHAR(30), -- 에이비씨분류
    replacement_item_id VARCHAR(50), -- 대체품목식별자
    incoming_inspection_indicator BOOLEAN, -- 수입검사여부
    final_inspection_indicator BOOLEAN, -- 생산입고(최종)검사여부
    outgoing_inspection_indicator BOOLEAN, -- 출하검사여부
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_item_master PRIMARY KEY (enterprise_id, item_id)
);

CREATE TABLE ksx.bom ( -- 자재명세서 (표 22)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    bom_id VARCHAR(50) NOT NULL, -- 자재명세서식별자
    bom_type VARCHAR(30), -- 자재명세서유형
    item_id VARCHAR(50), -- 품목식별자
    bom_quantity NUMERIC(18,6), -- 품목기준수량
    item_uom_code VARCHAR(20), -- 기준단위코드
    child_item_id VARCHAR(50) NOT NULL, -- 자품목식별자
    child_item_uom_code VARCHAR(20), -- 자품목기준단위코드
    actual_requirement_quantity NUMERIC(18,6), -- 실소요수량
    bom_revision_number INTEGER NOT NULL, -- 자재명세서버전
    valid_start_date_time TIMESTAMP, -- 유효시작일시
    valid_end_date_time TIMESTAMP, -- 유효종료일시
    routing_id VARCHAR(50), -- 공정경로식별자
    operation_sequence INTEGER, -- 공정순번
    back_flushed_indicator BOOLEAN, -- 백플러시여부
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_bom PRIMARY KEY (enterprise_id, bom_id, bom_revision_number, child_item_id)
);

CREATE TABLE ksx.bom_header ( -- 자재명세서헤더 (표 —)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    bom_id VARCHAR(50) NOT NULL, -- 자재명세서식별자
    bom_revision_number INTEGER NOT NULL, -- 자재명세서버전
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_bom_header PRIMARY KEY (enterprise_id, bom_id, bom_revision_number)
);

CREATE TABLE ksx.lot ( -- 로트 (표 23)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    lot_id VARCHAR(50) NOT NULL, -- 로트식별자
    lot_name VARCHAR(200), -- 로트명
    lot_description VARCHAR(1000), -- 로트설명
    parent_lot_id VARCHAR(50), -- 모로트식별자
    child_lot_id VARCHAR(50), -- 자로트식별자
    lot_type VARCHAR(30), -- 로트유형
    item_id VARCHAR(50), -- 품목식별자
    carrier_id VARCHAR(50), -- 캐리어식별자
    production_order_id VARCHAR(50), -- 생산지시식별자
    production_order_sequence INTEGER, -- 생산지시순번
    scheduled_due_date DATE, -- 생산마감기한
    lot_priority INTEGER, -- 로트우선순위
    current_operation_id VARCHAR(50), -- 현재공정식별자
    next_operation_id VARCHAR(50), -- 다음공정식별자
    lot_state VARCHAR(30), -- 로트상태
    hold_indicator BOOLEAN, -- 보류여부
    hot_indicator BOOLEAN, -- 긴급여부
    rework_indicator BOOLEAN, -- 재작업여부
    lot_created_quantity NUMERIC(18,6), -- 로트수량
    produced_quantity NUMERIC(18,6), -- 생산수량
    defect_quantity NUMERIC(18,6), -- 불량수량
    rework_quantity INTEGER, -- 재작업수량
    rework_count INTEGER, -- 재작업횟수
    total_rework_count INTEGER, -- 총재작업횟수
    lot_started_date_time TIMESTAMP, -- 공정투입일시
    personnel_id VARCHAR(50), -- 사원식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_lot PRIMARY KEY (enterprise_id, lot_id)
);

CREATE TABLE ksx.routing ( -- 공정경로 (표 24)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    routing_id VARCHAR(50) NOT NULL, -- 공정경로식별자
    routing_name VARCHAR(200), -- 공정경로명
    item_id VARCHAR(50), -- 품목식별자
    operation_id VARCHAR(50), -- 공정식별자
    operation_sequence INTEGER NOT NULL, -- 공정순번
    last_operation_indicator BOOLEAN, -- 최종공정여부
    use_indicator BOOLEAN, -- 사용여부
    setup_time INTERVAL, -- 준비시간
    run_time INTERVAL, -- 작업시간
    move_time INTERVAL, -- 이동시간
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_routing PRIMARY KEY (enterprise_id, routing_id, operation_sequence)
);

CREATE TABLE ksx.routing_header ( -- 공정경로헤더 (표 —)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    routing_id VARCHAR(50) NOT NULL, -- 공정경로식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_routing_header PRIMARY KEY (enterprise_id, routing_id)
);

CREATE TABLE ksx.operation ( -- 공정 (표 25)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    operation_id VARCHAR(50) NOT NULL, -- 공정식별자
    operation_name VARCHAR(200), -- 공정명
    operation_type VARCHAR(30), -- 공정유형
    use_indicator BOOLEAN, -- 사용여부
    operation_large_class VARCHAR(30), -- 공정대분류
    operation_medium_class VARCHAR(30), -- 공정중분류
    operation_small_class VARCHAR(30), -- 공정소분류
    back_flushed_indicator BOOLEAN, -- 백플러시여부
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_operation PRIMARY KEY (enterprise_id, operation_id)
);

CREATE TABLE ksx.equipment ( -- 설비 (표 26)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    equipment_id VARCHAR(50) NOT NULL, -- 설비식별자
    equipment_name VARCHAR(200), -- 설비명
    parent_equipment_id VARCHAR(50), -- 상위설비식별자
    equipment_type VARCHAR(30), -- 설비유형
    equipment_large_class VARCHAR(30), -- 설비대분류
    equipment_medium_class VARCHAR(30), -- 설비중분류
    equipment_small_class VARCHAR(30), -- 설비소분류
    department_in_charge_id VARCHAR(50), -- 관리부서식별자
    person_in_charge_id VARCHAR(50), -- 관리자식별자
    operation_id VARCHAR(50), -- 공정식별자
    use_indicator BOOLEAN, -- 사용여부
    daq_device VARCHAR(255), -- 데이터수집장치
    fixed_asset_id VARCHAR(50), -- 고정자산식별자
    model_number VARCHAR(50), -- 모델번호
    serial_number VARCHAR(50), -- 일련번호
    country_of_origin VARCHAR(255), -- 제조국가
    manufacturer VARCHAR(255), -- 제조업체
    acquisition_date DATE, -- 취득일
    location VARCHAR(1000), -- 위치
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_equipment PRIMARY KEY (enterprise_id, equipment_id)
);

CREATE TABLE ksx.operation_equipment ( -- 공정설비 (표 27)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    operation_id VARCHAR(50) NOT NULL, -- 공정식별자
    operation_name VARCHAR(200), -- 공정명
    equipment_id VARCHAR(50) NOT NULL, -- 설비식별자
    equipment_name VARCHAR(200), -- 설비명
    equipment_small_class VARCHAR(30), -- 설비소분류
    equipment_quantity INTEGER, -- 기준사용대수
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_operation_equipment PRIMARY KEY (enterprise_id, operation_id, equipment_id)
);

CREATE TABLE ksx.carrier ( -- 캐리어 (표 28)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    carrier_id VARCHAR(50) NOT NULL, -- 캐리어식별자
    carrier_type VARCHAR(30), -- 캐리어유형
    item_type VARCHAR(30), -- 품목유형
    load_state VARCHAR(30), -- 적재상태
    carrier_state VARCHAR(30), -- 캐리어상태
    current_quantity NUMERIC(18,6), -- 적재수량
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_carrier PRIMARY KEY (enterprise_id, carrier_id)
);

CREATE TABLE ksx.stocker_inventory ( -- 저장소재공정보 (표 29)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    stocker_id VARCHAR(50) NOT NULL, -- 저장소식별자
    zone_id VARCHAR(50), -- 구역식별자
    full_capacity INTEGER, -- 최대용량
    current_capacity INTEGER, -- 현재용량
    lot_id VARCHAR(50), -- 로트식별자
    carrier_id VARCHAR(50), -- 캐리어식별자
    alternate_stocker_id VARCHAR(50), -- 대체저장소식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_stocker_inventory PRIMARY KEY (enterprise_id, stocker_id)
);

CREATE TABLE ksx.warehouse_location ( -- 창고 (표 30)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    warehouse_id VARCHAR(50) NOT NULL, -- 창고식별자
    warehouse_name VARCHAR(200), -- 창고명
    warehouse_type VARCHAR(30), -- 창고유형
    use_indicator BOOLEAN, -- 사용여부
    negative_inventory_indicator BOOLEAN, -- 음수재고허용여부
    warehouse_section_list VARCHAR(1000), -- 창고섹션목록
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_warehouse_location PRIMARY KEY (enterprise_id, warehouse_id)
);

CREATE TABLE ksx.batch ( -- 배치 (표 31)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    batch_id VARCHAR(50) NOT NULL, -- 배치식별자
    batch_name VARCHAR(200), -- 배치명
    batch_description VARCHAR(1000), -- 배치설명
    batch_type VARCHAR(30), -- 배치유형
    parent_batch_id VARCHAR(50), -- 모배치식별자
    item_id VARCHAR(50), -- 품목식별자
    lot_id VARCHAR(50), -- 로트식별자
    production_order_id VARCHAR(50), -- 생산지시식별자
    production_order_sequence INTEGER, -- 생산지시순번
    bom_id VARCHAR(50), -- 자재명세서식별자
    bom_revision_number INTEGER, -- 자재명세서버전
    recipe_id VARCHAR(50), -- 레시피식별자
    recipe_version VARCHAR(255), -- 레시피버전
    operation_id VARCHAR(50), -- 공정식별자
    equipment_id VARCHAR(50), -- 설비식별자
    batch_state VARCHAR(30), -- 배치상태
    hold_indicator BOOLEAN, -- 보류여부
    rework_indicator BOOLEAN, -- 재작업여부
    quality_disposition_code VARCHAR(30), -- 품질판정코드
    batch_planned_quantity NUMERIC(18,6), -- 배치계획수량
    produced_quantity NUMERIC(18,6), -- 생산수량
    defect_quantity NUMERIC(18,6), -- 불량수량
    item_uom_code VARCHAR(20), -- 기준단위코드
    schedule_start_date_time TIMESTAMP, -- 계획시작일시
    schedule_end_date_time TIMESTAMP, -- 계획종료일시
    batch_start_date_time TIMESTAMP, -- 배치시작일시
    batch_end_date_time TIMESTAMP, -- 배치종료일시
    manufacture_date DATE, -- 제조일
    valid_end_date DATE, -- 유효종료일
    personnel_id VARCHAR(50), -- 사원식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_batch PRIMARY KEY (enterprise_id, batch_id)
);

CREATE TABLE ksx.line ( -- 라인 (표 32)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    line_id VARCHAR(50) NOT NULL, -- 라인식별자
    line_name VARCHAR(200), -- 라인명
    line_description VARCHAR(1000), -- 라인설명
    line_type VARCHAR(30), -- 라인유형
    production_method_type VARCHAR(30), -- 생산방식유형
    parent_line_id VARCHAR(50), -- 상위라인식별자
    department_in_charge_id VARCHAR(50), -- 관리부서식별자
    person_in_charge_id VARCHAR(50), -- 관리자식별자
    calendar_id VARCHAR(50), -- 달력식별자
    issue_warehouse_id VARCHAR(50), -- 출고창고식별자
    receipt_warehouse_id VARCHAR(50), -- 입고창고식별자
    standard_capacity NUMERIC(18,6), -- 표준생산능력
    capacity_uom_code VARCHAR(20), -- 생산능력단위코드
    standard_cycle_time INTERVAL, -- 표준사이클타임
    shift_count INTEGER, -- 작업조수
    standard_headcount INTEGER, -- 표준작업인원
    location VARCHAR(1000), -- 위치
    use_indicator BOOLEAN, -- 사용여부
    valid_start_date DATE, -- 유효시작일
    valid_end_date DATE, -- 유효종료일
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_line PRIMARY KEY (enterprise_id, line_id)
);

CREATE TABLE ksx.enterprise ( -- 회사 (표 33)
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    enterprise_name VARCHAR(200), -- 회사명
    business_registration_number VARCHAR(50), -- 사업자등록번호
    corporate_registration_number VARCHAR(50), -- 법인등록번호
    representative_name VARCHAR(200), -- 대표자명
    parent_enterprise_id VARCHAR(50), -- 상위회사식별자
    country_id VARCHAR(30), -- 국가식별자
    base_currency_code VARCHAR(30), -- 기준통화코드
    dial_number VARCHAR(30), -- 전화번호
    fax_number VARCHAR(30), -- 팩스번호
    postal_code VARCHAR(10), -- 우편번호
    base_address VARCHAR(1000), -- 기본주소
    detail_address VARCHAR(1000), -- 상세주소
    use_indicator BOOLEAN, -- 사용여부
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_enterprise PRIMARY KEY (enterprise_id)
);

CREATE TABLE ksx.project_master ( -- 프로젝트마스터 (표 34)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    project_id VARCHAR(50) NOT NULL, -- 프로젝트식별자
    project_name VARCHAR(200), -- 프로젝트명
    project_status_code VARCHAR(30), -- 프로젝트상태코드
    responsible_department_id VARCHAR(50), -- 프로젝트담당부서식별자
    person_in_charge_id VARCHAR(50), -- 프로젝트담당자식별자
    project_contract_date DATE, -- 프로젝트계약일
    expected_start_date DATE, -- 시작예정일
    expected_end_date DATE, -- 종료예정일
    actual_start_date DATE, -- 실제시작일
    actual_end_date DATE, -- 실제종료일
    sales_document_number VARCHAR(50), -- 수주문서번호
    sales_document_sequence INTEGER, -- 수주문서순번
    item_id VARCHAR(50), -- 품목식별자
    use_indicator BOOLEAN, -- 사용여부
    division_id VARCHAR(50), -- 사업부식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_project_master PRIMARY KEY (enterprise_id, project_id)
);

CREATE TABLE ksx.engineering_change_order ( -- 설계변경지시 (표 35)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    engineering_change_order_id VARCHAR(50) NOT NULL, -- 설계변경지시식별자
    item_id VARCHAR(50), -- 품목식별자
    valid_start_date DATE, -- 유효시작일
    valid_end_date DATE, -- 유효종료일
    expected_execution_date DATE, -- 적용예정일
    execution_date DATE, -- 적용이행일
    bom_type VARCHAR(30), -- 자재명세서유형
    bom_id VARCHAR(50), -- 자재명세서식별자
    bom_revision_number INTEGER, -- 자재명세서버전
    child_item_id VARCHAR(50), -- 자품목식별자
    item_uom_code VARCHAR(20), -- 기준단위코드
    actual_requirement_quantity NUMERIC(18,6), -- 실소요수량
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_engineering_change_order PRIMARY KEY (enterprise_id, engineering_change_order_id)
);

CREATE TABLE ksx.sales_order ( -- 수주오더 (표 36)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    sales_order_id VARCHAR(50) NOT NULL, -- 수주오더식별자
    sales_document_number VARCHAR(50), -- 수주문서번호
    sales_document_sequence INTEGER, -- 수주문서순번
    sales_order_type VARCHAR(30), -- 수주유형
    customer_id VARCHAR(50), -- 고객사식별자
    sales_date DATE, -- 수주일
    requested_delivery_date DATE, -- 요청납기일
    sales_status VARCHAR(30), -- 수주상태
    shipment_terms_code VARCHAR(30), -- 출하조건코드
    sales_transaction_type VARCHAR(30), -- 거래유형
    return_indicator BOOLEAN, -- 반품여부
    export_indicator BOOLEAN, -- 수출여부
    sales_automatic_approval_indicator BOOLEAN, -- 수주자동승인여부
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    item_quantity NUMERIC(18,6), -- 품목수량
    item_uom_code VARCHAR(20), -- 기준단위코드
    selling_uom_code VARCHAR(20), -- 판매단위코드
    conversion_unit_quantity NUMERIC(18,6), -- 단위환산수량
    item_unit_quantity NUMERIC(18,6), -- 기준단위수량
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT uk_sales_order_doc UNIQUE (enterprise_id, sales_document_number, sales_document_sequence),
    CONSTRAINT pk_sales_order PRIMARY KEY (enterprise_id, sales_order_id)
);

CREATE TABLE ksx.sales_plan ( -- 판매계획 (표 37)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    sales_plan_id VARCHAR(50) NOT NULL, -- 판매계획식별자
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    sales_projection NUMERIC(18,6), -- 판매추정치
    projection_start_date DATE, -- 예측시작일
    projection_end_date DATE, -- 예측종료일
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_sales_plan PRIMARY KEY (enterprise_id, sales_plan_id)
);

CREATE TABLE ksx.base_price ( -- 기준가격 (표 38)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    item_id VARCHAR(50) NOT NULL, -- 품목식별자
    currency_code VARCHAR(30) NOT NULL, -- 환종코드
    unit_price NUMERIC(18,6), -- 단가
    payment_terms_code VARCHAR(30), -- 결제조건코드
    use_indicator BOOLEAN, -- 사용여부
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_base_price PRIMARY KEY (enterprise_id, item_id, currency_code)
);

CREATE TABLE ksx.purchase_requisition ( -- 구매요청 (표 39)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    purchase_requisition_id VARCHAR(50) NOT NULL, -- 구매요청식별자
    purchase_requisition_revision_number INTEGER, -- 구매요청버전
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    demand_quantity NUMERIC(18,6), -- 구매요청수량
    item_uom_code VARCHAR(20), -- 기준단위코드
    purchase_requisition_unit_price NUMERIC(18,6), -- 구매요청단가
    currency_code VARCHAR(30), -- 환종코드
    vendor_id VARCHAR(50), -- 공급사식별자
    vendor_name VARCHAR(200), -- 공급사명
    requested_delivery_date DATE, -- 요청납기일
    requester_department_id VARCHAR(50), -- 구매요청부서
    requester_personnel_id VARCHAR(50), -- 구매요청자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_purchase_requisition PRIMARY KEY (enterprise_id, purchase_requisition_id)
);

CREATE TABLE ksx.purchase_order ( -- 구매발주 (표 40)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    purchase_order_id VARCHAR(50) NOT NULL, -- 구매발주식별자
    purchase_document_number VARCHAR(50), -- 구매문서번호
    vendor_id VARCHAR(50), -- 공급사식별자
    payment_terms_code VARCHAR(30), -- 결제조건코드
    purchase_group_code VARCHAR(30), -- 구매그룹코드
    currency_code VARCHAR(30), -- 환종코드
    exchange_rate NUMERIC(18,6), -- 환율
    purchase_approval_date DATE, -- 승인일
    purchase_order_date DATE, -- 구매발주일
    purchase_order_type_code VARCHAR(30), -- 발주유형코드
    purchase_transaction_type VARCHAR(30), -- 거래유형
    purchase_order_start_date DATE, -- 시작일
    purchase_order_valid_date DATE, -- 유효일
    personnel_id VARCHAR(50), -- 사원식별자
    purchase_order_closing_indicator BOOLEAN, -- 발주마감여부
    purchase_order_closing_date DATE, -- 발주마감일
    purchase_document_sequence INTEGER, -- 구매문서순번
    item_purchase_type VARCHAR(30), -- 구매라인유형
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    purchase_order_line_status_code VARCHAR(30), -- 발주라인상태코드
    tax_code VARCHAR(30), -- 세무코드
    item_uom_code VARCHAR(20), -- 기준단위코드
    purchase_order_uom_code VARCHAR(20), -- 발주단위코드
    conversion_unit_quantity NUMERIC(18,6), -- 단위환산수량
    item_unit_quantity NUMERIC(18,6), -- 기준단위수량
    purchase_order_quantity NUMERIC(18,6), -- 구매발주수량
    purchase_goods_receipt_quantity NUMERIC(18,6), -- 구매입고수량
    purchase_transaction_unit_price NUMERIC(18,6), -- 구매거래단가
    purchase_transaction_price NUMERIC(18,6), -- 구매거래금액
    purchase_order_unit_price NUMERIC(18,6), -- 발주단가
    purchase_order_price NUMERIC(18,6), -- 발주금액
    vat_price NUMERIC(18,6), -- 부가세금액
    expected_delivery_date DATE, -- 납기예정일
    incoming_inspection_indicator BOOLEAN, -- 수입검사여부
    account_code VARCHAR(30), -- 계정코드
    vat_transaction_unit_price NUMERIC(18,6), -- 부가세포함거래단가
    vat_transaction_price NUMERIC(18,6), -- 부가세포함거래금액
    vat_carrying_amount NUMERIC(18,6), -- 부가세포함장부금액
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT uk_purchase_order_doc UNIQUE (enterprise_id, purchase_document_number, purchase_document_sequence),
    CONSTRAINT pk_purchase_order PRIMARY KEY (enterprise_id, purchase_order_id)
);

CREATE TABLE ksx.material_arrival ( -- 자재도착 (표 41)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    purchase_document_number VARCHAR(50) NOT NULL, -- 구매문서번호
    purchase_document_sequence INTEGER NOT NULL, -- 구매문서순번
    item_id VARCHAR(50), -- 품목식별자
    purchase_goods_receipt_quantity NUMERIC(18,6), -- 구매입고수량
    receipt_warehouse_id VARCHAR(50), -- 입고창고식별자
    goods_receipt_date DATE, -- 입고처리일
    lot_id VARCHAR(50) NOT NULL, -- 로트식별자
    item_quantity NUMERIC(18,6), -- 품목수량
    vendor_id VARCHAR(50), -- 공급사식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_material_arrival PRIMARY KEY (enterprise_id, purchase_document_number, purchase_document_sequence, lot_id)
);

CREATE TABLE ksx.goods_receipt ( -- 입고 (표 42)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    goods_receipt_id VARCHAR(50) NOT NULL, -- 입고식별자
    warehouse_id VARCHAR(50), -- 창고식별자
    personnel_id VARCHAR(50), -- 사원식별자
    goods_receipt_sequence INTEGER NOT NULL, -- 입고순번
    goods_receipt_type VARCHAR(30), -- 입고처리유형
    goods_receipt_return_type VARCHAR(30), -- 입고반품유형
    goods_receipt_date DATE, -- 입고처리일
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    inventory_transaction_document_number VARCHAR(50), -- 수불문서번호
    inventory_transaction_document_sequence INTEGER, -- 수불문서순번
    inventory_transaction_type_code VARCHAR(30), -- 수불유형코드
    invoice_number VARCHAR(50), -- 송장번호
    invoice_sequence INTEGER, -- 송장라인순번
    invoice_processing_indicator BOOLEAN, -- 송장처리여부
    incoming_inspection_indicator BOOLEAN, -- 수입검사여부
    vendor_id VARCHAR(50), -- 공급사식별자
    purchase_order_uom_code VARCHAR(20), -- 발주단위코드
    item_unit_quantity NUMERIC(18,6), -- 기준단위수량
    goods_receipt_quantity NUMERIC(18,6), -- 입고처리수량
    incoming_inspection_accepted_quantity NUMERIC(18,6), -- 수입검사합격수량
    incoming_inspection_rejected_quantity NUMERIC(18,6), -- 수입검사불합격수량
    purchase_group_code VARCHAR(30), -- 구매그룹코드
    item_uom_code VARCHAR(20), -- 기준단위코드
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_goods_receipt PRIMARY KEY (enterprise_id, goods_receipt_id, goods_receipt_sequence)
);

CREATE TABLE ksx.goods_issue ( -- 자재불출 (표 43)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    goods_issue_id VARCHAR(50) NOT NULL, -- 자재불출식별자
    inventory_transaction_document_number VARCHAR(50), -- 수불문서번호
    inventory_transaction_document_sequence INTEGER, -- 수불문서순번
    item_id VARCHAR(50), -- 품목식별자
    inventory_transaction_type_code VARCHAR(30), -- 수불유형코드
    inventory_transfer_type VARCHAR(30), -- 입출고유형
    inventory_variation_type VARCHAR(30), -- 재고증감유형
    inventory_transaction_type VARCHAR(30), -- 수불유형
    lot_id VARCHAR(50), -- 로트식별자
    serial_use_indicator BOOLEAN, -- 시리얼사용여부
    vendor_id VARCHAR(50), -- 공급사식별자
    warehouse_id VARCHAR(50), -- 창고식별자
    item_uom_code VARCHAR(20), -- 기준단위코드
    item_unit_quantity NUMERIC(18,6), -- 기준단위수량
    order_uom_code VARCHAR(20), -- 오더단위코드
    order_quantity NUMERIC(18,6), -- 오더수량
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_goods_issue PRIMARY KEY (enterprise_id, goods_issue_id)
);

CREATE TABLE ksx.production_planning ( -- 생산계획 (표 44)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    production_plan_id VARCHAR(50) NOT NULL, -- 생산계획식별자
    item_id VARCHAR(50), -- 품목식별자
    production_plan_quantity INTEGER, -- 생산계획수량
    schedule_start_date_time TIMESTAMP, -- 생산계획시작일시
    schedule_end_date_time TIMESTAMP, -- 생산계획종료일시
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_production_planning PRIMARY KEY (enterprise_id, production_plan_id)
);

CREATE TABLE ksx.production_order ( -- 생산지시 (표 45)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    production_order_id VARCHAR(50) NOT NULL, -- 생산지시식별자
    production_order_sequence INTEGER NOT NULL, -- 생산지시순번
    item_id VARCHAR(50), -- 품목식별자
    line_id VARCHAR(50), -- 라인식별자
    routing_id VARCHAR(50), -- 공정경로식별자
    bom_id VARCHAR(50), -- 자재명세서식별자
    bom_revision_number INTEGER, -- 자재명세서버전
    item_uom_code VARCHAR(20), -- 기준단위코드
    production_order_quantity INTEGER, -- 생산지시수량
    production_due_date_time TIMESTAMP, -- 생산완료기한일시
    schedule_start_date_time TIMESTAMP, -- 생산계획시작일시
    schedule_end_date_time TIMESTAMP, -- 생산계획종료일시
    sales_document_number VARCHAR(50), -- 수주문서번호
    sales_document_sequence INTEGER, -- 수주문서순번
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_production_order PRIMARY KEY (enterprise_id, production_order_id, production_order_sequence)
);

CREATE TABLE ksx.operation_start ( -- 착공 (표 46)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    lot_id VARCHAR(50) NOT NULL, -- 로트식별자
    lot_name VARCHAR(200), -- 로트명
    lot_description VARCHAR(1000), -- 로트설명
    lot_created_quantity NUMERIC(18,6), -- 로트수량
    operation_id VARCHAR(50) NOT NULL, -- 공정식별자
    equipment_id VARCHAR(50), -- 설비식별자
    operation_start_time TIMESTAMP NOT NULL, -- 착공시간
    personnel_id VARCHAR(50), -- 사원식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_operation_start PRIMARY KEY (enterprise_id, lot_id, operation_id, operation_start_time)
) PARTITION BY RANGE (operation_start_time);
CREATE TABLE ksx.operation_start_default PARTITION OF ksx.operation_start DEFAULT;
SELECT gov.ensure_partitions('ksx.operation_start', 'month', 3);
CREATE INDEX ix_operation_start_plant_time ON ksx.operation_start (enterprise_id, plant_id, operation_start_time);

CREATE TABLE ksx.operation_end ( -- 완공 (표 47)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    lot_id VARCHAR(50) NOT NULL, -- 로트식별자
    lot_name VARCHAR(200), -- 로트명
    lot_description VARCHAR(1000), -- 로트설명
    lot_created_quantity NUMERIC(18,6), -- 로트수량
    operation_id VARCHAR(50) NOT NULL, -- 공정식별자
    equipment_id VARCHAR(50), -- 설비식별자
    operation_end_time TIMESTAMP NOT NULL, -- 완공시간
    personnel_id VARCHAR(50), -- 사원식별자
    produced_quantity NUMERIC(18,6), -- 생산수량
    defect_quantity NUMERIC(18,6), -- 불량수량
    rework_count INTEGER, -- 재작업횟수
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_operation_end PRIMARY KEY (enterprise_id, lot_id, operation_id, operation_end_time)
) PARTITION BY RANGE (operation_end_time);
CREATE TABLE ksx.operation_end_default PARTITION OF ksx.operation_end DEFAULT;
SELECT gov.ensure_partitions('ksx.operation_end', 'month', 3);
CREATE INDEX ix_operation_end_plant_time ON ksx.operation_end (enterprise_id, plant_id, operation_end_time);

CREATE TABLE ksx.transfer_command ( -- 이동지시 (표 48)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    transfer_command_id VARCHAR(50) NOT NULL, -- 이동지시식별자
    lot_id VARCHAR(50), -- 로트식별자
    lot_name VARCHAR(200), -- 로트명
    lot_description VARCHAR(1000), -- 로트설명
    carrier_id VARCHAR(50), -- 캐리어식별자
    source_id VARCHAR(50), -- 출발지식별자
    source_type VARCHAR(30), -- 출발지유형
    source_name VARCHAR(200), -- 출발지명
    destination_id VARCHAR(50), -- 목적지식별자
    destination_type VARCHAR(30), -- 목적지유형
    destination_name VARCHAR(200), -- 목적지명
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_transfer_command PRIMARY KEY (enterprise_id, transfer_command_id)
);

CREATE TABLE ksx.transfer_start ( -- 운행시작 (표 49)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    transfer_command_id VARCHAR(50) NOT NULL, -- 이동지시식별자
    lot_id VARCHAR(50), -- 로트식별자
    lot_name VARCHAR(200), -- 로트명
    lot_description VARCHAR(1000), -- 로트설명
    carrier_id VARCHAR(50), -- 캐리어식별자
    transfer_start_date_time TIMESTAMP, -- 운행시작일시
    current_location VARCHAR(1000), -- 현재위치
    destination_id VARCHAR(50), -- 목적지식별자
    destination_type VARCHAR(30), -- 목적지유형
    destination_name VARCHAR(200), -- 목적지명
    error_code VARCHAR(30), -- 오류코드
    error_message VARCHAR(1000), -- 오류메세지
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_transfer_start PRIMARY KEY (enterprise_id, transfer_command_id)
);

CREATE TABLE ksx.transfer_end ( -- 운행완료 (표 50)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    transfer_command_id VARCHAR(50) NOT NULL, -- 이동지시식별자
    lot_id VARCHAR(50), -- 로트식별자
    lot_name VARCHAR(200), -- 로트명
    lot_description VARCHAR(1000), -- 로트설명
    carrier_id VARCHAR(50), -- 캐리어식별자
    transfer_end_date_time TIMESTAMP, -- 운행완료일시
    destination_id VARCHAR(50), -- 목적지식별자
    destination_type VARCHAR(30), -- 목적지유형
    destination_name VARCHAR(200), -- 목적지명
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_transfer_end PRIMARY KEY (enterprise_id, transfer_command_id)
);

CREATE TABLE ksx.in_transit_location ( -- 운송위치 (표 51)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    transfer_command_id VARCHAR(50) NOT NULL, -- 이동지시식별자
    lot_id VARCHAR(50), -- 로트식별자
    lot_name VARCHAR(200), -- 로트명
    lot_description VARCHAR(1000), -- 로트설명
    carrier_id VARCHAR(50), -- 캐리어식별자
    current_location VARCHAR(1000) NOT NULL, -- 현재위치
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_in_transit_location PRIMARY KEY (enterprise_id, transfer_command_id, current_location)
);

CREATE TABLE ksx.equipment_state ( -- 설비상태 (표 52)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    equipment_id VARCHAR(50) NOT NULL, -- 설비식별자
    equipment_state VARCHAR(30), -- 설비상태
    equipment_control_mode VARCHAR(30), -- 설비제어모드
    equipment_operation_mode VARCHAR(30), -- 설비운영모드
    processed_lot_quantity NUMERIC(18,6), -- 진행로트수량
    last_processed_lot_id VARCHAR(50), -- 최종진행로트식별자
    last_processed_operation_id VARCHAR(50), -- 최종진행공정식별자
    error_code VARCHAR(30), -- 오류코드
    error_message VARCHAR(1000), -- 오류메세지
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_equipment_state PRIMARY KEY (enterprise_id, equipment_id)
);

CREATE TABLE ksx.alarm ( -- 알람 (표 53)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    equipment_id VARCHAR(50) NOT NULL, -- 설비식별자
    alarm_state VARCHAR(30), -- 알람상태
    error_code VARCHAR(30) NOT NULL, -- 오류코드
    error_message VARCHAR(1000), -- 오류메세지
    event_date_time TIMESTAMP NOT NULL, -- 이벤트발생일시
    current_location VARCHAR(1000), -- 현재위치
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_alarm PRIMARY KEY (enterprise_id, equipment_id, event_date_time, error_code)
) PARTITION BY RANGE (event_date_time);
CREATE TABLE ksx.alarm_default PARTITION OF ksx.alarm DEFAULT;
SELECT gov.ensure_partitions('ksx.alarm', 'month', 3);
CREATE INDEX ix_alarm_plant_time ON ksx.alarm (enterprise_id, plant_id, event_date_time);

CREATE TABLE ksx.supplier_inspection_plan ( -- 협력업체품질검사계획 (표 54)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    vendor_id VARCHAR(50), -- 공급사식별자
    project_id VARCHAR(50), -- 프로젝트식별자
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    item_uom_code VARCHAR(20), -- 기준단위코드
    purchase_order_id VARCHAR(50), -- 구매발주식별자
    purchase_order_quantity NUMERIC(18,6), -- 구매발주수량
    lot_id VARCHAR(50), -- 로트식별자
    batch_id VARCHAR(50), -- 배치식별자
    expected_delivery_date DATE, -- 납기예정일
    inspection_plan_id VARCHAR(50) NOT NULL, -- 검사계획식별자
    inspection_id VARCHAR(50) NOT NULL, -- 검사식별자
    inspection_name VARCHAR(200), -- 검사명
    inspector VARCHAR(255), -- 검사자
    inspection_location VARCHAR(1000), -- 검사위치
    expected_inspection_date DATE, -- 검사예정일
    expected_inspection_time_period INTEGER, -- 검사예정기간
    inspection_method VARCHAR(30), -- 검사방법
    inspection_plan_quantity NUMERIC(18,6), -- 검사계획수량
    inspection_check_sheet VARCHAR(1000), -- 검사체크시트
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_supplier_inspection_plan PRIMARY KEY (enterprise_id, inspection_plan_id, inspection_id)
);

CREATE TABLE ksx.supplier_inspection_application ( -- 협력업체품질검사신청 (표 55)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    vendor_id VARCHAR(50), -- 공급사식별자
    project_id VARCHAR(50), -- 프로젝트식별자
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    item_uom_code VARCHAR(20), -- 기준단위코드
    purchase_order_id VARCHAR(50), -- 구매발주식별자
    lot_id VARCHAR(50), -- 로트식별자
    batch_id VARCHAR(50), -- 배치식별자
    inspection_plan_id VARCHAR(50), -- 검사계획식별자
    inspection_id VARCHAR(50), -- 검사식별자
    inspection_application_id VARCHAR(50) NOT NULL, -- 검사신청식별자
    application_personnel_id VARCHAR(50), -- 검사신청자
    inspection_name VARCHAR(200), -- 검사명
    inspection_location VARCHAR(1000), -- 검사위치
    inspection_method VARCHAR(30), -- 검사방법
    expected_inspection_date DATE, -- 검사예정일
    inspection_date DATE, -- 검사일
    inspection_time_period INTEGER, -- 검사기간
    inspection_quantity NUMERIC(18,6), -- 검사수량
    self_check_inspection_result_sheet VARCHAR(1000), -- 자체점검결과시트
    inspection_status_code VARCHAR(30), -- 검사상태코드
    reason_for_application VARCHAR(255), -- 검사신청사유
    inspection_cancel_reason VARCHAR(1000), -- 검사취소사유
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_supplier_inspection_application PRIMARY KEY (enterprise_id, inspection_application_id)
);

CREATE TABLE ksx.supplier_inspection_result ( -- 협력업체품질검사결과 (표 56)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    vendor_id VARCHAR(50), -- 공급사식별자
    project_id VARCHAR(50), -- 프로젝트식별자
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    lot_id VARCHAR(50), -- 로트식별자
    batch_id VARCHAR(50), -- 배치식별자
    inspection_plan_id VARCHAR(50), -- 검사계획식별자
    inspection_id VARCHAR(50), -- 검사식별자
    inspection_application_id VARCHAR(50), -- 검사신청식별자
    inspection_result_id VARCHAR(50) NOT NULL, -- 검사결과식별자
    inspector VARCHAR(255), -- 검사자
    inspection_participant VARCHAR(1000), -- 검사입회자
    inspection_location VARCHAR(1000), -- 검사위치
    inspection_date DATE, -- 검사일
    inspection_quantity NUMERIC(18,6), -- 검사수량
    inspection_result VARCHAR(30), -- 검사결과
    inspection_result_sheet VARCHAR(1000), -- 검사결과시트
    inspection_status_code VARCHAR(30), -- 검사상태코드
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_supplier_inspection_result PRIMARY KEY (enterprise_id, inspection_result_id)
);

CREATE TABLE ksx.corrective_action_request ( -- 시정조치요청 (표 57)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    vendor_id VARCHAR(50), -- 공급사식별자
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    lot_id VARCHAR(50), -- 로트식별자
    batch_id VARCHAR(50), -- 배치식별자
    inspection_application_id VARCHAR(50), -- 검사신청식별자
    corrective_action_request_id VARCHAR(50) NOT NULL, -- 시정조치요청식별자
    corrective_action_request_issuer_id VARCHAR(50), -- 시정조치요청발행자식별자
    corrective_action_request_recipient_id VARCHAR(50), -- 시정조치요청접수자식별자
    corrective_action_request_location VARCHAR(1000), -- 시정조치요청위치
    corrective_action_request_document_reference VARCHAR(255), -- 시정조치요청첨부자료
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_corrective_action_request PRIMARY KEY (enterprise_id, corrective_action_request_id)
);

CREATE TABLE ksx.corrective_action_plan ( -- 시정조치계획 (표 58)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    vendor_id VARCHAR(50), -- 공급사식별자
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    lot_id VARCHAR(50), -- 로트식별자
    batch_id VARCHAR(50), -- 배치식별자
    corrective_action_request_id VARCHAR(50), -- 시정조치요청식별자
    corrective_action_plan_id VARCHAR(50) NOT NULL, -- 시정조치계획식별자
    person_in_charge_id VARCHAR(50), -- 시정조치담당자식별자
    person_in_charge_email VARCHAR(255), -- 시정조치담당자이메일명
    person_in_charge_dial_number VARCHAR(30), -- 시정조치담당자전화번호
    expected_corrective_action_date DATE, -- 시정조치예정일
    corrective_action_request_document_reference VARCHAR(255), -- 시정조치요청첨부자료
    corrective_action_approval_indicator BOOLEAN, -- 시정조치접수여부
    corrective_action_status_code VARCHAR(30), -- 시정조치상태코드
    reason_for_rejection VARCHAR(255), -- 반려사유
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_corrective_action_plan PRIMARY KEY (enterprise_id, corrective_action_plan_id)
);

CREATE TABLE ksx.corrective_action_result ( -- 시정조치결과 (표 59)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    vendor_id VARCHAR(50), -- 공급사식별자
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    lot_id VARCHAR(50), -- 로트식별자
    batch_id VARCHAR(50), -- 배치식별자
    corrective_action_request_id VARCHAR(50), -- 시정조치요청식별자
    corrective_action_plan_id VARCHAR(50), -- 시정조치계획식별자
    corrective_action_result_id VARCHAR(50) NOT NULL, -- 시정조치결과식별자
    person_in_charge_id VARCHAR(50), -- 시정조치담당자식별자
    person_in_charge_email VARCHAR(255), -- 시정조치담당자이메일명
    person_in_charge_dial_number VARCHAR(30), -- 시정조치담당자전화번호
    corrective_action_confirmor_id VARCHAR(50), -- 시정조치확인자식별자
    corrective_action_confirmor_email VARCHAR(255), -- 시정조치확인자이메일명
    corrective_action_confirmor_dial_number VARCHAR(30), -- 시정조치확인자전화번호
    corrective_action_date_time TIMESTAMP, -- 시정조치일시
    corrective_action_result_description VARCHAR(1000), -- 시정조치결과내용
    corrective_action_status_code VARCHAR(30), -- 시정조치상태코드
    reason_for_rejection VARCHAR(255), -- 반려사유
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_corrective_action_result PRIMARY KEY (enterprise_id, corrective_action_result_id)
);

CREATE TABLE ksx.product_packing ( -- 제품포장 (표 60)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    packing_type VARCHAR(30), -- 포장유형
    warehouse_id VARCHAR(50), -- 창고식별자
    serial_number VARCHAR(50), -- 일련번호
    box_number VARCHAR(50) NOT NULL, -- 포장박스번호
    pallet_number VARCHAR(50), -- 포장파렛트번호
    item_id VARCHAR(50), -- 품목식별자
    packing_sequence INTEGER NOT NULL, -- 포장순번
    lot_id VARCHAR(50), -- 로트식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_product_packing PRIMARY KEY (enterprise_id, box_number, packing_sequence)
);

CREATE TABLE ksx.equipment_parameter ( -- 설비파라미터 (표 61)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    parameter_id VARCHAR(50) NOT NULL, -- 파라미터식별자
    parameter_name VARCHAR(200), -- 파라미터명
    parameter_type VARCHAR(30), -- 파라미터유형
    parameter_grade VARCHAR(30), -- 파라미터등급
    parameter_uom_code VARCHAR(20), -- 파라미터단위코드
    equipment_id VARCHAR(50), -- 설비식별자
    lsl NUMERIC(18,6), -- 규격하한
    usl NUMERIC(18,6), -- 규격상한
    periodic_data_collection_indicator BOOLEAN, -- 주기적수집여부
    data_collection_period INTERVAL, -- 수집주기
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_equipment_parameter PRIMARY KEY (enterprise_id, parameter_id)
);

CREATE TABLE ksx.trace_parameter ( -- 설비파라미터이력 (표 62)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    equipment_id VARCHAR(50) NOT NULL, -- 설비식별자
    parameter_id VARCHAR(50) NOT NULL, -- 파라미터식별자
    event_date_time TIMESTAMP NOT NULL, -- 이벤트발생일시
    parameter_uom_code VARCHAR(20), -- 파라미터단위코드
    parameter_value NUMERIC(18,6), -- 파라미터값
    validation_result_code VARCHAR(30), -- 검증결과코드
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_trace_parameter PRIMARY KEY (enterprise_id, equipment_id, parameter_id, event_date_time)
) PARTITION BY RANGE (event_date_time);
CREATE TABLE ksx.trace_parameter_default PARTITION OF ksx.trace_parameter DEFAULT;
SELECT gov.ensure_partitions('ksx.trace_parameter', 'month', 3);
CREATE INDEX ix_trace_parameter_plant_time ON ksx.trace_parameter (enterprise_id, plant_id, event_date_time);

CREATE TABLE ksx.production_performance ( -- 생산실적 (표 63)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    production_performance_id VARCHAR(50) NOT NULL, -- 생산실적식별자
    production_performance_sequence INTEGER NOT NULL, -- 생산실적순번
    production_order_id VARCHAR(50), -- 생산지시식별자
    production_order_sequence INTEGER, -- 생산지시순번
    item_id VARCHAR(50), -- 품목식별자
    item_uom_code VARCHAR(20), -- 기준단위코드
    produced_quantity NUMERIC(18,6), -- 생산수량
    defect_quantity NUMERIC(18,6), -- 불량수량
    rework_quantity INTEGER, -- 재작업수량
    operation_id VARCHAR(50), -- 공정식별자
    routing_id VARCHAR(50), -- 공정경로식별자
    operation_sequence INTEGER, -- 공정순번
    personnel_id VARCHAR(50), -- 사원식별자
    production_performance_date DATE, -- 생산실적일자
    execution_start_date_time TIMESTAMP, -- 생산시작일시
    execution_end_date_time TIMESTAMP, -- 생산종료일시
    cancel_indicator BOOLEAN, -- 취소여부
    cancel_date_time TIMESTAMP, -- 취소일시
    lot_id VARCHAR(50), -- 로트식별자
    batch_id VARCHAR(50), -- 배치식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_production_performance PRIMARY KEY (enterprise_id, production_performance_id, production_performance_sequence)
);

CREATE TABLE ksx.production_performance_item ( -- 생산실적투입품목 (표 64)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    production_performance_id VARCHAR(50) NOT NULL, -- 생산실적식별자
    production_performance_sequence INTEGER NOT NULL, -- 생산실적순번
    production_order_id VARCHAR(50), -- 생산지시식별자
    production_order_sequence INTEGER, -- 생산지시순번
    item_id VARCHAR(50) NOT NULL, -- 품목식별자
    item_uom_code VARCHAR(20), -- 기준단위코드
    line_id VARCHAR(50), -- 라인식별자
    operation_id VARCHAR(50), -- 공정식별자
    lot_id VARCHAR(50), -- 로트식별자
    replacement_child_item_id VARCHAR(50), -- 대체자재식별자
    warehouse_id VARCHAR(50), -- 창고식별자
    warehouse_section VARCHAR(50), -- 창고섹션
    required_quantity INTEGER, -- 소요수량
    issued_quantity INTEGER, -- 출고수량
    issued_indicator BOOLEAN, -- 출고완료여부
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_production_performance_item PRIMARY KEY (enterprise_id, production_performance_id, production_performance_sequence, item_id)
);

CREATE TABLE ksx.production_performance_personnel ( -- 생산실적투입인력 (표 65)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    production_performance_id VARCHAR(50) NOT NULL, -- 생산실적식별자
    production_performance_sequence INTEGER NOT NULL, -- 생산실적순번
    production_order_id VARCHAR(50), -- 생산지시식별자
    production_order_sequence INTEGER, -- 생산지시순번
    operation_id VARCHAR(50), -- 공정식별자
    personnel_id VARCHAR(50) NOT NULL, -- 사원식별자
    execution_start_date_time TIMESTAMP, -- 생산시작일시
    execution_end_date_time TIMESTAMP, -- 생산종료일시
    task_group_code VARCHAR(30), -- 근무조코드
    actual_labor_date_time TIMESTAMP, -- 투입일시
    actual_labor_time INTERVAL, -- 투입시간
    actual_labor_time_uom_code VARCHAR(20), -- 투입시간단위코드
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_production_performance_personnel PRIMARY KEY (enterprise_id, production_performance_id, production_performance_sequence, personnel_id)
);

CREATE TABLE ksx.production_performance_equipment ( -- 설비활용실적 (표 66)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    production_performance_id VARCHAR(50) NOT NULL, -- 생산실적식별자
    production_performance_sequence INTEGER NOT NULL, -- 생산실적순번
    production_order_id VARCHAR(50), -- 생산지시식별자
    production_order_sequence INTEGER, -- 생산지시순번
    item_uom_code VARCHAR(20), -- 기준단위코드
    produced_quantity NUMERIC(18,6), -- 생산수량
    defect_quantity NUMERIC(18,6), -- 불량수량
    operation_id VARCHAR(50), -- 공정식별자
    routing_id VARCHAR(50), -- 공정경로식별자
    operation_sequence INTEGER, -- 공정순번
    personnel_id VARCHAR(50), -- 사원식별자
    execution_start_date_time TIMESTAMP, -- 생산시작일시
    execution_end_date_time TIMESTAMP, -- 생산종료일시
    cancel_indicator BOOLEAN, -- 취소여부
    cancel_date_time TIMESTAMP, -- 취소일시
    equipment_id VARCHAR(50) NOT NULL, -- 설비식별자
    setup_time INTERVAL, -- 준비시간
    run_time INTERVAL, -- 가동시간
    inspection_finished_indicator BOOLEAN, -- 공정검사여부
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_production_performance_equipment PRIMARY KEY (enterprise_id, production_performance_id, production_performance_sequence, equipment_id)
);

CREATE TABLE ksx.production_performance_quality ( -- 생산품질실적 (표 67)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    production_performance_id VARCHAR(50) NOT NULL, -- 생산실적식별자
    production_performance_sequence INTEGER NOT NULL, -- 생산실적순번
    production_order_id VARCHAR(50), -- 생산지시식별자
    production_order_sequence INTEGER, -- 생산지시순번
    item_id VARCHAR(50), -- 품목식별자
    item_uom_code VARCHAR(20), -- 기준단위코드
    operation_id VARCHAR(50), -- 공정식별자
    routing_id VARCHAR(50), -- 공정경로식별자
    operation_sequence INTEGER, -- 공정순번
    execution_start_date_time TIMESTAMP, -- 생산시작일시
    execution_end_date_time TIMESTAMP, -- 생산종료일시
    lot_id VARCHAR(50), -- 로트식별자
    batch_id VARCHAR(50), -- 배치식별자
    defect_type_quantity INTEGER, -- 불량유형별수량
    defect_type_code VARCHAR(30) NOT NULL, -- 불량유형코드
    defect_type_detail_code VARCHAR(30) NOT NULL, -- 불량유형상세코드
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_production_performance_quality PRIMARY KEY (enterprise_id, production_performance_id, production_performance_sequence, defect_type_code, defect_type_detail_code)
);

CREATE TABLE ksx.inventory ( -- 재고 (표 68)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    warehouse_id VARCHAR(50) NOT NULL, -- 창고식별자
    item_id VARCHAR(50) NOT NULL, -- 품목식별자
    inventory_quantity NUMERIC(18,6), -- 현재고수량
    item_uom_code VARCHAR(20), -- 기준단위코드
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_inventory PRIMARY KEY (enterprise_id, warehouse_id, item_id)
);

CREATE TABLE ksx.available_inventory ( -- 가용재고 (표 69)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    available_inventory_id VARCHAR(50) NOT NULL, -- 가용재고식별자
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    available_inventory_quantity NUMERIC(18,6), -- 가용재고량
    item_uom_code VARCHAR(20), -- 기준단위코드
    demand_priority NUMERIC(18,6), -- 요청우선순위
    prior_demand_quantity NUMERIC(18,6), -- 요청우선수량
    expected_delivery_date DATE, -- 납기예정일
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_available_inventory PRIMARY KEY (enterprise_id, available_inventory_id)
);

CREATE TABLE ksx.stock_transfer ( -- 재고이동 (표 70)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    stock_transfer_id VARCHAR(50) NOT NULL, -- 재고이동식별자
    inventory_transaction_document_number VARCHAR(50), -- 수불문서번호
    item_id VARCHAR(50), -- 품목식별자
    warehouse_id VARCHAR(50), -- 창고식별자
    receipt_warehouse_id VARCHAR(50), -- 입고창고식별자
    stock_transfer_quantity NUMERIC(18,6), -- 재고이동수량
    transfer_date_time TIMESTAMP, -- 이동일시
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_stock_transfer PRIMARY KEY (enterprise_id, stock_transfer_id)
);

CREATE TABLE ksx.inventory_count ( -- 재고실사 (표 71)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    inventory_count_document_number VARCHAR(50) NOT NULL, -- 재고실사문서번호
    inventory_count_date_time TIMESTAMP, -- 재고실사일시
    warehouse_id VARCHAR(50) NOT NULL, -- 창고식별자
    item_id VARCHAR(50) NOT NULL, -- 품목식별자
    inventory_quantity NUMERIC(18,6), -- 현재고수량
    inventory_count_quantity NUMERIC(18,6), -- 실사수량
    item_uom_code VARCHAR(20), -- 기준단위코드
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_inventory_count PRIMARY KEY (enterprise_id, inventory_count_document_number, warehouse_id, item_id)
);

CREATE TABLE ksx.product_incoming ( -- 제품입고 (표 72)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    product_incoming_id VARCHAR(50) NOT NULL, -- 제품입고식별자
    product_incoming_sequence INTEGER NOT NULL, -- 제품입고순번
    inventory_transaction_document_number VARCHAR(50), -- 수불문서번호
    inventory_transaction_document_sequence INTEGER, -- 수불문서순번
    inventory_transaction_date DATE, -- 수불일
    item_id VARCHAR(50), -- 품목식별자
    customer_id VARCHAR(50), -- 고객사식별자
    warehouse_id VARCHAR(50), -- 창고식별자
    inventory_transaction_type_code VARCHAR(30), -- 수불유형코드
    serial_use_indicator BOOLEAN, -- 시리얼사용여부
    inventory_transfer_type VARCHAR(30), -- 입출고유형
    inventory_variation_type VARCHAR(30), -- 재고증감유형
    inventory_transaction_type VARCHAR(30), -- 수불유형
    lot_control_indicator BOOLEAN, -- 로트사용여부
    lot_id VARCHAR(50), -- 로트식별자
    item_uom_code VARCHAR(20), -- 기준단위코드
    item_unit_quantity NUMERIC(18,6), -- 기준단위수량
    order_uom_code VARCHAR(20), -- 오더단위코드
    order_quantity NUMERIC(18,6), -- 오더수량
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_product_incoming PRIMARY KEY (enterprise_id, product_incoming_id, product_incoming_sequence)
);

CREATE TABLE ksx.product_release_request ( -- 출하의뢰 (표 73)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    product_release_request_id VARCHAR(50) NOT NULL, -- 출하요청식별자
    product_release_request_document_number VARCHAR(50), -- 납품문서번호
    product_release_request_type VARCHAR(30), -- 납품구분유형
    product_release_request_date DATE, -- 납품지시일
    product_release_request_sequence INTEGER NOT NULL, -- 납품순번
    line_id VARCHAR(50), -- 라인식별자
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    product_release_request_quantity NUMERIC(18,6), -- 납품수량
    product_release_quantity NUMERIC(18,6), -- 출고수량
    sales_quantity NUMERIC(18,6), -- 매출수량
    item_uom_code VARCHAR(20), -- 기준단위코드
    selling_uom_code VARCHAR(20), -- 판매단위코드
    item_unit_quantity NUMERIC(18,6), -- 기준단위수량
    product_release_unit_quantity NUMERIC(18,6), -- 기준출고수량
    sales_unit_quantity NUMERIC(18,6), -- 기준매출수량
    warehouse_id VARCHAR(50), -- 창고식별자
    requested_delivery_date DATE, -- 요청납기일
    sales_document_number VARCHAR(50), -- 수주문서번호
    sales_document_sequence INTEGER, -- 수주문서순번
    customer_id VARCHAR(50), -- 고객사식별자
    product_release_date DATE, -- 출고일
    delivery_date DATE, -- 납품일
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_product_release_request PRIMARY KEY (enterprise_id, product_release_request_id, product_release_request_sequence)
);

CREATE TABLE ksx.product_release_request_header ( -- 출하의뢰헤더 (표 —)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    product_release_request_id VARCHAR(50) NOT NULL, -- 출하요청식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_product_release_request_header PRIMARY KEY (enterprise_id, product_release_request_id)
);

CREATE TABLE ksx.product_release ( -- 제품출고 (표 74)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    product_release_id VARCHAR(50) NOT NULL, -- 출고식별자
    product_release_sequence INTEGER NOT NULL, -- 출고순번
    product_release_request_id VARCHAR(50), -- 출하요청식별자
    sales_document_number VARCHAR(50), -- 수주문서번호
    sales_document_sequence INTEGER, -- 수주문서순번
    inventory_transaction_date DATE, -- 수불일
    line_id VARCHAR(50), -- 라인식별자
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    order_uom_code VARCHAR(20), -- 오더단위코드
    order_quantity NUMERIC(18,6), -- 오더수량
    selling_uom_code VARCHAR(20), -- 판매단위코드
    sales_quantity NUMERIC(18,6), -- 매출수량
    return_indicator BOOLEAN, -- 반품여부
    item_uom_code VARCHAR(20), -- 기준단위코드
    item_unit_quantity NUMERIC(18,6), -- 기준단위수량
    sales_unit_quantity NUMERIC(18,6), -- 기준매출수량
    return_unit_quantity NUMERIC(18,6), -- 기준반품수량
    customer_id VARCHAR(50), -- 고객사식별자
    lot_id VARCHAR(50), -- 로트식별자
    serial_use_indicator BOOLEAN, -- 시리얼사용여부
    warehouse_id VARCHAR(50), -- 창고식별자
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_product_release PRIMARY KEY (enterprise_id, product_release_id, product_release_sequence)
);

CREATE TABLE ksx."return" ( -- 반품 (표 75)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    return_id VARCHAR(50) NOT NULL, -- 반품식별자
    item_id VARCHAR(50), -- 품목식별자
    lot_id VARCHAR(50), -- 로트식별자
    batch_id VARCHAR(50), -- 배치식별자
    warehouse_id VARCHAR(50), -- 창고식별자
    return_sequence INTEGER NOT NULL, -- 반품순서
    return_number VARCHAR(50), -- 반품번호
    product_return_document_number VARCHAR(50), -- 반품문서번호
    return_date_time TIMESTAMP, -- 반품일시
    customer_id VARCHAR(50), -- 고객사식별자
    vendor_id VARCHAR(50), -- 공급사식별자
    return_quantity NUMERIC(18,6), -- 반품수량
    return_type VARCHAR(30), -- 반품유형
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_return PRIMARY KEY (enterprise_id, return_id, return_sequence)
);

CREATE TABLE ksx.product_trace_parameter_on_customer ( -- 고객제품데이터 (표 76)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    item_id VARCHAR(50) NOT NULL, -- 품목식별자
    serial_number VARCHAR(50) NOT NULL, -- 제조번호
    location VARCHAR(1000), -- 위치
    item_type VARCHAR(30), -- 품목유형
    parameter_name VARCHAR(200) NOT NULL, -- 파라미터명
    parameter_value NUMERIC(18,6), -- 파라미터값
    collection_date_time TIMESTAMP NOT NULL, -- 수집일시
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_product_trace_parameter_on_customer PRIMARY KEY (enterprise_id, item_id, serial_number, parameter_name, collection_date_time)
);

CREATE TABLE ksx.after_sales_service_request ( -- 사후서비스신청 (표 77)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    request_number VARCHAR(50) NOT NULL, -- 신청번호
    transfer_sequence INTEGER, -- 이관순번
    basic_accept_process_code VARCHAR(30), -- 접수내용단순처리코드
    promised_visit_date_time TIMESTAMP, -- 약속방문일시
    transfer_registration_code VARCHAR(30), -- 이관등록코드
    serial_number VARCHAR(50), -- 제조번호
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_after_sales_service_request PRIMARY KEY (enterprise_id, request_number)
);

CREATE TABLE ksx.after_sales_service_request_result ( -- 사후서비스결과 (표 78)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    item_id VARCHAR(50), -- 품목식별자
    item_name VARCHAR(200), -- 품목명
    request_number VARCHAR(50) NOT NULL, -- 신청번호
    transfer_sequence INTEGER NOT NULL, -- 이관순번
    register_sequence INTEGER NOT NULL, -- 등록순번
    repair_sequence INTEGER NOT NULL, -- 수리순번
    serial_number VARCHAR(50), -- 제조번호
    fault_large_class VARCHAR(30), -- 하자현상대분류
    fault_small_class VARCHAR(30), -- 하자현상소분류
    error_code VARCHAR(30), -- 오류코드
    installation_date DATE, -- 설치일
    processing_date DATE, -- 처리일
    end_indicator BOOLEAN, -- 종료여부
    work_type VARCHAR(30), -- 작업유형
    child_item_id VARCHAR(50), -- 자품목식별자
    child_item_name VARCHAR(200), -- 자품목명
    item_specification VARCHAR(1000), -- 품목사양
    repair_type VARCHAR(30), -- 수리유형
    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)
    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)
    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각
    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)
    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태
    CONSTRAINT pk_after_sales_service_request_result PRIMARY KEY (enterprise_id, request_number, transfer_sequence, register_sequence, repair_sequence)
);



-- 국문 주석 (카탈로그·Text-to-SQL 이 읽는다)
COMMENT ON TABLE ksx.site IS '사업장 — 회사 내 하위 관리단위로서의 사업장을 의미한다.';
COMMENT ON TABLE ksx.plant IS '공장 — 회사 내 하위 관리단위로서의 공장을 의미한다.';
COMMENT ON TABLE ksx.department IS '부서 — 회사 내 하위 관리 단위로서의 부서를 의미한다.';
COMMENT ON TABLE ksx.personnel IS '사원 — 사원코드, 사원명, 인적정보 등을 관리하는 사원 마스터를 의미한다. 일반적으로 HRMS(Human Resource Management System)에서 사용되지만 작업 스케줄링 또는 자원 할당에서 사용될 수도 있다.';
COMMENT ON TABLE ksx.customer_party_master IS '고객사 — 고객사 코드, 고객사명, 사업자등록번호 등 고객사 정보를 관리하는 고객사 마스터를 의미한다.';
COMMENT ON TABLE ksx.vendor_party_master IS '공급사 — 공급사 코드, 공급사명, 사업자등록번호 등 공급사 정보를 관리하는 공급사 마스터를 의미한다.';
COMMENT ON TABLE ksx.common_code_master IS '공통코드정보 — 애플리케이션 내에서 사용되는 각종 코드를 모아 놓은 통합 코드를 의미한다.';
COMMENT ON TABLE ksx.work_calendar IS '달력 — 생산 현장의 달력을 의미한다. 단, 인사에서 사용하는 일반 달력과는 차이가 있다.';
COMMENT ON TABLE ksx.uom_group IS '단위그룹 — 측정 단위의 집합을 의미한다. 일반적으로 재고관리 단위가 기본단위가 되며 특정 프로세스에서 변경될 수 있고, 재고에 반영될 때는 환산계수가 적용된다.';
COMMENT ON TABLE ksx.item_master IS '품목마스터 — 품목코드, 품목명, 규격 등과 각종 속성값을 관리하는 품목마스터를 의미한다. 단, 수량정보는 포함하지 않는다.';
COMMENT ON TABLE ksx.bom IS '자재명세서 — 품목을 구성하거나 품목을 생산하기 위해 투입되는 자재명세서를 의미한다.';
COMMENT ON TABLE ksx.bom_header IS '자재명세서헤더 — 물리 보조 테이블(표준 외): 자재명세서의 자재명세서식별자+자재명세서버전 단위 헤더. 자재명세서 전체를 참조하는 FK를 위해 둠';
COMMENT ON TABLE ksx.lot IS '로트 — 묶음 생산 단위의 정보를 의미한다.';
COMMENT ON TABLE ksx.routing IS '공정경로 — 생산 시 필요한 공정의 순서를 의미하며, 작업자, 기계를 포함한 경로와 관련된 모든 리소스, 활동에 대한 정보를 의미한다.';
COMMENT ON TABLE ksx.routing_header IS '공정경로헤더 — 물리 보조 테이블(표준 외): 공정경로의 공정경로식별자 단위 헤더. 공정경로 전체를 참조하는 FK를 위해 둠';
COMMENT ON TABLE ksx.operation IS '공정 — 생산작업을 수행하는 작업장 또는 작업장 내 세부 작업단위를 의미한다.';
COMMENT ON TABLE ksx.equipment IS '설비 — 설비명, 설비유형 등 설비 관리 및 회사의 자산으로서 관리를 위한 설비정보를 의미한다.';
COMMENT ON TABLE ksx.operation_equipment IS '공정설비 — 공정별 사용되는 설비 정보 데이터를 의미한다.';
COMMENT ON TABLE ksx.carrier IS '캐리어 — 제조 공정 내 이동에 필요한 물리적 용기를 의미한다.';
COMMENT ON TABLE ksx.stocker_inventory IS '저장소재공정보 — 공장 내 공정 물류 저장소 정보를 의미한다. 이는 공정 내 물류 최적화를 위해 Lot Dispatcher를 사용하는데 SCS(StockerControlSystem), Dispatcher, MES 상호연동을 위해 존재한다.';
COMMENT ON TABLE ksx.warehouse_location IS '창고 — 재고를 모아 놓고 관리하는 위치를 의미한다.';
COMMENT ON TABLE ksx.batch IS '배치 — 배치 공정의 1회 실행으로 생산되고 있거나 생산된 물질의 단위를 의미한다. 원료를 정해진 양만큼 투입하여 일괄 처리하는 공정(배합, 반응, 발효, 열처리 등)의 생산 단위이며, 공급사에서 생산하여 납품한 구매품의 배치를 포함한다.';
COMMENT ON TABLE ksx.line IS '라인 — 같은 공장 안에서 공정과 설비를 일정한 흐름으로 배치하여 특정 품목 또는 품목군을 생산하는 생산 단위를 의미한다. 라인은 공장에 속하며, 하나 이상의 공정과 설비로 구성된다.';
COMMENT ON TABLE ksx.enterprise IS '회사 — 기업업무시스템 간 제조업무데이터를 교환하는 법인 단위의 회사를 의미한다. 회사는 하나 이상의 사업장으로 구성되며, 모든 명사 정보의 최상위 소유 범위가 된다.';
COMMENT ON TABLE ksx.project_master IS '프로젝트마스터 — 프로젝트 코드, 프로젝트명 등을 관리하는 프로젝트마스터를 의미한다. 주요 프로젝트 필드의 ProjectAccounting 관련 애플리케이션 활성화를 위한정보로 활용되기도 한다.';
COMMENT ON TABLE ksx.engineering_change_order IS '설계변경지시 — 제품의 설계를 변경하는 지시를 의미한다. 설계변경지시 수행 결과는 BOM 및 공정경로BOM에 반영된다.';
COMMENT ON TABLE ksx.sales_order IS '수주오더 — 고객사 주문정보를 의미한다.';
COMMENT ON TABLE ksx.sales_plan IS '판매계획 — 고객사 Forecast정보 및 수요예측정보를 토대로 작성된 판매계획을 의미한다.';
COMMENT ON TABLE ksx.base_price IS '기준가격 — 구매요청 시 참조하기 위한 구매품의 기준가격 정보를 의미한다.';
COMMENT ON TABLE ksx.purchase_requisition IS '구매요청 — 생산 또는 판매를 위해 수급되어야 할 품목을 요청하는 것을 의미한다(원부자재, 소모품, 상품 등).';
COMMENT ON TABLE ksx.purchase_order IS '구매발주 — 구매자가 공급자의 품목을 구매하기 위한 주문을 의미한다.';
COMMENT ON TABLE ksx.material_arrival IS '자재도착 — 자재가 입고 전 수입검사를 위해 도착한 정보를 의미한다.';
COMMENT ON TABLE ksx.goods_receipt IS '입고 — 구매 발주된 품목을 협력업체로부터 납품 받은 정보를 의미한다.';
COMMENT ON TABLE ksx.goods_issue IS '자재불출 — 자재불출 요청된 자재를 불출하는 것을 의미한다(일반적으로 재고 관리주체가 다를 경우 창고관리부서에서 사용).';
COMMENT ON TABLE ksx.production_planning IS '생산계획 — 특정 제품을 생산하기 위한 계획을 의미한다.';
COMMENT ON TABLE ksx.production_order IS '생산지시 — 특정 제품의 생산을 지시하는 정보를 의미한다.';
COMMENT ON TABLE ksx.operation_start IS '착공 — 설비에 해당 공정의 생산을 지시한다.';
COMMENT ON TABLE ksx.operation_end IS '완공 — 해당 공정의 생산 완료를 보고한다.';
COMMENT ON TABLE ksx.transfer_command IS '이동지시 — 현재 공정에서 다음 공정으로 작업할 Lot의 이동을 지시한다.';
COMMENT ON TABLE ksx.transfer_start IS '운행시작 — 이동지시 명령을 받아 운행 시작 시 시작 정보를 보고한다.';
COMMENT ON TABLE ksx.transfer_end IS '운행완료 — 이동지시 명령을 받아 운행 완료 시 완료 정보를 보고한다.';
COMMENT ON TABLE ksx.in_transit_location IS '운송위치 — 이동 중 현재 운송 위치 정보를 보고한다.';
COMMENT ON TABLE ksx.equipment_state IS '설비상태 — 설비의 상태가 변경될 시 상태 정보를 보고한다.';
COMMENT ON TABLE ksx.alarm IS '알람 — 설비에서 발생하는 알람 정보를 의미한다.';
COMMENT ON TABLE ksx.supplier_inspection_plan IS '협력업체품질검사계획 — 수주산업에서 프로젝트성으로 추진하고 있는 협력업체 발주품에 대해 발주처 및 협력업체 품질부서에서 품질검사를 하기 위한 일정 계획을 의미한다.';
COMMENT ON TABLE ksx.supplier_inspection_application IS '협력업체품질검사신청 — 품질검사계획에 따라 협력업체에 품질검사를 신청하는 것을 의미한다.';
COMMENT ON TABLE ksx.supplier_inspection_result IS '협력업체품질검사결과 — 검사결과를 품질관리 부서에 전달하는 것을 의미한다.';
COMMENT ON TABLE ksx.corrective_action_request IS '시정조치요청 — 공급사에 시정조치를 요청하는 것을 의미한다.';
COMMENT ON TABLE ksx.corrective_action_plan IS '시정조치계획 — 공급사에서 시정조치 사항을 기술하고, 시정조치 계획을 수립하여 고객사에게 전달하는 것을 의미한다.';
COMMENT ON TABLE ksx.corrective_action_result IS '시정조치결과 — 시정조치계획에 따라 수행 결과를 고객사에 전달하는 것을 의미한다.';
COMMENT ON TABLE ksx.product_packing IS '제품포장 — 제품 출하를 위해 완성된 제품을 포장하기 위한 정보를 의미한다.';
COMMENT ON TABLE ksx.equipment_parameter IS '설비파라미터 — 설비에서 수집되는 Parameter 값의 집합을 의미한다.';
COMMENT ON TABLE ksx.trace_parameter IS '설비파라미터이력 — 설비에서 수집되는 Parameter 값의 적재 및 검증 이력을 의미한다.';
COMMENT ON TABLE ksx.production_performance IS '생산실적 — 생산지시에 의해 실행된 생산의 실적 결과 정보를 의미한다.';
COMMENT ON TABLE ksx.production_performance_item IS '생산실적투입품목 — 생산 과정에서 투입되는 모든 품목(원자재, 부자재, 반제품, 완제품 등) 관련 정보를 의미한다.';
COMMENT ON TABLE ksx.production_performance_personnel IS '생산실적투입인력 — 생산 과정에서 투입된 인력정보를 의미한다. 생산실적투입인력 명사는 표 65와같은 정보 속성을 포함하고 있다.';
COMMENT ON TABLE ksx.production_performance_equipment IS '설비활용실적 — 생산 과정에서 사용된 설비의 활용실적 정보를 의미한다.';
COMMENT ON TABLE ksx.production_performance_quality IS '생산품질실적 — 생산 과정에서 발생한 품질정보를 의미한다.';
COMMENT ON TABLE ksx.inventory IS '재고 — 저장위치에 있는 품목의 실제 보유(On-hand) 수량을 의미한다.';
COMMENT ON TABLE ksx.available_inventory IS '가용재고 — 현 재고와 특정 시점까지의 예상 입출고를 감안하여 사용 가능한 재고를 의미한다.';
COMMENT ON TABLE ksx.stock_transfer IS '재고이동 — 재고가 다른 창고로 이동하기 위해 필요한 정보를 의미한다.';
COMMENT ON TABLE ksx.inventory_count IS '재고실사 — 보관된 재고에 대해 실수량을 파악하기 위한 정보를 의미한다.';
COMMENT ON TABLE ksx.product_incoming IS '제품입고 — 생산된 제품을 창고에 저장하는 것을 의미한다.';
COMMENT ON TABLE ksx.product_release_request IS '출하의뢰 — 수주된 품목에 대한 출하를 의뢰하는 것을 의미한다.';
COMMENT ON TABLE ksx.product_release_request_header IS '출하의뢰헤더 — 물리 보조 테이블(표준 외): 출하의뢰의 출하요청식별자 단위 헤더. 출하의뢰 전체를 참조하는 FK를 위해 둠';
COMMENT ON TABLE ksx.product_release IS '제품출고 — 수주된 품목을 고객에게 보내는 것을 의미한다.';
COMMENT ON TABLE ksx."return" IS '반품 — 반품(구매반품, 제품반품)에 대한 정보를 의미한다.';
COMMENT ON TABLE ksx.product_trace_parameter_on_customer IS '고객제품데이터 — 고객에게 판매 완료 후 부가적인 서비스 제공 및 가치창출을 위해 고객 제품에서 수집되는 데이터를 의미한다.';
COMMENT ON TABLE ksx.after_sales_service_request IS '사후서비스신청 — 고객에게 판매된 제품의 고장으로 제조자 혹은 대리점 등에 고장 접수 시 필요한 데이터를 의미한다.';
COMMENT ON TABLE ksx.after_sales_service_request_result IS '사후서비스결과 — 고객의 사후서비스 접수 이후 제조사 혹은 대리점의 처리결과를 교환하기 위해 필요한 데이터를 의미한다.';
COMMENT ON COLUMN ksx.site.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.site.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.site.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.site.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.site.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.site.note IS '비고';
COMMENT ON COLUMN ksx.site.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.site.site_name IS '사업장명';
COMMENT ON COLUMN ksx.site.business_registration_number IS '사업자등록번호';
COMMENT ON COLUMN ksx.site.dial_number IS '전화번호';
COMMENT ON COLUMN ksx.site.postal_code IS '우편번호';
COMMENT ON COLUMN ksx.site.base_address IS '기본주소';
COMMENT ON COLUMN ksx.site.detail_address IS '상세주소';
COMMENT ON COLUMN ksx.site.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.plant.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.plant.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.plant.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.plant.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.plant.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.plant.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.plant.note IS '비고';
COMMENT ON COLUMN ksx.plant.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.plant.plant_name IS '공장명';
COMMENT ON COLUMN ksx.plant.dial_number IS '전화번호';
COMMENT ON COLUMN ksx.plant.country_id IS '국가식별자';
COMMENT ON COLUMN ksx.plant.postal_code IS '우편번호';
COMMENT ON COLUMN ksx.plant.base_address IS '기본주소';
COMMENT ON COLUMN ksx.plant.detail_address IS '상세주소';
COMMENT ON COLUMN ksx.department.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.department.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.department.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.department.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.department.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.department.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.department.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.department.note IS '비고';
COMMENT ON COLUMN ksx.department.department_id IS '부서식별자';
COMMENT ON COLUMN ksx.department.department_name IS '부서명';
COMMENT ON COLUMN ksx.department.parent_department_id IS '상위부서식별자';
COMMENT ON COLUMN ksx.personnel.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.personnel.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.personnel.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.personnel.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.personnel.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.personnel.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.personnel.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.personnel.note IS '비고';
COMMENT ON COLUMN ksx.personnel.personnel_id IS '사원식별자';
COMMENT ON COLUMN ksx.personnel.personnel_name IS '사원명';
COMMENT ON COLUMN ksx.personnel.department_id IS '부서식별자';
COMMENT ON COLUMN ksx.personnel.employment_status_type IS '재직유형';
COMMENT ON COLUMN ksx.personnel.person_in_charge_email IS '담당자이메일명';
COMMENT ON COLUMN ksx.personnel.person_in_charge_dial_number IS '담당자전화번호';
COMMENT ON COLUMN ksx.customer_party_master.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.customer_party_master.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.customer_party_master.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.customer_party_master.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.customer_party_master.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.customer_party_master.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.customer_party_master.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.customer_party_master.note IS '비고';
COMMENT ON COLUMN ksx.customer_party_master.customer_id IS '고객사식별자';
COMMENT ON COLUMN ksx.customer_party_master.customer_name IS '고객사명';
COMMENT ON COLUMN ksx.customer_party_master.business_registration_number IS '사업자등록번호';
COMMENT ON COLUMN ksx.customer_party_master.representative_name IS '대표자명';
COMMENT ON COLUMN ksx.customer_party_master.country_id IS '국가식별자';
COMMENT ON COLUMN ksx.customer_party_master.postal_code IS '우편번호';
COMMENT ON COLUMN ksx.customer_party_master.base_address IS '기본주소';
COMMENT ON COLUMN ksx.customer_party_master.detail_address IS '상세주소';
COMMENT ON COLUMN ksx.customer_party_master.dial_number IS '전화번호';
COMMENT ON COLUMN ksx.customer_party_master.fax_number IS '팩스번호';
COMMENT ON COLUMN ksx.customer_party_master.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.customer_party_master.person_in_charge_name IS '담당자명';
COMMENT ON COLUMN ksx.customer_party_master.person_in_charge_email IS '담당자이메일명';
COMMENT ON COLUMN ksx.customer_party_master.person_in_charge_dial_number IS '담당자전화번호';
COMMENT ON COLUMN ksx.vendor_party_master.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.vendor_party_master.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.vendor_party_master.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.vendor_party_master.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.vendor_party_master.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.vendor_party_master.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.vendor_party_master.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.vendor_party_master.note IS '비고';
COMMENT ON COLUMN ksx.vendor_party_master.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.vendor_party_master.vendor_name IS '공급사명';
COMMENT ON COLUMN ksx.vendor_party_master.business_registration_number IS '사업자등록번호';
COMMENT ON COLUMN ksx.vendor_party_master.representative_name IS '대표자명';
COMMENT ON COLUMN ksx.vendor_party_master.country_id IS '국가식별자';
COMMENT ON COLUMN ksx.vendor_party_master.postal_code IS '우편번호';
COMMENT ON COLUMN ksx.vendor_party_master.base_address IS '기본주소';
COMMENT ON COLUMN ksx.vendor_party_master.detail_address IS '상세주소';
COMMENT ON COLUMN ksx.vendor_party_master.dial_number IS '전화번호';
COMMENT ON COLUMN ksx.vendor_party_master.fax_number IS '팩스번호';
COMMENT ON COLUMN ksx.vendor_party_master.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.vendor_party_master.person_in_charge_name IS '담당자명';
COMMENT ON COLUMN ksx.vendor_party_master.person_in_charge_email IS '담당자이메일명';
COMMENT ON COLUMN ksx.vendor_party_master.person_in_charge_dial_number IS '담당자전화번호';
COMMENT ON COLUMN ksx.common_code_master.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.common_code_master.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.common_code_master.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.common_code_master.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.common_code_master.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.common_code_master.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.common_code_master.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.common_code_master.note IS '비고';
COMMENT ON COLUMN ksx.common_code_master.common_code_id IS '공통코드식별자';
COMMENT ON COLUMN ksx.common_code_master.common_code_name IS '공통코드명';
COMMENT ON COLUMN ksx.common_code_master.common_code_group IS '공통코드그룹';
COMMENT ON COLUMN ksx.common_code_master.parent_common_code_group IS '상위공통코드그룹';
COMMENT ON COLUMN ksx.common_code_master.parent_common_code_id IS '상위공통코드식별자';
COMMENT ON COLUMN ksx.common_code_master.common_code_sequence IS '표시순번';
COMMENT ON COLUMN ksx.common_code_master.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.work_calendar.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.work_calendar.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.work_calendar.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.work_calendar.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.work_calendar.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.work_calendar.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.work_calendar.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.work_calendar.note IS '비고';
COMMENT ON COLUMN ksx.work_calendar.calendar_id IS '달력식별자';
COMMENT ON COLUMN ksx.work_calendar.calendar_type IS '달력유형';
COMMENT ON COLUMN ksx.work_calendar.calendar_date IS '달력일자';
COMMENT ON COLUMN ksx.work_calendar.day_of_week IS '요일';
COMMENT ON COLUMN ksx.work_calendar.week_of_year IS '주수';
COMMENT ON COLUMN ksx.work_calendar.day_of_year IS '총누계일수';
COMMENT ON COLUMN ksx.work_calendar.schedule_type IS '근무일유형';
COMMENT ON COLUMN ksx.uom_group.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.uom_group.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.uom_group.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.uom_group.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.uom_group.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.uom_group.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.uom_group.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.uom_group.note IS '비고';
COMMENT ON COLUMN ksx.uom_group.uom_group_id IS '단위그룹식별자';
COMMENT ON COLUMN ksx.uom_group.uom_group_name IS '단위그룹명';
COMMENT ON COLUMN ksx.uom_group.uom_code IS '단위코드';
COMMENT ON COLUMN ksx.uom_group.uom_code_name IS '단위코드명';
COMMENT ON COLUMN ksx.uom_group.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.item_master.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.item_master.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.item_master.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.item_master.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.item_master.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.item_master.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.item_master.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.item_master.note IS '비고';
COMMENT ON COLUMN ksx.item_master.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.item_master.item_name IS '품목명';
COMMENT ON COLUMN ksx.item_master.item_type IS '품목유형';
COMMENT ON COLUMN ksx.item_master.phantom_indicator IS '가상품목여부';
COMMENT ON COLUMN ksx.item_master.item_large_class IS '품목대분류';
COMMENT ON COLUMN ksx.item_master.item_medium_class IS '품목중분류';
COMMENT ON COLUMN ksx.item_master.item_small_class IS '품목소분류';
COMMENT ON COLUMN ksx.item_master.model_name IS '모델명';
COMMENT ON COLUMN ksx.item_master.item_specification IS '품목사양';
COMMENT ON COLUMN ksx.item_master.item_detail_specification IS '품목상세사양';
COMMENT ON COLUMN ksx.item_master.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.item_master.country_of_origin IS '원산국가';
COMMENT ON COLUMN ksx.item_master.place_of_origin IS '원산지역';
COMMENT ON COLUMN ksx.item_master.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.item_master.weight IS '중량';
COMMENT ON COLUMN ksx.item_master.net_weight IS '순중량';
COMMENT ON COLUMN ksx.item_master.weight_uom_code IS '중량단위코드';
COMMENT ON COLUMN ksx.item_master.volume IS '부피';
COMMENT ON COLUMN ksx.item_master.volume_uom_code IS '부피단위코드';
COMMENT ON COLUMN ksx.item_master.length IS '길이';
COMMENT ON COLUMN ksx.item_master.width IS '너비';
COMMENT ON COLUMN ksx.item_master.height IS '높이';
COMMENT ON COLUMN ksx.item_master.dimension_uom_code IS '치수단위코드';
COMMENT ON COLUMN ksx.item_master.valid_end_date IS '유효종료일';
COMMENT ON COLUMN ksx.item_master.drawing_number IS '도면번호';
COMMENT ON COLUMN ksx.item_master.lot_control_indicator IS '로트사용여부';
COMMENT ON COLUMN ksx.item_master.purchase_lead_time IS '구매리드타임';
COMMENT ON COLUMN ksx.item_master.production_lead_time IS '생산리드타임';
COMMENT ON COLUMN ksx.item_master.lot_size IS '로트사이즈';
COMMENT ON COLUMN ksx.item_master.main_customer_id IS '주요 고객사식별자';
COMMENT ON COLUMN ksx.item_master.main_vendor_id IS '주요 공급사식별자';
COMMENT ON COLUMN ksx.item_master.safety_stock IS '안전재고';
COMMENT ON COLUMN ksx.item_master.maximum_stock_level IS '최대재고수준';
COMMENT ON COLUMN ksx.item_master.receipt_warehouse_id IS '입고창고식별자';
COMMENT ON COLUMN ksx.item_master.issue_warehouse_id IS '출고창고식별자';
COMMENT ON COLUMN ksx.item_master.abc_class IS '에이비씨분류';
COMMENT ON COLUMN ksx.item_master.replacement_item_id IS '대체품목식별자';
COMMENT ON COLUMN ksx.item_master.incoming_inspection_indicator IS '수입검사여부';
COMMENT ON COLUMN ksx.item_master.final_inspection_indicator IS '생산입고(최종)검사여부';
COMMENT ON COLUMN ksx.item_master.outgoing_inspection_indicator IS '출하검사여부';
COMMENT ON COLUMN ksx.bom.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.bom.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.bom.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.bom.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.bom.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.bom.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.bom.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.bom.note IS '비고';
COMMENT ON COLUMN ksx.bom.bom_id IS '자재명세서식별자';
COMMENT ON COLUMN ksx.bom.bom_type IS '자재명세서유형';
COMMENT ON COLUMN ksx.bom.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.bom.bom_quantity IS '품목기준수량';
COMMENT ON COLUMN ksx.bom.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.bom.child_item_id IS '자품목식별자';
COMMENT ON COLUMN ksx.bom.child_item_uom_code IS '자품목기준단위코드';
COMMENT ON COLUMN ksx.bom.actual_requirement_quantity IS '실소요수량';
COMMENT ON COLUMN ksx.bom.bom_revision_number IS '자재명세서버전';
COMMENT ON COLUMN ksx.bom.valid_start_date_time IS '유효시작일시';
COMMENT ON COLUMN ksx.bom.valid_end_date_time IS '유효종료일시';
COMMENT ON COLUMN ksx.bom.routing_id IS '공정경로식별자';
COMMENT ON COLUMN ksx.bom.operation_sequence IS '공정순번';
COMMENT ON COLUMN ksx.bom.back_flushed_indicator IS '백플러시여부';
COMMENT ON COLUMN ksx.bom_header.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.bom_header.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.bom_header.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.bom_header.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.bom_header.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.bom_header.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.bom_header.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.bom_header.note IS '비고';
COMMENT ON COLUMN ksx.bom_header.bom_id IS '자재명세서식별자';
COMMENT ON COLUMN ksx.bom_header.bom_revision_number IS '자재명세서버전';
COMMENT ON COLUMN ksx.lot.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.lot.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.lot.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.lot.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.lot.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.lot.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.lot.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.lot.note IS '비고';
COMMENT ON COLUMN ksx.lot.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.lot.lot_name IS '로트명';
COMMENT ON COLUMN ksx.lot.lot_description IS '로트설명';
COMMENT ON COLUMN ksx.lot.parent_lot_id IS '모로트식별자';
COMMENT ON COLUMN ksx.lot.child_lot_id IS '자로트식별자';
COMMENT ON COLUMN ksx.lot.lot_type IS '로트유형';
COMMENT ON COLUMN ksx.lot.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.lot.carrier_id IS '캐리어식별자';
COMMENT ON COLUMN ksx.lot.production_order_id IS '생산지시식별자';
COMMENT ON COLUMN ksx.lot.production_order_sequence IS '생산지시순번';
COMMENT ON COLUMN ksx.lot.scheduled_due_date IS '생산마감기한';
COMMENT ON COLUMN ksx.lot.lot_priority IS '로트우선순위';
COMMENT ON COLUMN ksx.lot.current_operation_id IS '현재공정식별자';
COMMENT ON COLUMN ksx.lot.next_operation_id IS '다음공정식별자';
COMMENT ON COLUMN ksx.lot.lot_state IS '로트상태';
COMMENT ON COLUMN ksx.lot.hold_indicator IS '보류여부';
COMMENT ON COLUMN ksx.lot.hot_indicator IS '긴급여부';
COMMENT ON COLUMN ksx.lot.rework_indicator IS '재작업여부';
COMMENT ON COLUMN ksx.lot.lot_created_quantity IS '로트수량';
COMMENT ON COLUMN ksx.lot.produced_quantity IS '생산수량';
COMMENT ON COLUMN ksx.lot.defect_quantity IS '불량수량';
COMMENT ON COLUMN ksx.lot.rework_quantity IS '재작업수량';
COMMENT ON COLUMN ksx.lot.rework_count IS '재작업횟수';
COMMENT ON COLUMN ksx.lot.total_rework_count IS '총재작업횟수';
COMMENT ON COLUMN ksx.lot.lot_started_date_time IS '공정투입일시';
COMMENT ON COLUMN ksx.lot.personnel_id IS '사원식별자';
COMMENT ON COLUMN ksx.routing.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.routing.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.routing.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.routing.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.routing.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.routing.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.routing.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.routing.note IS '비고';
COMMENT ON COLUMN ksx.routing.routing_id IS '공정경로식별자';
COMMENT ON COLUMN ksx.routing.routing_name IS '공정경로명';
COMMENT ON COLUMN ksx.routing.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.routing.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.routing.operation_sequence IS '공정순번';
COMMENT ON COLUMN ksx.routing.last_operation_indicator IS '최종공정여부';
COMMENT ON COLUMN ksx.routing.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.routing.setup_time IS '준비시간';
COMMENT ON COLUMN ksx.routing.run_time IS '작업시간';
COMMENT ON COLUMN ksx.routing.move_time IS '이동시간';
COMMENT ON COLUMN ksx.routing_header.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.routing_header.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.routing_header.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.routing_header.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.routing_header.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.routing_header.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.routing_header.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.routing_header.note IS '비고';
COMMENT ON COLUMN ksx.routing_header.routing_id IS '공정경로식별자';
COMMENT ON COLUMN ksx.operation.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.operation.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.operation.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.operation.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.operation.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.operation.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.operation.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.operation.note IS '비고';
COMMENT ON COLUMN ksx.operation.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.operation.operation_name IS '공정명';
COMMENT ON COLUMN ksx.operation.operation_type IS '공정유형';
COMMENT ON COLUMN ksx.operation.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.operation.operation_large_class IS '공정대분류';
COMMENT ON COLUMN ksx.operation.operation_medium_class IS '공정중분류';
COMMENT ON COLUMN ksx.operation.operation_small_class IS '공정소분류';
COMMENT ON COLUMN ksx.operation.back_flushed_indicator IS '백플러시여부';
COMMENT ON COLUMN ksx.equipment.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.equipment.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.equipment.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.equipment.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.equipment.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.equipment.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.equipment.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.equipment.note IS '비고';
COMMENT ON COLUMN ksx.equipment.equipment_id IS '설비식별자';
COMMENT ON COLUMN ksx.equipment.equipment_name IS '설비명';
COMMENT ON COLUMN ksx.equipment.parent_equipment_id IS '상위설비식별자';
COMMENT ON COLUMN ksx.equipment.equipment_type IS '설비유형';
COMMENT ON COLUMN ksx.equipment.equipment_large_class IS '설비대분류';
COMMENT ON COLUMN ksx.equipment.equipment_medium_class IS '설비중분류';
COMMENT ON COLUMN ksx.equipment.equipment_small_class IS '설비소분류';
COMMENT ON COLUMN ksx.equipment.department_in_charge_id IS '관리부서식별자';
COMMENT ON COLUMN ksx.equipment.person_in_charge_id IS '관리자식별자';
COMMENT ON COLUMN ksx.equipment.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.equipment.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.equipment.daq_device IS '데이터수집장치';
COMMENT ON COLUMN ksx.equipment.fixed_asset_id IS '고정자산식별자';
COMMENT ON COLUMN ksx.equipment.model_number IS '모델번호';
COMMENT ON COLUMN ksx.equipment.serial_number IS '일련번호';
COMMENT ON COLUMN ksx.equipment.country_of_origin IS '제조국가';
COMMENT ON COLUMN ksx.equipment.manufacturer IS '제조업체';
COMMENT ON COLUMN ksx.equipment.acquisition_date IS '취득일';
COMMENT ON COLUMN ksx.equipment.location IS '위치';
COMMENT ON COLUMN ksx.operation_equipment.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.operation_equipment.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.operation_equipment.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.operation_equipment.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.operation_equipment.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.operation_equipment.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.operation_equipment.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.operation_equipment.note IS '비고';
COMMENT ON COLUMN ksx.operation_equipment.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.operation_equipment.operation_name IS '공정명';
COMMENT ON COLUMN ksx.operation_equipment.equipment_id IS '설비식별자';
COMMENT ON COLUMN ksx.operation_equipment.equipment_name IS '설비명';
COMMENT ON COLUMN ksx.operation_equipment.equipment_small_class IS '설비소분류';
COMMENT ON COLUMN ksx.operation_equipment.equipment_quantity IS '기준사용대수';
COMMENT ON COLUMN ksx.carrier.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.carrier.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.carrier.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.carrier.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.carrier.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.carrier.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.carrier.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.carrier.note IS '비고';
COMMENT ON COLUMN ksx.carrier.carrier_id IS '캐리어식별자';
COMMENT ON COLUMN ksx.carrier.carrier_type IS '캐리어유형';
COMMENT ON COLUMN ksx.carrier.item_type IS '품목유형';
COMMENT ON COLUMN ksx.carrier.load_state IS '적재상태';
COMMENT ON COLUMN ksx.carrier.carrier_state IS '캐리어상태';
COMMENT ON COLUMN ksx.carrier.current_quantity IS '적재수량';
COMMENT ON COLUMN ksx.stocker_inventory.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.stocker_inventory.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.stocker_inventory.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.stocker_inventory.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.stocker_inventory.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.stocker_inventory.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.stocker_inventory.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.stocker_inventory.note IS '비고';
COMMENT ON COLUMN ksx.stocker_inventory.stocker_id IS '저장소식별자';
COMMENT ON COLUMN ksx.stocker_inventory.zone_id IS '구역식별자';
COMMENT ON COLUMN ksx.stocker_inventory.full_capacity IS '최대용량';
COMMENT ON COLUMN ksx.stocker_inventory.current_capacity IS '현재용량';
COMMENT ON COLUMN ksx.stocker_inventory.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.stocker_inventory.carrier_id IS '캐리어식별자';
COMMENT ON COLUMN ksx.stocker_inventory.alternate_stocker_id IS '대체저장소식별자';
COMMENT ON COLUMN ksx.warehouse_location.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.warehouse_location.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.warehouse_location.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.warehouse_location.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.warehouse_location.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.warehouse_location.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.warehouse_location.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.warehouse_location.note IS '비고';
COMMENT ON COLUMN ksx.warehouse_location.warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx.warehouse_location.warehouse_name IS '창고명';
COMMENT ON COLUMN ksx.warehouse_location.warehouse_type IS '창고유형';
COMMENT ON COLUMN ksx.warehouse_location.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.warehouse_location.negative_inventory_indicator IS '음수재고허용여부';
COMMENT ON COLUMN ksx.warehouse_location.warehouse_section_list IS '창고섹션목록';
COMMENT ON COLUMN ksx.batch.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.batch.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.batch.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.batch.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.batch.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.batch.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.batch.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.batch.note IS '비고';
COMMENT ON COLUMN ksx.batch.batch_id IS '배치식별자';
COMMENT ON COLUMN ksx.batch.batch_name IS '배치명';
COMMENT ON COLUMN ksx.batch.batch_description IS '배치설명';
COMMENT ON COLUMN ksx.batch.batch_type IS '배치유형';
COMMENT ON COLUMN ksx.batch.parent_batch_id IS '모배치식별자';
COMMENT ON COLUMN ksx.batch.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.batch.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.batch.production_order_id IS '생산지시식별자';
COMMENT ON COLUMN ksx.batch.production_order_sequence IS '생산지시순번';
COMMENT ON COLUMN ksx.batch.bom_id IS '자재명세서식별자';
COMMENT ON COLUMN ksx.batch.bom_revision_number IS '자재명세서버전';
COMMENT ON COLUMN ksx.batch.recipe_id IS '레시피식별자';
COMMENT ON COLUMN ksx.batch.recipe_version IS '레시피버전';
COMMENT ON COLUMN ksx.batch.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.batch.equipment_id IS '설비식별자';
COMMENT ON COLUMN ksx.batch.batch_state IS '배치상태';
COMMENT ON COLUMN ksx.batch.hold_indicator IS '보류여부';
COMMENT ON COLUMN ksx.batch.rework_indicator IS '재작업여부';
COMMENT ON COLUMN ksx.batch.quality_disposition_code IS '품질판정코드';
COMMENT ON COLUMN ksx.batch.batch_planned_quantity IS '배치계획수량';
COMMENT ON COLUMN ksx.batch.produced_quantity IS '생산수량';
COMMENT ON COLUMN ksx.batch.defect_quantity IS '불량수량';
COMMENT ON COLUMN ksx.batch.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.batch.schedule_start_date_time IS '계획시작일시';
COMMENT ON COLUMN ksx.batch.schedule_end_date_time IS '계획종료일시';
COMMENT ON COLUMN ksx.batch.batch_start_date_time IS '배치시작일시';
COMMENT ON COLUMN ksx.batch.batch_end_date_time IS '배치종료일시';
COMMENT ON COLUMN ksx.batch.manufacture_date IS '제조일';
COMMENT ON COLUMN ksx.batch.valid_end_date IS '유효종료일';
COMMENT ON COLUMN ksx.batch.personnel_id IS '사원식별자';
COMMENT ON COLUMN ksx.line.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.line.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.line.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.line.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.line.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.line.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.line.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.line.note IS '비고';
COMMENT ON COLUMN ksx.line.line_id IS '라인식별자';
COMMENT ON COLUMN ksx.line.line_name IS '라인명';
COMMENT ON COLUMN ksx.line.line_description IS '라인설명';
COMMENT ON COLUMN ksx.line.line_type IS '라인유형';
COMMENT ON COLUMN ksx.line.production_method_type IS '생산방식유형';
COMMENT ON COLUMN ksx.line.parent_line_id IS '상위라인식별자';
COMMENT ON COLUMN ksx.line.department_in_charge_id IS '관리부서식별자';
COMMENT ON COLUMN ksx.line.person_in_charge_id IS '관리자식별자';
COMMENT ON COLUMN ksx.line.calendar_id IS '달력식별자';
COMMENT ON COLUMN ksx.line.issue_warehouse_id IS '출고창고식별자';
COMMENT ON COLUMN ksx.line.receipt_warehouse_id IS '입고창고식별자';
COMMENT ON COLUMN ksx.line.standard_capacity IS '표준생산능력';
COMMENT ON COLUMN ksx.line.capacity_uom_code IS '생산능력단위코드';
COMMENT ON COLUMN ksx.line.standard_cycle_time IS '표준사이클타임';
COMMENT ON COLUMN ksx.line.shift_count IS '작업조수';
COMMENT ON COLUMN ksx.line.standard_headcount IS '표준작업인원';
COMMENT ON COLUMN ksx.line.location IS '위치';
COMMENT ON COLUMN ksx.line.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.line.valid_start_date IS '유효시작일';
COMMENT ON COLUMN ksx.line.valid_end_date IS '유효종료일';
COMMENT ON COLUMN ksx.enterprise.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.enterprise.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.enterprise.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.enterprise.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.enterprise.note IS '비고';
COMMENT ON COLUMN ksx.enterprise.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.enterprise.enterprise_name IS '회사명';
COMMENT ON COLUMN ksx.enterprise.business_registration_number IS '사업자등록번호';
COMMENT ON COLUMN ksx.enterprise.corporate_registration_number IS '법인등록번호';
COMMENT ON COLUMN ksx.enterprise.representative_name IS '대표자명';
COMMENT ON COLUMN ksx.enterprise.parent_enterprise_id IS '상위회사식별자';
COMMENT ON COLUMN ksx.enterprise.country_id IS '국가식별자';
COMMENT ON COLUMN ksx.enterprise.base_currency_code IS '기준통화코드';
COMMENT ON COLUMN ksx.enterprise.dial_number IS '전화번호';
COMMENT ON COLUMN ksx.enterprise.fax_number IS '팩스번호';
COMMENT ON COLUMN ksx.enterprise.postal_code IS '우편번호';
COMMENT ON COLUMN ksx.enterprise.base_address IS '기본주소';
COMMENT ON COLUMN ksx.enterprise.detail_address IS '상세주소';
COMMENT ON COLUMN ksx.enterprise.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.project_master.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.project_master.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.project_master.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.project_master.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.project_master.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.project_master.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.project_master.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.project_master.note IS '비고';
COMMENT ON COLUMN ksx.project_master.project_id IS '프로젝트식별자';
COMMENT ON COLUMN ksx.project_master.project_name IS '프로젝트명';
COMMENT ON COLUMN ksx.project_master.project_status_code IS '프로젝트상태코드';
COMMENT ON COLUMN ksx.project_master.responsible_department_id IS '프로젝트담당부서식별자';
COMMENT ON COLUMN ksx.project_master.person_in_charge_id IS '프로젝트담당자식별자';
COMMENT ON COLUMN ksx.project_master.project_contract_date IS '프로젝트계약일';
COMMENT ON COLUMN ksx.project_master.expected_start_date IS '시작예정일';
COMMENT ON COLUMN ksx.project_master.expected_end_date IS '종료예정일';
COMMENT ON COLUMN ksx.project_master.actual_start_date IS '실제시작일';
COMMENT ON COLUMN ksx.project_master.actual_end_date IS '실제종료일';
COMMENT ON COLUMN ksx.project_master.sales_document_number IS '수주문서번호';
COMMENT ON COLUMN ksx.project_master.sales_document_sequence IS '수주문서순번';
COMMENT ON COLUMN ksx.project_master.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.project_master.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.project_master.division_id IS '사업부식별자';
COMMENT ON COLUMN ksx.engineering_change_order.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.engineering_change_order.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.engineering_change_order.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.engineering_change_order.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.engineering_change_order.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.engineering_change_order.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.engineering_change_order.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.engineering_change_order.note IS '비고';
COMMENT ON COLUMN ksx.engineering_change_order.engineering_change_order_id IS '설계변경지시식별자';
COMMENT ON COLUMN ksx.engineering_change_order.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.engineering_change_order.valid_start_date IS '유효시작일';
COMMENT ON COLUMN ksx.engineering_change_order.valid_end_date IS '유효종료일';
COMMENT ON COLUMN ksx.engineering_change_order.expected_execution_date IS '적용예정일';
COMMENT ON COLUMN ksx.engineering_change_order.execution_date IS '적용이행일';
COMMENT ON COLUMN ksx.engineering_change_order.bom_type IS '자재명세서유형';
COMMENT ON COLUMN ksx.engineering_change_order.bom_id IS '자재명세서식별자';
COMMENT ON COLUMN ksx.engineering_change_order.bom_revision_number IS '자재명세서버전';
COMMENT ON COLUMN ksx.engineering_change_order.child_item_id IS '자품목식별자';
COMMENT ON COLUMN ksx.engineering_change_order.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.engineering_change_order.actual_requirement_quantity IS '실소요수량';
COMMENT ON COLUMN ksx.sales_order.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.sales_order.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.sales_order.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.sales_order.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.sales_order.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.sales_order.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.sales_order.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.sales_order.note IS '비고';
COMMENT ON COLUMN ksx.sales_order.sales_order_id IS '수주오더식별자';
COMMENT ON COLUMN ksx.sales_order.sales_document_number IS '수주문서번호';
COMMENT ON COLUMN ksx.sales_order.sales_document_sequence IS '수주문서순번';
COMMENT ON COLUMN ksx.sales_order.sales_order_type IS '수주유형';
COMMENT ON COLUMN ksx.sales_order.customer_id IS '고객사식별자';
COMMENT ON COLUMN ksx.sales_order.sales_date IS '수주일';
COMMENT ON COLUMN ksx.sales_order.requested_delivery_date IS '요청납기일';
COMMENT ON COLUMN ksx.sales_order.sales_status IS '수주상태';
COMMENT ON COLUMN ksx.sales_order.shipment_terms_code IS '출하조건코드';
COMMENT ON COLUMN ksx.sales_order.sales_transaction_type IS '거래유형';
COMMENT ON COLUMN ksx.sales_order.return_indicator IS '반품여부';
COMMENT ON COLUMN ksx.sales_order.export_indicator IS '수출여부';
COMMENT ON COLUMN ksx.sales_order.sales_automatic_approval_indicator IS '수주자동승인여부';
COMMENT ON COLUMN ksx.sales_order.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.sales_order.item_name IS '품목명';
COMMENT ON COLUMN ksx.sales_order.item_quantity IS '품목수량';
COMMENT ON COLUMN ksx.sales_order.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.sales_order.selling_uom_code IS '판매단위코드';
COMMENT ON COLUMN ksx.sales_order.conversion_unit_quantity IS '단위환산수량';
COMMENT ON COLUMN ksx.sales_order.item_unit_quantity IS '기준단위수량';
COMMENT ON COLUMN ksx.sales_plan.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.sales_plan.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.sales_plan.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.sales_plan.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.sales_plan.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.sales_plan.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.sales_plan.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.sales_plan.note IS '비고';
COMMENT ON COLUMN ksx.sales_plan.sales_plan_id IS '판매계획식별자';
COMMENT ON COLUMN ksx.sales_plan.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.sales_plan.item_name IS '품목명';
COMMENT ON COLUMN ksx.sales_plan.sales_projection IS '판매추정치';
COMMENT ON COLUMN ksx.sales_plan.projection_start_date IS '예측시작일';
COMMENT ON COLUMN ksx.sales_plan.projection_end_date IS '예측종료일';
COMMENT ON COLUMN ksx.base_price.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.base_price.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.base_price.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.base_price.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.base_price.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.base_price.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.base_price.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.base_price.note IS '비고';
COMMENT ON COLUMN ksx.base_price.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.base_price.currency_code IS '환종코드';
COMMENT ON COLUMN ksx.base_price.unit_price IS '단가';
COMMENT ON COLUMN ksx.base_price.payment_terms_code IS '결제조건코드';
COMMENT ON COLUMN ksx.base_price.use_indicator IS '사용여부';
COMMENT ON COLUMN ksx.purchase_requisition.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.purchase_requisition.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.purchase_requisition.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.purchase_requisition.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.purchase_requisition.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.purchase_requisition.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.purchase_requisition.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.purchase_requisition.note IS '비고';
COMMENT ON COLUMN ksx.purchase_requisition.purchase_requisition_id IS '구매요청식별자';
COMMENT ON COLUMN ksx.purchase_requisition.purchase_requisition_revision_number IS '구매요청버전';
COMMENT ON COLUMN ksx.purchase_requisition.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.purchase_requisition.item_name IS '품목명';
COMMENT ON COLUMN ksx.purchase_requisition.demand_quantity IS '구매요청수량';
COMMENT ON COLUMN ksx.purchase_requisition.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.purchase_requisition.purchase_requisition_unit_price IS '구매요청단가';
COMMENT ON COLUMN ksx.purchase_requisition.currency_code IS '환종코드';
COMMENT ON COLUMN ksx.purchase_requisition.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.purchase_requisition.vendor_name IS '공급사명';
COMMENT ON COLUMN ksx.purchase_requisition.requested_delivery_date IS '요청납기일';
COMMENT ON COLUMN ksx.purchase_requisition.requester_department_id IS '구매요청부서';
COMMENT ON COLUMN ksx.purchase_requisition.requester_personnel_id IS '구매요청자';
COMMENT ON COLUMN ksx.purchase_order.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.purchase_order.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.purchase_order.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.purchase_order.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.purchase_order.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.purchase_order.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.purchase_order.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.purchase_order.note IS '비고';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_id IS '구매발주식별자';
COMMENT ON COLUMN ksx.purchase_order.purchase_document_number IS '구매문서번호';
COMMENT ON COLUMN ksx.purchase_order.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.purchase_order.payment_terms_code IS '결제조건코드';
COMMENT ON COLUMN ksx.purchase_order.purchase_group_code IS '구매그룹코드';
COMMENT ON COLUMN ksx.purchase_order.currency_code IS '환종코드';
COMMENT ON COLUMN ksx.purchase_order.exchange_rate IS '환율';
COMMENT ON COLUMN ksx.purchase_order.purchase_approval_date IS '승인일';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_date IS '구매발주일';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_type_code IS '발주유형코드';
COMMENT ON COLUMN ksx.purchase_order.purchase_transaction_type IS '거래유형';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_start_date IS '시작일';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_valid_date IS '유효일';
COMMENT ON COLUMN ksx.purchase_order.personnel_id IS '사원식별자';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_closing_indicator IS '발주마감여부';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_closing_date IS '발주마감일';
COMMENT ON COLUMN ksx.purchase_order.purchase_document_sequence IS '구매문서순번';
COMMENT ON COLUMN ksx.purchase_order.item_purchase_type IS '구매라인유형';
COMMENT ON COLUMN ksx.purchase_order.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.purchase_order.item_name IS '품목명';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_line_status_code IS '발주라인상태코드';
COMMENT ON COLUMN ksx.purchase_order.tax_code IS '세무코드';
COMMENT ON COLUMN ksx.purchase_order.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_uom_code IS '발주단위코드';
COMMENT ON COLUMN ksx.purchase_order.conversion_unit_quantity IS '단위환산수량';
COMMENT ON COLUMN ksx.purchase_order.item_unit_quantity IS '기준단위수량';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_quantity IS '구매발주수량';
COMMENT ON COLUMN ksx.purchase_order.purchase_goods_receipt_quantity IS '구매입고수량';
COMMENT ON COLUMN ksx.purchase_order.purchase_transaction_unit_price IS '구매거래단가';
COMMENT ON COLUMN ksx.purchase_order.purchase_transaction_price IS '구매거래금액';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_unit_price IS '발주단가';
COMMENT ON COLUMN ksx.purchase_order.purchase_order_price IS '발주금액';
COMMENT ON COLUMN ksx.purchase_order.vat_price IS '부가세금액';
COMMENT ON COLUMN ksx.purchase_order.expected_delivery_date IS '납기예정일';
COMMENT ON COLUMN ksx.purchase_order.incoming_inspection_indicator IS '수입검사여부';
COMMENT ON COLUMN ksx.purchase_order.account_code IS '계정코드';
COMMENT ON COLUMN ksx.purchase_order.vat_transaction_unit_price IS '부가세포함거래단가';
COMMENT ON COLUMN ksx.purchase_order.vat_transaction_price IS '부가세포함거래금액';
COMMENT ON COLUMN ksx.purchase_order.vat_carrying_amount IS '부가세포함장부금액';
COMMENT ON COLUMN ksx.material_arrival.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.material_arrival.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.material_arrival.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.material_arrival.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.material_arrival.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.material_arrival.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.material_arrival.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.material_arrival.note IS '비고';
COMMENT ON COLUMN ksx.material_arrival.purchase_document_number IS '구매문서번호';
COMMENT ON COLUMN ksx.material_arrival.purchase_document_sequence IS '구매문서순번';
COMMENT ON COLUMN ksx.material_arrival.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.material_arrival.purchase_goods_receipt_quantity IS '구매입고수량';
COMMENT ON COLUMN ksx.material_arrival.receipt_warehouse_id IS '입고창고식별자';
COMMENT ON COLUMN ksx.material_arrival.goods_receipt_date IS '입고처리일';
COMMENT ON COLUMN ksx.material_arrival.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.material_arrival.item_quantity IS '품목수량';
COMMENT ON COLUMN ksx.material_arrival.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.goods_receipt.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.goods_receipt.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.goods_receipt.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.goods_receipt.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.goods_receipt.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.goods_receipt.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.goods_receipt.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.goods_receipt.note IS '비고';
COMMENT ON COLUMN ksx.goods_receipt.goods_receipt_id IS '입고식별자';
COMMENT ON COLUMN ksx.goods_receipt.warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx.goods_receipt.personnel_id IS '사원식별자';
COMMENT ON COLUMN ksx.goods_receipt.goods_receipt_sequence IS '입고순번';
COMMENT ON COLUMN ksx.goods_receipt.goods_receipt_type IS '입고처리유형';
COMMENT ON COLUMN ksx.goods_receipt.goods_receipt_return_type IS '입고반품유형';
COMMENT ON COLUMN ksx.goods_receipt.goods_receipt_date IS '입고처리일';
COMMENT ON COLUMN ksx.goods_receipt.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.goods_receipt.item_name IS '품목명';
COMMENT ON COLUMN ksx.goods_receipt.inventory_transaction_document_number IS '수불문서번호';
COMMENT ON COLUMN ksx.goods_receipt.inventory_transaction_document_sequence IS '수불문서순번';
COMMENT ON COLUMN ksx.goods_receipt.inventory_transaction_type_code IS '수불유형코드';
COMMENT ON COLUMN ksx.goods_receipt.invoice_number IS '송장번호';
COMMENT ON COLUMN ksx.goods_receipt.invoice_sequence IS '송장라인순번';
COMMENT ON COLUMN ksx.goods_receipt.invoice_processing_indicator IS '송장처리여부';
COMMENT ON COLUMN ksx.goods_receipt.incoming_inspection_indicator IS '수입검사여부';
COMMENT ON COLUMN ksx.goods_receipt.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.goods_receipt.purchase_order_uom_code IS '발주단위코드';
COMMENT ON COLUMN ksx.goods_receipt.item_unit_quantity IS '기준단위수량';
COMMENT ON COLUMN ksx.goods_receipt.goods_receipt_quantity IS '입고처리수량';
COMMENT ON COLUMN ksx.goods_receipt.incoming_inspection_accepted_quantity IS '수입검사합격수량';
COMMENT ON COLUMN ksx.goods_receipt.incoming_inspection_rejected_quantity IS '수입검사불합격수량';
COMMENT ON COLUMN ksx.goods_receipt.purchase_group_code IS '구매그룹코드';
COMMENT ON COLUMN ksx.goods_receipt.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.goods_issue.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.goods_issue.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.goods_issue.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.goods_issue.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.goods_issue.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.goods_issue.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.goods_issue.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.goods_issue.note IS '비고';
COMMENT ON COLUMN ksx.goods_issue.goods_issue_id IS '자재불출식별자';
COMMENT ON COLUMN ksx.goods_issue.inventory_transaction_document_number IS '수불문서번호';
COMMENT ON COLUMN ksx.goods_issue.inventory_transaction_document_sequence IS '수불문서순번';
COMMENT ON COLUMN ksx.goods_issue.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.goods_issue.inventory_transaction_type_code IS '수불유형코드';
COMMENT ON COLUMN ksx.goods_issue.inventory_transfer_type IS '입출고유형';
COMMENT ON COLUMN ksx.goods_issue.inventory_variation_type IS '재고증감유형';
COMMENT ON COLUMN ksx.goods_issue.inventory_transaction_type IS '수불유형';
COMMENT ON COLUMN ksx.goods_issue.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.goods_issue.serial_use_indicator IS '시리얼사용여부';
COMMENT ON COLUMN ksx.goods_issue.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.goods_issue.warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx.goods_issue.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.goods_issue.item_unit_quantity IS '기준단위수량';
COMMENT ON COLUMN ksx.goods_issue.order_uom_code IS '오더단위코드';
COMMENT ON COLUMN ksx.goods_issue.order_quantity IS '오더수량';
COMMENT ON COLUMN ksx.production_planning.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.production_planning.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.production_planning.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.production_planning.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.production_planning.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.production_planning.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.production_planning.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.production_planning.note IS '비고';
COMMENT ON COLUMN ksx.production_planning.production_plan_id IS '생산계획식별자';
COMMENT ON COLUMN ksx.production_planning.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.production_planning.production_plan_quantity IS '생산계획수량';
COMMENT ON COLUMN ksx.production_planning.schedule_start_date_time IS '생산계획시작일시';
COMMENT ON COLUMN ksx.production_planning.schedule_end_date_time IS '생산계획종료일시';
COMMENT ON COLUMN ksx.production_order.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.production_order.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.production_order.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.production_order.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.production_order.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.production_order.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.production_order.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.production_order.note IS '비고';
COMMENT ON COLUMN ksx.production_order.production_order_id IS '생산지시식별자';
COMMENT ON COLUMN ksx.production_order.production_order_sequence IS '생산지시순번';
COMMENT ON COLUMN ksx.production_order.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.production_order.line_id IS '라인식별자';
COMMENT ON COLUMN ksx.production_order.routing_id IS '공정경로식별자';
COMMENT ON COLUMN ksx.production_order.bom_id IS '자재명세서식별자';
COMMENT ON COLUMN ksx.production_order.bom_revision_number IS '자재명세서버전';
COMMENT ON COLUMN ksx.production_order.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.production_order.production_order_quantity IS '생산지시수량';
COMMENT ON COLUMN ksx.production_order.production_due_date_time IS '생산완료기한일시';
COMMENT ON COLUMN ksx.production_order.schedule_start_date_time IS '생산계획시작일시';
COMMENT ON COLUMN ksx.production_order.schedule_end_date_time IS '생산계획종료일시';
COMMENT ON COLUMN ksx.production_order.sales_document_number IS '수주문서번호';
COMMENT ON COLUMN ksx.production_order.sales_document_sequence IS '수주문서순번';
COMMENT ON COLUMN ksx.operation_start.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.operation_start.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.operation_start.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.operation_start.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.operation_start.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.operation_start.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.operation_start.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.operation_start.note IS '비고';
COMMENT ON COLUMN ksx.operation_start.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.operation_start.lot_name IS '로트명';
COMMENT ON COLUMN ksx.operation_start.lot_description IS '로트설명';
COMMENT ON COLUMN ksx.operation_start.lot_created_quantity IS '로트수량';
COMMENT ON COLUMN ksx.operation_start.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.operation_start.equipment_id IS '설비식별자';
COMMENT ON COLUMN ksx.operation_start.operation_start_time IS '착공시간';
COMMENT ON COLUMN ksx.operation_start.personnel_id IS '사원식별자';
COMMENT ON COLUMN ksx.operation_end.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.operation_end.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.operation_end.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.operation_end.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.operation_end.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.operation_end.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.operation_end.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.operation_end.note IS '비고';
COMMENT ON COLUMN ksx.operation_end.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.operation_end.lot_name IS '로트명';
COMMENT ON COLUMN ksx.operation_end.lot_description IS '로트설명';
COMMENT ON COLUMN ksx.operation_end.lot_created_quantity IS '로트수량';
COMMENT ON COLUMN ksx.operation_end.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.operation_end.equipment_id IS '설비식별자';
COMMENT ON COLUMN ksx.operation_end.operation_end_time IS '완공시간';
COMMENT ON COLUMN ksx.operation_end.personnel_id IS '사원식별자';
COMMENT ON COLUMN ksx.operation_end.produced_quantity IS '생산수량';
COMMENT ON COLUMN ksx.operation_end.defect_quantity IS '불량수량';
COMMENT ON COLUMN ksx.operation_end.rework_count IS '재작업횟수';
COMMENT ON COLUMN ksx.transfer_command.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.transfer_command.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.transfer_command.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.transfer_command.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.transfer_command.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.transfer_command.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.transfer_command.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.transfer_command.note IS '비고';
COMMENT ON COLUMN ksx.transfer_command.transfer_command_id IS '이동지시식별자';
COMMENT ON COLUMN ksx.transfer_command.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.transfer_command.lot_name IS '로트명';
COMMENT ON COLUMN ksx.transfer_command.lot_description IS '로트설명';
COMMENT ON COLUMN ksx.transfer_command.carrier_id IS '캐리어식별자';
COMMENT ON COLUMN ksx.transfer_command.source_id IS '출발지식별자';
COMMENT ON COLUMN ksx.transfer_command.source_type IS '출발지유형';
COMMENT ON COLUMN ksx.transfer_command.source_name IS '출발지명';
COMMENT ON COLUMN ksx.transfer_command.destination_id IS '목적지식별자';
COMMENT ON COLUMN ksx.transfer_command.destination_type IS '목적지유형';
COMMENT ON COLUMN ksx.transfer_command.destination_name IS '목적지명';
COMMENT ON COLUMN ksx.transfer_start.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.transfer_start.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.transfer_start.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.transfer_start.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.transfer_start.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.transfer_start.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.transfer_start.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.transfer_start.note IS '비고';
COMMENT ON COLUMN ksx.transfer_start.transfer_command_id IS '이동지시식별자';
COMMENT ON COLUMN ksx.transfer_start.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.transfer_start.lot_name IS '로트명';
COMMENT ON COLUMN ksx.transfer_start.lot_description IS '로트설명';
COMMENT ON COLUMN ksx.transfer_start.carrier_id IS '캐리어식별자';
COMMENT ON COLUMN ksx.transfer_start.transfer_start_date_time IS '운행시작일시';
COMMENT ON COLUMN ksx.transfer_start.current_location IS '현재위치';
COMMENT ON COLUMN ksx.transfer_start.destination_id IS '목적지식별자';
COMMENT ON COLUMN ksx.transfer_start.destination_type IS '목적지유형';
COMMENT ON COLUMN ksx.transfer_start.destination_name IS '목적지명';
COMMENT ON COLUMN ksx.transfer_start.error_code IS '오류코드';
COMMENT ON COLUMN ksx.transfer_start.error_message IS '오류메세지';
COMMENT ON COLUMN ksx.transfer_end.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.transfer_end.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.transfer_end.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.transfer_end.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.transfer_end.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.transfer_end.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.transfer_end.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.transfer_end.note IS '비고';
COMMENT ON COLUMN ksx.transfer_end.transfer_command_id IS '이동지시식별자';
COMMENT ON COLUMN ksx.transfer_end.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.transfer_end.lot_name IS '로트명';
COMMENT ON COLUMN ksx.transfer_end.lot_description IS '로트설명';
COMMENT ON COLUMN ksx.transfer_end.carrier_id IS '캐리어식별자';
COMMENT ON COLUMN ksx.transfer_end.transfer_end_date_time IS '운행완료일시';
COMMENT ON COLUMN ksx.transfer_end.destination_id IS '목적지식별자';
COMMENT ON COLUMN ksx.transfer_end.destination_type IS '목적지유형';
COMMENT ON COLUMN ksx.transfer_end.destination_name IS '목적지명';
COMMENT ON COLUMN ksx.in_transit_location.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.in_transit_location.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.in_transit_location.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.in_transit_location.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.in_transit_location.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.in_transit_location.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.in_transit_location.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.in_transit_location.note IS '비고';
COMMENT ON COLUMN ksx.in_transit_location.transfer_command_id IS '이동지시식별자';
COMMENT ON COLUMN ksx.in_transit_location.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.in_transit_location.lot_name IS '로트명';
COMMENT ON COLUMN ksx.in_transit_location.lot_description IS '로트설명';
COMMENT ON COLUMN ksx.in_transit_location.carrier_id IS '캐리어식별자';
COMMENT ON COLUMN ksx.in_transit_location.current_location IS '현재위치';
COMMENT ON COLUMN ksx.equipment_state.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.equipment_state.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.equipment_state.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.equipment_state.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.equipment_state.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.equipment_state.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.equipment_state.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.equipment_state.note IS '비고';
COMMENT ON COLUMN ksx.equipment_state.equipment_id IS '설비식별자';
COMMENT ON COLUMN ksx.equipment_state.equipment_state IS '설비상태';
COMMENT ON COLUMN ksx.equipment_state.equipment_control_mode IS '설비제어모드';
COMMENT ON COLUMN ksx.equipment_state.equipment_operation_mode IS '설비운영모드';
COMMENT ON COLUMN ksx.equipment_state.processed_lot_quantity IS '진행로트수량';
COMMENT ON COLUMN ksx.equipment_state.last_processed_lot_id IS '최종진행로트식별자';
COMMENT ON COLUMN ksx.equipment_state.last_processed_operation_id IS '최종진행공정식별자';
COMMENT ON COLUMN ksx.equipment_state.error_code IS '오류코드';
COMMENT ON COLUMN ksx.equipment_state.error_message IS '오류메세지';
COMMENT ON COLUMN ksx.alarm.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.alarm.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.alarm.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.alarm.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.alarm.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.alarm.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.alarm.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.alarm.note IS '비고';
COMMENT ON COLUMN ksx.alarm.equipment_id IS '설비식별자';
COMMENT ON COLUMN ksx.alarm.alarm_state IS '알람상태';
COMMENT ON COLUMN ksx.alarm.error_code IS '오류코드';
COMMENT ON COLUMN ksx.alarm.error_message IS '오류메세지';
COMMENT ON COLUMN ksx.alarm.event_date_time IS '이벤트발생일시';
COMMENT ON COLUMN ksx.alarm.current_location IS '현재위치';
COMMENT ON COLUMN ksx.supplier_inspection_plan.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.supplier_inspection_plan.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.supplier_inspection_plan.note IS '비고';
COMMENT ON COLUMN ksx.supplier_inspection_plan.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.project_id IS '프로젝트식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.item_name IS '품목명';
COMMENT ON COLUMN ksx.supplier_inspection_plan.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.supplier_inspection_plan.purchase_order_id IS '구매발주식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.purchase_order_quantity IS '구매발주수량';
COMMENT ON COLUMN ksx.supplier_inspection_plan.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.batch_id IS '배치식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.expected_delivery_date IS '납기예정일';
COMMENT ON COLUMN ksx.supplier_inspection_plan.inspection_plan_id IS '검사계획식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.inspection_id IS '검사식별자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.inspection_name IS '검사명';
COMMENT ON COLUMN ksx.supplier_inspection_plan.inspector IS '검사자';
COMMENT ON COLUMN ksx.supplier_inspection_plan.inspection_location IS '검사위치';
COMMENT ON COLUMN ksx.supplier_inspection_plan.expected_inspection_date IS '검사예정일';
COMMENT ON COLUMN ksx.supplier_inspection_plan.expected_inspection_time_period IS '검사예정기간';
COMMENT ON COLUMN ksx.supplier_inspection_plan.inspection_method IS '검사방법';
COMMENT ON COLUMN ksx.supplier_inspection_plan.inspection_plan_quantity IS '검사계획수량';
COMMENT ON COLUMN ksx.supplier_inspection_plan.inspection_check_sheet IS '검사체크시트';
COMMENT ON COLUMN ksx.supplier_inspection_application.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.supplier_inspection_application.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.supplier_inspection_application.note IS '비고';
COMMENT ON COLUMN ksx.supplier_inspection_application.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.project_id IS '프로젝트식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.item_name IS '품목명';
COMMENT ON COLUMN ksx.supplier_inspection_application.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.supplier_inspection_application.purchase_order_id IS '구매발주식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.batch_id IS '배치식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.inspection_plan_id IS '검사계획식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.inspection_id IS '검사식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.inspection_application_id IS '검사신청식별자';
COMMENT ON COLUMN ksx.supplier_inspection_application.application_personnel_id IS '검사신청자';
COMMENT ON COLUMN ksx.supplier_inspection_application.inspection_name IS '검사명';
COMMENT ON COLUMN ksx.supplier_inspection_application.inspection_location IS '검사위치';
COMMENT ON COLUMN ksx.supplier_inspection_application.inspection_method IS '검사방법';
COMMENT ON COLUMN ksx.supplier_inspection_application.expected_inspection_date IS '검사예정일';
COMMENT ON COLUMN ksx.supplier_inspection_application.inspection_date IS '검사일';
COMMENT ON COLUMN ksx.supplier_inspection_application.inspection_time_period IS '검사기간';
COMMENT ON COLUMN ksx.supplier_inspection_application.inspection_quantity IS '검사수량';
COMMENT ON COLUMN ksx.supplier_inspection_application.self_check_inspection_result_sheet IS '자체점검결과시트';
COMMENT ON COLUMN ksx.supplier_inspection_application.inspection_status_code IS '검사상태코드';
COMMENT ON COLUMN ksx.supplier_inspection_application.reason_for_application IS '검사신청사유';
COMMENT ON COLUMN ksx.supplier_inspection_application.inspection_cancel_reason IS '검사취소사유';
COMMENT ON COLUMN ksx.supplier_inspection_result.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.supplier_inspection_result.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.supplier_inspection_result.note IS '비고';
COMMENT ON COLUMN ksx.supplier_inspection_result.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.project_id IS '프로젝트식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.item_name IS '품목명';
COMMENT ON COLUMN ksx.supplier_inspection_result.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.batch_id IS '배치식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspection_plan_id IS '검사계획식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspection_id IS '검사식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspection_application_id IS '검사신청식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspection_result_id IS '검사결과식별자';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspector IS '검사자';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspection_participant IS '검사입회자';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspection_location IS '검사위치';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspection_date IS '검사일';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspection_quantity IS '검사수량';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspection_result IS '검사결과';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspection_result_sheet IS '검사결과시트';
COMMENT ON COLUMN ksx.supplier_inspection_result.inspection_status_code IS '검사상태코드';
COMMENT ON COLUMN ksx.corrective_action_request.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.corrective_action_request.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.corrective_action_request.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.corrective_action_request.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.corrective_action_request.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.corrective_action_request.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.corrective_action_request.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.corrective_action_request.note IS '비고';
COMMENT ON COLUMN ksx.corrective_action_request.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.corrective_action_request.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.corrective_action_request.item_name IS '품목명';
COMMENT ON COLUMN ksx.corrective_action_request.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.corrective_action_request.batch_id IS '배치식별자';
COMMENT ON COLUMN ksx.corrective_action_request.inspection_application_id IS '검사신청식별자';
COMMENT ON COLUMN ksx.corrective_action_request.corrective_action_request_id IS '시정조치요청식별자';
COMMENT ON COLUMN ksx.corrective_action_request.corrective_action_request_issuer_id IS '시정조치요청발행자식별자';
COMMENT ON COLUMN ksx.corrective_action_request.corrective_action_request_recipient_id IS '시정조치요청접수자식별자';
COMMENT ON COLUMN ksx.corrective_action_request.corrective_action_request_location IS '시정조치요청위치';
COMMENT ON COLUMN ksx.corrective_action_request.corrective_action_request_document_reference IS '시정조치요청첨부자료';
COMMENT ON COLUMN ksx.corrective_action_plan.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.corrective_action_plan.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.corrective_action_plan.note IS '비고';
COMMENT ON COLUMN ksx.corrective_action_plan.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.item_name IS '품목명';
COMMENT ON COLUMN ksx.corrective_action_plan.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.batch_id IS '배치식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.corrective_action_request_id IS '시정조치요청식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.corrective_action_plan_id IS '시정조치계획식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.person_in_charge_id IS '시정조치담당자식별자';
COMMENT ON COLUMN ksx.corrective_action_plan.person_in_charge_email IS '시정조치담당자이메일명';
COMMENT ON COLUMN ksx.corrective_action_plan.person_in_charge_dial_number IS '시정조치담당자전화번호';
COMMENT ON COLUMN ksx.corrective_action_plan.expected_corrective_action_date IS '시정조치예정일';
COMMENT ON COLUMN ksx.corrective_action_plan.corrective_action_request_document_reference IS '시정조치요청첨부자료';
COMMENT ON COLUMN ksx.corrective_action_plan.corrective_action_approval_indicator IS '시정조치접수여부';
COMMENT ON COLUMN ksx.corrective_action_plan.corrective_action_status_code IS '시정조치상태코드';
COMMENT ON COLUMN ksx.corrective_action_plan.reason_for_rejection IS '반려사유';
COMMENT ON COLUMN ksx.corrective_action_result.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.corrective_action_result.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.corrective_action_result.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.corrective_action_result.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.corrective_action_result.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.corrective_action_result.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.corrective_action_result.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.corrective_action_result.note IS '비고';
COMMENT ON COLUMN ksx.corrective_action_result.vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx.corrective_action_result.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.corrective_action_result.item_name IS '품목명';
COMMENT ON COLUMN ksx.corrective_action_result.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.corrective_action_result.batch_id IS '배치식별자';
COMMENT ON COLUMN ksx.corrective_action_result.corrective_action_request_id IS '시정조치요청식별자';
COMMENT ON COLUMN ksx.corrective_action_result.corrective_action_plan_id IS '시정조치계획식별자';
COMMENT ON COLUMN ksx.corrective_action_result.corrective_action_result_id IS '시정조치결과식별자';
COMMENT ON COLUMN ksx.corrective_action_result.person_in_charge_id IS '시정조치담당자식별자';
COMMENT ON COLUMN ksx.corrective_action_result.person_in_charge_email IS '시정조치담당자이메일명';
COMMENT ON COLUMN ksx.corrective_action_result.person_in_charge_dial_number IS '시정조치담당자전화번호';
COMMENT ON COLUMN ksx.corrective_action_result.corrective_action_confirmor_id IS '시정조치확인자식별자';
COMMENT ON COLUMN ksx.corrective_action_result.corrective_action_confirmor_email IS '시정조치확인자이메일명';
COMMENT ON COLUMN ksx.corrective_action_result.corrective_action_confirmor_dial_number IS '시정조치확인자전화번호';
COMMENT ON COLUMN ksx.corrective_action_result.corrective_action_date_time IS '시정조치일시';
COMMENT ON COLUMN ksx.corrective_action_result.corrective_action_result_description IS '시정조치결과내용';
COMMENT ON COLUMN ksx.corrective_action_result.corrective_action_status_code IS '시정조치상태코드';
COMMENT ON COLUMN ksx.corrective_action_result.reason_for_rejection IS '반려사유';
COMMENT ON COLUMN ksx.product_packing.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.product_packing.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.product_packing.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.product_packing.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.product_packing.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.product_packing.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.product_packing.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.product_packing.note IS '비고';
COMMENT ON COLUMN ksx.product_packing.packing_type IS '포장유형';
COMMENT ON COLUMN ksx.product_packing.warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx.product_packing.serial_number IS '일련번호';
COMMENT ON COLUMN ksx.product_packing.box_number IS '포장박스번호';
COMMENT ON COLUMN ksx.product_packing.pallet_number IS '포장파렛트번호';
COMMENT ON COLUMN ksx.product_packing.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.product_packing.packing_sequence IS '포장순번';
COMMENT ON COLUMN ksx.product_packing.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.equipment_parameter.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.equipment_parameter.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.equipment_parameter.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.equipment_parameter.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.equipment_parameter.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.equipment_parameter.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.equipment_parameter.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.equipment_parameter.note IS '비고';
COMMENT ON COLUMN ksx.equipment_parameter.parameter_id IS '파라미터식별자';
COMMENT ON COLUMN ksx.equipment_parameter.parameter_name IS '파라미터명';
COMMENT ON COLUMN ksx.equipment_parameter.parameter_type IS '파라미터유형';
COMMENT ON COLUMN ksx.equipment_parameter.parameter_grade IS '파라미터등급';
COMMENT ON COLUMN ksx.equipment_parameter.parameter_uom_code IS '파라미터단위코드';
COMMENT ON COLUMN ksx.equipment_parameter.equipment_id IS '설비식별자';
COMMENT ON COLUMN ksx.equipment_parameter.lsl IS '규격하한';
COMMENT ON COLUMN ksx.equipment_parameter.usl IS '규격상한';
COMMENT ON COLUMN ksx.equipment_parameter.periodic_data_collection_indicator IS '주기적수집여부';
COMMENT ON COLUMN ksx.equipment_parameter.data_collection_period IS '수집주기';
COMMENT ON COLUMN ksx.trace_parameter.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.trace_parameter.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.trace_parameter.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.trace_parameter.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.trace_parameter.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.trace_parameter.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.trace_parameter.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.trace_parameter.note IS '비고';
COMMENT ON COLUMN ksx.trace_parameter.equipment_id IS '설비식별자';
COMMENT ON COLUMN ksx.trace_parameter.parameter_id IS '파라미터식별자';
COMMENT ON COLUMN ksx.trace_parameter.event_date_time IS '이벤트발생일시';
COMMENT ON COLUMN ksx.trace_parameter.parameter_uom_code IS '파라미터단위코드';
COMMENT ON COLUMN ksx.trace_parameter.parameter_value IS '파라미터값';
COMMENT ON COLUMN ksx.trace_parameter.validation_result_code IS '검증결과코드';
COMMENT ON COLUMN ksx.production_performance.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.production_performance.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.production_performance.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.production_performance.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.production_performance.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.production_performance.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.production_performance.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.production_performance.note IS '비고';
COMMENT ON COLUMN ksx.production_performance.production_performance_id IS '생산실적식별자';
COMMENT ON COLUMN ksx.production_performance.production_performance_sequence IS '생산실적순번';
COMMENT ON COLUMN ksx.production_performance.production_order_id IS '생산지시식별자';
COMMENT ON COLUMN ksx.production_performance.production_order_sequence IS '생산지시순번';
COMMENT ON COLUMN ksx.production_performance.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.production_performance.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.production_performance.produced_quantity IS '생산수량';
COMMENT ON COLUMN ksx.production_performance.defect_quantity IS '불량수량';
COMMENT ON COLUMN ksx.production_performance.rework_quantity IS '재작업수량';
COMMENT ON COLUMN ksx.production_performance.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.production_performance.routing_id IS '공정경로식별자';
COMMENT ON COLUMN ksx.production_performance.operation_sequence IS '공정순번';
COMMENT ON COLUMN ksx.production_performance.personnel_id IS '사원식별자';
COMMENT ON COLUMN ksx.production_performance.production_performance_date IS '생산실적일자';
COMMENT ON COLUMN ksx.production_performance.execution_start_date_time IS '생산시작일시';
COMMENT ON COLUMN ksx.production_performance.execution_end_date_time IS '생산종료일시';
COMMENT ON COLUMN ksx.production_performance.cancel_indicator IS '취소여부';
COMMENT ON COLUMN ksx.production_performance.cancel_date_time IS '취소일시';
COMMENT ON COLUMN ksx.production_performance.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.production_performance.batch_id IS '배치식별자';
COMMENT ON COLUMN ksx.production_performance_item.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.production_performance_item.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.production_performance_item.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.production_performance_item.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.production_performance_item.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.production_performance_item.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.production_performance_item.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.production_performance_item.note IS '비고';
COMMENT ON COLUMN ksx.production_performance_item.production_performance_id IS '생산실적식별자';
COMMENT ON COLUMN ksx.production_performance_item.production_performance_sequence IS '생산실적순번';
COMMENT ON COLUMN ksx.production_performance_item.production_order_id IS '생산지시식별자';
COMMENT ON COLUMN ksx.production_performance_item.production_order_sequence IS '생산지시순번';
COMMENT ON COLUMN ksx.production_performance_item.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.production_performance_item.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.production_performance_item.line_id IS '라인식별자';
COMMENT ON COLUMN ksx.production_performance_item.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.production_performance_item.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.production_performance_item.replacement_child_item_id IS '대체자재식별자';
COMMENT ON COLUMN ksx.production_performance_item.warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx.production_performance_item.warehouse_section IS '창고섹션';
COMMENT ON COLUMN ksx.production_performance_item.required_quantity IS '소요수량';
COMMENT ON COLUMN ksx.production_performance_item.issued_quantity IS '출고수량';
COMMENT ON COLUMN ksx.production_performance_item.issued_indicator IS '출고완료여부';
COMMENT ON COLUMN ksx.production_performance_personnel.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.production_performance_personnel.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.production_performance_personnel.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.production_performance_personnel.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.production_performance_personnel.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.production_performance_personnel.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.production_performance_personnel.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.production_performance_personnel.note IS '비고';
COMMENT ON COLUMN ksx.production_performance_personnel.production_performance_id IS '생산실적식별자';
COMMENT ON COLUMN ksx.production_performance_personnel.production_performance_sequence IS '생산실적순번';
COMMENT ON COLUMN ksx.production_performance_personnel.production_order_id IS '생산지시식별자';
COMMENT ON COLUMN ksx.production_performance_personnel.production_order_sequence IS '생산지시순번';
COMMENT ON COLUMN ksx.production_performance_personnel.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.production_performance_personnel.personnel_id IS '사원식별자';
COMMENT ON COLUMN ksx.production_performance_personnel.execution_start_date_time IS '생산시작일시';
COMMENT ON COLUMN ksx.production_performance_personnel.execution_end_date_time IS '생산종료일시';
COMMENT ON COLUMN ksx.production_performance_personnel.task_group_code IS '근무조코드';
COMMENT ON COLUMN ksx.production_performance_personnel.actual_labor_date_time IS '투입일시';
COMMENT ON COLUMN ksx.production_performance_personnel.actual_labor_time IS '투입시간';
COMMENT ON COLUMN ksx.production_performance_personnel.actual_labor_time_uom_code IS '투입시간단위코드';
COMMENT ON COLUMN ksx.production_performance_equipment.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.production_performance_equipment.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.production_performance_equipment.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.production_performance_equipment.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.production_performance_equipment.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.production_performance_equipment.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.production_performance_equipment.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.production_performance_equipment.note IS '비고';
COMMENT ON COLUMN ksx.production_performance_equipment.production_performance_id IS '생산실적식별자';
COMMENT ON COLUMN ksx.production_performance_equipment.production_performance_sequence IS '생산실적순번';
COMMENT ON COLUMN ksx.production_performance_equipment.production_order_id IS '생산지시식별자';
COMMENT ON COLUMN ksx.production_performance_equipment.production_order_sequence IS '생산지시순번';
COMMENT ON COLUMN ksx.production_performance_equipment.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.production_performance_equipment.produced_quantity IS '생산수량';
COMMENT ON COLUMN ksx.production_performance_equipment.defect_quantity IS '불량수량';
COMMENT ON COLUMN ksx.production_performance_equipment.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.production_performance_equipment.routing_id IS '공정경로식별자';
COMMENT ON COLUMN ksx.production_performance_equipment.operation_sequence IS '공정순번';
COMMENT ON COLUMN ksx.production_performance_equipment.personnel_id IS '사원식별자';
COMMENT ON COLUMN ksx.production_performance_equipment.execution_start_date_time IS '생산시작일시';
COMMENT ON COLUMN ksx.production_performance_equipment.execution_end_date_time IS '생산종료일시';
COMMENT ON COLUMN ksx.production_performance_equipment.cancel_indicator IS '취소여부';
COMMENT ON COLUMN ksx.production_performance_equipment.cancel_date_time IS '취소일시';
COMMENT ON COLUMN ksx.production_performance_equipment.equipment_id IS '설비식별자';
COMMENT ON COLUMN ksx.production_performance_equipment.setup_time IS '준비시간';
COMMENT ON COLUMN ksx.production_performance_equipment.run_time IS '가동시간';
COMMENT ON COLUMN ksx.production_performance_equipment.inspection_finished_indicator IS '공정검사여부';
COMMENT ON COLUMN ksx.production_performance_quality.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.production_performance_quality.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.production_performance_quality.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.production_performance_quality.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.production_performance_quality.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.production_performance_quality.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.production_performance_quality.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.production_performance_quality.note IS '비고';
COMMENT ON COLUMN ksx.production_performance_quality.production_performance_id IS '생산실적식별자';
COMMENT ON COLUMN ksx.production_performance_quality.production_performance_sequence IS '생산실적순번';
COMMENT ON COLUMN ksx.production_performance_quality.production_order_id IS '생산지시식별자';
COMMENT ON COLUMN ksx.production_performance_quality.production_order_sequence IS '생산지시순번';
COMMENT ON COLUMN ksx.production_performance_quality.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.production_performance_quality.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.production_performance_quality.operation_id IS '공정식별자';
COMMENT ON COLUMN ksx.production_performance_quality.routing_id IS '공정경로식별자';
COMMENT ON COLUMN ksx.production_performance_quality.operation_sequence IS '공정순번';
COMMENT ON COLUMN ksx.production_performance_quality.execution_start_date_time IS '생산시작일시';
COMMENT ON COLUMN ksx.production_performance_quality.execution_end_date_time IS '생산종료일시';
COMMENT ON COLUMN ksx.production_performance_quality.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.production_performance_quality.batch_id IS '배치식별자';
COMMENT ON COLUMN ksx.production_performance_quality.defect_type_quantity IS '불량유형별수량';
COMMENT ON COLUMN ksx.production_performance_quality.defect_type_code IS '불량유형코드';
COMMENT ON COLUMN ksx.production_performance_quality.defect_type_detail_code IS '불량유형상세코드';
COMMENT ON COLUMN ksx.inventory.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.inventory.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.inventory.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.inventory.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.inventory.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.inventory.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.inventory.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.inventory.note IS '비고';
COMMENT ON COLUMN ksx.inventory.warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx.inventory.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.inventory.inventory_quantity IS '현재고수량';
COMMENT ON COLUMN ksx.inventory.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.available_inventory.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.available_inventory.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.available_inventory.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.available_inventory.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.available_inventory.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.available_inventory.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.available_inventory.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.available_inventory.note IS '비고';
COMMENT ON COLUMN ksx.available_inventory.available_inventory_id IS '가용재고식별자';
COMMENT ON COLUMN ksx.available_inventory.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.available_inventory.item_name IS '품목명';
COMMENT ON COLUMN ksx.available_inventory.available_inventory_quantity IS '가용재고량';
COMMENT ON COLUMN ksx.available_inventory.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.available_inventory.demand_priority IS '요청우선순위';
COMMENT ON COLUMN ksx.available_inventory.prior_demand_quantity IS '요청우선수량';
COMMENT ON COLUMN ksx.available_inventory.expected_delivery_date IS '납기예정일';
COMMENT ON COLUMN ksx.stock_transfer.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.stock_transfer.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.stock_transfer.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.stock_transfer.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.stock_transfer.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.stock_transfer.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.stock_transfer.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.stock_transfer.note IS '비고';
COMMENT ON COLUMN ksx.stock_transfer.stock_transfer_id IS '재고이동식별자';
COMMENT ON COLUMN ksx.stock_transfer.inventory_transaction_document_number IS '수불문서번호';
COMMENT ON COLUMN ksx.stock_transfer.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.stock_transfer.warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx.stock_transfer.receipt_warehouse_id IS '입고창고식별자';
COMMENT ON COLUMN ksx.stock_transfer.stock_transfer_quantity IS '재고이동수량';
COMMENT ON COLUMN ksx.stock_transfer.transfer_date_time IS '이동일시';
COMMENT ON COLUMN ksx.inventory_count.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.inventory_count.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.inventory_count.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.inventory_count.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.inventory_count.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.inventory_count.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.inventory_count.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.inventory_count.note IS '비고';
COMMENT ON COLUMN ksx.inventory_count.inventory_count_document_number IS '재고실사문서번호';
COMMENT ON COLUMN ksx.inventory_count.inventory_count_date_time IS '재고실사일시';
COMMENT ON COLUMN ksx.inventory_count.warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx.inventory_count.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.inventory_count.inventory_quantity IS '현재고수량';
COMMENT ON COLUMN ksx.inventory_count.inventory_count_quantity IS '실사수량';
COMMENT ON COLUMN ksx.inventory_count.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.product_incoming.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.product_incoming.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.product_incoming.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.product_incoming.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.product_incoming.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.product_incoming.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.product_incoming.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.product_incoming.note IS '비고';
COMMENT ON COLUMN ksx.product_incoming.product_incoming_id IS '제품입고식별자';
COMMENT ON COLUMN ksx.product_incoming.product_incoming_sequence IS '제품입고순번';
COMMENT ON COLUMN ksx.product_incoming.inventory_transaction_document_number IS '수불문서번호';
COMMENT ON COLUMN ksx.product_incoming.inventory_transaction_document_sequence IS '수불문서순번';
COMMENT ON COLUMN ksx.product_incoming.inventory_transaction_date IS '수불일';
COMMENT ON COLUMN ksx.product_incoming.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.product_incoming.customer_id IS '고객사식별자';
COMMENT ON COLUMN ksx.product_incoming.warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx.product_incoming.inventory_transaction_type_code IS '수불유형코드';
COMMENT ON COLUMN ksx.product_incoming.serial_use_indicator IS '시리얼사용여부';
COMMENT ON COLUMN ksx.product_incoming.inventory_transfer_type IS '입출고유형';
COMMENT ON COLUMN ksx.product_incoming.inventory_variation_type IS '재고증감유형';
COMMENT ON COLUMN ksx.product_incoming.inventory_transaction_type IS '수불유형';
COMMENT ON COLUMN ksx.product_incoming.lot_control_indicator IS '로트사용여부';
COMMENT ON COLUMN ksx.product_incoming.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.product_incoming.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.product_incoming.item_unit_quantity IS '기준단위수량';
COMMENT ON COLUMN ksx.product_incoming.order_uom_code IS '오더단위코드';
COMMENT ON COLUMN ksx.product_incoming.order_quantity IS '오더수량';
COMMENT ON COLUMN ksx.product_release_request.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.product_release_request.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.product_release_request.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.product_release_request.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.product_release_request.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.product_release_request.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.product_release_request.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.product_release_request.note IS '비고';
COMMENT ON COLUMN ksx.product_release_request.product_release_request_id IS '출하요청식별자';
COMMENT ON COLUMN ksx.product_release_request.product_release_request_document_number IS '납품문서번호';
COMMENT ON COLUMN ksx.product_release_request.product_release_request_type IS '납품구분유형';
COMMENT ON COLUMN ksx.product_release_request.product_release_request_date IS '납품지시일';
COMMENT ON COLUMN ksx.product_release_request.product_release_request_sequence IS '납품순번';
COMMENT ON COLUMN ksx.product_release_request.line_id IS '라인식별자';
COMMENT ON COLUMN ksx.product_release_request.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.product_release_request.item_name IS '품목명';
COMMENT ON COLUMN ksx.product_release_request.product_release_request_quantity IS '납품수량';
COMMENT ON COLUMN ksx.product_release_request.product_release_quantity IS '출고수량';
COMMENT ON COLUMN ksx.product_release_request.sales_quantity IS '매출수량';
COMMENT ON COLUMN ksx.product_release_request.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.product_release_request.selling_uom_code IS '판매단위코드';
COMMENT ON COLUMN ksx.product_release_request.item_unit_quantity IS '기준단위수량';
COMMENT ON COLUMN ksx.product_release_request.product_release_unit_quantity IS '기준출고수량';
COMMENT ON COLUMN ksx.product_release_request.sales_unit_quantity IS '기준매출수량';
COMMENT ON COLUMN ksx.product_release_request.warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx.product_release_request.requested_delivery_date IS '요청납기일';
COMMENT ON COLUMN ksx.product_release_request.sales_document_number IS '수주문서번호';
COMMENT ON COLUMN ksx.product_release_request.sales_document_sequence IS '수주문서순번';
COMMENT ON COLUMN ksx.product_release_request.customer_id IS '고객사식별자';
COMMENT ON COLUMN ksx.product_release_request.product_release_date IS '출고일';
COMMENT ON COLUMN ksx.product_release_request.delivery_date IS '납품일';
COMMENT ON COLUMN ksx.product_release_request_header.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.product_release_request_header.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.product_release_request_header.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.product_release_request_header.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.product_release_request_header.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.product_release_request_header.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.product_release_request_header.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.product_release_request_header.note IS '비고';
COMMENT ON COLUMN ksx.product_release_request_header.product_release_request_id IS '출하요청식별자';
COMMENT ON COLUMN ksx.product_release.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.product_release.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.product_release.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.product_release.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.product_release.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.product_release.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.product_release.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.product_release.note IS '비고';
COMMENT ON COLUMN ksx.product_release.product_release_id IS '출고식별자';
COMMENT ON COLUMN ksx.product_release.product_release_sequence IS '출고순번';
COMMENT ON COLUMN ksx.product_release.product_release_request_id IS '출하요청식별자';
COMMENT ON COLUMN ksx.product_release.sales_document_number IS '수주문서번호';
COMMENT ON COLUMN ksx.product_release.sales_document_sequence IS '수주문서순번';
COMMENT ON COLUMN ksx.product_release.inventory_transaction_date IS '수불일';
COMMENT ON COLUMN ksx.product_release.line_id IS '라인식별자';
COMMENT ON COLUMN ksx.product_release.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.product_release.item_name IS '품목명';
COMMENT ON COLUMN ksx.product_release.order_uom_code IS '오더단위코드';
COMMENT ON COLUMN ksx.product_release.order_quantity IS '오더수량';
COMMENT ON COLUMN ksx.product_release.selling_uom_code IS '판매단위코드';
COMMENT ON COLUMN ksx.product_release.sales_quantity IS '매출수량';
COMMENT ON COLUMN ksx.product_release.return_indicator IS '반품여부';
COMMENT ON COLUMN ksx.product_release.item_uom_code IS '기준단위코드';
COMMENT ON COLUMN ksx.product_release.item_unit_quantity IS '기준단위수량';
COMMENT ON COLUMN ksx.product_release.sales_unit_quantity IS '기준매출수량';
COMMENT ON COLUMN ksx.product_release.return_unit_quantity IS '기준반품수량';
COMMENT ON COLUMN ksx.product_release.customer_id IS '고객사식별자';
COMMENT ON COLUMN ksx.product_release.lot_id IS '로트식별자';
COMMENT ON COLUMN ksx.product_release.serial_use_indicator IS '시리얼사용여부';
COMMENT ON COLUMN ksx.product_release.warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx."return".enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx."return".site_id IS '사업장식별자';
COMMENT ON COLUMN ksx."return".plant_id IS '공장식별자';
COMMENT ON COLUMN ksx."return".creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx."return".creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx."return".modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx."return".modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx."return".note IS '비고';
COMMENT ON COLUMN ksx."return".return_id IS '반품식별자';
COMMENT ON COLUMN ksx."return".item_id IS '품목식별자';
COMMENT ON COLUMN ksx."return".lot_id IS '로트식별자';
COMMENT ON COLUMN ksx."return".batch_id IS '배치식별자';
COMMENT ON COLUMN ksx."return".warehouse_id IS '창고식별자';
COMMENT ON COLUMN ksx."return".return_sequence IS '반품순서';
COMMENT ON COLUMN ksx."return".return_number IS '반품번호';
COMMENT ON COLUMN ksx."return".product_return_document_number IS '반품문서번호';
COMMENT ON COLUMN ksx."return".return_date_time IS '반품일시';
COMMENT ON COLUMN ksx."return".customer_id IS '고객사식별자';
COMMENT ON COLUMN ksx."return".vendor_id IS '공급사식별자';
COMMENT ON COLUMN ksx."return".return_quantity IS '반품수량';
COMMENT ON COLUMN ksx."return".return_type IS '반품유형';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.note IS '비고';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.serial_number IS '제조번호';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.location IS '위치';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.item_type IS '품목유형';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.parameter_name IS '파라미터명';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.parameter_value IS '파라미터값';
COMMENT ON COLUMN ksx.product_trace_parameter_on_customer.collection_date_time IS '수집일시';
COMMENT ON COLUMN ksx.after_sales_service_request.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.after_sales_service_request.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.after_sales_service_request.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.after_sales_service_request.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.after_sales_service_request.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.after_sales_service_request.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.after_sales_service_request.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.after_sales_service_request.note IS '비고';
COMMENT ON COLUMN ksx.after_sales_service_request.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.after_sales_service_request.item_name IS '품목명';
COMMENT ON COLUMN ksx.after_sales_service_request.request_number IS '신청번호';
COMMENT ON COLUMN ksx.after_sales_service_request.transfer_sequence IS '이관순번';
COMMENT ON COLUMN ksx.after_sales_service_request.basic_accept_process_code IS '접수내용단순처리코드';
COMMENT ON COLUMN ksx.after_sales_service_request.promised_visit_date_time IS '약속방문일시';
COMMENT ON COLUMN ksx.after_sales_service_request.transfer_registration_code IS '이관등록코드';
COMMENT ON COLUMN ksx.after_sales_service_request.serial_number IS '제조번호';
COMMENT ON COLUMN ksx.after_sales_service_request_result.enterprise_id IS '회사식별자';
COMMENT ON COLUMN ksx.after_sales_service_request_result.site_id IS '사업장식별자';
COMMENT ON COLUMN ksx.after_sales_service_request_result.plant_id IS '공장식별자';
COMMENT ON COLUMN ksx.after_sales_service_request_result.creator_id IS '등록자식별자';
COMMENT ON COLUMN ksx.after_sales_service_request_result.creation_date_time IS '등록일시';
COMMENT ON COLUMN ksx.after_sales_service_request_result.modifier_id IS '수정자식별자';
COMMENT ON COLUMN ksx.after_sales_service_request_result.modification_date_time IS '수정일시';
COMMENT ON COLUMN ksx.after_sales_service_request_result.note IS '비고';
COMMENT ON COLUMN ksx.after_sales_service_request_result.item_id IS '품목식별자';
COMMENT ON COLUMN ksx.after_sales_service_request_result.item_name IS '품목명';
COMMENT ON COLUMN ksx.after_sales_service_request_result.request_number IS '신청번호';
COMMENT ON COLUMN ksx.after_sales_service_request_result.transfer_sequence IS '이관순번';
COMMENT ON COLUMN ksx.after_sales_service_request_result.register_sequence IS '등록순번';
COMMENT ON COLUMN ksx.after_sales_service_request_result.repair_sequence IS '수리순번';
COMMENT ON COLUMN ksx.after_sales_service_request_result.serial_number IS '제조번호';
COMMENT ON COLUMN ksx.after_sales_service_request_result.fault_large_class IS '하자현상대분류';
COMMENT ON COLUMN ksx.after_sales_service_request_result.fault_small_class IS '하자현상소분류';
COMMENT ON COLUMN ksx.after_sales_service_request_result.error_code IS '오류코드';
COMMENT ON COLUMN ksx.after_sales_service_request_result.installation_date IS '설치일';
COMMENT ON COLUMN ksx.after_sales_service_request_result.processing_date IS '처리일';
COMMENT ON COLUMN ksx.after_sales_service_request_result.end_indicator IS '종료여부';
COMMENT ON COLUMN ksx.after_sales_service_request_result.work_type IS '작업유형';
COMMENT ON COLUMN ksx.after_sales_service_request_result.child_item_id IS '자품목식별자';
COMMENT ON COLUMN ksx.after_sales_service_request_result.child_item_name IS '자품목명';
COMMENT ON COLUMN ksx.after_sales_service_request_result.item_specification IS '품목사양';
COMMENT ON COLUMN ksx.after_sales_service_request_result.repair_type IS '수리유형';
