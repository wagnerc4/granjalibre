-- psql contabilidad -v activity='1' -f db_users.sql



GRANT USAGE ON SCHEMA activity_:activity TO select_user;
GRANT SELECT ON ALL TABLES IN SCHEMA activity_:activity TO select_user;

GRANT USAGE ON SCHEMA activity_:activity TO update_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA activity_:activity TO update_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA activity_:activity TO update_user;

GRANT USAGE ON SCHEMA activity_:activity TO delete_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA activity_:activity TO delete_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA activity_:activity TO delete_user;



-- REVOKE ALL ON ALL TABLES IN SCHEMA public FROM select_user;
-- REVOKE ALL ON ALL TABLES IN SCHEMA activity_1 FROM select_user;
-- REVOKE ALL ON SCHEMA activity_1 FROM select_user;
-- DROP ROLE select_user;

-- REVOKE ALL ON ALL TABLES IN SCHEMA public FROM update_user;
-- REVOKE ALL ON ALL TABLES IN SCHEMA activity_1 FROM update_user;
-- REVOKE ALL ON ALL SEQUENCES IN SCHEMA activity_1 FROM update_user;
-- REVOKE ALL ON SCHEMA activity_1 FROM update_user;
-- DROP ROLE update_user;

-- REVOKE ALL ON ALL TABLES IN SCHEMA public FROM delete_user;
-- REVOKE ALL ON ALL TABLES IN SCHEMA activity_1 FROM delete_user;
-- REVOKE ALL ON ALL SEQUENCES IN SCHEMA activity_1 FROM delete_user;
-- REVOKE ALL ON SCHEMA activity_1 FROM delete_user;
-- DROP ROLE delete_user;



GRANT USAGE ON SCHEMA activity_:activity TO repuser;
GRANT SELECT ON ALL TABLES IN SCHEMA activity_:activity TO repuser;
