-- **************************************** --
-------------------- TABLES ------------------
-- **************************************** --

/*** SESSIONS ***/
CREATE TABLE sessions (
  id CHAR(40) UNIQUE NOT NULL,
  ts INTEGER NOT NULL,
  data VARCHAR(100)
);

/*** MAIN ***/
CREATE TABLE farms (
  id SERIAL PRIMARY KEY NOT NULL,
  farm VARCHAR(100) UNIQUE NOT NULL,
  owner VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(50) UNIQUE NOT NULL,
  pass CHAR(40) NOT NULL,
  ts INTEGER NOT NULL,
  CHECK (TRIM(farm) <> '' AND farm !~* '[^a-z0-9 :.,/()#-]+'),
  CHECK (TRIM(owner) <> '' AND owner !~* '[^a-z0-9 :.,/()#@-]+')
);

CREATE TABLE activities (
  id INTEGER PRIMARY KEY NOT NULL,
  farm_id INTEGER NOT NULL,
  spiece VARCHAR(20) NOT NULL,
  type VARCHAR(10) NOT NULL,
  ts INTEGER NOT NULL,
  url VARCHAR(20) UNIQUE NOT NULL,
  logo VARCHAR(20) DEFAULT NULL,
  template VARCHAR(20) DEFAULT NULL,
  activity VARCHAR(80) UNIQUE NOT NULL,
  CHECK (spiece IN('pig', 'cow', 'rabbit')),
  CHECK (type IN ('meet', 'milk')),
  CHECK (TRIM(url) <> '' AND url !~ '[^a-z0-9]+'),
  CHECK (TRIM(logo) <> '' AND logo !~ '[^a-zA-Z0-9._-]+'),
  CHECK (TRIM(template) <> '' AND template !~ '[^a-z.]+'),
  CHECK (TRIM(activity) <> '' AND activity !~ '[^a-zA-Z0-9 ()&#;,./-]+'),
  FOREIGN KEY(farm_id) REFERENCES farms(id)
);



-- ****************
-- public_animals
-- ****************
CREATE TABLE animals (
  id SERIAL PRIMARY KEY NOT NULL,
  father_id INTEGER DEFAULT NULL,
  mother_id INTEGER DEFAULT NULL,
  FOREIGN KEY(father_id) REFERENCES animals(id),
  FOREIGN KEY(mother_id) REFERENCES animals(id)
);


CREATE TABLE animals_activities (
  id SERIAL PRIMARY KEY NOT NULL,
  animal_id INTEGER NOT NULL,
  activity_id INTEGER NOT NULL,
  FOREIGN KEY(animal_id) REFERENCES animals(id),
  FOREIGN KEY(activity_id) REFERENCES activities(id)
);

CREATE UNIQUE INDEX animals_activities_idx ON animals_activities (
  animal_id ASC,
  id DESC
);


CREATE TABLE animals_semen (
  id INTEGER PRIMARY KEY NOT NULL,
  FOREIGN KEY(id) REFERENCES public.animals(id)
);

CREATE TABLE animals_semen_activities (
  id SERIAL PRIMARY KEY NOT NULL,
  animal_id INTEGER NOT NULL,
  activity_id INTEGER NOT NULL,
  FOREIGN KEY(animal_id) REFERENCES animals(id),
  FOREIGN KEY(activity_id) REFERENCES activities(id)
);

CREATE UNIQUE INDEX animals_semen_activities_idx ON animals_semen_activities (
  animal_id ASC,
  id DESC
);



-- ************************************** --
------------------- USERS ------------------
-- ************************************** --
-- /etc/postgresql/10/main/pg_hba.conf
--   local   all             all                                     trust
-- service postgresql restart
-- psql granjalibre -U select_user


CREATE USER select_user;
CREATE USER update_user;
CREATE USER delete_user;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO select_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO update_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO delete_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.sessions TO select_user;

GRANT SELECT, INSERT ON TABLE public.animals, public.animals_activities, public.animals_semen, public.animals_semen_activities TO update_user;

GRANT SELECT, INSERT ON TABLE public.animals, public.animals_activities, public.animals_semen_activities TO delete_user;

GRANT SELECT, INSERT, DELETE ON TABLE public.animals_semen TO delete_user;
