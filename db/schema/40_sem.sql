-- =============================================================================
-- 시맨틱 존 (sem) — 지식그래프의 관계형 사본·감사 원장
-- 운영 질의는 Fuseki(물질화) + Ontop(가상화, ksx 존 직결)이 맡는다.
-- 이 스키마는 (1) 물질화 트리플의 출처·등급 추적 (2) 추론 결과 원장 (3) 동일성 판정 영속화
-- (4) 임베딩 메타를 SQL 로 조인 가능하게 남긴다.
-- =============================================================================
CREATE TABLE sem.named_graph (
    graph_iri        VARCHAR(300) PRIMARY KEY,   -- …/graph/{Ent}/{Site}/{Plant} · …/graph/inferred/{Ent}/{Site}
    graph_kind       VARCHAR(12) NOT NULL CHECK (graph_kind IN ('TBOX','SHAPES','CODELIST','ABOX','INFERRED','BOD','CAUSAL')),
    enterprise_id    VARCHAR(50),
    site_id          VARCHAR(50),
    plant_id         VARCHAR(50),
    store            VARCHAR(20) NOT NULL DEFAULT 'fuseki',  -- fuseki|ontop(virtual)|age
    triple_count     BIGINT,
    refreshed_at     TIMESTAMPTZ
);

-- 물질화 쿼드 (추론 결과 · BOD 원장 · 문서 유래 사실 · 예측). 기준정보/트랜잭션은 Ontop 가상화이므로 여기 복제하지 않는다.
CREATE TABLE sem.quad (
    quad_id          BIGSERIAL,
    graph_iri        VARCHAR(300) NOT NULL REFERENCES sem.named_graph(graph_iri),
    s                VARCHAR(500) NOT NULL,
    p                VARCHAR(300) NOT NULL,
    o_iri            VARCHAR(500),
    o_literal        TEXT,
    o_datatype       VARCHAR(100),
    o_lang           VARCHAR(10),
    tier             VARCHAR(10) NOT NULL CHECK (tier IN ('STANDARD','ASSERTED','INFERRED','GENERATED')),
    job_run_id       UUID REFERENCES catalog.job_run(run_id),
    source_chunk_id  UUID REFERENCES catalog.document_chunk(chunk_id),   -- 문서 유래면 페이지·섹션까지 추적
    confidence       NUMERIC(4,3),
    valid_from       TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to         TIMESTAMPTZ,                -- NULL = 현재 유효. 덮어쓰지 않고 기간을 닫는다
    PRIMARY KEY (quad_id),
    CHECK ((o_iri IS NULL) <> (o_literal IS NULL))
);
CREATE INDEX ix_quad_spo ON sem.quad (s, p) WHERE valid_to IS NULL;
CREATE INDEX ix_quad_pos ON sem.quad (p, o_iri) WHERE valid_to IS NULL;
CREATE INDEX ix_quad_graph ON sem.quad (graph_iri);
-- 현재 유효한 사실은 그래프 안에서 한 번만 (리뷰 F19). 추론 재실행이 같은 사실을 또 넣으면 실패하므로 ON CONFLICT DO NOTHING 으로 적재한다.
-- 긴 리터럴은 btree 한도(약 2.7KB)를 넘으므로 md5 로 비교한다.
CREATE UNIQUE INDEX ux_quad_current ON sem.quad (graph_iri, s, p, coalesce(o_iri, ''), md5(coalesce(o_literal, '')), coalesce(o_datatype, ''), coalesce(o_lang, ''))
    WHERE valid_to IS NULL;
CREATE INDEX ix_quad_graph_s ON sem.quad (graph_iri, s) WHERE valid_to IS NULL;
CREATE INDEX ix_quad_chunk   ON sem.quad (source_chunk_id) WHERE source_chunk_id IS NOT NULL;
CREATE INDEX ix_quad_job     ON sem.quad (job_run_id) WHERE job_run_id IS NOT NULL;

-- 파생 사실의 근거 (CKD 교훈: derived / derivedBy / fromFacts)
CREATE TABLE sem.derivation (
    quad_id          BIGINT PRIMARY KEY REFERENCES sem.quad(quad_id) ON DELETE CASCADE,
    derived_by       VARCHAR(300) NOT NULL,      -- 규칙 IRI(rules/otd-risk) 또는 모델 버전
    from_facts       BIGINT[] NOT NULL,          -- 근거 quad_id 목록 (가상화 사실은 IRI 로 from_iris 에)
    from_iris        TEXT[] NOT NULL DEFAULT '{}',
    derived_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 동일성 판정 — owl:sameAs 를 전역으로 쓰지 않는다. 같지 않다는 판정도 영속화해 재병합을 막는다.
CREATE TABLE sem.identity_decision (
    decision_id      BIGSERIAL PRIMARY KEY,
    left_iri         VARCHAR(500) NOT NULL,
    right_iri        VARCHAR(500) NOT NULL,
    verdict          VARCHAR(12) NOT NULL CHECK (verdict IN ('SAME','NOT_SAME')),
    group_id         VARCHAR(100),               -- SAME 은 검증 그룹 안에서만 폐포 계산
    method           VARCHAR(10) NOT NULL CHECK (method IN ('rule','embedding','llm','human')),
    evidence         TEXT,
    decided_by       VARCHAR(50),
    decided_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    enterprise_id    VARCHAR(50),                -- 판정 대상 회사. NULL = 공용(표준 개념) (재검토 N5)
    CHECK (left_iri COLLATE "C" < right_iri COLLATE "C"),   -- 바이트 순서로 고정: DB 콜레이션과 무관하게 앱 정렬과 같다 (리뷰 F25)
    UNIQUE (left_iri, right_iri)
);

-- 별칭 (다국어·약어 표기: PDRN / 피디알엔)
CREATE TABLE sem.alias (
    entity_iri       VARCHAR(500) NOT NULL,
    alias            VARCHAR(300) NOT NULL,
    lang             VARCHAR(10),
    source           VARCHAR(50),
    enterprise_id    VARCHAR(50),                -- NULL = 공용 별칭 (재검토 N5)
    PRIMARY KEY (entity_iri, alias)
);

-- 임베딩 인덱스 (pgvector). 차원은 1024 로 통일한다(bge-m3 등 다국어 모델 기준).
-- HNSW 는 index_id 마다 부분 인덱스를 따로 만든다 (리뷰 F20). 하나로 섞으면 "청크만" 같은 필터 질의가
-- ef_search 후보를 다른 대상에 빼앗겨 결과가 모자라거나 빈다. 질의는 반드시 WHERE index_id = '<id>' 를 붙인다.
-- pgvector 0.8 이상이면 SET hnsw.iterative_scan = relaxed_order 로 회사·공장 필터 재현율도 보강한다.
-- 수천만 건을 넘겨 분리가 필요해지면 store_uri 를 외부 벡터DB 로 바꾸고 embedding 을 비운다.
CREATE TABLE sem.embedding_index (
    index_id         VARCHAR(100) PRIMARY KEY,
    model_name       VARCHAR(100) NOT NULL,
    dimension        INTEGER NOT NULL DEFAULT 1024 CHECK (dimension = 1024),
    target           VARCHAR(20) NOT NULL CHECK (target IN ('NODE','CHUNK','SCHEMA')),  -- SCHEMA = 클래스·속성 라벨(자동 매핑용)
    store_uri        VARCHAR(500) NOT NULL DEFAULT 'postgresql://lake/sem.embedding_item',
    item_count       BIGINT,
    built_at         TIMESTAMPTZ
);
CREATE TABLE sem.embedding_item (
    index_id         VARCHAR(100) NOT NULL REFERENCES sem.embedding_index(index_id),
    item_key         VARCHAR(500) NOT NULL,      -- 노드 IRI 또는 chunk_id
    enterprise_id    VARCHAR(50),                -- NULL = 공용(클래스·속성 라벨 등 SCHEMA 임베딩)
    site_id          VARCHAR(50),
    plant_id         VARCHAR(50),
    text_hash        CHAR(64) NOT NULL,          -- 원문이 바뀌면 재임베딩
    content          TEXT,                       -- 원문 (근거 인용·재랭킹용)
    embedding        vector(1024) NOT NULL,
    embedded_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (index_id, item_key)
);
-- 코사인 유사도 HNSW 부분 인덱스 — embedding_index 에 행을 넣으면 트리거가 만든다.
-- 질의: SELECT ... FROM sem.embedding_item WHERE index_id = 'chunks' ORDER BY embedding <=> $1 LIMIT k
-- 대량 빌드 전: SET maintenance_work_mem = '2GB'; SET max_parallel_maintenance_workers = 4;
CREATE OR REPLACE FUNCTION sem.ensure_embedding_hnsw() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, sem AS $$
DECLARE opclass text := (SELECT quote_ident(extnamespace::regnamespace::text) || '.vector_cosine_ops' FROM pg_extension WHERE extname = 'vector');
BEGIN
  EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON sem.embedding_item USING hnsw (embedding %s) '
                 'WITH (m = 16, ef_construction = 64) WHERE index_id = %L',
                 'ix_emb_hnsw_' || left(md5(NEW.index_id), 12), opclass, NEW.index_id);
  RETURN NEW;
END $$;
CREATE TRIGGER trg_embedding_index_hnsw AFTER INSERT ON sem.embedding_index
    FOR EACH ROW EXECUTE FUNCTION sem.ensure_embedding_hnsw();

-- 추론으로 생긴 리스크 이벤트 원장 (Decision Engine 입력)
CREATE TABLE sem.risk_event (
    event_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_class_iri  VARCHAR(300) NOT NULL REFERENCES onto.class(class_iri) DEFERRABLE INITIALLY DEFERRED,  -- arcon:OTDRiskEvent | arcon:SpecOutEvent | arcon:SupplyRiskEvent
    enterprise_id    VARCHAR(50) NOT NULL,
    site_id          VARCHAR(50),
    plant_id         VARCHAR(50),
    source_iri       VARCHAR(500) NOT NULL,      -- 원인 개체
    affected_iris    TEXT[] NOT NULL DEFAULT '{}',
    risk_level       VARCHAR(10) NOT NULL CHECK (risk_level IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    detail           JSONB,
    derived_by       VARCHAR(300) NOT NULL,
    detected_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    status           VARCHAR(12) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','ACTIONED','SUPPRESSED','CLOSED'))
);
CREATE INDEX ix_risk_open ON sem.risk_event (enterprise_id, status) WHERE status = 'OPEN';
