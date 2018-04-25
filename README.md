# granjalibre
Animals production application

Packages needed:

postgresql python3-psycopg2 python3-tz python3-bottle

Install:

  createuser -s root

  createdb granjalibre

  psql granjalibre -f db_main_tables.sql

  psql granjalibre -f db_main_triggers.sql

  psql granjalibre -v activity='1' -f db_ajustes.sql
  
  psql granjalibre -v activity='1' -f db_reproduction_tables.sql

  psql granjalibre -v activity='1' -f db_reproduction_triggers.sql

  psql granjalibre -v activity='1' -f db_production_tables.sql

  psql granjalibre -v activity='1' -f db_production_triggers.sql

  psql granjalibre -v activity='1' -f db_users.sql

  psql granjalibre

    INSERT INTO farms VALUES(1, 'COOP FARM', 'coop', 'user@mail.com', MD5('pass'), 0);

    INSERT INTO activities VALUES(1, 1, 'pig', 'meet', 0, 'granjax', NULL, NULL, 'COOP FARM');

    SET search_path to activity_1;

    INSERT INTO workers VALUES(DEFAULT, 'x', '123', 'user@mail.com', MD5('pass'),
                               'delete', 'settings_roles', TRUE);
