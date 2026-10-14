-- KS X 9101-1:2025 v1.0 테이블정의서 DDL 시트 원문 (PostgreSQL 참고). FK는 관계목록 참조

CREATE TABLE site ( -- 사업장 (표 12)
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
    CONSTRAINT pk_site PRIMARY KEY (enterprise_id, site_id)
);

CREATE TABLE plant ( -- 공장 (표 13)
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
    CONSTRAINT pk_plant PRIMARY KEY (enterprise_id, plant_id)
);

CREATE TABLE department ( -- 부서 (표 14)
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
    CONSTRAINT pk_department PRIMARY KEY (enterprise_id, department_id)
);

CREATE TABLE personnel ( -- 사원 (표 15)
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
    CONSTRAINT pk_personnel PRIMARY KEY (enterprise_id, personnel_id)
);

CREATE TABLE customer_party_master ( -- 고객사 (표 16)
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
    CONSTRAINT pk_customer_party_master PRIMARY KEY (enterprise_id, customer_id)
);

CREATE TABLE vendor_party_master ( -- 공급사 (표 17)
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
    CONSTRAINT pk_vendor_party_master PRIMARY KEY (enterprise_id, vendor_id)
);

CREATE TABLE common_code_master ( -- 공통코드정보 (표 18)
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
    CONSTRAINT pk_common_code_master PRIMARY KEY (enterprise_id, common_code_group, common_code_id)
);

CREATE TABLE work_calendar ( -- 달력 (표 19)
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
    CONSTRAINT pk_work_calendar PRIMARY KEY (enterprise_id, calendar_id)
);

CREATE TABLE uom_group ( -- 단위그룹 (표 20)
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
    CONSTRAINT pk_uom_group PRIMARY KEY (enterprise_id, uom_group_id, uom_code)
);

CREATE TABLE item_master ( -- 품목마스터 (표 21)
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
    CONSTRAINT pk_item_master PRIMARY KEY (enterprise_id, item_id)
);

CREATE TABLE bom ( -- 자재명세서 (표 22)
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
    CONSTRAINT pk_bom PRIMARY KEY (enterprise_id, bom_id, bom_revision_number, child_item_id)
);

CREATE TABLE bom_header ( -- 자재명세서헤더 (표 —)
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
    CONSTRAINT pk_bom_header PRIMARY KEY (enterprise_id, bom_id, bom_revision_number)
);

CREATE TABLE lot ( -- 로트 (표 23)
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
    CONSTRAINT pk_lot PRIMARY KEY (enterprise_id, lot_id)
);

CREATE TABLE routing ( -- 공정경로 (표 24)
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
    CONSTRAINT pk_routing PRIMARY KEY (enterprise_id, routing_id, operation_sequence)
);

CREATE TABLE routing_header ( -- 공정경로헤더 (표 —)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    routing_id VARCHAR(50) NOT NULL, -- 공정경로식별자
    CONSTRAINT pk_routing_header PRIMARY KEY (enterprise_id, routing_id)
);

CREATE TABLE operation ( -- 공정 (표 25)
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
    CONSTRAINT pk_operation PRIMARY KEY (enterprise_id, operation_id)
);

CREATE TABLE equipment ( -- 설비 (표 26)
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
    CONSTRAINT pk_equipment PRIMARY KEY (enterprise_id, equipment_id)
);

CREATE TABLE operation_equipment ( -- 공정설비 (표 27)
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
    CONSTRAINT pk_operation_equipment PRIMARY KEY (enterprise_id, operation_id, equipment_id)
);

CREATE TABLE carrier ( -- 캐리어 (표 28)
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
    CONSTRAINT pk_carrier PRIMARY KEY (enterprise_id, carrier_id)
);

CREATE TABLE stocker_inventory ( -- 저장소재공정보 (표 29)
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
    CONSTRAINT pk_stocker_inventory PRIMARY KEY (enterprise_id, stocker_id)
);

CREATE TABLE warehouse_location ( -- 창고 (표 30)
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
    CONSTRAINT pk_warehouse_location PRIMARY KEY (enterprise_id, warehouse_id)
);

CREATE TABLE batch ( -- 배치 (표 31)
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
    CONSTRAINT pk_batch PRIMARY KEY (enterprise_id, batch_id)
);

CREATE TABLE line ( -- 라인 (표 32)
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
    CONSTRAINT pk_line PRIMARY KEY (enterprise_id, line_id)
);

CREATE TABLE enterprise ( -- 회사 (표 33)
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
    CONSTRAINT pk_enterprise PRIMARY KEY (enterprise_id)
);

CREATE TABLE project_master ( -- 프로젝트마스터 (표 34)
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
    CONSTRAINT pk_project_master PRIMARY KEY (enterprise_id, project_id)
);

CREATE TABLE engineering_change_order ( -- 설계변경지시 (표 35)
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
    CONSTRAINT pk_engineering_change_order PRIMARY KEY (enterprise_id, engineering_change_order_id)
);

CREATE TABLE sales_order ( -- 수주오더 (표 36)
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
    CONSTRAINT uk_sales_order_doc UNIQUE (enterprise_id, sales_document_number, sales_document_sequence),
    CONSTRAINT pk_sales_order PRIMARY KEY (enterprise_id, sales_order_id)
);

CREATE TABLE sales_plan ( -- 판매계획 (표 37)
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
    CONSTRAINT pk_sales_plan PRIMARY KEY (enterprise_id, sales_plan_id)
);

CREATE TABLE base_price ( -- 기준가격 (표 38)
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
    CONSTRAINT pk_base_price PRIMARY KEY (enterprise_id, item_id, currency_code)
);

CREATE TABLE purchase_requisition ( -- 구매요청 (표 39)
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
    CONSTRAINT pk_purchase_requisition PRIMARY KEY (enterprise_id, purchase_requisition_id)
);

CREATE TABLE purchase_order ( -- 구매발주 (표 40)
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
    CONSTRAINT uk_purchase_order_doc UNIQUE (enterprise_id, purchase_document_number, purchase_document_sequence),
    CONSTRAINT pk_purchase_order PRIMARY KEY (enterprise_id, purchase_order_id)
);

CREATE TABLE material_arrival ( -- 자재도착 (표 41)
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
    CONSTRAINT pk_material_arrival PRIMARY KEY (enterprise_id, purchase_document_number, purchase_document_sequence, lot_id)
);

CREATE TABLE goods_receipt ( -- 입고 (표 42)
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
    CONSTRAINT pk_goods_receipt PRIMARY KEY (enterprise_id, goods_receipt_id, goods_receipt_sequence)
);

CREATE TABLE goods_issue ( -- 자재불출 (표 43)
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
    CONSTRAINT pk_goods_issue PRIMARY KEY (enterprise_id, goods_issue_id)
);

CREATE TABLE production_planning ( -- 생산계획 (표 44)
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
    CONSTRAINT pk_production_planning PRIMARY KEY (enterprise_id, production_plan_id)
);

CREATE TABLE production_order ( -- 생산지시 (표 45)
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
    CONSTRAINT pk_production_order PRIMARY KEY (enterprise_id, production_order_id, production_order_sequence)
);

CREATE TABLE operation_start ( -- 착공 (표 46)
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
    CONSTRAINT pk_operation_start PRIMARY KEY (enterprise_id, lot_id, operation_id, operation_start_time)
);

CREATE TABLE operation_end ( -- 완공 (표 47)
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
    CONSTRAINT pk_operation_end PRIMARY KEY (enterprise_id, lot_id, operation_id, operation_end_time)
);

CREATE TABLE transfer_command ( -- 이동지시 (표 48)
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
    CONSTRAINT pk_transfer_command PRIMARY KEY (enterprise_id, transfer_command_id)
);

CREATE TABLE transfer_start ( -- 운행시작 (표 49)
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
    CONSTRAINT pk_transfer_start PRIMARY KEY (enterprise_id, transfer_command_id)
);

CREATE TABLE transfer_end ( -- 운행완료 (표 50)
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
    CONSTRAINT pk_transfer_end PRIMARY KEY (enterprise_id, transfer_command_id)
);

CREATE TABLE in_transit_location ( -- 운송위치 (표 51)
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
    CONSTRAINT pk_in_transit_location PRIMARY KEY (enterprise_id, transfer_command_id, current_location)
);

CREATE TABLE equipment_state ( -- 설비상태 (표 52)
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
    CONSTRAINT pk_equipment_state PRIMARY KEY (enterprise_id, equipment_id)
);

CREATE TABLE alarm ( -- 알람 (표 53)
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
    CONSTRAINT pk_alarm PRIMARY KEY (enterprise_id, equipment_id, event_date_time, error_code)
);

CREATE TABLE supplier_inspection_plan ( -- 협력업체품질검사계획 (표 54)
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
    CONSTRAINT pk_supplier_inspection_plan PRIMARY KEY (enterprise_id, inspection_plan_id, inspection_id)
);

CREATE TABLE supplier_inspection_application ( -- 협력업체품질검사신청 (표 55)
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
    CONSTRAINT pk_supplier_inspection_application PRIMARY KEY (enterprise_id, inspection_application_id)
);

CREATE TABLE supplier_inspection_result ( -- 협력업체품질검사결과 (표 56)
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
    CONSTRAINT pk_supplier_inspection_result PRIMARY KEY (enterprise_id, inspection_result_id)
);

CREATE TABLE corrective_action_request ( -- 시정조치요청 (표 57)
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
    CONSTRAINT pk_corrective_action_request PRIMARY KEY (enterprise_id, corrective_action_request_id)
);

CREATE TABLE corrective_action_plan ( -- 시정조치계획 (표 58)
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
    CONSTRAINT pk_corrective_action_plan PRIMARY KEY (enterprise_id, corrective_action_plan_id)
);

CREATE TABLE corrective_action_result ( -- 시정조치결과 (표 59)
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
    CONSTRAINT pk_corrective_action_result PRIMARY KEY (enterprise_id, corrective_action_result_id)
);

CREATE TABLE product_packing ( -- 제품포장 (표 60)
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
    CONSTRAINT pk_product_packing PRIMARY KEY (enterprise_id, box_number, packing_sequence)
);

CREATE TABLE equipment_parameter ( -- 설비파라미터 (표 61)
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
    CONSTRAINT pk_equipment_parameter PRIMARY KEY (enterprise_id, parameter_id)
);

CREATE TABLE trace_parameter ( -- 설비파라미터이력 (표 62)
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
    CONSTRAINT pk_trace_parameter PRIMARY KEY (enterprise_id, equipment_id, parameter_id, event_date_time)
);

CREATE TABLE production_performance ( -- 생산실적 (표 63)
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
    CONSTRAINT pk_production_performance PRIMARY KEY (enterprise_id, production_performance_id, production_performance_sequence)
);

CREATE TABLE production_performance_item ( -- 생산실적투입품목 (표 64)
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
    CONSTRAINT pk_production_performance_item PRIMARY KEY (enterprise_id, production_performance_id, production_performance_sequence, item_id)
);

CREATE TABLE production_performance_personnel ( -- 생산실적투입인력 (표 65)
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
    CONSTRAINT pk_production_performance_personnel PRIMARY KEY (enterprise_id, production_performance_id, production_performance_sequence, personnel_id)
);

CREATE TABLE production_performance_equipment ( -- 설비활용실적 (표 66)
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
    CONSTRAINT pk_production_performance_equipment PRIMARY KEY (enterprise_id, production_performance_id, production_performance_sequence, equipment_id)
);

CREATE TABLE production_performance_quality ( -- 생산품질실적 (표 67)
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
    CONSTRAINT pk_production_performance_quality PRIMARY KEY (enterprise_id, production_performance_id, production_performance_sequence, defect_type_code, defect_type_detail_code)
);

CREATE TABLE inventory ( -- 재고 (표 68)
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
    CONSTRAINT pk_inventory PRIMARY KEY (enterprise_id, warehouse_id, item_id)
);

CREATE TABLE available_inventory ( -- 가용재고 (표 69)
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
    CONSTRAINT pk_available_inventory PRIMARY KEY (enterprise_id, available_inventory_id)
);

CREATE TABLE stock_transfer ( -- 재고이동 (표 70)
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
    CONSTRAINT pk_stock_transfer PRIMARY KEY (enterprise_id, stock_transfer_id)
);

CREATE TABLE inventory_count ( -- 재고실사 (표 71)
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
    CONSTRAINT pk_inventory_count PRIMARY KEY (enterprise_id, inventory_count_document_number, warehouse_id, item_id)
);

CREATE TABLE product_incoming ( -- 제품입고 (표 72)
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
    CONSTRAINT pk_product_incoming PRIMARY KEY (enterprise_id, product_incoming_id, product_incoming_sequence)
);

CREATE TABLE product_release_request ( -- 출하의뢰 (표 73)
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
    CONSTRAINT pk_product_release_request PRIMARY KEY (enterprise_id, product_release_request_id, product_release_request_sequence)
);

CREATE TABLE product_release_request_header ( -- 출하의뢰헤더 (표 —)
    enterprise_id VARCHAR(50) NOT NULL, -- 회사식별자
    site_id VARCHAR(50) NOT NULL, -- 사업장식별자
    plant_id VARCHAR(50) NOT NULL, -- 공장식별자
    creator_id VARCHAR(50), -- 등록자식별자
    creation_date_time TIMESTAMP, -- 등록일시
    modifier_id VARCHAR(50), -- 수정자식별자
    modification_date_time TIMESTAMP, -- 수정일시
    note VARCHAR(1000), -- 비고
    product_release_request_id VARCHAR(50) NOT NULL, -- 출하요청식별자
    CONSTRAINT pk_product_release_request_header PRIMARY KEY (enterprise_id, product_release_request_id)
);

CREATE TABLE product_release ( -- 제품출고 (표 74)
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
    CONSTRAINT pk_product_release PRIMARY KEY (enterprise_id, product_release_id, product_release_sequence)
);

CREATE TABLE return ( -- 반품 (표 75)
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
    CONSTRAINT pk_return PRIMARY KEY (enterprise_id, return_id, return_sequence)
);

CREATE TABLE product_trace_parameter_on_customer ( -- 고객제품데이터 (표 76)
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
    CONSTRAINT pk_product_trace_parameter_on_customer PRIMARY KEY (enterprise_id, item_id, serial_number, parameter_name, collection_date_time)
);

CREATE TABLE after_sales_service_request ( -- 사후서비스신청 (표 77)
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
    CONSTRAINT pk_after_sales_service_request PRIMARY KEY (enterprise_id, request_number)
);

CREATE TABLE after_sales_service_request_result ( -- 사후서비스결과 (표 78)
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
    CONSTRAINT pk_after_sales_service_request_result PRIMARY KEY (enterprise_id, request_number, transfer_sequence, register_sequence, repair_sequence)
);

