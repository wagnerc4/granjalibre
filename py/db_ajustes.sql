-- psql granjalibre -v activity='1' -f db_ajustes.sql
-- \set activity '1'

CREATE SCHEMA activity_:activity;

SET search_path TO activity_:activity;


/******************************************************************/
/**************************** TABLES ******************************/
/******************************************************************/
CREATE TABLE workers (
  id SERIAL PRIMARY KEY NOT NULL,
  worker VARCHAR(50) UNIQUE NOT NULL,
  phones VARCHAR(100) NOT NULL,
  email VARCHAR(50) UNIQUE NOT NULL,
  pass CHAR(40) NOT NULL,
  privilege VARCHAR(10) NOT NULL,
  access TEXT NOT NULL,
  root BOOLEAN NOT NULL,
  CHECK (TRIM(worker) <> '' AND worker !~ '[^a-zA-Z0-9 ().-]+'),
  CHECK (TRIM(phones) <> '' AND phones !~ '[^0-9 (),-]+'),
  CHECK (TRIM(email) <> '' AND email !~ '[^a-z0-9@_.-]+'),
  CHECK (privilege IN ('select', 'insert', 'update', 'delete')),
  CHECK (TRIM(access) <> '' AND access !~ '[^a-z0-9_,]+')
);

/*
select max(id) from workers;
ALTER SEQUENCE workers_id_seq RESTART WITH 26;
*/


CREATE TABLE calendar (
  id SERIAL PRIMARY KEY NOT NULL,
  worker VARCHAR(50) NOT NULL,
  color VARCHAR(10) DEFAULT NULL,
  title VARCHAR(100) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  CHECK (TRIM(color) <> '' AND color !~ '[^a-z0-9#]+'),
  CHECK (TRIM(title) <> '' AND title !~ '[^a-zA-Z0-9 ()#$:,./-]+')
);


CREATE TABLE querys (
  id SERIAL PRIMARY KEY NOT NULL,
  query TEXT NOT NULL,
  defs TEXT NOT NULL,
  code VARCHAR(50) UNIQUE NOT NULL,
  title VARCHAR(100) UNIQUE NOT NULL,
  graph_type VARCHAR(20) DEFAULT NULL,
  graph_x VARCHAR(20) DEFAULT NULL,
  graph_y VARCHAR(20) DEFAULT NULL,
  CHECK (TRIM(query) <> '' AND query !~* '[^a-z0-9 _\]\[{}()"'';:,.&|?!~$%<>=/*+-\\^]+'),
  CHECK (TRIM(defs) <> '' AND defs !~* '[^a-z0-9 _\]\[{}()"'';:,.&|?!~$%<>=/*+-\\^]+'),
  CHECK (TRIM(code) <> '' AND code !~* '[^a-z0-9_]+'),
  CHECK (TRIM(title) <> '' AND title !~* '[^a-z0-9 @#&()"'';:,.%<>=/*+-]+'),
  CHECK (TRIM(graph_type) <> '' AND graph_type !~* '[^a-z0-9_]+'),
  CHECK (TRIM(graph_x) <> '' AND graph_x !~* '[^0-9,]+'),
  CHECK (TRIM(graph_y) <> '' AND graph_y !~* '[^0-9,]+')
);


----------------------- ALERTS ------------------
CREATE TABLE crons (
  id SERIAL PRIMARY KEY NOT NULL,
  cron VARCHAR(100) UNIQUE NOT NULL,
  CHECK (TRIM(cron) <> '' AND cron !~* '[^a-z0-9 /*,-]+')
);

-- INSERT INTO crons VALUES(DEFAULT, '*/5 5-17 * * 1-5');
-- INSERT INTO crons VALUES(DEFAULT, '0 6 * * 1-6');
-- INSERT INTO crons VALUES(DEFAULT, '0 12 * * 1-6');
-- INSERT INTO crons VALUES(DEFAULT, '0 5 1 * *');


CREATE TABLE alerts (
  id SERIAL PRIMARY KEY NOT NULL,
  cron_id INTEGER NOT NULL,
  query_id INTEGER NOT NULL,
  type VARCHAR(10) NOT NULL,
  CHECK (type in ('sms', 'calendar', 'notify')),
  FOREIGN KEY(cron_id) REFERENCES crons(id),
  FOREIGN KEY(query_id) REFERENCES querys(id)
);


CREATE TABLE alerts_targets (
  id SERIAL PRIMARY KEY NOT NULL,
  alert_id INTEGER NOT NULL,
  target VARCHAR(50) NOT NULL,
  CHECK (TRIM(target) <> '' AND target !~* '[^a-z0-9 &#;.+-]+'),
  FOREIGN KEY(alert_id) REFERENCES alerts(id) ON DELETE CASCADE
);


CREATE TABLE alerts_done (
  id INTEGER PRIMARY KEY NOT NULL,
  last_day DATE NOT NULL,
  FOREIGN KEY(id) REFERENCES alerts(id) ON DELETE CASCADE
);


/*******************************************************************/
/************************** FUNCTIONS ******************************/
/*******************************************************************/





/******************************************************************/
/************************** TRIGGERS ******************************/
/******************************************************************/




/******************************************************************/
/*************************** QUERIES ******************************/
/******************************************************************/
/*
INSERT INTO querys VALUES(
  DEFAULT,
  REGEXP_REPLACE('
SELECT c.relname AS table,
        (SELECT STRING_AGG(attname, '','') FROM pg_catalog.pg_attribute
         WHERE attrelid=c.oid AND attnum > 0 AND NOT attisdropped) AS columns
FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON c.relnamespace=n.oid
WHERE c.relkind IN (''r'', ''v'') AND n.nspname=%(schema)s ORDER BY c.relname;
', '\s+\n', '\\\\', 'g'),
  '[]',
  'query_tables',
  'Estructura tablas',
  NULL, NULL, NULL);
*/
