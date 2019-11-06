-- psql conta2 -v activity='1' -f db_update.sql


SET search_path TO activity_:activity;


DROP TABLE events_querys;

CREATE TABLE events_querys (
  id SERIAL PRIMARY KEY NOT NULL,
  lft INTEGER NOT NULL,
  rgt INTEGER NOT NULL,
  title VARCHAR(100) UNIQUE NOT NULL,
  tbl TEXT DEFAULT NULL,
  var TEXT DEFAULT NULL,
  rnd INTEGER DEFAULT NULL,
  agg BOOLEAN DEFAULT NULL,
  CHECK (lft > 0),
  CHECK (rgt > 0),
  CHECK (TRIM(title) <> '' AND title !~* '[^a-z0-9 @#&()"'';:,.%<>=/*+-]+'),
  CHECK (TRIM(tbl) <> '' AND tbl !~* '[^a-z0-9 _\]\[{}()"'';:,.&|?!~$%<>=/*+-\\^]+'),
  CHECK (TRIM(var) <> '' AND var !~* '[^a-z0-9 _\]\[{}()"'';:,.&|?!~$%<>=/*+-\\^]+'),
  CHECK (rnd >= 0 AND rnd <=4)
);


CREATE OR REPLACE FUNCTION get_events_querys(ids INT[], d1 DATE, d2 DATE, g1 TEXT, g2 TEXT)
RETURNS TABLE(x TEXT, y TEXT, z NUMERIC) AS $$
DECLARE
  r RECORD;
BEGIN
  g1 := REPLACE(g1, 'parity', 'parity_char');
  g2 := REPLACE(g2, 'parity', 'parity_char');
  g2 := CASE WHEN g1 <> g2 AND g2 <> '' THEN g2 ELSE NULL END;
  FOR r IN SELECT * FROM events_querys WHERE id IN (SELECT UNNEST(ids)) ORDER BY lft LOOP
    RETURN QUERY EXECUTE
      FORMAT('WITH t AS(SELECT * FROM %s t,
                        LATERAL (SELECT (SELECT animal FROM animals WHERE id=t.animal_id),
                                        (SELECT race FROM races WHERE id=t.race_id),
                                        (SELECT worker FROM workers WHERE id=t.worker_id),
                                        TO_CHAR(t.parity, ''00'') AS parity_char,
                                        TO_CHAR(TO_TIMESTAMP(t.ts), ''YYYY-WW'') AS week,
                                        TO_CHAR(TO_TIMESTAMP(t.ts), ''YYYY-mm'') AS month,
                                        TO_CHAR(TO_TIMESTAMP(t.ts), ''YYYY'') AS year) g
                        WHERE TO_TIMESTAMP(ts)::DATE >= ''%s'' AND
                              TO_TIMESTAMP(ts)::DATE <= ''%s'')
              SELECT CONCAT_WS(''_'', ''%s'', %s) AS x, %s::TEXT AS y, ROUND(%s, %s)
              FROM t GROUP BY %s UNION
              SELECT CONCAT_WS(''_'', ''%s'', %s), NULL, ROUND(%s, %s)
              FROM t %s ORDER BY y, x;', FORMAT(r.tbl, d1, d2), d1, d2,
             r.title, COALESCE(g2, 'NULL'), g1,
             CASE WHEN r.agg AND g1 IN ('year', 'month', 'week') AND g2 IS NULL
                  THEN 'SUM(' || r.var || ') OVER (ORDER BY ' || g1 || ')' ELSE r.var END, r.rnd,
             CONCAT_WS(',', g1, g2),
             r.title, COALESCE(g2, 'NULL'), r.var, r.rnd,
             CASE WHEN g2 IS NULL THEN '' ELSE 'GROUP BY ' || g2 END);
  END LOOP;
END;
$$
LANGUAGE plpgsql;

/*
SELECT id, title, tbl FROM events_querys ORDER BY id;

-- SEVICIOS
SELECT * FROM get_events_querys(ARRAY[2,3,4,5,6,7,8,9,10,11,12,13,14], '2018-01-01', '2018-08-30', 'month', '') \crosstabview

-- PARTOS
SELECT * FROM get_events_querys(ARRAY[16,17,18,19,20,21,22,23,24,25,26,27], '2018-01-01', '2018-08-30', 'month', '') \crosstabview

-- DESTETES
SELECT * FROM get_events_querys(ARRAY[29,30,31,32,33,34,35,36,37,38], '2018-01-01', '2018-08-30', 'month', '') \crosstabview

-- INVENTARIOS
SELECT * FROM get_events_querys(ARRAY[40,41,42,43,44,45,46,47], '2018-01-01', '2018-08-30', 'month', '') \crosstabview


SELECT * FROM get_events_querys(ARRAY[2,3,4,5,6,7,8,9,10,11,12,13,14,
                                      16,17,18,19,20,21,22,23,24,25,26,27,
                                      29,30,31,32,33,34,35,36,37,38,
                                      40,41,42,43,44,45,46,47,48,49,50], '2018-01-01', '2018-08-30', 'month', '') \crosstabview
*/


INSERT INTO events_querys
VALUES(DEFAULT, 1, 28, 'SERVICIOS', NULL, NULL, NULL, NULL);

INSERT INTO events_querys
VALUES(DEFAULT, 2, 3, 'Total Servicios', 'ev_service', 'SUM(1)', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 4, 5, 'Total 1er Servicios', 'ev_service', 'SUM(1-repeat::INT)', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 6, 7, 'Total Repeticiones', 'ev_service', 'SUM(repeat::INT)', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 8, 9, 'Porcentage Repeticiones', 'ev_service', 'SUM(repeat::INT)::NUMERIC / SUM(1)::NUMERIC * 100', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 10, 11, 'Total Cubriciones Multiples', 'ev_service', 'SUM(1) FILTER (WHERE matings > 1)', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 12, 13, 'Porcentage Cubriciones Multiples', 'ev_service', 'SUM(1) FILTER (WHERE matings > 1)::NUMERIC / SUM(1)::NUMERIC * 100', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 14, 15, 'Promedio Cubriciones / Servicio', 'ev_service', 'SUM(matings)::NUMERIC / SUM(1)::NUMERIC', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 16, 17, 'Promedio Edad Ingreso', 'ev_entry_female', 'AVG(ts - (SELECT birth_ts FROM animals WHERE id=t.animal_id)) / 86400', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 18, 19, 'Promedio Edad 1er Servicio Nuliparas', 'ev_service', 'AVG(ts - (SELECT birth_ts FROM animals WHERE id=t.animal_id)) FILTER(WHERE NOT repeat AND parity = 0) / 86400', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 20, 21, 'Total 1er Servicio Nuliparas', 'ev_service', 'SUM(1) FILTER(WHERE NOT repeat AND parity = 0)', 0, FALSE);

-- Entry to 1st service interval

INSERT INTO events_querys
VALUES(DEFAULT, 22, 23, 'Total 1er Servicio Multiparas', 'ev_service', 'SUM(1) FILTER(WHERE NOT repeat AND parity > 0)', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 24, 25, 'Promedio Intervalo destete - 1er Servicio', 'ev_service',
       'AVG(ts - (SELECT MAX(ts) FROM ev_wean WHERE id < t.id AND animal_id=t.animal_id)) FILTER(WHERE NOT repeat AND parity > 0) / 86400', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 26, 27, 'Porcentage Servidas 7 dias', 'ev_service',
       '(SUM(((ts - (SELECT MAX(ts) FROM ev_wean WHERE id < t.id AND animal_id=t.animal_id)) <= (7 * 86400))::INT) FILTER(WHERE NOT repeat AND parity > 0))::NUMERIC / SUM(1-repeat::INT) * 100', 1, FALSE);

-- % Presumed Pregnant at [n] days

-- Farrowing rate (service cohort)



INSERT INTO events_querys
VALUES(DEFAULT, 29, 54, 'PARTOS', NULL, NULL, NULL, NULL);

INSERT INTO events_querys
VALUES(DEFAULT, 30, 31, 'Total Partos', 'ev_farrow', 'SUM(1)', 0, FALSE);

-- Avg parity farrowed

INSERT INTO events_querys
VALUES(DEFAULT, 32, 33, 'Porcentage Nacidos Vivos < 7', 'ev_farrow', 'SUM(1) FILTER (WHERE (males+females) < 7)::NUMERIC / SUM(1)::NUMERIC * 100', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 34, 35, 'Promedio Nacidos / Camada', 'ev_farrow', 'AVG(males+females+deaths+mummies)', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 36, 37, 'Promedio Vivos / Camada', 'ev_farrow', 'AVG(males+females)', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 38, 39, 'Promedio Muertos / Camada', 'ev_farrow', 'AVG(deaths)', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 40, 41, 'Porcentage Muertos', 'ev_farrow', 'SUM(deaths)::NUMERIC / SUM(males+females+deaths+mummies)::NUMERIC * 100', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 42, 43, 'Promedio Momias / Camada', 'ev_farrow', 'AVG(mummies)', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 44, 45, 'Porcentage Momias', 'ev_farrow', 'SUM(mummies)::NUMERIC / SUM(males+females+deaths+mummies)::NUMERIC * 100', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 46, 47, 'Promedio Peso / Nacidos Vivos', 'ev_farrow', 'SUM(weight)/SUM(males+females)', 1, FALSE);

-- Farrowing rate

-- Adjusted farrowing rate

INSERT INTO events_querys
VALUES(DEFAULT, 48, 49, 'Promedio Intervalo Servicio - Parto', 'ev_farrow', 'AVG(ts - (SELECT MAX(ts) FROM ev_service WHERE id < t.id AND animal_id=t.animal_id)) / 86400', 1, FALSE);  -- TODO

INSERT INTO events_querys
VALUES(DEFAULT, 50, 51, 'Promedio Intervalo Parto - Parto', 'ev_farrow', 'AVG(ts - (SELECT MAX(ts) FROM ev_farrow WHERE id < t.id AND animal_id=t.animal_id)) FILTER(WHERE parity > 1) / 86400', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 52, 53, 'Total Abortos', 'ev_abortion', 'SUM(1)', 0, FALSE);

-- Preweaning mortality rate

-- Litters / mated female / year

-- Litters / female / year

-- Liveborn / mated female /year



INSERT INTO events_querys
VALUES(DEFAULT, 55, 76, 'DESTETES', NULL, NULL, NULL, NULL);

INSERT INTO events_querys
VALUES(DEFAULT, 56, 57, 'Total Animales Destetados', '(SELECT * FROM ev_wean UNION SELECT * FROM ev_partial_wean)', 'SUM(animals)', 0, FALSE);

/*
INSERT INTO events_querys
VALUES(DEFAULT, 58, 59, 'Total Hembras Destetadas', '(SELECT * FROM ev_wean UNION SELECT * FROM ev_partial_wean)', 'COUNT(DISTINCT animal_id)', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 60, 61, 'Promedio Destetados / Hembra', '(SELECT * FROM ev_wean UNION SELECT * FROM ev_partial_wean)', 'SUM(animals)::NUMERIC / COUNT(DISTINCT animal_id)', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 62, 63, 'Promedio Peso / Animal', '(SELECT * FROM ev_wean UNION SELECT * FROM ev_partial_wean)',
       'CASE WHEN SUM(animals) > 0 THEN SUM(weight) / SUM(animals) ELSE 0 END', 1, FALSE);
*/

INSERT INTO events_querys
VALUES(DEFAULT, 58, 59, 'Total Camadas Destetadas', 'ev_wean', 'SUM(1)', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 60, 61, 'Total Animales Destetadas / Camada', 'ev_wean',
       'SUM(COALESCE((SELECT SUM(animals) FROM ev_partial_wean WHERE animal_id=t.animal_id AND parity=t.parity), 0) + animals)', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 62, 63, 'Promedio Destetados / Camada', 'ev_wean',
       'SUM(COALESCE((SELECT SUM(animals) FROM ev_partial_wean WHERE animal_id=t.animal_id AND parity=t.parity), 0) + animals)::NUMERIC / SUM(1)', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 64, 65, 'Promedio Peso / Animal', 'ev_wean',
       'CASE WHEN SUM(COALESCE((SELECT SUM(animals) FROM ev_partial_wean WHERE animal_id=t.animal_id AND parity=t.parity), 0) + animals) > 0 ' ||
       '     THEN SUM(COALESCE((SELECT SUM(weight) FROM ev_partial_wean WHERE animal_id=t.animal_id AND parity=t.parity), 0) + weight) / ' ||
       '          SUM(COALESCE((SELECT SUM(animals) FROM ev_partial_wean WHERE animal_id=t.animal_id AND parity=t.parity), 0) + animals) ' ||
       '     ELSE 0 END', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 66, 67, 'Promedio Edad Destete', 'ev_wean',
       'AVG(ts - (SELECT ts FROM ev_farrow WHERE animal_id=t.animal_id AND parity=t.parity)) / 86400', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 68, 69, 'Porcentage Destetadas Servidas 7 dias', 'ev_wean',
       '(SUM(COALESCE((((SELECT MIN(ts) FROM ev_service WHERE id > t.id AND animal_id=t.animal_id)-ts) <= (7 * 86400))::INT, 0)))::NUMERIC / SUM(1) * 100', 1, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 70, 71, 'Total Adopciones Netas', 'ev_wean',
       'SUM(COALESCE((SELECT SUM(animals) FROM ev_adoption WHERE animal_id=t.animal_id AND parity=t.parity), 0) -' ||
       '    COALESCE((SELECT SUM(animals) FROM ev_foster WHERE animal_id=t.animal_id AND parity=t.parity), 0))', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 72, 73, 'Total Muertes Predestete', 'ev_wean',
       'SUM((SELECT SUM(animals) FROM ev_death WHERE animal_id=t.animal_id AND parity=t.parity))', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 74, 75, 'Porcentage Mortalidad Predestete',
       '(SELECT *, (SELECT males+females FROM ev_farrow WHERE animal_id=e.animal_id AND parity=e.parity) +' ||
       '           COALESCE((SELECT SUM(animals) FROM ev_adoption WHERE animal_id=e.animal_id AND parity=e.parity), 0) -' ||
       '           COALESCE((SELECT SUM(animals) FROM ev_foster WHERE animal_id=e.animal_id AND parity=e.parity), 0) AS piglets' ||
       ' FROM ev_wean e)',
       'CASE WHEN SUM(piglets) > 0 ' ||
       '     THEN SUM(piglets - COALESCE((SELECT SUM(animals) FROM ev_partial_wean ' ||
       '                                  WHERE animal_id=t.animal_id AND parity=t.parity), 0) - animals) / ' ||
       '          SUM(piglets) * 100' ||
       '     ELSE 0 END', 1, FALSE);

/*
Weaned / mated female / year - average number of weaned pigs produced per mated female, calculated on an annualized basis. Excludes the gilt pool.
Expression: TotalWeaned * 365 / MatedFemaleDays

Weaned / female / year - average number of weaned pigs produced per female, calculated on an annualized basis. Includes the gilt pool.
Expression: TotalWeaned * 365 / FemaleDays
*/


INSERT INTO events_querys
VALUES(DEFAULT, 77, 94, 'INVENTARIOS', NULL, NULL, NULL, NULL);


-- DELETE FROM events_querys WHERE id IN (40, 41);
INSERT INTO events_querys
VALUES(DEFAULT, 78, 79, 'Total Machos',
       '(SELECT id, animal_id, race_id, worker_id,' ||
       '        CASE WHEN TO_TIMESTAMP(ts)::DATE < ''%1$s''' ||
       '             THEN EXTRACT(epoch FROM ''%1$s''::TIMESTAMP WITH TIME ZONE)' ||
       '             ELSE ts END AS ts,' ||
       '        parity, tableoid::regclass::name AS tablename' ||
       ' FROM events e' ||
       ' WHERE TO_TIMESTAMP(ts)::DATE <= ''%2$s'' AND' ||
       '       (tableoid = ''ev_entry_male''::regclass::oid AND' ||
       '        NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=e.animal_id AND' ||
       '                   TO_TIMESTAMP(ts)::DATE < ''%1$s'') OR' ||
       '        tableoid = ''ev_sale''::regclass::oid AND' ||
       '        TO_TIMESTAMP(ts)::DATE >= ''%1$s'' AND' ||
       '        EXISTS(SELECT id FROM ev_entry_male WHERE animal_id=e.animal_id)))',
       'SUM(CASE WHEN tablename = ''ev_sale'' THEN -1 ELSE 1 END)', 0, TRUE);

INSERT INTO events_querys
VALUES(DEFAULT, 80, 81, 'Total Hembras',
       '(SELECT id, animal_id, race_id, worker_id,' ||
       '        CASE WHEN TO_TIMESTAMP(ts)::DATE < ''%1$s''' ||
       '             THEN EXTRACT(epoch FROM ''%1$s''::TIMESTAMP WITH TIME ZONE)' ||
       '             ELSE ts END AS ts,' ||
       '        (SELECT parity FROM events' ||
       '         WHERE animal_id=e.animal_id AND TO_TIMESTAMP(ts)::DATE <= ''%2$s''' ||
       '         ORDER BY id DESC LIMIT 1) AS parity,' ||
       '        tableoid::regclass::name AS tablename' ||
       ' FROM events e' ||
       ' WHERE TO_TIMESTAMP(ts)::DATE <= ''%2$s'' AND' ||
       '       (tableoid = ''ev_entry_female''::regclass::oid AND' ||
       '        NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=e.animal_id AND' ||
       '                   TO_TIMESTAMP(ts)::DATE < ''%1$s'') OR' ||
       '        tableoid = ''ev_sale''::regclass::oid AND' ||
       '        TO_TIMESTAMP(ts)::DATE >= ''%1$s'' AND' ||
       '        EXISTS(SELECT id FROM ev_entry_female WHERE animal_id=e.animal_id)))',
       'SUM(CASE WHEN tablename = ''ev_sale'' THEN -1 ELSE 1 END)', 0, TRUE);

INSERT INTO events_querys
VALUES(DEFAULT, 80, 81, 'Total Reposiciones',
       '(SELECT id, animal_id, race_id, worker_id,' ||
       '        CASE WHEN TO_TIMESTAMP(ts)::DATE < ''%1$s''' ||
       '             THEN EXTRACT(epoch FROM ''%1$s''::TIMESTAMP WITH TIME ZONE)' ||
       '             ELSE ts END AS ts,' ||
       '        parity, tableoid::regclass::name AS tablename' ||
       ' FROM events e' ||
       ' WHERE TO_TIMESTAMP(ts)::DATE <= ''%2$s'' AND' ||
       '       (id=(SELECT MIN(id) FROM ev_service WHERE animal_id=e.animal_id) AND' ||
       '        NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=e.animal_id AND' ||
       '                   TO_TIMESTAMP(ts)::DATE < ''%1$s'') OR' ||
       '        tableoid = ''ev_entry_female''::regclass::oid AND' ||
       '        NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=e.animal_id AND' ||
       '                   TO_TIMESTAMP(ts)::DATE < ''%1$s'') OR' ||
       '        tableoid = ''ev_sale''::regclass::oid AND' ||
       '        TO_TIMESTAMP(ts)::DATE >= ''%1$s'' AND' ||
       '        EXISTS(SELECT id FROM ev_entry_female WHERE animal_id=e.animal_id))' ||
       ' UNION' ||
       ' SELECT *, ''ev_sale_service''' ||
       ' FROM events e' ||
       ' WHERE tableoid = ''ev_sale''::regclass::oid AND' ||
       '       EXISTS(SELECT id FROM ev_service WHERE animal_id=e.animal_id) AND' ||
       '       TO_TIMESTAMP(ts)::DATE >= ''%1$s'' AND TO_TIMESTAMP(ts)::DATE <= ''%2$s'')',
       'SUM(CASE tablename WHEN ''ev_entry_female'' THEN 1' ||
       '                   WHEN ''ev_service'' THEN -1' ||
       '                   WHEN ''ev_sale'' THEN -1' ||
       '                   ELSE 1 END)', 0, TRUE);

INSERT INTO events_querys
VALUES(DEFAULT, 80, 81, 'Total Productivas',
       '(SELECT id, animal_id, race_id, worker_id,' ||
       '        CASE WHEN TO_TIMESTAMP(ts)::DATE < ''%1$s''' ||
       '             THEN EXTRACT(epoch FROM ''%1$s''::TIMESTAMP WITH TIME ZONE)' ||
       '             ELSE ts END AS ts,' ||
       '        (SELECT parity FROM events' ||
       '         WHERE animal_id=e.animal_id AND TO_TIMESTAMP(ts)::DATE <= ''%2$s''' ||
       '         ORDER BY id DESC LIMIT 1) AS parity,' ||
       '        tableoid::regclass::name AS tablename' ||
       ' FROM events e' ||
       ' WHERE TO_TIMESTAMP(ts)::DATE <= ''%2$s'' AND' ||
       '       (id=(SELECT MIN(id) FROM ev_service WHERE animal_id=e.animal_id) AND' ||
       '        NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=e.animal_id AND' ||
       '                   TO_TIMESTAMP(ts)::DATE < ''%1$s'') OR' ||
       '        tableoid = ''ev_sale''::regclass::oid AND' ||
       '        TO_TIMESTAMP(ts)::DATE >= ''%1$s'' AND' ||
       '        EXISTS(SELECT id FROM ev_service WHERE animal_id=e.animal_id)))',
       'SUM(CASE WHEN tablename = ''ev_sale'' THEN -1 ELSE 1 END)', 0, TRUE);

INSERT INTO events_querys
VALUES(DEFAULT, 80, 81, 'Total Paridas',
       '(SELECT id, animal_id, race_id, worker_id,' ||
       '        CASE WHEN TO_TIMESTAMP(ts)::DATE < ''%1$s''' ||
       '             THEN EXTRACT(epoch FROM ''%1$s''::TIMESTAMP WITH TIME ZONE)' ||
       '             ELSE ts END AS ts,' ||
       '        (SELECT parity FROM events' ||
       '         WHERE animal_id=e.animal_id AND TO_TIMESTAMP(ts)::DATE <= ''%2$s''' ||
       '         ORDER BY id DESC LIMIT 1) AS parity,' ||
       '        tableoid::regclass::name AS tablename' ||
       ' FROM events e' ||
       ' WHERE TO_TIMESTAMP(ts)::DATE <= ''%2$s'' AND' ||
       '       (id=(SELECT MIN(id) FROM ev_farrow WHERE animal_id=e.animal_id) AND' ||
       '        NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=e.animal_id AND' ||
       '                   TO_TIMESTAMP(ts)::DATE < ''%1$s'') OR' ||
       '        tableoid = ''ev_sale''::regclass::oid AND' ||
       '        TO_TIMESTAMP(ts)::DATE >= ''%1$s'' AND' ||
       '        EXISTS(SELECT id FROM ev_farrow WHERE animal_id=e.animal_id)))',
       'SUM(CASE WHEN tablename = ''ev_sale'' THEN -1 ELSE 1 END)', 0, TRUE);

/*
 '(SUM(CASE WHEN tablename = ''ev_sale'' THEN -1 ELSE 1 END) FILTER (WHERE parity > 0)):NUMERIC /'
 'SUM(CASE WHEN tablename = ''ev_sale'' THEN -1 ELSE 1 END) FILTER (WHERE tablename <> ''ev_farrow'')', 1, TRUE);
*/

/*
INSERT INTO events_querys
VALUES(DEFAULT, 58, 59, 'Promedio Paridas', 'ev_entry_female',
       'SUM((NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=t.animal_id) AND ' ||
       '     EXISTS(SELECT id FROM ev_farrow WHERE animal_id=t.animal_id LIMIT 1))::INT) / ' ||
       'SUM((NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=t.animal_id))::INT)', 0, FALSE);
*/

/*
Avg total female inventory - average total female inventory during the report period. Includes the gilt pool.
Expression: FemaleDays / PeriodDays

Avg mated female inventory - average mated female inventory during the report period. Excludes the gilt pool.
Expression: MatedFemaleDays / PeriodDays

Avg unmated female inventory - average gilt pool inventory during the report period.
Expression: UnmatedFemaleDays / PeriodDays
*/

INSERT INTO events_querys
VALUES(DEFAULT, 82, 83, 'Total Hembras Ingresadas', 'ev_entry_female', 'SUM(1)', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 84, 85, 'Promedio Edad Hembrar Ingresadas', 'ev_entry_female', 'AVG((ts - (SELECT birth_ts FROM animals WHERE id=t.animal_id))) / 86400', 0, FALSE);

/*
Females transferred in - number of females imported from another database or farm.
Expression: FemalesTransferredIn

Total females added - total number of females entered + transferred in.
Expression: Entered+FemalesTransferredIn

Females transferred out - number of females removed in the time period with removal type Transferred.
Expression: TransferredOut
*/

INSERT INTO events_querys
VALUES(DEFAULT, 86, 87, 'Total Muertes Hembras', 'ev_sale',
       'SUM(EXISTS(SELECT id FROM deaths WHERE id=t.death_id AND death ~* ''muerte'')::INT)', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 88, 89, 'Total Salidas Hembras', 'ev_sale',
       'SUM(EXISTS(SELECT id FROM deaths WHERE id=t.death_id AND death !~* ''muerte'')::INT)', 0, FALSE);

/*
FemaleDays: The sum of all active female days during the period. A female contributes one female day
for each day she was active during the period, beginning at her entry date into the
breeding herd and ending with her removal.


Replacement rate - rate at which new breeding females are entered into the breeding herd calculated on an annualized basis.
Expression: Entered * 365 / FemaleDays * 100

Death rate - rate at which females have died in the herd calculated on an annualized basis.
Expression: Deaths * 365 / FemaleDays

Culling rate - rate at which females are culled from the herd calculated on an annualized basis.
Expression: Culled * 365 / FemaleDays * 100

Avg parity of culled females - the average parity of females culled in the time period.
Expression: SumParityCulled / Culled

Avg NPD / female / year - average non-productive days per female calculated on an annualized basis. Non-productive days are days in which a breeding female is neither gestating or lactating. Includes the gilt pool.
Expression: NonProductiveDays * 365 / FemaleDays

Avg NPD / mated female / year - average non-productive days per mated female calculated on an annualized basis. Non-productive days are days in which a breeding female is neither gestating or lactating. Excludes the gilt pool.
Expression: (MatedFemaleDays - GestationDays - LactatingDays)*365 / MatedFemaleDays
*/

INSERT INTO events_querys
VALUES(DEFAULT, 90, 91, 'Promedio Nacidos Vivos / Hembras Salidas', 'ev_sale',
       'SUM((SELECT SUM(males+females) FROM ev_farrow WHERE animal_id=t.animal_id)) / SUM(1)', 0, FALSE);

INSERT INTO events_querys
VALUES(DEFAULT, 92, 93, 'Promedio Destetados / Hembras Salidas', 'ev_sale',
       'SUM(COALESCE((SELECT SUM(animals) FROM ev_partial_wean WHERE animal_id=t.animal_id), 0) + ' ||
       '    (SELECT SUM(animals) FROM ev_wean WHERE animal_id=t.animal_id)) / SUM(1)', 0, FALSE);
