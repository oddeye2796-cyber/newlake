-- V0011: 미리보기에서 키 값이 비어 있는 행(현장 내보내기의 합계·소계 줄 등)을 배치 전체에서 센다.
-- 미리보기는 앞 200행만 보여 주므로 맨 끝 합계 줄은 변환 때 "not-null 위반" 으로만 드러났다.
CREATE OR REPLACE FUNCTION gov.ingest_batch_blank_keys(p_batch_id uuid, p_cols text[])
RETURNS TABLE (n bigint, first_seq bigint, last_seq bigint) LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_ingest_role();
BEGIN
  IF NOT EXISTS (SELECT 1 FROM raw.ingest_batch b JOIN catalog.dataset d ON d.dataset_id = b.dataset_id
                  WHERE b.batch_id = p_batch_id AND d.enterprise_id = v_ent) THEN
    RAISE EXCEPTION '배치 % 가 없거나 다른 회사 것입니다', p_batch_id;
  END IF;
  IF p_cols IS NULL OR cardinality(p_cols) = 0 THEN
    n := 0; first_seq := NULL; last_seq := NULL; RETURN NEXT; RETURN;
  END IF;
  RETURN QUERY SELECT count(*)::bigint, min(r.record_seq), max(r.record_seq)
                 FROM raw.landing_record r
                WHERE r.batch_id = p_batch_id
                  AND EXISTS (SELECT 1 FROM unnest(p_cols) c WHERE nullif(btrim(r.payload ->> c), '') IS NULL);
END $$;
REVOKE ALL ON FUNCTION gov.ingest_batch_blank_keys(uuid, text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.ingest_batch_blank_keys(uuid, text[]) TO lake_app;
