-- =============================================================================
-- 데이터 카탈로그 (catalog) — DCAT·PROV·DQV 를 테이블로
-- 핵심 연결: dataset.represents_class_iri → onto.class
--   이 한 컬럼으로 "로트 관련 데이터 전부", "로트에 걸린 품질 규칙", "로트 열람 권한"이 이어진다.
-- =============================================================================
CREATE TABLE catalog.zone (
    zone_id        VARCHAR(12) PRIMARY KEY,
    label_ko       VARCHAR(50) NOT NULL,
    zone_order     SMALLINT NOT NULL UNIQUE,
    default_retention INTERVAL,
    description    VARCHAR(500)
);
INSERT INTO catalog.zone VALUES
 ('RAW',      '원천 존',   1, INTERVAL '6 months', '원천 포맷 그대로 · append-only'),
 ('STANDARD', '표준 존',   2, NULL,                'KS X 9101 테이블 · 코드 표준화 완료'),
 ('SEMANTIC', '시맨틱 존', 3, NULL,                'RDF 트리플 · 추론 · 임베딩'),
 ('CURATED',  '활용 존',   4, INTERVAL '2 years',  'KPI · 피처 · 학습데이터 · 서빙');

CREATE TABLE catalog.source_system (
    source_system_id VARCHAR(50) PRIMARY KEY,
    label_ko         VARCHAR(100) NOT NULL,
    system_type      VARCHAR(20) NOT NULL,        -- ERP|MES|QMS|WMS|PLM|SCADA|SECS_GEM|EDMS|SENSOR|FILE
    connection_kind  VARCHAR(20),                 -- JDBC|KAFKA|MQTT|OPC_UA|SFTP|REST|BOD
    ksx_compliant    BOOLEAN NOT NULL DEFAULT FALSE,  -- 표준 속성명 그대로면 자동 매핑 1단계에서 해소
    owner_dept       VARCHAR(100),
    enterprise_id    VARCHAR(50) NOT NULL
);

CREATE TABLE catalog.dataset (
    dataset_id        VARCHAR(150) PRIMARY KEY,   -- 예: std.lot, raw.mes.lot_history, cur.kpi_oee_daily
    title_ko          VARCHAR(200) NOT NULL,
    description       TEXT,
    zone_id           VARCHAR(12) NOT NULL REFERENCES catalog.zone(zone_id),
    represents_class_iri VARCHAR(300) REFERENCES onto.class(class_iri) DEFERRABLE INITIALLY DEFERRED,
    source_system_id  VARCHAR(50) REFERENCES catalog.source_system(source_system_id),
    location_uri      VARCHAR(500) NOT NULL,      -- postgresql:// · s3:// · sparql:// · qdrant://
    format            VARCHAR(20) NOT NULL,       -- table|parquet|iceberg|jsonl|csv|rdf|vector|pdf
    ingest_mode       VARCHAR(10) CHECK (ingest_mode IN ('batch','stream','cdc','file','derived')),
    schedule_cron     VARCHAR(50),
    schema_version    VARCHAR(50),
    record_count      BIGINT,
    size_bytes        BIGINT,
    last_ingested_at  TIMESTAMPTZ,
    quality_score     NUMERIC(5,2),               -- 최근 품질 실행 적합률(%)
    quality_status    VARCHAR(10) DEFAULT 'UNKNOWN' CHECK (quality_status IN ('UNKNOWN','PASS','WARN','FAIL')),
    sensitivity       VARCHAR(12) NOT NULL DEFAULT 'INTERNAL' CHECK (sensitivity IN ('PUBLIC','INTERNAL','CONFIDENTIAL','PERSONAL')),
    pseudonymized     BOOLEAN NOT NULL DEFAULT FALSE,
    retention         INTERVAL,
    owner_user_id     VARCHAR(50),
    steward_user_id   VARCHAR(50),
    tags              TEXT[] NOT NULL DEFAULT '{}',
    enterprise_id     VARCHAR(50),                -- NULL = 모든 회사 공용(표준 존 정의 등). 회사 데이터셋은 RLS 로 격리 (리뷰 F18)
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_dataset_class ON catalog.dataset (represents_class_iri);
CREATE INDEX ix_dataset_zone  ON catalog.dataset (zone_id);
CREATE INDEX ix_dataset_ent   ON catalog.dataset (enterprise_id);
CREATE INDEX ix_dataset_tags  ON catalog.dataset USING GIN (tags);
CREATE INDEX ix_dataset_fts   ON catalog.dataset USING GIN (to_tsvector('simple', title_ko || ' ' || coalesce(description,'')));

CREATE TABLE catalog.dataset_field (
    dataset_id        VARCHAR(150) NOT NULL REFERENCES catalog.dataset(dataset_id) ON DELETE CASCADE,
    field_name        VARCHAR(100) NOT NULL,
    label_ko          VARCHAR(200),
    data_type         VARCHAR(50),
    is_pk             BOOLEAN NOT NULL DEFAULT FALSE,
    is_required       BOOLEAN NOT NULL DEFAULT FALSE,
    maps_to_property_iri VARCHAR(300),            -- onto.property (원천 존 필드는 매핑 후 채움)
    mapping_method    VARCHAR(10) CHECK (mapping_method IN ('rule','embedding','llm','human')),
    mapping_confidence NUMERIC(4,3),
    mapping_status    VARCHAR(10) NOT NULL DEFAULT 'PROPOSED' CHECK (mapping_status IN ('PROPOSED','APPROVED','REJECTED')),
    null_ratio        NUMERIC(5,4),               -- 프로파일링 결과
    distinct_count    BIGINT,
    PRIMARY KEY (dataset_id, field_name)
);

-- RML/OBDA 매핑 버전 (Setup 산출물)
CREATE TABLE catalog.mapping (
    mapping_id        VARCHAR(100) PRIMARY KEY,   -- 예: ksx9101/lot.rml.ttl@v3
    source_dataset_id VARCHAR(150) NOT NULL REFERENCES catalog.dataset(dataset_id),
    target_class_iri  VARCHAR(300) NOT NULL REFERENCES onto.class(class_iri) DEFERRABLE INITIALLY DEFERRED,
    kind              VARCHAR(10) NOT NULL CHECK (kind IN ('RML','OBDA','SQL')),
    version_no        INTEGER NOT NULL,
    artifact_uri      VARCHAR(500),
    status            VARCHAR(10) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','REVIEW','APPROVED','RETIRED')),
    approved_by       VARCHAR(50),
    approved_at       TIMESTAMPTZ,
    f1_score          NUMERIC(4,3)                -- 골드 스탠더드 대비 매핑 정확도
);

-- 자동 매핑 검토 큐 (Human-in-the-loop)
CREATE TABLE catalog.mapping_review (
    review_id         BIGSERIAL PRIMARY KEY,
    dataset_id        VARCHAR(150) NOT NULL,
    field_name        VARCHAR(100) NOT NULL,
    candidate_property_iri VARCHAR(300),
    method            VARCHAR(10) NOT NULL,
    confidence        NUMERIC(4,3),
    rationale         TEXT,                       -- LLM 재순위 근거 등
    decision          VARCHAR(10) CHECK (decision IN ('ACCEPT','REJECT','EDIT')),
    decided_by        VARCHAR(50),
    decided_at        TIMESTAMPTZ,
    FOREIGN KEY (dataset_id, field_name) REFERENCES catalog.dataset_field(dataset_id, field_name) ON DELETE CASCADE
);

-- 계보 (PROV-O)
CREATE TABLE catalog.pipeline (
    pipeline_id       VARCHAR(100) PRIMARY KEY,
    label_ko          VARCHAR(200) NOT NULL,
    from_zone         VARCHAR(12) REFERENCES catalog.zone(zone_id),
    to_zone           VARCHAR(12) REFERENCES catalog.zone(zone_id),
    engine            VARCHAR(30),                -- airflow|dagster|kafka-streams|morph-kgc|ontop|dbt
    schedule_cron     VARCHAR(50),
    owner_user_id     VARCHAR(50),
    enabled           BOOLEAN NOT NULL DEFAULT TRUE,
    enterprise_id     VARCHAR(50)                 -- NULL = 공용 파이프라인 정의 (재검토 N5)
);
CREATE TABLE catalog.job_run (
    run_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pipeline_id       VARCHAR(100) NOT NULL REFERENCES catalog.pipeline(pipeline_id),
    mapping_id        VARCHAR(100) REFERENCES catalog.mapping(mapping_id),
    started_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at          TIMESTAMPTZ,
    status            VARCHAR(10) NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING','SUCCESS','FAILED','PARTIAL')),
    rows_in           BIGINT,
    rows_out          BIGINT,
    rows_rejected     BIGINT,
    code_version      VARCHAR(60),                -- 파서·생성기 git sha
    error_message     TEXT,                       -- 실패 레코드 키·값이 들어갈 수 있다 → 회사 범위로 격리
    enterprise_id     VARCHAR(50)                 -- 실행 대상 회사. NULL = 공용 작업 (재검토 N5)
);
CREATE TABLE catalog.lineage_edge (
    edge_id           BIGSERIAL PRIMARY KEY,
    from_dataset_id   VARCHAR(150) NOT NULL REFERENCES catalog.dataset(dataset_id),
    to_dataset_id     VARCHAR(150) NOT NULL REFERENCES catalog.dataset(dataset_id),
    pipeline_id       VARCHAR(100) REFERENCES catalog.pipeline(pipeline_id),
    relation          VARCHAR(20) NOT NULL DEFAULT 'wasDerivedFrom',
    field_map         JSONB,                      -- 컬럼 단위 계보 {"to_col": ["from_col", ...]} — 원천 컬럼명 노출
    enterprise_id     VARCHAR(50),                -- NULL = 공용 계보 (재검토 N5)
    UNIQUE NULLS NOT DISTINCT (from_dataset_id, to_dataset_id, pipeline_id)   -- 파이프라인 없는 간선도 중복 금지 (리뷰 F24)
);

-- 비정형 문서 근거 (문서·페이지·섹션) — RAG 인용, 문서 유래 트리플의 출처
CREATE TABLE catalog.source_document (
    document_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dataset_id        VARCHAR(150) REFERENCES catalog.dataset(dataset_id),
    title             VARCHAR(500) NOT NULL,
    doc_type          VARCHAR(30),                -- 단일 코드리스트(cl:DocumentType) 로만 관리 — 분산 선언 금지
    uri               VARCHAR(1000) NOT NULL,
    sha256            CHAR(64) NOT NULL,
    page_count        INTEGER,
    language          VARCHAR(10) DEFAULT 'ko',
    sensitivity       VARCHAR(12) NOT NULL DEFAULT 'INTERNAL',
    enterprise_id     VARCHAR(50) NOT NULL,       -- 회사 격리 키 (70_rls.sql)
    site_id           VARCHAR(50),
    plant_id          VARCHAR(50),
    ingested_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (enterprise_id, dataset_id, sha256)   -- 같은 PDF 가 여러 데이터셋에 속할 수 있다 (리뷰 F30)
);
CREATE TABLE catalog.document_chunk (
    chunk_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id       UUID NOT NULL REFERENCES catalog.source_document(document_id) ON DELETE CASCADE,
    enterprise_id     VARCHAR(50) NOT NULL,       -- 문서의 범위를 그대로 복사 (RLS 판정용)
    site_id           VARCHAR(50),
    plant_id          VARCHAR(50),
    page_no           INTEGER,
    section_path      VARCHAR(500),               -- 예: 3.2 > 표 24
    chunk_text        TEXT NOT NULL,
    token_count       INTEGER,
    mentioned_class_iris TEXT[] NOT NULL DEFAULT '{}'   -- 엔티티 추출 결과
);

-- 품질 (DQV + SHACL)
CREATE TABLE catalog.quality_rule (
    rule_id           VARCHAR(100) PRIMARY KEY,
    label_ko          VARCHAR(200) NOT NULL,
    dimension         VARCHAR(10) NOT NULL CHECK (dimension IN ('완전성','유일성','유효성','일관성','정확성','구조','값','관계','의미')),
    target_class_iri  VARCHAR(300) REFERENCES onto.class(class_iri) DEFERRABLE INITIALLY DEFERRED,  -- 클래스 단위 규칙은 그 클래스를 represents 하는 모든 데이터셋에 적용
    target_dataset_id VARCHAR(150) REFERENCES catalog.dataset(dataset_id),
    shape_iri         VARCHAR(300),               -- ksx:LotShape 등
    sql_check         TEXT,                       -- SHACL 이 아닌 SQL 규칙 (위반 행을 반환)
    severity          VARCHAR(10) NOT NULL DEFAULT 'Violation' CHECK (severity IN ('Info','Warning','Violation')),
    threshold         NUMERIC(5,2),               -- 적합률 임계(%)
    enabled           BOOLEAN NOT NULL DEFAULT TRUE,
    CHECK (target_class_iri IS NOT NULL OR target_dataset_id IS NOT NULL)
);
CREATE TABLE catalog.quality_run (
    quality_run_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_run_id        UUID REFERENCES catalog.job_run(run_id),
    dataset_id        VARCHAR(150) NOT NULL REFERENCES catalog.dataset(dataset_id),
    executed_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    focus_count       BIGINT NOT NULL,
    violation_count   BIGINT NOT NULL,
    conformance_rate  NUMERIC(7,4) GENERATED ALWAYS AS
                      (CASE WHEN focus_count = 0 THEN 100 ELSE 100.0 * (focus_count - violation_count) / focus_count END) STORED,
    report_uri        VARCHAR(500)                -- SHACL 검증 리포트(TTL/JSON) 원본
);
CREATE TABLE catalog.quality_violation (
    violation_id      BIGSERIAL PRIMARY KEY,
    quality_run_id    UUID NOT NULL REFERENCES catalog.quality_run(quality_run_id) ON DELETE CASCADE,
    rule_id           VARCHAR(100) REFERENCES catalog.quality_rule(rule_id),
    focus_node        VARCHAR(500) NOT NULL,      -- A-Box IRI 또는 테이블 PK 문자열
    result_path       VARCHAR(300),
    message           VARCHAR(1000),
    severity          VARCHAR(10) NOT NULL,
    status            VARCHAR(10) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','ACK','FIXED','WAIVED')),
    assignee_user_id  VARCHAR(50),
    resolved_at       TIMESTAMPTZ
);
CREATE INDEX ix_violation_open ON catalog.quality_violation (status) WHERE status = 'OPEN';
