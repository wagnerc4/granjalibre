/*******************************************************************/
/************************** FUNCTIONS ******************************/
/*******************************************************************/

CREATE OR REPLACE FUNCTION farm_name(activity_id INTEGER)
RETURNS VARCHAR AS $$
DECLARE
  farm_name VARCHAR;
BEGIN
  SELECT (SELECT farm FROM public.farms WHERE id=a.farm_id)
  FROM public.activities a WHERE id=activity_id INTO farm_name;
  RETURN farm_name;
END;
$$
LANGUAGE plpgsql;


--------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION animal_information(_id INTEGER)
RETURNS TABLE(animal VARCHAR, pedigree VARCHAR, litter VARCHAR,
  birth_ts INTEGER, race VARCHAR, female BOOLEAN, sale_ts INTEGER,
  first_a_id INTEGER, last_a_id INTEGER, prev_a_id INTEGER) AS $$
DECLARE
  activities INTEGER[];
  array_length INTEGER;
BEGIN
  SELECT ARRAY_AGG(activity_id), COUNT(*)
  FROM (SELECT activity_id FROM public.animals_activities
        WHERE animal_id=_id ORDER BY id ASC) t
  INTO activities, array_length;
  RETURN QUERY EXECUTE '
SELECT animal, pedigree, litter, birth_ts,
  (SELECT race FROM activity_' || activities[1] || '.races
   WHERE id=a.race_id),
  EXISTS(SELECT id FROM activity_' || activities[1] || '.ev_entry_female
         WHERE animal_id=a.id),
  (SELECT ts FROM activity_' || activities[array_length] || '.ev_sale
   WHERE animal_id=a.id),
  ' || activities[1] || ',
  ' || activities[array_length] || ',
  ' || COALESCE(activities[array_length - 1], 0) || '
FROM activity_' || activities[1] || '.animals a WHERE a.id=' || _id;
END;
$$
LANGUAGE plpgsql;


-------------------------------------------------------------------


CREATE OR REPLACE FUNCTION animals_activities_insert_function()
RETURNS TRIGGER AS $$
DECLARE
  last_a_id INTEGER;
BEGIN
  RAISE NOTICE 'Checking new activity!';
  SELECT activity_id FROM public.animals_activities
  WHERE animal_id=NEW.animal_id ORDER BY id DESC LIMIT 1 INTO last_a_id;
  IF last_a_id = NEW.activity_id THEN
    RAISE EXCEPTION 'La granja debe ser distinta!';
  END IF;
  RAISE NOTICE 'Checking activity spiece!';
  IF (SELECT spiece FROM public.activities WHERE id=last_a_id) <>
     (SELECT spiece FROM public.activities
      WHERE id=REGEXP_REPLACE(CURRENT_SCHEMA(), '\D+', '')::INTEGER) THEN
    RAISE EXCEPTION 'La especie debe ser la misma de la granja actual!';
  END IF;
  IF NEW.activity_id IS NULL
    THEN RETURN NULL;
    ELSE RETURN NEW;
  END IF;
END;
$$
LANGUAGE plpgsql;


-------------------------------------------------------------------


CREATE OR REPLACE FUNCTION animals_semen_insert_function()
RETURNS TRIGGER AS $$
DECLARE
  last_a_id INTEGER;
BEGIN
  RAISE NOTICE 'Checking last farm activity!';
  SELECT activity_id FROM public.animals_activities
  WHERE animal_id=NEW.id ORDER BY id DESC LIMIT 1 INTO last_a_id;
  IF last_a_id <> REGEXP_REPLACE(CURRENT_SCHEMA(), '\D+', '')::INTEGER THEN
    RAISE EXCEPTION 'Animal de otra granja!';
  END IF;
  RAISE NOTICE 'Checking animal sex!';
  IF EXISTS(SELECT id FROM ev_entry_female WHERE animal_id=NEW.id) THEN
    RAISE EXCEPTION 'Animal es una hembra!';
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION animals_semen_delete_function()
RETURNS TRIGGER AS $$
DECLARE
  last_a_id INTEGER;
  animal_a_id INTEGER;
  ev_sale_semen_id INTEGER;
BEGIN
  RAISE NOTICE 'Checking last farm activity!';
  SELECT activity_id FROM public.animals_activities
  WHERE animal_id=OLD.id ORDER BY id DESC LIMIT 1 INTO last_a_id;
  IF last_a_id <> REGEXP_REPLACE(CURRENT_SCHEMA(), '\D+', '')::INTEGER THEN
    RAISE EXCEPTION 'Animal de otra granja!';
  END IF;
  RAISE NOTICE 'Checking semen in other farms!';
  FOR animal_a_id IN
    SELECT activity_id FROM public.animals_semen_activities
    WHERE animal_id=OLD.id LOOP
    EXECUTE 'SELECT id FROM activity_' || animal_a_id || '.ev_sale_semen
             WHERE animal_id=' || OLD.id INTO ev_sale_semen_id;
    IF ev_sale_semen_id IS NULL THEN
      RAISE EXCEPTION 'Semen presente en otras granjas!';
    END IF;
  END LOOP;
  RETURN OLD;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION toggle_animals_semen_function(a_id INTEGER)
RETURNS VOID AS $$
BEGIN
  RAISE NOTICE 'Setting animals semen!';
  IF EXISTS(SELECT id FROM public.animals_semen WHERE id=a_id) THEN
    DELETE FROM public.animals_semen WHERE id=a_id;
  ELSE
    INSERT INTO public.animals_semen VALUES(a_id);
  END IF;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION animals_semen_activities_insert_function()
RETURNS TRIGGER AS $$
DECLARE
  last_a_id INTEGER;
  ev_entry_female_id INTEGER;
BEGIN
  RAISE NOTICE 'Checking activity spiece!';
  SELECT activity_id FROM public.animals_activities
  WHERE animal_id=NEW.animal_id ORDER BY id DESC LIMIT 1 INTO last_a_id;
  IF (SELECT spiece FROM public.activities WHERE id=last_a_id) <>
     (SELECT spiece FROM public.activities WHERE id=NEW.activity_id) THEN
    RAISE EXCEPTION 'La especie debe ser la misma de la granja actual!';
  END IF;
  RAISE NOTICE 'Checking animal sex!';
  EXECUTE 'SELECT id FROM activity_' || last_a_id || '.ev_entry_female
           WHERE animal_id=' || NEW.animal_id INTO ev_entry_female_id;
  IF ev_entry_female_id IS NOT NULL THEN
    RAISE EXCEPTION 'Animal es una hembra!';
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;


/******************************************************************/
/************************** TRIGGERS ******************************/
/******************************************************************/

CREATE TRIGGER animals_activities_insert_trigger
  BEFORE INSERT ON animals_activities
  FOR EACH ROW EXECUTE PROCEDURE animals_activities_insert_function(); 

CREATE TRIGGER animals_semen_insert_trigger
  BEFORE INSERT ON animals_semen
  FOR EACH ROW EXECUTE PROCEDURE animals_semen_insert_function(); 

CREATE TRIGGER animals_semen_delete_trigger
  AFTER DELETE ON animals_semen
  FOR EACH ROW EXECUTE PROCEDURE animals_semen_delete_function(); 

CREATE TRIGGER animals_semen_activities_insert_trigger
  BEFORE INSERT ON animals_semen_activities
  FOR EACH ROW EXECUTE PROCEDURE animals_semen_activities_insert_function();
