/*** ACTIVITIES ***/

-- psql granjalibre -v activity='1' -f db_activities.sql
-- \set activity '1'


SET search_path TO activity_:activity;


/**********************************************/
/***************** TABLES *********************/
/**********************************************/
-- ****************
-- intervals
-- ****************
CREATE TABLE variables (
  id INTEGER PRIMARY KEY,
  var VARCHAR(15) NOT NULL,
  val NUMERIC(4,1) NOT NULL,
  CHECK (val >= 0)
);


-- ****************
-- races
-- ****************
CREATE TABLE races (
  id SERIAL PRIMARY KEY NOT NULL,
  race VARCHAR(30) UNIQUE NOT NULL,
  active SMALLINT NOT NULL,
  CHECK (TRIM(race) <> '' AND race !~* '[^a-z0-9 :.,/()#-]+'),
  CHECK (active IN (0, 1))
);


-- ****************
-- deaths
-- ****************
CREATE TABLE deaths (
  id SERIAL PRIMARY KEY NOT NULL,
  death VARCHAR(30) UNIQUE NOT NULL,
  type CHAR(5) NOT NULL,
  active SMALLINT NOT NULL,
  CHECK (TRIM(death) <> '' AND death !~* '[^a-z0-9 :.,/()#-]+'),
  CHECK (type IN ('adult', 'young')),
  CHECK (active IN (0, 1))
);


-- ****************
-- animals
-- ****************
CREATE TABLE animals (
  id INTEGER PRIMARY KEY NOT NULL,
  race_id INTEGER NOT NULL,
  animal VARCHAR(30) UNIQUE NOT NULL,
  pedigree VARCHAR(30) UNIQUE NULL,
  litter VARCHAR(10) NOT NULL,
  birth_ts INTEGER NOT NULL,
  create_ts INTEGER NOT NULL,
  CHECK (TRIM(animal) <> '' AND animal !~* '[^a-z0-9 :.,/()#-]+'),
  CHECK (TRIM(pedigree) <> '' AND pedigree !~* '[^a-z0-9 :.,/()#-]+'),
  CHECK (litter ~* '^\d+[a-z]$'),
  FOREIGN KEY(id) REFERENCES public.animals(id),
  FOREIGN KEY(race_id) REFERENCES races(id)
);


-- ****************
-- animals_eartags
-- ****************
CREATE TABLE animals_eartags (
  id INTEGER PRIMARY KEY NOT NULL,
  eartag VARCHAR(20) UNIQUE NOT NULL,
  CHECK (TRIM(eartag) <> '' AND eartag !~* '[^a-z0-9 :.,/()#-]+'),
  FOREIGN KEY(id) REFERENCES animals(id)
);


/******************* EVENTS *******************/
-- ****************
-- events
-- ****************
CREATE TABLE events (
  id SERIAL PRIMARY KEY NOT NULL,
  animal_id INTEGER NOT NULL,
  ts INTEGER NOT NULL,
  parity INTEGER NOT NULL,
  CHECK (parity >= 0),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
);

CREATE UNIQUE INDEX events_idx ON events (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_entry_female
-- ****************
CREATE TABLE ev_entry_female (
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_entry_female_idx ON ev_entry_female (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_entry_male
-- ****************
CREATE TABLE ev_entry_male (
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_entry_male_idx ON ev_entry_male (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_entry_semen
-- ****************
CREATE TABLE ev_entry_semen (
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_entry_semen_idx ON ev_entry_semen (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_sale_semen
-- ****************
CREATE TABLE ev_sale_semen (
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_sale_semen_idx ON ev_sale_semen (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_sale
-- ****************
CREATE TABLE ev_sale (
  death_id INTEGER NOT NULL,
  -- destination INTEGER NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id),
  FOREIGN KEY(death_id) REFERENCES deaths(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_sale_idx ON ev_sale (
  animal_id ASC,
  id ASC
);


/***************** reproductive events *********************/
-- ****************
-- ev_heat
-- ****************
CREATE TABLE ev_heat (
  lordosis SMALLINT NOT NULL,
  CHECK (lordosis IN (1, 2, 3, 4, 5)),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_heat_idx ON ev_heat (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_service
-- ****************
CREATE TABLE ev_service (
  male_id INTEGER NOT NULL,
  matings SMALLINT NOT NULL,
  lordosis SMALLINT NOT NULL,
  quality SMALLINT NOT NULL,
  CHECK (matings > 0 AND matings < 10),
  CHECK (lordosis IN (1, 2, 3, 4, 5)),
  CHECK (quality IN (1, 2, 3, 4, 5)),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id),
  FOREIGN KEY(male_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_service_idx ON ev_service (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_preg_checks+
-- ****************
CREATE TABLE ev_check_pos (
  test CHAR(2) NOT NULL,
  CHECK (test IN ('us', 'px', 'vs')),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_check_pos_idx ON ev_check_pos (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_preg_checks-
-- ****************
CREATE TABLE ev_check_neg (
  test CHAR(2) NOT NULL,
  CHECK (test IN ('us', 'px', 'vs', 're')),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_check_neg_idx ON ev_check_neg (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_abortion
-- ****************
CREATE TABLE ev_abortion (
  inducted SMALLINT NOT NULL,
  CHECK (inducted IN(0, 1)),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_abortion_idx ON ev_abortion (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_farrow
-- ****************
CREATE TABLE ev_farrow (
  litter VARCHAR(10) UNIQUE NOT NULL,
  males INTEGER NOT NULL,
  females INTEGER NOT NULL,
  weight NUMERIC(5,2) NOT NULL,
  deaths INTEGER NOT NULL,
  mummies INTEGER NOT NULL,
  hernias INTEGER NOT NULL,
  cryptorchids INTEGER NOT NULL,
  dystocia SMALLINT NOT NULL,
  retention SMALLINT NOT NULL,
  inducted SMALLINT NOT NULL,
  asisted SMALLINT NOT NULL,
  CHECK (litter ~* '^\d+[a-z]$'),
  CHECK (males >= 0),
  CHECK (females >= 0),
  CHECK (males > 0 OR females > 0),
  CHECK (weight > 0),
  CHECK (deaths >= 0),
  CHECK (mummies >= 0),
  CHECK (hernias >= 0),
  CHECK (cryptorchids >= 0),
  CHECK (dystocia IN(0, 1)),
  CHECK (retention IN(0, 1)),
  CHECK (inducted IN(0, 1)),
  CHECK (asisted IN(0, 1)),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_farrow_idx ON ev_farrow (
  animal_id ASC,
  id ASC
);

-- for genelogy_function
CREATE UNIQUE INDEX ev_farrow_litterx ON ev_farrow (
  litter ASC
);


-- ****************
-- ev_death
-- ****************
CREATE TABLE ev_death (
  death_id INTEGER NOT NULL,
  animals INTEGER NOT NULL,
  CHECK (animals > 0),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id),
  FOREIGN KEY(death_id) REFERENCES deaths(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_death_idx ON ev_death (
  animal_id ASC,
  id ASC
);

-- for litters_resumen
--CREATE UNIQUE INDEX ev_death_parityx ON ev_death (
--  animal_id ASC,
--  parity ASC
--);


-- ****************
-- ev_foster
-- ****************
CREATE TABLE ev_foster (
  animals INTEGER NOT NULL,
  weight NUMERIC(5,2) NOT NULL,
  CHECK (animals > 0),
  CHECK (weight >= 0),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_foster_idx ON ev_foster (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_adoption
-- ****************
CREATE TABLE ev_adoption (
  animals INTEGER NOT NULL,
  weight NUMERIC(5,2) NOT NULL,
  CHECK (animals > 0),
  CHECK (weight >= 0),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_adoption_idx ON ev_adoption (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_wean
-- ****************
CREATE TABLE ev_wean (
  animals INTEGER NOT NULL,
  weight NUMERIC(5,2) NOT NULL,
  CHECK (animals >= 0),
  CHECK (weight >= 0),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_wean_idx ON ev_wean (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_partial_wean
-- ****************
CREATE TABLE ev_partial_wean (
  animals INTEGER NOT NULL,
  weight NUMERIC(5,2) NOT NULL,
  CHECK (animals > 0),
  CHECK (weight >= 0),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_partial_wean_idx ON ev_partial_wean (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_semen
-- ****************
CREATE TABLE ev_semen (
  volumen NUMERIC(5,2) NOT NULL,
  concentration NUMERIC(6,2) NOT NULL,
  motility SMALLINT NOT NULL,
  -- morfology INTEGER NOT NULL,
  -- grumos SMALLINT NOT NULL,
  dosis INTEGER NOT NULL,
  CHECK (volumen > 0),
  CHECK (concentration >= 0),
  CHECK (motility IN (0, 1, 2, 3, 4, 5)),
  CHECK (dosis >= 0),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_semen_idx ON ev_semen (
  animal_id ASC,
  id ASC
);


/****************************************************/
-- ****************
-- ev_ubication
-- ****************
CREATE TABLE ev_ubication (
  ubication VARCHAR(15) NOT NULL,
  CHECK (TRIM(ubication) <> '' AND ubication !~* '[^a-z0-9 :.,/()#-]+'),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_ubication_idx ON ev_ubication (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_feed
-- ****************
CREATE TABLE ev_feed (
  weight NUMERIC(4,2) NOT NULL,
  CHECK (weight >= 0),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_feed_idx ON ev_feed (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_condition
-- ****************
CREATE TABLE ev_condition (
  condition NUMERIC(2,1) NOT NULL,
  weight NUMERIC(5,2) NOT NULL,
  backfat NUMERIC(5,2) NULL,
  CHECK (condition IN(1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5)),
  CHECK (weight >= 0),
  CHECK (backfat >= 0),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_condition_idx ON ev_condition (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_milk
-- ****************
CREATE TABLE ev_milk (
  weight NUMERIC(4,2) NOT NULL,
  quality SMALLINT NOT NULL,
  CHECK (weight >= 0),  -- 0 = end
  CHECK (quality IN(1, 2, 3, 4, 5)),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_milk_idx ON ev_milk (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_dry
-- ****************
CREATE TABLE ev_dry (
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_dry_idx ON ev_dry (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_temperature
-- ****************
CREATE TABLE ev_temperature (
  temperature NUMERIC(4,2) NOT NULL,
  CHECK (temperature > 0 AND temperature < 50),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_temperature_idx ON ev_temperature (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_treatment
-- ****************
CREATE TABLE ev_treatment (
  treatment VARCHAR(10) NOT NULL,
  dose VARCHAR(15) NOT NULL,
  frequency INTEGER NOT NULL,
  days INTEGER NOT NULL,
  route CHAR(2) NOT NULL,
  CHECK (TRIM(treatment) <> '' AND treatment !~* '[^a-z0-9 :.,/()#-]+'),
  CHECK (dose ~* '[0-9]?(\.)?[0-9]ui/kg|ml/kg|mg/kg|g/kg'),
  CHECK (frequency IN (6, 8, 12, 24, 48, 72)),
  CHECK (days > 0),
  CHECK (route IN ('im', 'iv', 'ip', 'sc', 'po')),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_treatment_idx ON ev_treatment (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_palpation
-- ****************
CREATE TABLE ev_palpation (
  palpation VARCHAR(100) NOT NULL,
  CHECK (TRIM(palpation) <> '' AND palpation !~* '[^a-z0-9 :.,/()#-]+'),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_palpation_idx ON ev_palpation (
  animal_id ASC,
  id ASC
);


-- ****************
-- ev_note
-- ****************
CREATE TABLE ev_note (
  note VARCHAR(100) NOT NULL,
  CHECK (TRIM(note) <> '' AND note !~* '[^a-z0-9 :.,/()#-]+'),
  PRIMARY KEY (id),
  FOREIGN KEY(animal_id) REFERENCES animals(id)
) INHERITS (events);

CREATE UNIQUE INDEX ev_note_idx ON ev_note (
  animal_id ASC,
  id ASC
);


/******************************************************************/
/*************************** QUERIES ******************************/
/******************************************************************/
/*
-- animal information
SELECT animal_rules_function(12);



-- females unproductives stock
--last_events: ev_entry_female, ev_heat, ev_check_neg, ev_abortion, ev_wean
SELECT (SELECT animal FROM animals WHERE id=e.animal_id) AS animal,
       (SELECT ubication FROM ev_ubication WHERE animal_id=e.animal_id
        ORDER BY id DESC LIMIT 1) AS ubication,
       e.ts AS ts,
       e.parity AS parity,
       e.tableoid::regclass::name AS status
FROM events e WHERE tableoid IN (
  'ev_entry_female'::regclass::oid,
  'ev_heat'::regclass::oid,
  'ev_check_neg'::regclass::oid,
  'ev_abortion'::regclass::oid,
  'ev_wean'::regclass::oid
) AND
  NOT EXISTS(SELECT id FROM ev_heat  -- (filter only the last)
             WHERE animal_id=e.animal_id AND id>e.id) AND
  NOT EXISTS(SELECT id FROM ev_service
             WHERE animal_id=e.animal_id AND id>e.id) AND
  NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=e.animal_id)
UNION ALL
SELECT (SELECT animal FROM animals WHERE id=e.animal_id) AS animal,
       (SELECT ubication FROM ev_ubication WHERE animal_id=e.animal_id
        ORDER BY id DESC LIMIT 1) AS ubication,
       e.ts AS ts,
       e.parity AS parity,
       'ev_service' AS status
FROM ev_service e WHERE
  NOT EXISTS(SELECT id FROM ev_check_neg
             WHERE animal_id=e.animal_id AND id>e.id) AND
  NOT EXISTS(SELECT id FROM ev_abortion
             WHERE animal_id=e.animal_id AND id>e.id) AND
  NOT EXISTS(SELECT id FROM ev_farrow
             WHERE animal_id=e.animal_id AND id>e.id) AND
  EXTRACT(epoch FROM now()) > (e.ts + EXTRACT(EPOCH FROM 
   ((SELECT val FROM variables WHERE var='preg_max') || ' days')::INTERVAL))
UNION ALL
SELECT (SELECT animal FROM animals WHERE id=e.animal_id) AS animal,
       (SELECT ubication FROM ev_ubication WHERE animal_id=e.animal_id
        ORDER BY id DESC LIMIT 1) AS ubication,
       e.ts AS ts,
       e.parity AS parity,
       'ev_farrow' AS status
FROM ev_farrow e WHERE
  NOT EXISTS(SELECT id FROM ev_wean
             WHERE animal_id=e.animal_id AND id>e.id) AND
  EXTRACT(epoch FROM now()) > (e.ts + EXTRACT(EPOCH FROM 
   ((SELECT val FROM variables WHERE var='farr_serv') || ' days')::INTERVAL));


-- females served stock
-- last_events: ev_service
SELECT (SELECT animal FROM animals WHERE id=e.animal_id) AS animal,
       (SELECT ubication FROM ev_ubication WHERE animal_id=e.animal_id
        ORDER BY id DESC LIMIT 1) AS ubication,
       e.ts AS ts,
       e.parity AS parity
FROM ev_service e WHERE
  NOT EXISTS(SELECT id FROM ev_check_pos
             WHERE animal_id=e.animal_id AND id>e.id) AND
  NOT EXISTS(SELECT id FROM ev_check_neg
             WHERE animal_id=e.animal_id AND id>e.id) AND
  EXTRACT(epoch FROM now()) <= (e.ts + EXTRACT(EPOCH FROM 
   ((SELECT val FROM variables WHERE var='preg_max') || ' days')::INTERVAL));


-- females productives stock
-- last_events: ev_check_pos, ev_farrow
SELECT (SELECT animal FROM animals WHERE id=e.animal_id) AS animal,
       (SELECT ubication FROM ev_ubication WHERE animal_id=e.animal_id
        ORDER BY id DESC LIMIT 1) AS ubication,
       e.ts AS ts,
       e.parity AS parity,
       'ev_check_pos' AS status
FROM ev_service e WHERE
  EXISTS(SELECT id FROM ev_check_pos
         WHERE animal_id=e.animal_id AND id>e.id) AND
  NOT EXISTS(SELECT id FROM ev_check_neg
             WHERE animal_id=e.animal_id AND id>e.id) AND
  NOT EXISTS(SELECT id FROM ev_abortion
             WHERE animal_id=e.animal_id AND id>e.id) AND
  NOT EXISTS(SELECT id FROM ev_farrow
             WHERE animal_id=e.animal_id AND id>e.id) AND
  EXTRACT(epoch FROM now()) <= (e.ts + EXTRACT(EPOCH FROM 
   ((SELECT val FROM variables WHERE var='preg_max') || ' days')::INTERVAL))
UNION ALL
SELECT (SELECT animal FROM animals WHERE id=e.animal_id) AS animal,
       (SELECT ubication FROM ev_ubication WHERE animal_id=e.animal_id
        ORDER BY id DESC LIMIT 1) AS ubication,
       e.ts AS ts,
       e.parity AS parity,
       'ev_farrow' AS status
FROM ev_farrow e WHERE
  NOT EXISTS(SELECT id FROM ev_wean
             WHERE animal_id=e.animal_id AND id>e.id) AND
  EXTRACT(epoch FROM now()) <= (e.ts + EXTRACT(EPOCH FROM 
   ((SELECT val FROM variables WHERE var='farr_serv') || ' days')::INTERVAL));


-- litters stock
SELECT (SELECT animal FROM animals WHERE id=f.animal_id),
       (SELECT ubication FROM ev_ubication
        WHERE animal_id=f.animal_id ORDER BY id DESC LIMIT 1),
       f.ts,
       f.litter,
       f.males,
       f.females,
       (SELECT SUM(animals) FROM ev_death
        WHERE animal_id=f.animal_id AND id>f.id),
       (SELECT SUM(animals) FROM ev_foster
        WHERE animal_id=f.animal_id AND id>f.id),
       (SELECT SUM(animals) FROM ev_adoption
        WHERE animal_id=f.animal_id AND id>f.id),
       (SELECT SUM(animals) FROM ev_partial_wean
        WHERE animal_id=f.animal_id AND id>f.id)
FROM ev_farrow f WHERE NOT EXISTS(SELECT id FROM ev_wean
                                  WHERE animal_id=f.animal_id AND id>f.id)
ORDER BY f.ts ASC;


-- reproduction resumen
SELECT p.relname, ROUND(AVG(e.parity), 2),
  CASE
    WHEN p.relname='ev_entry_male' THEN COUNT(*)::TEXT
    WHEN p.relname='ev_entry_female' THEN COUNT(*)::TEXT
    WHEN p.relname='ev_sale' THEN COUNT(*)::TEXT
    WHEN p.relname='ev_heat' THEN COUNT(*)::TEXT
    WHEN p.relname='ev_service' THEN COUNT(*)::TEXT
    WHEN p.relname='ev_check_neg' THEN
      CONCAT_WS('_',
        COUNT(*),
        ROUND(AVG((SELECT (e.ts-MAX(ts))/86400 FROM ev_service
                   WHERE animal_id=e.animal_id AND id<e.id)), 2)
      )
    WHEN p.relname='ev_abortion' THEN
      CONCAT_WS('_',
        COUNT(*),
        ROUND(AVG((SELECT (e.ts-MAX(ts))/86400 FROM ev_service
                   WHERE animal_id=e.animal_id AND id<e.id)), 2)
      )
    WHEN p.relname='ev_farrow' THEN
      CONCAT_WS('_',
        COUNT(*),
        SUM((SELECT males+females FROM ev_farrow WHERE id=e.id)),
        SUM((SELECT deaths FROM ev_farrow WHERE id=e.id)),
        SUM((SELECT mummies FROM ev_farrow WHERE id=e.id)),
        SUM((SELECT weight FROM ev_farrow WHERE id=e.id))
      )
    WHEN p.relname='ev_death' THEN
      CONCAT_WS('_',
        SUM((SELECT animals FROM ev_death WHERE id=e.id)),
        ROUND(AVG((SELECT (e.ts-MAX(ts))/86400 FROM ev_farrow
                   WHERE animal_id=e.animal_id AND id<e.id)), 2)
      )
--      CONCAT_WS('_',
--        SUM((CASE WHEN (SELECT (e.ts-MAX(ts))/86400 FROM ev_farrow
--                        WHERE animal_id=e.animal_id AND id<e.id) < 2
--                  THEN (SELECT animals FROM ev_death WHERE id=e.id)
--                  ELSE 0 END)),
--        SUM((CASE WHEN (SELECT (e.ts-MAX(ts))/86400 FROM ev_farrow
--                        WHERE animal_id=e.animal_id AND id<e.id)
--                       BETWEEN 2 AND 8
--                 THEN (SELECT animals FROM ev_death WHERE id=e.id)
--                 ELSE 0 END)),
--        SUM((CASE WHEN (SELECT (e.ts-MAX(ts))/86400 FROM ev_farrow
--                        WHERE animal_id=e.animal_id AND id<e.id) > 8
--                 THEN (SELECT animals FROM ev_death WHERE id=e.id)
--                 ELSE 0 END))
--      )
    WHEN p.relname='ev_wean' THEN
      CONCAT_WS('_',
        COUNT(*),
        ROUND(AVG((SELECT (e.ts-MAX(ts))/86400 FROM ev_farrow
                   WHERE animal_id=e.animal_id AND id<e.id)), 2),
        SUM((SELECT animals FROM ev_wean WHERE id=e.id)),
        SUM((SELECT weight FROM ev_wean WHERE id=e.id))
      )
  END
FROM events e JOIN pg_class p ON e.tableoid=p.oid
WHERE p.relname IN ('ev_entry_male', 'ev_entry_female', 'ev_sale', 
                    'ev_heat', 'ev_service', 'ev_check_neg',
                    'ev_abortion', 'ev_farrow', 'ev_death', 'ev_wean')
--      AND e.ts >= %s AND e.ts <= %s;
GROUP BY p.relname;


-- actives resumen
SELECT (SELECT (SELECT race FROM races WHERE id=animals.race_id)
          || '_' || animal FROM animals WHERE id=e.animal_id) AS race_animal,
  SUM(CASE WHEN tableoid = 'ev_heat'::regclass::oid OR
                tableoid = 'ev_service'::regclass::oid THEN 1 ELSE 0 END),
  SUM(CASE WHEN tableoid = 'ev_farrow'::regclass::oid THEN 1 ELSE 0 END),
  SUM(CASE WHEN tableoid = 'ev_wean'::regclass::oid THEN 1 ELSE 0 END),
  MIN(CASE WHEN tableoid = 'ev_heat'::regclass::oid OR
                tableoid = 'ev_service'::regclass::oid THEN ts ELSE NULL END),
  MIN(CASE WHEN tableoid = 'ev_farrow'::regclass::oid THEN ts ELSE NULL END),
  MAX(CASE WHEN tableoid = 'ev_farrow'::regclass::oid THEN ts ELSE NULL END),
  MAX(CASE WHEN tableoid = 'ev_wean'::regclass::oid THEN ts ELSE NULL END),
  SUM(COALESCE((SELECT males+females FROM ev_farrow WHERE id=e.id), 0)),
  SUM(COALESCE((SELECT deaths FROM ev_farrow WHERE id=e.id), 0)),
  SUM(COALESCE((SELECT animals FROM ev_wean WHERE id=e.id), 0) +
      COALESCE((SELECT animals FROM ev_partial_wean WHERE id=e.id), 0))
FROM events e
WHERE tableoid IN ('ev_heat'::regclass::oid,
                   'ev_service'::regclass::oid,
                   'ev_farrow'::regclass::oid,
                   'ev_wean'::regclass::oid,
                   'ev_partial_wean'::regclass::oid) AND
  EXISTS(SELECT id FROM ev_entry_female WHERE animal_id=e.animal_id) AND
  NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=e.animal_id)
GROUP BY animal_id ORDER BY race_animal;


-- fertility analisys
SELECT s.ts,
       CASE WHEN EXISTS(SELECT id FROM ev_check_neg
                        WHERE animal_id=s.animal_id AND parity=s.parity)
       THEN 1 ELSE 0 END,
       CASE WHEN EXISTS(SELECT id FROM ev_farrow
                        WHERE animal_id=s.animal_id AND parity=s.parity)
       THEN 1 ELSE 0 END
FROM ev_service s
--WHERE ts>=%s AND ts<=%s
ORDER BY ts ASC;


-- repetitive analisys
SELECT parity, COUNT(id) - 1, MIN(ts), MAX(ts)
FROM events
WHERE tableoid IN ('ev_heat'::regclass::oid, 'ev_service'::regclass::oid)
--      AND ts>=%s AND ts<=%s
GROUP BY animal_id, parity;


-- farrow service analisys
WITH services AS(
  SELECT animal_id, parity, MIN(ts) AS min_ts, MAX(ts) AS max_ts
  FROM ev_service GROUP BY animal_id, parity
)
SELECT f.ts, s.min_ts, s.max_ts
FROM ev_farrow f JOIN services s ON f.animal_id=s.animal_id AND
                                    f.parity=s.parity
--WHERE f.ts>=%s AND f.ts<=%s;


-- males resumen
WITH farrows AS(
  SELECT males, females, deaths, mummies, weight,
         (SELECT MAX(id) FROM ev_service
          WHERE animal_id=f.animal_id AND id<f.id) AS service_id
  FROM ev_farrow f
)
SELECT (SELECT (SELECT race FROM races WHERE id=animals.race_id)
          || '_' || animal FROM animals WHERE id=s.male_id) AS race_animal,
  COUNT(s.id),
  SUM(CASE WHEN EXISTS(SELECT id FROM ev_check_neg
                        WHERE animal_id=s.animal_id AND parity=s.parity)
      THEN 1 ELSE 0 END),
  COUNT(f.service_id),
  SUM(f.males),
  SUM(f.females),
  SUM(f.deaths),
  SUM(f.mummies),
  SUM(f.weight)
FROM ev_service s
LEFT JOIN farrows f ON s.id=f.service_id
WHERE NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=s.male_id) OR
      EXISTS(SELECT id FROM ev_entry_semen WHERE animal_id=s.male_id) AND
      NOT EXISTS(SELECT id FROM ev_sale_semen WHERE animal_id=s.male_id)
GROUP BY s.male_id ORDER BY race_animal;


-- males usage resumen
SELECT ts,
       CASE WHEN EXISTS(SELECT id FROM ev_check_neg
                        WHERE animal_id=s.animal_id AND parity=s.parity)
       THEN 1 ELSE 0 END,
       (SELECT animal FROM animals WHERE id=s.male_id)
FROM ev_service s
--WHERE ts>=%s AND ts<=%s
ORDER BY ts ASC;


-- litters resumen
SELECT litter,
       (SELECT (SELECT (SELECT race FROM races WHERE id=animals.race_id)
                  || '_' || animal FROM animals WHERE id=s.male_id)
        FROM ev_service s WHERE animal_id=f.animal_id AND id<f.id
        ORDER BY id DESC LIMIT 1),
       (SELECT (SELECT race FROM races WHERE id=animals.race_id)
          || '_' || animal FROM animals WHERE id=f.animal_id),
       ts,
       males,
       females,
       weight,
       (SELECT ts FROM ev_wean WHERE animal_id=f.animal_id AND id>f.id
        ORDER BY id ASC LIMIT 1) AS ts2
FROM ev_farrow f
--WHERE ts >= %s AND ts <= %s
ORDER BY ts ASC;


-- litters deaths resumen
SELECT ts,
       parity,
       (SELECT death FROM deaths WHERE id=e.death_id),
       (SELECT ubication FROM ev_ubication
        WHERE animal_id=e.animal_id AND id<e.id ORDER BY id DESC LIMIT 1),
       animals
FROM ev_death e
--WHERE ts>=%s AND ts<=%s
ORDER BY ts;



-- sales resumen
SELECT (SELECT (SELECT race FROM races WHERE id=animals.race_id)
          || '_' || animal FROM animals WHERE id=e.animal_id) AS race_animal,
       parity,
       ts,
       CASE WHEN EXISTS(SELECT id FROM ev_entry_female
                        WHERE animal_id=e.animal_id)
       THEN 0 ELSE 1 END,
       (SELECT death FROM deaths WHERE id=e.death_id)
FROM ev_sale e
--WHERE ts>=%s AND ts<=%s;
ORDER BY race_animal;
*/


/****************** OTHER *********************/
/*
CREATE UNIQUE INDEX events_female_idx ON events (
  animal_id ASC,
  id DESC
) WHERE tableoid IN (
  'ev_entry_female'::regclass::oid,
  'ev_sale'::regclass::oid,
  'ev_heat'::regclass::oid,
  'ev_service'::regclass::oid,
  'ev_check_pos'::regclass::oid,
  'ev_check_neg'::regclass::oid,
  'ev_abortion'::regclass::oid,
  'ev_farrow'::regclass::oid,
  'ev_wean'::regclass::oid
);

CREATE VIEW view_females_last_events AS
  SELECT MAX(id) AS id FROM events WHERE tableoid IN (
    'ev_entry_female'::regclass::oid,
    'ev_heat'::regclass::oid,
    'ev_service'::regclass::oid,
    'ev_check_pos'::regclass::oid,
    'ev_check_neg'::regclass::oid,
    'ev_abortion'::regclass::oid,
    'ev_farrow'::regclass::oid,
    'ev_wean'::regclass::oid
  ) AND NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id = events.animal_id)
  GROUP BY animal_id;

SELECT e.id FROM events e
INNER JOIN view_females_last_events last ON e.id=last.id;


-- group_concat() => array_to_string(array_agg(employee), ',')
*/


-- TODO

-- graficos

-- esquema logica cuentas
-- esquema logica animales
-- esquema logica reproduccion

-- contabilidad
-- produccion
