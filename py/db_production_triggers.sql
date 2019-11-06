/*** ACTIVITIES ***/

-- psql granjalibre -v activity='1' -f db_production.sql
-- \set activity '1'

SET search_path TO activity_:activity;


/****************************************************/
/***************** DEFAULT DATA *********************/
/****************************************************/
-- ****************
-- week_feeds
-- ****************
INSERT INTO week_feeds VALUES (1, 0.60, 'preini 1');
INSERT INTO week_feeds VALUES (2, 1.20, 'preini 1');
INSERT INTO week_feeds VALUES (3, 2.00, 'preini 1');
INSERT INTO week_feeds VALUES (4, 3.00, 'preini 2');
INSERT INTO week_feeds VALUES (5, 4.30, 'preini 2');
INSERT INTO week_feeds VALUES (6, 5.60, 'inicio 1');
INSERT INTO week_feeds VALUES (7, 7.00, 'inicio 1');
INSERT INTO week_feeds VALUES (8, 8.40, 'inicio 1');
INSERT INTO week_feeds VALUES (9, 10.00, 'inicio 2');
INSERT INTO week_feeds VALUES (10, 11.20, 'inicio 2');
INSERT INTO week_feeds VALUES (11, 12.30, 'inicio 2');
INSERT INTO week_feeds VALUES (12, 13.40, 'inicio 2');
INSERT INTO week_feeds VALUES (13, 14.40, 'desarrollo');
INSERT INTO week_feeds VALUES (14, 15.40, 'desarrollo');
INSERT INTO week_feeds VALUES (15, 16.20, 'desarrollo');
INSERT INTO week_feeds VALUES (16, 17.00, 'desarrollo');
INSERT INTO week_feeds VALUES (17, 17.60, 'desarrollo');
INSERT INTO week_feeds VALUES (18, 18.20, 'desarrollo');
INSERT INTO week_feeds VALUES (19, 18.80, 'desarrollo');
INSERT INTO week_feeds VALUES (20, 19.30, 'desarrollo');
INSERT INTO week_feeds VALUES (21, 19.60, 'engorde');
INSERT INTO week_feeds VALUES (22, 19.60, 'engorde');
INSERT INTO week_feeds VALUES (23, 19.60, 'engorde');
INSERT INTO week_feeds VALUES (24, 19.60, 'engorde');
INSERT INTO week_feeds VALUES (25, 19.60, 'engorde');
INSERT INTO week_feeds VALUES (26, 19.60, 'engorde');


-- ****************
-- feeds
-- ****************
INSERT INTO feeds VALUES (1, 'pre', 'preinicio cerdo', TRUE);
INSERT INTO feeds VALUES (2, 'ini', 'inicio cerdo', TRUE);
INSERT INTO feeds VALUES (3, 'des', 'desarrollo cerdo', TRUE);
INSERT INTO feeds VALUES (4, 'eng', 'engorde cerdo', TRUE);
INSERT INTO feeds VALUES (5, 'ree', 'reemplazo cerda', TRUE);

ALTER SEQUENCE feeds_id_seq RESTART WITH 6;



/*************************************************/
/***************** FUNCTIONS *********************/
/*************************************************/
CREATE OR REPLACE FUNCTION g_ev_cols_function(tbl NAME, e_id INTEGER)
RETURNS TABLE(_data TEXT) AS $$
DECLARE
  cols VARCHAR;
BEGIN
  cols := CASE tbl
    WHEN 'g_ev_feeds' THEN '(SELECT CONCAT_WS(''_'',
                               (SELECT feed FROM feeds WHERE id=pf.feed_id), ingress, egress)
                             FROM pens_feeds pf WHERE id=t.pens_feeds_id)'
    WHEN 'g_ev_stock' THEN 'ingress, egress, deaths,
                            (SELECT death FROM deaths WHERE id=t.death_id)'
    WHEN 'g_ev_weights' THEN 'animals, weight'
    WHEN 'g_ev_diseases' THEN 'animals, disease, medication'
    WHEN 'g_ev_notes' THEN 'note'
  END;
  RETURN QUERY EXECUTE 'SELECT CONCAT_WS(''_'', ' || 
    cols || ') ' || 'FROM ' || tbl || ' t WHERE id=' || e_id;
END;
$$
LANGUAGE plpgsql;





-- TODO pens_feeds_move_delete_function





-- g_ev_stock_move_delete_function
CREATE OR REPLACE FUNCTION g_ev_stock_delete_function()
RETURNS TRIGGER AS $$
DECLARE
  other_id INTEGER;
BEGIN
  RAISE NOTICE 'Deleting g_ev_stock!';

  -- 1. check group final_date IS NULL
  -- 2.1. check OLD.ingress > 0 OR OLD.egress >0
  -- 2.2. check id in g_ev_stock_move
  -- 2.3. delete other_group

/*


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
*/
  RETURN NULL;
END;
$$
LANGUAGE plpgsql;
