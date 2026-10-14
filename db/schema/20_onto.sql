-- =============================================================================
-- 온톨로지 레지스트리 (onto)
-- TTL 파일이 진실의 원본이고, 이 테이블은 카탈로그·UI·권한이 SQL 로 조인하기 위한 사본이다.
-- 레지스트리는 항상 "현재 릴리스" 한 벌만 담는다. 행의 version_id 는 마지막으로 바꾼 릴리스다.
-- 과거 버전은 onto.ontology_version.artifact_uri 의 TTL 번들로 보관하고 diff 는 TTL 끼리 한다 (리뷰 F17).
-- 런타임에서 수정하지 않는다(Setup → Execution 단방향). 시드(90)는 upsert 라 새 릴리스를 그대로 덮어쓴다.
-- =============================================================================
CREATE TABLE onto.namespace (
    prefix        VARCHAR(20) PRIMARY KEY,
    iri           VARCHAR(300) NOT NULL UNIQUE,
    layer         VARCHAR(20) NOT NULL CHECK (layer IN ('STANDARD','EXTENSION','META','VOCAB','DATA')),
    mutable       BOOLEAN NOT NULL,
    description   VARCHAR(500)
);
INSERT INTO onto.namespace VALUES
 ('ksx',   'https://ontology.impix.co.kr/ksx9101/',      'STANDARD',  FALSE, 'KS X 9101 표준 코어 — 생성기 산출, 불변'),
 ('ksxv',  'https://ontology.impix.co.kr/ksx9101/verb/', 'STANDARD',  FALSE, 'BOD 동사 12종'),
 ('arcon', 'https://ontology.impix.co.kr/arcon/',        'EXTENSION', TRUE,  '기업 확장 — 액션·리스크·KPI·유지보수·인과'),
 ('lake',  'https://ontology.impix.co.kr/lake/',         'META',      TRUE,  '데이터레이크 메타 온톨로지'),
 ('cl',    'https://data.impix.co.kr/arcon/codelist/',   'VOCAB',     TRUE,  'SKOS 코드리스트'),
 ('d',     'https://data.impix.co.kr/arcon/',            'DATA',      TRUE,  'A-Box 인스턴스 {Ent}/{Noun}/{PK}');

CREATE TABLE onto.ontology_version (
    version_id    VARCHAR(60) PRIMARY KEY,
    ontology_iri  VARCHAR(300) NOT NULL,
    version_info  VARCHAR(100) NOT NULL,
    source        VARCHAR(300),
    status        VARCHAR(12) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','VALIDATED','RELEASED','RETIRED')),
    validated_at  TIMESTAMPTZ,              -- Ontology Validation Service 게이트 통과 시각
    released_at   TIMESTAMPTZ,
    artifact_uri  VARCHAR(500)              -- 산출물 8종 번들 위치
);

CREATE TABLE onto.class (
    class_iri       VARCHAR(300) PRIMARY KEY,
    local_name      VARCHAR(100) NOT NULL,
    label_ko        VARCHAR(200) NOT NULL,          -- 한글 라벨 필수 (UI 가 IRI 를 노출하지 않음)
    label_en        VARCHAR(200),
    business_group  VARCHAR(30),                    -- 업무영역 9개
    parent_class_iri VARCHAR(300) REFERENCES onto.class(class_iri) DEFERRABLE INITIALLY DEFERRED,
    standard_clause VARCHAR(20),
    physical_table  VARCHAR(100),                   -- 표준 존 테이블 (ksx.*)
    primary_key     VARCHAR(300),
    is_event        BOOLEAN NOT NULL DEFAULT FALSE,
    is_standard     BOOLEAN NOT NULL DEFAULT TRUE,  -- FALSE = arcon 확장
    definition_ko   TEXT,
    version_id      VARCHAR(60) REFERENCES onto.ontology_version(version_id)
);

CREATE TABLE onto.property (
    property_iri     VARCHAR(300) PRIMARY KEY,
    local_name       VARCHAR(100) NOT NULL,
    kind             VARCHAR(10) NOT NULL CHECK (kind IN ('OBJECT','DATATYPE','CODE','ANNOTATION')),
    label_ko         VARCHAR(200),
    range_iri        VARCHAR(300),
    code_scheme      VARCHAR(200),                  -- CODE 일 때 공통코드그룹
    source_attribute VARCHAR(100),                  -- 표준 영문 속성명
    is_transitive    BOOLEAN NOT NULL DEFAULT FALSE,   -- owl:TransitiveProperty (arcon:derivedFrom 등)
    super_property_iri VARCHAR(300) REFERENCES onto.property(property_iri) DEFERRABLE INITIALLY DEFERRED,  -- rdfs:subPropertyOf
    version_id       VARCHAR(60) REFERENCES onto.ontology_version(version_id)
);

-- 관계 = (주어 클래스, 객체속성, 목적어 클래스). 그래프 탐색 UI·RML·Cypher 스키마의 공통 원천
CREATE TABLE onto.link (
    link_id           BIGSERIAL PRIMARY KEY,
    subject_class_iri VARCHAR(300) NOT NULL REFERENCES onto.class(class_iri) DEFERRABLE INITIALLY DEFERRED,
    property_iri      VARCHAR(300) NOT NULL REFERENCES onto.property(property_iri) DEFERRABLE INITIALLY DEFERRED,
    object_class_iri  VARCHAR(300) NOT NULL REFERENCES onto.class(class_iri) DEFERRABLE INITIALLY DEFERRED,
    fk_columns        VARCHAR(300),
    relation_kind     VARCHAR(20) NOT NULL          -- 명사 참조|자기 참조|헤더 참조|헤더-라인|다형 참조|표준 외 대상|하위 목록 참조
);
CREATE INDEX ix_link_subject ON onto.link (subject_class_iri);
CREATE INDEX ix_link_object  ON onto.link (object_class_iri);

-- 비즈니스 액션 "정의" (무엇을 할 수 있는가). 실행 정책은 gov.action_policy
CREATE TABLE onto.action (
    action_iri       VARCHAR(300) PRIMARY KEY,
    label_ko         VARCHAR(200) NOT NULL,
    verb             VARCHAR(30) NOT NULL CHECK (verb IN ('Process','Cancel','Change','Sync','Notify','Get')),
    target_class_iri VARCHAR(300) NOT NULL REFERENCES onto.class(class_iri) DEFERRABLE INITIALLY DEFERRED,
    sets_property_iri VARCHAR(300) REFERENCES onto.property(property_iri) DEFERRABLE INITIALLY DEFERRED,
    precondition_shape VARCHAR(300),
    scenario_ref     VARCHAR(20)                    -- 부속서 A 교환 시나리오 번호
);
-- 액션 정의 시드는 클래스 레지스트리(90)가 채워진 뒤 91_seed_actions.sql 에서 넣는다 (IRI FK).
