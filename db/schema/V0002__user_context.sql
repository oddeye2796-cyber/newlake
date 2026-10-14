-- =============================================================================
-- V0002 — 로그인 사용자 → 범위·역할 해석 (API 서버용)
-- lake_app 은 gov.app_user·gov.role_assignment 를 직접 읽지 못한다. 서버는 요청마다 이 함수로
-- 사용자의 회사·사업장·공장 범위와 역할을 받아 SET LOCAL app.* 에 넣는다.
-- 범위 규칙: 역할 배정 중 site_id 가 NULL 인 것이 하나라도 있으면 사업장 '*', 아니면 배정된 사업장 목록. 공장도 같다.
-- =============================================================================
CREATE OR REPLACE FUNCTION gov.user_context(p_user_id text)
RETURNS TABLE (user_id text, display_name text, enterprise_id text, roles text[], site_ids text, plant_ids text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
  SELECT u.user_id::text, u.display_name::text, u.enterprise_id::text,
         coalesce(array_agg(DISTINCT ra.role_id::text) FILTER (WHERE ra.role_id IS NOT NULL), '{}'),
         CASE WHEN bool_or(ra.site_id IS NULL) OR count(ra.role_id) = 0 THEN '*'
              ELSE string_agg(DISTINCT ra.site_id, ',') END,
         CASE WHEN bool_or(ra.plant_id IS NULL) OR count(ra.role_id) = 0 THEN '*'
              ELSE string_agg(DISTINCT ra.plant_id, ',') END
    FROM gov.app_user u
    LEFT JOIN gov.role_assignment ra
      ON ra.user_id = u.user_id AND ra.enterprise_id = u.enterprise_id
     AND (ra.valid_until IS NULL OR ra.valid_until >= current_date)
   WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
   GROUP BY u.user_id, u.display_name, u.enterprise_id
$$;
REVOKE ALL ON FUNCTION gov.user_context(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.user_context(text) TO lake_app;
