/*** ACTIVITIES ***/

-- psql granjalibre -v activity='1' -f db_activities.sql
-- \set activity '1'


SET search_path TO activity_:activity;


/****************************************************/
/***************** DEFAULT DATA *********************/
/****************************************************/
-- ****************
-- intervals
INSERT INTO variables VALUES (1, 'preg_min', 105);
INSERT INTO variables VALUES (2, 'preg', 114);
INSERT INTO variables VALUES (3, 'preg_max', 125);
INSERT INTO variables VALUES (4, 'farr_serv', 30);
INSERT INTO variables VALUES (5, 'temp', 38);
INSERT INTO variables VALUES (6, 'temp_max', 39.5);


-- ****************
-- races
-- ****************
INSERT INTO races VALUES (DEFAULT, 'f1', 1);
INSERT INTO races VALUES (DEFAULT, 'f2', 1);

ALTER SEQUENCE races_id_seq RESTART WITH 3;


-- ****************
-- deaths
-- ****************
INSERT INTO deaths VALUES (DEFAULT, 'diarrea', 'young', 1);
INSERT INTO deaths VALUES (DEFAULT, 'debilidad', 'young', 1);
INSERT INTO deaths VALUES (DEFAULT, 'aplastamiento', 'young', 1);
INSERT INTO deaths VALUES (DEFAULT, 'canibalismo', 'young', 1);
INSERT INTO deaths VALUES (DEFAULT, 'piernas abiertas', 'young', 1);
INSERT INTO deaths VALUES (DEFAULT, 'temblores', 'young', 1);
INSERT INTO deaths VALUES (DEFAULT, 'heridas', 'young', 1);
INSERT INTO deaths VALUES (DEFAULT, 'deshidratado', 'young', 1);
INSERT INTO deaths VALUES (DEFAULT, 'desconocido', 'young', 1);

INSERT INTO deaths VALUES (DEFAULT, 'matadero - no celo', 'adult', 1);
INSERT INTO deaths VALUES (DEFAULT, 'matadero - caquexia', 'adult', 1);
INSERT INTO deaths VALUES (DEFAULT, 'matadero - aborto', 'adult', 1);
INSERT INTO deaths VALUES (DEFAULT, 'matadero - parto distocico', 'adult', 1);
INSERT INTO deaths VALUES (DEFAULT, 'matadero - lactancia', 'adult', 1);
INSERT INTO deaths VALUES (DEFAULT, 'matadero - metritis', 'adult', 1);
INSERT INTO deaths VALUES (DEFAULT, 'matadero - edad', 'adult', 1);
INSERT INTO deaths VALUES (DEFAULT, 'matadero - renca', 'adult', 1);
INSERT INTO deaths VALUES (DEFAULT, 'matadero - repeticion', 'adult', 1);
INSERT INTO deaths VALUES (DEFAULT, 'matadero - respiratorio', 'adult', 1);
INSERT INTO deaths VALUES (DEFAULT, 'muerte - parto distocico', 'adult', 1);
INSERT INTO deaths VALUES (DEFAULT, 'muerte - desconocido', 'adult', 1);

ALTER SEQUENCE deaths_id_seq RESTART WITH 22;



/*******************************************************************/
/************************** FUNCTIONS ******************************/
/*******************************************************************/

/************************ SELECT FUNCTIONS *************************/
/*
CREATE OR REPLACE FUNCTION animal_genealogy_function(_id INTEGER)
RETURNS TABLE(a_id INTEGER, a_path TEXT, a_parents_id TEXT, a_animal TEXT,
              a_race VARCHAR, a_birth INTEGER, a_sale INTEGER) AS $$
BEGIN
  RETURN QUERY
WITH RECURSIVE search_genealogy(a_id, a_path, a_parents_id, a_animal,
                                a_race, a_birth, a_sale) AS (
    SELECT a.id, a.id::TEXT,
           (SELECT CONCAT_WS('_', animal_id,
                                 (SELECT male_id FROM ev_service
                                  WHERE id<f.id AND animal_id=f.animal_id
                                  ORDER BY id DESC LIMIT 1))
            FROM ev_farrow f WHERE litter=a.litter),
           CASE WHEN EXISTS(SELECT id FROM ev_entry_female
                            WHERE animal_id=a.id)
             THEN 'F: ' ELSE 'M: ' END || a.animal,
           (SELECT race FROM races WHERE id=a.race_id),
           a.birth_ts,
           (SELECT ts FROM ev_sale WHERE animal_id=a.id)
    FROM animals a WHERE a.id=_id
  UNION ALL
    SELECT a.id, CONCAT_WS('_', s.a_path, a.id),
           (SELECT CONCAT_WS('_', animal_id,
                                 (SELECT male_id FROM ev_service
                                  WHERE id<f.id AND animal_id=f.animal_id
                                  ORDER BY id DESC LIMIT 1))
            FROM ev_farrow f WHERE litter=a.litter),
           CASE WHEN a.id=REGEXP_REPLACE(s.a_parents_id, '_\d+', '')::INTEGER
             THEN 'F: ' ELSE 'M: ' END || a.animal,
           (SELECT race FROM races WHERE id=a.race_id),
           a.birth_ts,
           (SELECT ts FROM ev_sale WHERE animal_id=a.id)
    FROM animals a, search_genealogy s
    WHERE a.id=REGEXP_REPLACE(s.a_parents_id, '_\d+', '')::INTEGER OR
          a.id=REGEXP_REPLACE(s.a_parents_id, '\d+_', '')::INTEGER
)
SELECT * FROM search_genealogy;
END; $$
LANGUAGE plpgsql;
*/

CREATE OR REPLACE FUNCTION animal_genealogy_function(_id INTEGER)
RETURNS TABLE(a_id INT, a_father_id INT, a_mother_id INT, a_path TEXT,
              a_animal TEXT, a_race VARCHAR, a_birth INT, a_sale INT) AS $$
BEGIN
  RETURN QUERY
WITH RECURSIVE search_genealogy(a_id, a_father_id, a_mother_id, a_path,
                                a_animal, a_race, a_birth, a_sale) AS (
  SELECT a.id, a.father_id, a.mother_id, a.id::TEXT,
         CASE WHEN i.female THEN 'F: ' ELSE 'M: ' END || i.animal,
         i.race, i.birth_ts, i.sale_ts
  FROM public.animals a, public.animal_information(a.id) i WHERE a.id=_id
UNION ALL
  SELECT a.id, a.father_id, a.mother_id, CONCAT_WS('_', s.a_path, a.id),
         CASE WHEN i.female THEN 'F: ' ELSE 'M: ' END || i.animal,
         i.race, i.birth_ts, i.sale_ts
  FROM public.animals a, public.animal_information(a.id) i, search_genealogy s
  WHERE a.id=s.a_father_id OR a.id=s.a_mother_id
)
SELECT * FROM search_genealogy;
END; $$
LANGUAGE plpgsql;


----------------------------------------------------------------------


CREATE OR REPLACE FUNCTION animal_rules_function(a_id INTEGER)
RETURNS VARCHAR[] AS $$
DECLARE
  status VARCHAR;
  rules VARCHAR DEFAULT '';
BEGIN
  RAISE NOTICE 'Setting animal information (id: %)!', a_id;
  SELECT p.relname INTO status
  FROM events e JOIN pg_class p ON e.tableoid=p.oid
  WHERE e.animal_id = a_id AND 
        p.relname IN ('ev_sale_semen', 'ev_entry_semen', 'ev_sale')
  ORDER BY e.id DESC LIMIT 1;
  IF status = 'ev_entry_semen' THEN
    rules := 'sale_semen';
  ELSIF status IS NULL THEN
    rules := 'ubication|feed|condition|';
    IF EXISTS(SELECT id FROM ev_entry_male WHERE animal_id = a_id) THEN 
      status := 'ev_entry_male';
      rules := rules || 'semen|sale';
    ELSE
      SELECT p.relname INTO status
      FROM events e JOIN pg_class p ON e.tableoid=p.oid
      WHERE e.animal_id = a_id AND
            p.relname IN ('ev_entry_female', 'ev_heat', 'ev_service',
              'ev_check_pos', 'ev_check_neg', 'ev_abortion', 'ev_farrow',
         'ev_death', 'ev_foster', 'ev_adoption', 'ev_partial_wean', 'ev_wean')
      ORDER BY e.id DESC LIMIT 1;
      rules := rules || 'milk|dry|' || CASE status
        WHEN 'ev_entry_female' THEN 'heat|service|sale'
        WHEN 'ev_heat' THEN 'heat|service|sale'
        WHEN 'ev_service' THEN 'check_pos|check_neg'
        WHEN 'ev_check_pos' THEN 'check_pos|check_neg|abortion|farrow'
        WHEN 'ev_check_neg' THEN 'heat|service|sale'
        WHEN 'ev_abortion' THEN 'heat|service|sale'
        WHEN 'ev_farrow' THEN 'death|foster|adoption|partial_wean|wean'
        WHEN 'ev_death' THEN 'death|foster|adoption|partial_wean|wean'
        WHEN 'ev_foster' THEN 'death|foster|adoption|partial_wean|wean'
        WHEN 'ev_adoption' THEN 'death|foster|adoption|partial_wean|wean'
        WHEN 'ev_partial_wean' THEN 'death|foster|adoption|partial_wean|wean'
        WHEN 'ev_wean' THEN 'heat|service|sale'
      END;
    END IF;
    rules := rules || '|temperature|treatment|palpation|note';
  END IF;
  RETURN ARRAY[status, REGEXP_REPLACE(rules, '^|\m', 'ev_', 'g')];
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ev_cols_function(tbl NAME, e_id INTEGER)
RETURNS TABLE(_data TEXT) AS $$
DECLARE
  cols VARCHAR;
BEGIN
  cols := CASE tbl
    WHEN 'ev_entry_female' THEN '(SELECT CONCAT_WS(''_'', (SELECT race FROM races WHERE id=animals.race_id), litter, birth_ts, COALESCE(pedigree, ''''))
                                 FROM animals WHERE id=t.animal_id)'
    WHEN 'ev_entry_male' THEN '(SELECT CONCAT_WS(''_'', (SELECT race FROM races WHERE id=animals.race_id), litter, birth_ts, COALESCE(pedigree, ''''))
                                FROM animals WHERE id=t.animal_id)'
    WHEN 'ev_entry_semen' THEN '(SELECT CONCAT_WS(''_'', (SELECT race FROM races WHERE id=animals.race_id), litter, birth_ts, COALESCE(pedigree, ''''))
                                 FROM animals WHERE id=t.animal_id)'
    WHEN 'ev_sale_semen' THEN ''''''
    WHEN 'ev_sale' THEN '
CASE WHEN (SELECT last_a_id FROM public.animal_information(t.animal_id)) <>
          REGEXP_REPLACE(CURRENT_SCHEMA(), ''\D+'', '''')::INTEGER
  THEN public.farm_name((SELECT last_a_id
                         FROM public.animal_information(t.animal_id)))
  ELSE (SELECT death FROM deaths WHERE id=t.death_id)
END'
    WHEN 'ev_heat' THEN 'lordosis'
    WHEN 'ev_service' THEN '(SELECT animal FROM animals WHERE id=t.male_id), matings, lordosis, quality'
    WHEN 'ev_check_pos' THEN 'test'
    WHEN 'ev_check_neg' THEN 'test'
    WHEN 'ev_abortion' THEN 'inducted'
    WHEN 'ev_farrow' THEN 'litter, males, females, weight, deaths, mummies, hernias, cryptorchids, dystocia, retention, inducted, asisted'
    WHEN 'ev_death' THEN '(SELECT death FROM deaths WHERE id=t.death_id), animals'
    WHEN 'ev_foster' THEN '(SELECT animal FROM animals WHERE id=(SELECT animal_id FROM ev_adoption WHERE id=(t.id+1))), animals, weight'
    WHEN 'ev_adoption' THEN '(SELECT animal FROM animals WHERE id=(SELECT animal_id FROM ev_foster WHERE id=(t.id-1))), animals, weight'
    WHEN 'ev_partial_wean' THEN 'animals, weight'
    WHEN 'ev_wean' THEN 'animals, weight'
    WHEN 'ev_semen' THEN 'volumen, concentration, motility, dosis'
    WHEN 'ev_ubication' THEN 'ubication'
    -------------------------------------------------
    WHEN 'ev_feed' THEN 'weight'
    WHEN 'ev_condition' THEN 'condition, weight, backfat'
    WHEN 'ev_milk' THEN 'weight, quality'
    WHEN 'ev_dry' THEN ''''''
    WHEN 'ev_temperature' THEN 'temperature'
    -------------------------------------------------
    WHEN 'ev_treatment' THEN 'treatment, dose, frequency, days, route'
    WHEN 'ev_palpation' THEN 'palpation'
    WHEN 'ev_note' THEN 'note'
  END;
  RETURN QUERY EXECUTE 'SELECT CONCAT_WS(''_'', ' || 
    cols || ') ' || 'FROM ' || tbl || ' t WHERE id=' || e_id;
END;
$$
LANGUAGE plpgsql;


/*
CREATE OR REPLACE FUNCTION ev_chart_function(tbl NAME)
RETURNS VARCHAR AS $$
BEGIN
  RETURN CASE tbl
    WHEN 'ev_feed' THEN 'line'
    WHEN 'ev_condition' THEN 'line'
    WHEN 'ev_milk' THEN 'line'
    WHEN 'ev_temperature' THEN 'line'
    ELSE 'label'
  END;
END;
$$
LANGUAGE plpgsql;

-- constant events
CREATE OR REPLACE FUNCTION ev_data_constant_function(TEXT)
RETURNS SETOF RECORD AS $$
  SELECT id, tableoid::regclass::name, ts, parity,
         ev_cols_function(tableoid::regclass::name, id)
  FROM events
  WHERE tableoid IN (
    'ev_feed'::regclass::oid,
    'ev_condition'::regclass::oid,
    'ev_milk'::regclass::oid,
    'ev_temperature'::regclass::oid
  ) AND animal_id=(SELECT id FROM animals WHERE animal=$1) ORDER BY ts, id;
$$ LANGUAGE SQL;

-- variable events
CREATE OR REPLACE FUNCTION ev_data_variable_function(TEXT)
RETURNS SETOF RECORD AS $$
  SELECT id, tableoid::regclass::name, ts, parity,
         ev_cols_function(tableoid::regclass::name, id)
  FROM events
  WHERE tableoid NOT IN (
    'ev_feed'::regclass::oid,
    'ev_condition'::regclass::oid,
    'ev_milk'::regclass::oid,
    'ev_temperature'::regclass::oid
  ) AND animal_id=(SELECT id FROM animals WHERE animal=$1) ORDER BY ts, id;
$$ LANGUAGE SQL;
*/


CREATE OR REPLACE FUNCTION ev_data_function(e_id INT)
RETURNS TABLE(_id INT, _tbl NAME, _ts INT, _parity INT, _info TEXT) AS $$
BEGIN
  RETURN QUERY SELECT id, tableoid::regclass::name, ts, parity,
                      ev_cols_function(tableoid::regclass::name, id)
               FROM events WHERE id=e_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION litter_info_function(activity_id INT, ltt VARCHAR)
RETURNS TABLE(birth INT, _race VARCHAR, father_id INT, mother_id INT) AS $$
DECLARE
  l_info RECORD;
  l_race VARCHAR;
  f_race VARCHAR;
  m_race VARCHAR;
BEGIN
  RAISE NOTICE 'Validating litter (id: %)!', ltt;
  FOR l_info IN
    EXECUTE '
      SELECT ts, animal_id AS mother_id,
             (SELECT male_id FROM activity_' || activity_id || '.ev_service
              WHERE id<f.id AND animal_id=f.animal_id
              ORDER BY id DESC LIMIT 1) AS father_id
      FROM activity_' || activity_id || '.ev_farrow f
      WHERE litter=''' || ltt || '''' LOOP
    SELECT race FROM public.animal_information(l_info.father_id) INTO f_race;
    SELECT race FROM public.animal_information(l_info.mother_id) INTO m_race;
    IF f_race = m_race THEN
      l_race := f_race;
    ELSIF f_race NOT IN('f1', 'f2') AND m_race NOT IN('f1', 'f2') THEN
      l_race := 'f1';
    ELSE
      l_race := 'f2';
    END IF;
    RETURN QUERY SELECT l_info.ts, l_race, l_info.father_id, l_info.mother_id;
  END LOOP;
END;
$$
LANGUAGE plpgsql;


/**************** INSERT AND DELETE FUNCTIONS ****************/
CREATE OR REPLACE FUNCTION races_update_delete_function()
RETURNS TRIGGER AS $$
BEGIN
  RAISE NOTICE 'Checking races to update or delete!';
  IF (OLD.id = 1 OR OLD.id = 2) THEN
    RAISE EXCEPTION 'Razas f1 o f2 no pueden ser modificadas o borradas!';
  END IF;
  RETURN OLD;
END;
$$
LANGUAGE plpgsql;

--------------------------------------------------------------------

CREATE OR REPLACE FUNCTION animals_insert_function()
RETURNS TRIGGER AS $$
BEGIN
  RAISE NOTICE 'Validating animal name!';
  IF EXISTS(SELECT id FROM animals WHERE animal=NEW.animal) THEN
    RAISE EXCEPTION 'Animal con nombre repetido!';
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION animal_new_insert_function(
  a_entry INTEGER, a_name VARCHAR, a_pedigree VARCHAR,
  litter_a_id INTEGER, a_litter VARCHAR, a_birth INTEGER,
  a_race VARCHAR, a_sex VARCHAR, a_parity INTEGER) RETURNS VOID AS $$
DECLARE
  l_info RECORD;
  a_id INTEGER;
BEGIN
  RAISE NOTICE 'Validating litter!';
  SELECT * FROM litter_info_function(litter_a_id, a_litter) INTO l_info;
  IF l_info IS NOT NULL AND l_info.birth != a_birth OR
     l_info IS NOT NULL AND l_info._race != a_race THEN
    RAISE EXCEPTION 'Error en camada: %!', a_litter;
  END IF;


  --TODO not validate litter, select independ mother or father


  RAISE NOTICE 'Inserting animal!';
  --
  INSERT INTO public.animals
  VALUES(DEFAULT, l_info.father_id, l_info.mother_id) RETURNING id INTO a_id;
  INSERT INTO public.animals_activities
  VALUES(DEFAULT, a_id, REGEXP_REPLACE(CURRENT_SCHEMA(), '\D+', '')::INTEGER);
  --
  INSERT INTO animals
  VALUES(a_id, (SELECT id FROM races WHERE race=a_race), a_name, a_pedigree,
         a_litter, a_birth, EXTRACT(EPOCH FROM NOW())::INTEGER);
  IF a_sex = 'female'
    THEN INSERT INTO ev_entry_female VALUES(DEFAULT, a_id, a_entry, a_parity);
    ELSE INSERT INTO ev_entry_male VALUES(DEFAULT, a_id, a_entry, 0);
  END IF;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION animal_old_insert_function(_id INTEGER)
RETURNS VOID AS $$
DECLARE
  a_info RECORD;
  sale_info RECORD;
BEGIN
  RAISE NOTICE 'Selecting animal info!';
  SELECT * FROM public.animal_information(_id) INTO a_info;
  EXECUTE 'SELECT ts, parity FROM activity_' || a_info.prev_a_id || '.ev_sale
           WHERE animal_id=' || _id INTO sale_info;
  RAISE NOTICE 'Validating animal!';
  IF a_info.last_a_id <> REGEXP_REPLACE(CURRENT_SCHEMA(), '\D+', '')::INTEGER
    THEN RAISE EXCEPTION 'Ultima actividad no corresponde a actual!';
  END IF;
  RAISE NOTICE 'Checking animal race!';
  IF NOT EXISTS(SELECT id FROM races WHERE race=a_info.race) THEN
    INSERT INTO races VALUES(DEFAULT, a_info.race, 1);
  END IF;
  RAISE NOTICE 'Inserting animal!';
  INSERT INTO animals
  VALUES(_id, (SELECT id FROM races WHERE race=a_info.race), a_info.animal,
         a_info.pedigree, a_info.litter, a_info.birth_ts,
         EXTRACT(EPOCH FROM NOW())::INTEGER);
  IF a_info.female
    THEN INSERT INTO ev_entry_female
         VALUES(DEFAULT, _id, sale_info.ts, sale_info.parity);
    ELSE INSERT INTO ev_entry_male
         VALUES(DEFAULT, _id, sale_info.ts, 0);
  END IF;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION animal_semen_insert_function(_id INT, _ts INT)
RETURNS VOID AS $$
DECLARE
  current_activity INTEGER;
  sale_ts INTEGER;
  a_info RECORD;
BEGIN
  current_activity := REGEXP_REPLACE(CURRENT_SCHEMA(), '\D+', '')::INTEGER;
  --
  RAISE NOTICE 'Checking public animals semen activities!';
  IF EXISTS(SELECT id FROM public.animals_semen_activities
            WHERE animal_id=_id AND activity_id=current_activity) THEN
    RAISE EXCEPTION 'Semen ya ha sido ingresado!';
  END IF;
  --
  RAISE NOTICE 'Inserting animal!';
  IF EXISTS(SELECT id FROM animals WHERE id=_id) THEN
    SELECT ts FROM ev_sale WHERE animal_id=_id INTO sale_ts;
    IF sale_ts IS NULL THEN
      RAISE EXCEPTION 'Animal vivo!';
    ELSIF sale_ts > _ts THEN
      RAISE EXCEPTION 'Error en fecha ingreso semen!';
    END IF;
  ELSE
    SELECT * FROM public.animal_information(_id) INTO a_info;
    RAISE NOTICE 'Checking animal race!';
    IF NOT EXISTS(SELECT id FROM races WHERE race=a_info.race) THEN
      INSERT INTO races VALUES(DEFAULT, a_info.race, 1);
    END IF;
    INSERT INTO animals
    VALUES(_id, (SELECT id FROM races WHERE race=a_info.race), a_info.animal,
           a_info.pedigree, a_info.litter, a_info.birth_ts,
           EXTRACT(EPOCH FROM NOW())::INTEGER);
  END IF;
  --
  RAISE NOTICE 'Inserting entry semen!';
  INSERT INTO ev_entry_semen VALUES(DEFAULT, _id, _ts, 0);
  --
  RAISE NOTICE 'Inserting public animals semen activity!';
  INSERT INTO public.animals_semen_activities
  VALUES(DEFAULT, _id, current_activity);
END;
$$
LANGUAGE plpgsql;


--------------------------------------------------------------------

-- if delete entry then delete animal
CREATE OR REPLACE FUNCTION animals_delete_function()
RETURNS TRIGGER AS $$
DECLARE
  current_activity INTEGER;
BEGIN
  current_activity := REGEXP_REPLACE(CURRENT_SCHEMA(), '\D+', '')::INTEGER;
  --
  RAISE NOTICE 'Deleting excepcion para ingreso hembra gestante!';
  DELETE FROM events WHERE animal_id=OLD.animal_id;
  --
  RAISE NOTICE 'Deleting animal!';
  DELETE FROM animals WHERE id=OLD.animal_id;
  --
  RAISE NOTICE 'Deleting public animal_activity!';
  DELETE FROM public.animals_activities
  WHERE animal_id=OLD.animal_id AND activity_id=current_activity;
  --
  RAISE NOTICE 'Deleting public animal_semen_activity!';
  DELETE FROM public.animals_semen_activities
  WHERE animal_id=OLD.animal_id AND activity_id=current_activity;
  --
  RAISE NOTICE 'Deleting public animal!';
  IF NOT EXISTS(SELECT id FROM public.animals_activities
                WHERE animal_id=OLD.animal_id) AND
     NOT EXISTS(SELECT id FROM public.animals_semen_activities 
                WHERE animal_id=OLD.animal_id) THEN
    DELETE FROM public.animals WHERE id=OLD.animal_id;
    DELETE FROM public.animals_semen WHERE id=OLD.animal_id;
  END IF;
  RETURN OLD;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ev_sale_delete_function()
RETURNS TRIGGER AS $$
BEGIN
  RAISE NOTICE 'Deleting sale!';
  IF (SELECT last_a_id FROM public.animal_information(OLD.animal_id)) <>
     REGEXP_REPLACE(CURRENT_SCHEMA(), '\D+', '')::INTEGER THEN
    RAISE EXCEPTION 'Animal de otra granja!';
  END IF;
  RETURN OLD;
END;
$$
LANGUAGE plpgsql;


--------------------------------------------------------------------


CREATE OR REPLACE FUNCTION animals_eartags_insert_function()
RETURNS TRIGGER AS $$
BEGIN
  RAISE NOTICE 'Setting animal eartag!';
  DELETE FROM animals_eartags WHERE id=NEW.id;
  IF NEW.eartag <> ''
    THEN RETURN NEW;
    ELSE RETURN NULL;
  END IF;
END;
$$
LANGUAGE plpgsql;


/*
CREATE OR REPLACE FUNCTION ev_delete_function()
RETURNS TRIGGER AS $$
DECLARE
  status_ts INTEGER;
BEGIN
  RAISE NOTICE 'Checking event date!';
  SELECT e.ts INTO status_ts FROM events e 
  JOIN pg_class p ON e.tableoid=p.oid WHERE e.animal_id = OLD.animal_id AND
  p.relname IN ('entry_male', 'entry_female', 'ev_heat', 'ev_service',
    'ev_check_pos', 'ev_check_neg', 'ev_abortion', 'ev_farrow', 'ev_death', 
    'ev_foster', 'ev_adoption', 'ev_partial_wean', 'ev_wean', 'ev_semen')
  ORDER BY e.id DESC LIMIT 1;
  IF (OLD.ts < status_ts) THEN
    RAISE EXCEPTION 'Fecha menor a fecha reproductiva anterior!';
  END IF;
  RETURN OLD;
END;
$$
LANGUAGE plpgsql;
*/


CREATE OR REPLACE FUNCTION ev_insert_function() RETURNS TRIGGER AS $$
DECLARE
  rules VARCHAR[];
  entry_ts INTEGER;
  status_ts INTEGER;
  last_ts INTEGER;
  last_parity INTEGER;
BEGIN
  RAISE NOTICE 'Checking animal information!';
  SELECT animal_rules_function(NEW.animal_id) INTO rules; -- 1=status, 2=rules
  IF (rules[1] = 'ev_sale' OR rules[1] = 'ev_sale_semen') THEN 
    RAISE EXCEPTION 'Evento no permitido!';
  ELSIF (TG_TABLE_NAME !~ ('(' || rules[2] || ')')) THEN
    RAISE EXCEPTION 'Evento no permitido (estado: %)!', rules[1];
  END IF;
  -----------------------------------------------------
  RAISE NOTICE 'Checking event date!';
  SELECT ts INTO entry_ts FROM events
    WHERE animal_id = NEW.animal_id ORDER BY id ASC LIMIT 1;
  SELECT ts INTO status_ts FROM events WHERE animal_id = NEW.animal_id AND 
    tableoid::regclass::name = rules[1] ORDER BY id DESC LIMIT 1;
  SELECT ts, parity INTO last_ts, last_parity FROM events
    WHERE animal_id = NEW.animal_id ORDER BY id DESC LIMIT 1;
  IF (NEW.ts < entry_ts AND rules[1] = 'ev_female_entry') THEN
    RAISE NOTICE 'Excepcion para ingreso hembra gestante!';
  ELSIF (NEW.ts < entry_ts) THEN
    RAISE EXCEPTION 'Fecha menor a fecha ingreso!';
  ELSIF (NEW.ts < status_ts) THEN
    RAISE EXCEPTION 'Fecha menor a fecha reproductiva anterior!';
  ELSIF (NEW.ts < last_ts AND TG_TABLE_NAME = 'ev_sale') THEN
    RAISE EXCEPTION 'Fecha menor a fecha anterior!';
  ELSIF (TG_TABLE_NAME = 'ev_farrow') THEN
    IF (SELECT CASE WHEN
          NEW.ts <= (ts + EXTRACT(EPOCH FROM ((SELECT val FROM variables 
                    WHERE var='preg_min') || ' days')::INTERVAL)) OR
          NEW.ts >= (ts + EXTRACT(EPOCH FROM ((SELECT val FROM variables
                    WHERE var='preg_max') || ' days')::INTERVAL)) 
          THEN TRUE ELSE FALSE END 
        FROM ev_service WHERE animal_id=NEW.animal_id
        ORDER BY id DESC LIMIT 1) THEN 
      RAISE EXCEPTION 'Fecha parto fuera de rango (ts: %)!', NEW.ts;
    END IF;
  END IF;
  -----------------------------------------------------
  RAISE NOTICE 'Setting event parity!';
  IF (TG_TABLE_NAME = 'ev_farrow')
    THEN NEW.parity := last_parity + 1;
    ELSE NEW.parity := last_parity;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ev_service_insert_function()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS(SELECT id FROM ev_entry_male WHERE animal_id=NEW.male_id) AND
     NOT EXISTS(SELECT id FROM ev_entry_semen WHERE animal_id=NEW.male_id)
  THEN RAISE EXCEPTION 'Padrote incorrecto! (1)';
  ELSIF EXISTS(SELECT id FROM ev_sale_semen WHERE animal_id=NEW.male_id) OR
        EXISTS(SELECT id FROM ev_sale WHERE animal_id=NEW.male_id) AND
        NOT EXISTS(SELECT id FROM ev_entry_semen WHERE animal_id=NEW.male_id)
  THEN RAISE EXCEPTION 'Padrote incorrecto! (2)';
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ev_litter_stock_function()
RETURNS TRIGGER AS $$
DECLARE
  f_id INTEGER;
  mf INTEGER;
  dx INTEGER;
  fx INTEGER;
  ax INTEGER;
  pw INTEGER;
  stock INTEGER;
BEGIN
  RAISE NOTICE 'Checking litter stock!';
  SELECT MAX(id) INTO f_id FROM ev_farrow WHERE animal_id = NEW.animal_id;
  SELECT males + females INTO mf FROM ev_farrow WHERE id=f_id;
  SELECT COALESCE(SUM(animals), 0) INTO dx FROM ev_death
  WHERE animal_id=NEW.animal_id AND id>f_id;
  SELECT COALESCE(SUM(animals), 0) INTO fx FROM ev_foster
  WHERE animal_id=NEW.animal_id AND id>f_id;
  SELECT COALESCE(SUM(animals), 0) INTO ax FROM ev_adoption
  WHERE animal_id=NEW.animal_id AND id>f_id;
  SELECT COALESCE(SUM(animals), 0) INTO pw FROM ev_partial_wean
  WHERE animal_id=NEW.animal_id AND id>f_id;
  stock := mf - dx - fx + ax - pw;
  IF (TG_TABLE_NAME = 'ev_wean' AND stock <> NEW.animals OR
      stock < NEW.animals) THEN
    RAISE EXCEPTION 'Inventario camada incorrecto!';
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ev_adoption_insert_function()
RETURNS TRIGGER AS $$
DECLARE
  f_animal_id INTEGER;
BEGIN
  SELECT animal_id INTO f_animal_id FROM ev_foster ORDER BY id DESC LIMIT 1;
  IF (NEW.animal_id = f_animal_id) THEN
    RAISE EXCEPTION 'Madre adoptiva incorrecta!';
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;


-- if delete foster then delete adoption
CREATE OR REPLACE FUNCTION ev_foster_adoption_delete_function()
RETURNS TRIGGER AS $$
DECLARE
  other_id INTEGER;
BEGIN
  RAISE NOTICE 'Deleting foster_adoption!';
  IF (TG_TABLE_NAME = 'ev_foster')
    THEN other_id := OLD.id + 1;
    ELSE other_id := OLD.id - 1;
  END IF;
  IF EXISTS(SELECT id FROM ev_wean WHERE id > other_id AND
            animal_id = (SELECT animal_id FROM events WHERE id=other_id)) THEN
    RAISE EXCEPTION 'Borrado adoption +/- incorrecto!';
  END IF;
  IF (TG_TABLE_NAME = 'ev_foster')
    THEN DELETE FROM ev_adoption WHERE id = (OLD.id + 1); 
    ELSE DELETE FROM ev_foster WHERE id = (OLD.id - 1); 
  END IF;
  RETURN NULL;
END;
$$
LANGUAGE plpgsql;


/******************************************************************/
/************************** TRIGGERS ******************************/
/******************************************************************/
CREATE TRIGGER races_update_delete_trigger
  AFTER UPDATE OR DELETE ON races
  FOR EACH ROW EXECUTE PROCEDURE races_update_delete_function(); 

CREATE TRIGGER animals_insert_trigger
  BEFORE INSERT ON animals
  FOR EACH ROW EXECUTE PROCEDURE animals_insert_function(); 

CREATE TRIGGER ev_entry_female_delete_trigger
  AFTER DELETE ON ev_entry_female
  FOR EACH ROW EXECUTE PROCEDURE animals_delete_function(); 

CREATE TRIGGER ev_entry_male_delete_trigger
  AFTER DELETE ON ev_entry_male
  FOR EACH ROW EXECUTE PROCEDURE animals_delete_function(); 

CREATE TRIGGER ev_entry_semen_delete_trigger
  AFTER DELETE ON ev_entry_semen
  FOR EACH ROW EXECUTE PROCEDURE animals_delete_function(); 

CREATE TRIGGER ev_sale_delete_trigger
  AFTER DELETE ON ev_sale
  FOR EACH ROW EXECUTE PROCEDURE ev_sale_delete_function(); 

CREATE TRIGGER animals_eartags_insert_trigger
  BEFORE INSERT ON animals_eartags
  FOR EACH ROW EXECUTE PROCEDURE animals_eartags_insert_function(); 

CREATE TRIGGER ev_sale_insert_trigger
  BEFORE INSERT ON ev_sale
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_sale_semen_insert_trigger
  BEFORE INSERT ON ev_sale_semen
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_heat_insert_trigger
  BEFORE INSERT ON ev_heat
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_service_insert_trigger
  BEFORE INSERT ON ev_service
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_service_insert_trigger2
  BEFORE INSERT ON ev_service
  FOR EACH ROW EXECUTE PROCEDURE ev_service_insert_function(); 

CREATE TRIGGER ev_check_pos_insert_trigger
  BEFORE INSERT ON ev_check_pos
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_check_neg_insert_trigger
  BEFORE INSERT ON ev_check_neg
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_abortion_insert_trigger
  BEFORE INSERT ON ev_abortion
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_farrow_insert_trigger
  BEFORE INSERT ON ev_farrow
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_death_insert_trigger
  BEFORE INSERT ON ev_death
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_death_insert_trigger2
  BEFORE INSERT ON ev_death
  FOR EACH ROW EXECUTE PROCEDURE ev_litter_stock_function(); 

CREATE TRIGGER ev_foster_insert_trigger
  BEFORE INSERT ON ev_foster
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_foster_insert_trigger2
  BEFORE INSERT ON ev_foster
  FOR EACH ROW EXECUTE PROCEDURE ev_litter_stock_function(); 

CREATE TRIGGER ev_foster_delete_trigger
  AFTER DELETE ON ev_foster
  FOR EACH ROW EXECUTE PROCEDURE ev_foster_adoption_delete_function(); 

CREATE TRIGGER ev_adoption_insert_trigger
  BEFORE INSERT ON ev_adoption
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_adoption_insert_trigger2
  BEFORE INSERT ON ev_adoption
  FOR EACH ROW EXECUTE PROCEDURE ev_adoption_insert_function(); 

CREATE TRIGGER ev_adoption_delete_trigger
  AFTER DELETE ON ev_adoption
  FOR EACH ROW EXECUTE PROCEDURE ev_foster_adoption_delete_function(); 

CREATE TRIGGER ev_partial_wean_insert_trigger
  BEFORE INSERT ON ev_partial_wean
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_partial_wean_insert_trigger2
  BEFORE INSERT ON ev_partial_wean
  FOR EACH ROW EXECUTE PROCEDURE ev_litter_stock_function(); 

CREATE TRIGGER ev_wean_insert_trigger
  BEFORE INSERT ON ev_wean
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_wean_insert_trigger2
  BEFORE INSERT ON ev_wean
  FOR EACH ROW EXECUTE PROCEDURE ev_litter_stock_function(); 

CREATE TRIGGER ev_semen_insert_trigger
  BEFORE INSERT ON ev_semen
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_ubication_insert_trigger
  BEFORE INSERT ON ev_ubication
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_feed_insert_trigger
  BEFORE INSERT ON ev_feed
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_condition_insert_trigger
  BEFORE INSERT ON ev_condition
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_milk_insert_trigger
  BEFORE INSERT ON ev_milk
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_dry_insert_trigger
  BEFORE INSERT ON ev_dry
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_temperature_insert_trigger
  BEFORE INSERT ON ev_temperature
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_treatment_insert_trigger
  BEFORE INSERT ON ev_treatment
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_palpation_insert_trigger
  BEFORE INSERT ON ev_palpation
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 

CREATE TRIGGER ev_note_insert_trigger
  BEFORE INSERT ON ev_note
  FOR EACH ROW EXECUTE PROCEDURE ev_insert_function(); 
