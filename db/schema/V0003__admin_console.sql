-- =============================================================================
-- V0003 — 관리 화면(권한·감사)용 사용자·역할 조회
-- lake_app 은 gov.app_user·gov.role_assignment 를 직접 읽지 못한다. 관리자(admin)만 자기 회사 사용자 목록을 본다.
-- =============================================================================
CREATE OR REPLACE FUNCTION gov.admin_role_assignments()
RETURNS TABLE (user_id text, display_name text, status text, role_id text, role_label text,
               site_id text, plant_id text, valid_until date, granted_by text, granted_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_user text := nullif(current_setting('app.user_id', true), '');
  v_ent  text := nullif(current_setting('app.enterprise_id', true), '');
BEGIN
  IF NOT EXISTS (SELECT 1 FROM gov.role_assignment ra
                  WHERE ra.user_id = v_user AND ra.enterprise_id = v_ent AND ra.role_id = 'admin'
                    AND (ra.valid_until IS NULL OR ra.valid_until >= current_date)) THEN
    RAISE EXCEPTION '사용자·역할 목록은 관리자(admin)만 볼 수 있습니다';
  END IF;
  RETURN QUERY
  SELECT u.user_id::text, u.display_name::text, u.status::text, ra.role_id::text, r.label_ko::text,
         ra.site_id::text, ra.plant_id::text, ra.valid_until, ra.granted_by::text, ra.granted_at
    FROM gov.app_user u
    LEFT JOIN gov.role_assignment ra ON ra.user_id = u.user_id AND ra.enterprise_id = u.enterprise_id
    LEFT JOIN gov.role r ON r.role_id = ra.role_id
   WHERE u.enterprise_id = v_ent
   ORDER BY u.user_id, ra.role_id;
END $$;
REVOKE ALL ON FUNCTION gov.admin_role_assignments() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.admin_role_assignments() TO lake_app;
GRANT SELECT ON gov.role TO lake_app;
