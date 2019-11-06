/*** ACTIVITIES ***/

-- psql granjalibre -v activity='1' -f db_production.sql
-- \set activity '1'

SET search_path TO activity_:activity;


/**********************************************/
/***************** TABLES *********************/
/**********************************************/
-- ****************
-- week_feeds
-- ****************
CREATE TABLE week_feeds (
  id INTEGER PRIMARY KEY NOT NULL,
  weight NUMERIC(5,2) NOT NULL,
  feed_type VARCHAR(15) NOT NULL,
  CHECK (weight > 0),
  CHECK (TRIM(feed_type) <> '' AND feed_type !~* '[^a-z0-9 ]+')
);


-- ****************
-- feeds
-- ****************
CREATE TABLE feeds (
  id SERIAL PRIMARY KEY NOT NULL,
  feed VARCHAR(4) UNIQUE NOT NULL,
--  precio NUMERIC(12,2) NOT NULL,
  description VARCHAR(30) NOT NULL,
  active BOOLEAN NOT NULL,
  CHECK (TRIM(feed) <> '' AND feed !~* '[^a-z0-9-]+'),
  CHECK (TRIM(description) <> '' AND description !~* '[^a-z0-9 :.,/()#-]+')
);


-- ****************
-- pens
-- ****************
CREATE TABLE pens (
  id SERIAL PRIMARY KEY NOT NULL,
  pen VARCHAR(20) NOT NULL,
  lft INTEGER NOT NULL,
  rgt INTEGER NOT NULL,
  CHECK (TRIM(pen) <> '' AND pen !~* '[^a-z0-9 ]+'),
  CHECK (lft > 0),
  CHECK (rgt > 0)
);

CREATE INDEX pens_idx ON pens(lft, rgt);


-- ****************
-- pens_feeds
-- ****************
CREATE TABLE pens_feeds (
  id SERIAL PRIMARY KEY NOT NULL,
  pen_id INTEGER NOT NULL,
  feed_id INTEGER NOT NULL,
  date DATE NOT NULL,
  ingress NUMERIC(6,2) NOT NULL,
  egress NUMERIC(6,2) NOT NULL,
  CHECK (ingress >= 0),
  CHECK (egress >= 0),
  CHECK (ingress > 0 OR egress > 0),
  FOREIGN KEY(pen_id) REFERENCES pens(id),
  FOREIGN KEY(feed_id) REFERENCES feeds(id)
);

CREATE UNIQUE INDEX pens_feeds_idx ON pens_feeds (
  pen_id ASC,
  id ASC
);

CREATE TABLE pens_feeds_move (
  id SERIAL PRIMARY KEY NOT NULL,
  id_of INTEGER NOT NULL,
  pen_of INTEGER NOT NULL,
  id_to INTEGER NOT NULL,
  pen_to INTEGER NOT NULL,
  FOREIGN KEY(id_of) REFERENCES pens_feeds(id) ON DELETE CASCADE,
  FOREIGN KEY(pen_of) REFERENCES pens(id),
  FOREIGN KEY(id_to) REFERENCES pens_feeds(id) ON DELETE CASCADE,
  FOREIGN KEY(pen_to) REFERENCES pens(id)
);


-- ****************
-- groups
-- ****************
CREATE TABLE groups (
  id SERIAL PRIMARY KEY NOT NULL,
  date_initial DATE NOT NULL,
  date_final DATE DEFAULT NULL
);


/***************** EVENTS *********************/
-- ****************
-- groups_events
-- ****************
CREATE TABLE groups_events (
  id SERIAL PRIMARY KEY NOT NULL,
  group_id INTEGER NOT NULL,
  pen_id INTEGER NOT NULL,
  date DATE NOT NULL,
  FOREIGN KEY(group_id) REFERENCES groups(id),
  FOREIGN KEY(pen_id) REFERENCES pens(id)
);

CREATE UNIQUE INDEX groups_events_idx ON groups_events (
  group_id ASC,
  id ASC
);


-- ****************
-- g_ev_feeds
-- ****************
CREATE TABLE g_ev_feeds (
  pens_feeds_id INTEGER NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(group_id) REFERENCES groups(id),
  FOREIGN KEY(pen_id) REFERENCES pens(id),
  FOREIGN KEY(pens_feeds_id) REFERENCES pens_feeds(id)
) INHERITS (groups_events);

CREATE UNIQUE INDEX g_ev_feeds_idx ON g_ev_feeds (
  group_id ASC,
  id ASC
);

CREATE UNIQUE INDEX g_ev_feeds_pens_feeds_id_idx ON g_ev_feeds (
  pens_feeds_id ASC
);


-- ****************
-- g_ev_stock
-- ****************
CREATE TABLE g_ev_stock (
  ingress INTEGER NOT NULL,
  egress INTEGER NOT NULL,
  deaths INTEGER NOT NULL,
  death_id INTEGER DEFAULT NULL,
  date_birth DATE NOT NULL,
  date_wean DATE NOT NULL,
  CHECK (ingress >= 0),
  CHECK (egress >= 0),
  CHECK (deaths >= 0),
  CHECK (ingress > 0 OR egress > 0 OR deaths > 0),
  PRIMARY KEY (id),
  FOREIGN KEY(group_id) REFERENCES groups(id),
  FOREIGN KEY(pen_id) REFERENCES pens(id),
  FOREIGN KEY(death_id) REFERENCES deaths(id)
) INHERITS (groups_events);

CREATE UNIQUE INDEX g_ev_stock_idx ON g_ev_stock (
  group_id ASC,
  id ASC
);

CREATE TABLE g_ev_stock_move (
  id SERIAL PRIMARY KEY NOT NULL,
  id_of INTEGER NOT NULL,
  id_to INTEGER NOT NULL,
  FOREIGN KEY(id_of) REFERENCES g_ev_stock(id) ON DELETE CASCADE,
  FOREIGN KEY(id_to) REFERENCES g_ev_stock(id) ON DELETE CASCADE
);

CREATE TABLE g_ev_stock_feeds (
  id SERIAL PRIMARY KEY NOT NULL,
  ev_stock_id INTEGER NOT NULL,
  ev_feed_id INTEGER NOT NULL,
  FOREIGN KEY(ev_stock_id) REFERENCES g_ev_stock(id),
  FOREIGN KEY(ev_feed_id) REFERENCES g_ev_feeds(id)
);


-- ****************
-- g_ev_diseases
-- ****************
CREATE TABLE g_ev_diseases (
  animals INTEGER NOT NULL,
  disease VARCHAR(15) NOT NULL,
  medication VARCHAR(15) NOT NULL,
  CHECK (animals > 0),
  CHECK (TRIM(disease) <> '' AND disease !~* '[^a-z0-9 ]+'),
  CHECK (TRIM(medication) <> '' AND medication !~* '[^a-z0-9 ]+'),
  PRIMARY KEY (id),
  FOREIGN KEY(group_id) REFERENCES groups(id),
  FOREIGN KEY(pen_id) REFERENCES pens(id)
) INHERITS (groups_events);

CREATE UNIQUE INDEX g_ev_diseases_idx ON g_ev_diseases (
  group_id ASC,
  id ASC
);

-- ****************
-- g_ev_weights
-- ****************
CREATE TABLE g_ev_weights (
  animals INTEGER NOT NULL,
  weight NUMERIC(6,2) NOT NULL,
  CHECK (animals > 0),
  CHECK (weight > 0),
  PRIMARY KEY (id),
  FOREIGN KEY(group_id) REFERENCES groups(id),
  FOREIGN KEY(pen_id) REFERENCES pens(id)
) INHERITS (groups_events);

CREATE UNIQUE INDEX g_ev_weights_idx ON g_ev_weights (
  group_id ASC,
  id ASC
);


-- ****************
-- g_ev_notes
-- ****************
CREATE TABLE g_ev_notes (
  note VARCHAR(100) NOT NULL,
  CHECK (TRIM(note) <> '' AND note !~* '[^a-z0-9 :./()#-]+'),
  PRIMARY KEY (id),
  FOREIGN KEY(group_id) REFERENCES groups(id),
  FOREIGN KEY(pen_id) REFERENCES pens(id)
) INHERITS (groups_events);

CREATE UNIQUE INDEX g_ev_notes_idx ON g_ev_notes (
  group_id ASC,
  id ASC
);



/**********************************************/
/***************** QUERYS *********************/
/**********************************************/
/*
------------------------- CONSULTAS ------------------------
-- Resumen Corrales
    SELECT (SELECT pen FROM pens WHERE lft=MIN(p.lft)) AS place,
           n.pen AS house,
           (SELECT COUNT(*)-1 FROM pens WHERE lft>n.lft AND rgt<n.rgt) AS pens       
    FROM pens n, pens p WHERE n.lft BETWEEN p.lft AND p.rgt
    GROUP BY n.id HAVING COUNT(*) = 2 ORDER BY n.lft;


-- INVENTORY
WITH
  pens_paths AS (
    SELECT n.id, n.pen, STRING_AGG(p.pen, '_') AS path,
           n.pen='0' OR n.lft<>(n.rgt-1) AS parent
    FROM pens n, (SELECT * FROM pens ORDER BY lft) p
    WHERE n.lft BETWEEN p.lft AND p.rgt GROUP BY n.id ORDER BY n.lft),
  groups_inventory AS (
    SELECT (SELECT pen_id FROM groups_events WHERE group_id=g.id ORDER BY id DESC LIMIT 1),
           (SELECT SUM(ingress-egress-deaths) FROM g_ev_stock WHERE group_id=g.id) AS animals
    FROM groups g WHERE date_final IS NULL),
  feed_inventory AS (
    SELECT pen_id,
           (SELECT feed FROM feeds WHERE id=pf.feed_id) AS feed,
           SUM(ingress-egress) AS count
--    FROM pens_feeds pf WHERE NOT EXISTS(SELECT id FROM g_ev_feeds WHERE pens_feeds_id=pf.id)
    FROM pens_feeds pf WHERE EXISTS(SELECT id FROM pens WHERE pen='0' AND id=pf.pen_id)
    GROUP BY pen_id, feed_id HAVING SUM(ingress-egress)<>0)
SELECT id, pen, path, parent, pen='0' AS feed,
       COALESCE((SELECT animals FROM groups_inventory WHERE pen_id=pp.id), 0)
FROM pens_paths pp
UNION ALL
SELECT 0, fi.feed, CONCAT_WS('_', pp.path, fi.feed), FALSE, TRUE, fi.count
FROM feed_inventory fi JOIN pens_paths pp ON fi.pen_id=pp.id;



-- inventario animales (fechas)
    SELECT CONCAT_WS('-', (SELECT pen FROM pens WHERE rgt>(lft+1) AND lft<p.lft AND rgt>p.rgt
                           ORDER BY lft DESC LIMIT 1), p.pen) AS house_pen,
           date_initial,
           COALESCE(date_final, CURRENT_DATE) - date_initial,
           (SELECT SUM((SELECT SUM(ingress-egress) FROM pens_feeds WHERE id=ef.pens_feeds_id))
            FROM g_ev_feeds ef WHERE group_id=g.id AND date<=%s),
           (SELECT CONCAT_WS('_', SUM(CASE WHEN date<%s THEN ingress-egress-deaths ELSE 0 END), 
                                  SUM(CASE WHEN date>=%s THEN ingress ELSE 0 END),
                                  SUM(CASE WHEN date>=%s THEN egress ELSE 0 END),
                                  SUM(CASE WHEN date>=%s THEN deaths ELSE 0 END))
            FROM g_ev_stock WHERE group_id=g.id AND date<=%s)
    FROM (SELECT *, (SELECT pen_id FROM groups_events e
                     WHERE group_id=g.id ORDER BY id DESC LIMIT 1)
          FROM groups g WHERE date_initial<=%s AND (date_final>=%s OR date_final IS NULL)) g
    JOIN pens p ON g.pen_id=p.id ORDER BY house_pen;  d2, d1, d1, d1, d1, d2, d2, d1



-- inventario alimento (fechas)
    WITH
      feed_inventory AS (
        SELECT pen_id,
               (SELECT feed FROM feeds WHERE id=pf.feed_id) AS feed,
               SUM(CASE WHEN date<%s THEN ingress-egress ELSE 0 END) AS initial,
               SUM(CASE WHEN date>=%s THEN ingress ELSE 0 END) AS ingress,
               SUM(CASE WHEN date>=%s THEN egress ELSE 0 END) AS egress
        FROM pens_feeds pf
        WHERE date<=%s AND EXISTS(SELECT id FROM pens WHERE pen='0' AND id=pf.pen_id)
        GROUP BY pen_id, feed_id)
    SELECT (SELECT pen FROM pens WHERE rgt>(lft+1) AND lft<p.lft AND rgt>p.rgt
            ORDER BY lft DESC LIMIT 1) AS house,
           f.feed, f.initial, f.ingress, f.egress, f.initial + f.ingress - f.egress
    FROM pens p JOIN feed_inventory f ON p.id=f.pen_id
    ORDER BY house, feed;  d1, d1, d1, d2



-- Historial por grupo
    SELECT id, tableoid::regclass::name, date,
           g_ev_cols_function(tableoid::regclass::name, id)
    FROM groups_events
    WHERE group_id=%s
    ORDER BY date, id;
*/
