-- 역할 주기에서 사업장·공장을 직접 입력했을 때, 없으면 마스터에 새로 등록한다 (관리자만).
CREATE OR REPLACE FUNCTION gov.ensure_scope(p_site_id text, p_plant_id text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov, ksx AS $$
DECLARE
  v_ent text := gov.require_admin();
  v_me  text := current_setting('app.user_id', true);
  v_site_new boolean := false;
  v_plant_new boolean := false;
BEGIN
  IF nullif(btrim(p_site_id), '') IS NULL THEN
    RETURN jsonb_build_object('site_created', false, 'plant_created', false);
  END IF;
  INSERT INTO ksx.site (enterprise_id, site_id, creator_id, creation_date_time)
  VALUES (v_ent, btrim(p_site_id), v_me, now())
  ON CONFLICT DO NOTHING;
  v_site_new := FOUND;
  IF nullif(btrim(p_plant_id), '') IS NOT NULL THEN
    INSERT INTO ksx.plant (enterprise_id, site_id, plant_id, creator_id, creation_date_time)
    VALUES (v_ent, btrim(p_site_id), btrim(p_plant_id), v_me, now())
    ON CONFLICT DO NOTHING;
    v_plant_new := FOUND;
  END IF;
  IF v_site_new OR v_plant_new THEN
    INSERT INTO gov.audit_log (channel, action, object_ref, query_text)
    VALUES ('UI', 'ensure_scope', 'ksx.site:' || btrim(p_site_id),
            CASE WHEN v_site_new THEN 'site ' ELSE '' END || CASE WHEN v_plant_new THEN 'plant ' || btrim(p_plant_id) ELSE '' END);
  END IF;
  RETURN jsonb_build_object('site_created', v_site_new, 'plant_created', v_plant_new);
END $$;
GRANT EXECUTE ON FUNCTION gov.ensure_scope(text, text) TO lake_app;
