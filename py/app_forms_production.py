#from re import sub
from pytz import timezone
from datetime import datetime


cr_tz = timezone('America/Costa_Rica')


###################### PENS INVENTORY #######################
def produ_inventory(dbObj, rq):
  return dbObj.getRows("""
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
        FROM pens_feeds pf WHERE EXISTS(SELECT id FROM pens WHERE pen='0' AND id=pf.pen_id)
        GROUP BY pen_id, feed_id HAVING SUM(ingress-egress)<>0)
    SELECT id, pen, path, parent, pen='0' AS feed,
           COALESCE((SELECT animals FROM groups_inventory WHERE pen_id=pp.id), 0)
    FROM pens_paths pp
    UNION ALL
    SELECT 0, fi.feed, CONCAT_WS('_', pp.path, fi.feed), FALSE, TRUE, fi.count
    FROM feed_inventory fi JOIN pens_paths pp ON fi.pen_id=pp.id;""")


####################### PENS INVENTORY EVENTS ########################
def search_feed(dbObj, rq):
  return dbObj.getRowsAssoc("SELECT feed AS name FROM feeds WHERE feed ILIKE %s;",
                            ('%%%s%%' % rq['val'], ))


def search_produ_death(dbObj, rq):
  return dbObj.getRowsAssoc("""SELECT death AS name FROM deaths
                               WHERE type='young' AND active=1 AND death ILIKE %s;""",
                            ('%%%s%%' % rq['val'], ))


def insert_pen_feed(dbObj, rq):
  dbObj.execute("""INSERT INTO pens_feeds
                   VALUES(DEFAULT, %s, (SELECT id FROM feeds WHERE feed=%s), %s, %s, 0);""",
                (rq['target_pen'], rq['feed'], rq['date'], rq['units']))
  return produ_inventory(dbObj, rq)


def insert_feed_move(dbObj, rq):
  if rq['date'] > datetime.now(cr_tz).strftime("%Y-%m-%d"):
    raise Exception("error: fecha mayor a fecha actual!")
  if int(rq['units']) <= 0:
    raise Exception("error: traslado debe ser mayor a 0!")
  inventory = dbObj.getRow("""
    SELECT SUM(ingress-egress), MAX(date) FROM pens_feeds
    WHERE pen_id=%s AND feed_id=(SELECT id FROM feeds WHERE feed=%s);""", 
    (rq['source_pen'], rq['feed']))
  if int(rq['units']) > inventory[0]:
    raise Exception("error: traslado mayor a inventario disponible!")
  if rq['date'] < str(inventory[1]):
    raise Exception("error: fecha anterior a inventario disponible!")
  source_feed_id = dbObj.getRow("""
    INSERT INTO pens_feeds
    VALUES(DEFAULT, %s, (SELECT id FROM feeds WHERE feed=%s), %s, 0, %s) RETURNING id;""",
    (rq['source_pen'], rq['feed'], rq['date'], rq['units']))[0]
  target_feed_id = dbObj.getRow("""
    INSERT INTO pens_feeds
    VALUES(DEFAULT, %s, (SELECT id FROM feeds WHERE feed=%s), %s, %s, 0) RETURNING id;""",
    (rq['target_pen'], rq['feed'], rq['date'], rq['units']))[0]
  dbObj.execute("INSERT INTO pens_feeds_move VALUES(DEFAULT, %s, %s, %s, %s);",
                (source_feed_id, rq['source_pen'], target_feed_id, rq['target_pen']))
  return produ_inventory(dbObj, rq)


def insert_group_feed(dbObj, rq):
  if rq['date'] > datetime.now(cr_tz).strftime("%Y-%m-%d"):
    raise Exception("error: fecha mayor a fecha actual!")
  if int(rq['units']) <= 0:
    raise Exception("error: traslado debe ser mayor a 0!")
  inventory = dbObj.getRow("""
    SELECT SUM(ingress-egress), MAX(date) FROM pens_feeds
    WHERE pen_id=%s AND feed_id=(SELECT id FROM feeds WHERE feed=%s);""", 
    (rq['source_pen'], rq['feed']))
  if int(rq['units']) > inventory[0]:
    raise Exception("error: traslado mayor a inventario disponible!")
  if rq['date'] < str(inventory[1]):
    raise Exception("error: fecha anterior a inventario disponible!")
  target_group = dbObj.getRow("""
    SELECT group_id FROM groups_events e
    WHERE pen_id=%s AND
          (SELECT MIN(date) FROM g_ev_stock
           WHERE group_id=e.group_id AND pen_id=e.pen_id) <= %s AND
          (SELECT SUM(ingress-egress-deaths) FROM g_ev_stock
           WHERE group_id=e.group_id AND pen_id=e.pen_id) > 0
    ORDER BY id DESC LIMIT 1""", (rq['target_pen'], rq['date']))
  if not target_group:
    raise Exception("error: fecha inicial en corral o corral sin animales!")
  source_feed_id = dbObj.getRow("""
    INSERT INTO pens_feeds
    VALUES(DEFAULT, %s, (SELECT id FROM feeds WHERE feed=%s), %s, 0, %s) RETURNING id;""",
    (rq['source_pen'], rq['feed'], rq['date'], rq['units']))[0]
  target_feed_id = dbObj.getRow("""
    INSERT INTO pens_feeds
    VALUES(DEFAULT, %s, (SELECT id FROM feeds WHERE feed=%s), %s, %s, 0) RETURNING id;""",
    (rq['target_pen'], rq['feed'], rq['date'], rq['units']))[0]
  dbObj.execute("INSERT INTO g_ev_feeds VALUES(DEFAULT, %s, %s, %s, %s);",
                (target_group[0], rq['target_pen'], rq['date'], target_feed_id))
  dbObj.execute("INSERT INTO pens_feeds_move VALUES(DEFAULT, %s, %s, %s, %s);",
                (source_feed_id, rq['source_pen'], target_feed_id, rq['target_pen']))
  return produ_inventory(dbObj, rq)


def insert_pen_wean(dbObj, rq):
  if rq['date'] > datetime.now(cr_tz).strftime("%Y-%m-%d"):
    raise Exception("error: fecha mayor a fecha actual!")
  if rq['birth'] == '' or rq['birth'] > rq['date']:
    raise Exception("error: fecha parto!")
  target_group = dbObj.getRow("""
    SELECT group_id,
           (SELECT MIN(date) FROM g_ev_stock WHERE group_id=e.group_id AND pen_id=e.pen_id)
    FROM groups_events e
    WHERE pen_id=%s AND
          (SELECT SUM(ingress-egress-deaths) FROM g_ev_stock
           WHERE group_id=e.group_id AND pen_id=e.pen_id) > 0
    ORDER BY id DESC LIMIT 1""", (rq['target_pen'], ))
  if target_group and str(target_group[1]) > rq['date']:
    raise Exception("error: fecha inicial en corral mayor a fecha evento!")
  if not target_group:
    target_group = dbObj.getRow("""INSERT INTO groups VALUES(DEFAULT, %s, NULL)
                                   RETURNING id;""", (rq['date'], ))
  dbObj.execute("INSERT INTO g_ev_stock VALUES(DEFAULT, %s, %s, %s, %s, 0, 0, NULL, %s, %s);",
    (target_group[0], rq['target_pen'], rq['date'], rq['units'], rq['birth'], rq['date']))
  return produ_inventory(dbObj, rq)


def insert_group_move(dbObj, rq):
  if rq['date'] > datetime.now(cr_tz).strftime("%Y-%m-%d"):
    raise Exception("error: fecha mayor a fecha actual!")
  count = int(rq['units'])
  if count <= 0:
    raise Exception("error: traslado debe ser mayor a 0!")
  source_data = dbObj.getRow("""
    SELECT group_id,
           (SELECT SUM(ingress-egress-deaths) FROM g_ev_stock WHERE group_id=e.group_id),
           (SELECT MAX(date) FROM g_ev_stock WHERE group_id=e.group_id),
           (SELECT CURRENT_DATE - ROUND(SUM((ingress - egress - deaths) *
                                            (CURRENT_DATE - date_birth))::NUMERIC /
                                        SUM(ingress - egress - deaths)::NUMERIC)::INTEGER
            FROM g_ev_stock WHERE group_id=e.group_id) AS balanced_birth,
           (SELECT CURRENT_DATE - ROUND(SUM((ingress - egress - deaths) *
                                            (CURRENT_DATE - date_wean))::NUMERIC /
                                        SUM(ingress - egress - deaths)::NUMERIC)::INTEGER
            FROM g_ev_stock WHERE group_id=e.group_id) AS balanced_wean
    FROM groups_events e WHERE pen_id=%s ORDER BY id DESC LIMIT 1""", (rq['source_pen'], ))
  if count > source_data[1]:
    raise Exception("error: traslado mayor a inventario disponible!")
  if rq['date'] < str(source_data[2]):
    raise Exception("error: fecha anterior a inventario disponible!")
  target_group = dbObj.getRow("""
    SELECT group_id,
           (SELECT MIN(date) FROM g_ev_stock WHERE group_id=e.group_id AND pen_id=e.pen_id)
    FROM groups_events e
    WHERE pen_id=%s AND
          (SELECT SUM(ingress-egress-deaths) FROM g_ev_stock
           WHERE group_id=e.group_id AND pen_id=e.pen_id) > 0
          -- AND EXISTS(SELECT id FROM groups WHERE date_final IS NULL AND id=e.group_id)
    ORDER BY id DESC LIMIT 1""", (rq['target_pen'], ))
  if target_group and str(target_group[1]) > rq['date']:
    raise Exception("error: fecha inicial en corral mayor a fecha evento!")
  source_id = dbObj.getRow("""
    INSERT INTO g_ev_stock VALUES(DEFAULT, %s, %s, %s, 0, %s, 0, NULL, %s, %s) RETURNING id;""",
    (source_data[0], rq['source_pen'], rq['date'], count, source_data[3], source_data[4]))[0]
  if source_data[1] == count and not target_group:
    target_id = dbObj.getRow("""
      INSERT INTO g_ev_stock VALUES(DEFAULT, %s, %s, %s, %s, 0, 0, NULL, %s, %s) RETURNING id;""",
      (source_data[0], rq['target_pen'], rq['date'], count, source_data[3], source_data[4]))[0]
  else:
    if source_data[1] == count:
      dbObj.execute("UPDATE groups SET date_final=%s WHERE id=%s;", (rq['date'], source_data[0]))
    if not target_group:
      target_group = dbObj.getRow("""INSERT INTO groups VALUES(DEFAULT, %s, NULL)
                                     RETURNING id;""", (rq['date'], ))
    target_id = dbObj.getRow("""
      INSERT INTO g_ev_stock VALUES(DEFAULT, %s, %s, %s, %s, 0, 0, NULL, %s, %s) RETURNING id;""",
      (target_group[0], rq['target_pen'], rq['date'], count, source_data[3], source_data[4]))[0]
    feed_data = dbObj.getRows("""
      SELECT feed_id, date, SUM(ingress-egress) FROM pens_feeds pf
      WHERE EXISTS(SELECT id FROM g_ev_feeds WHERE pens_feeds_id=pf.id AND group_id=%s)
      GROUP BY feed_id, date;""", (source_data[0], ))
    for row in feed_data:
      total = row[2] if source_data[1] == count else row[2]*count/source_data[1]
      source_feed_id = dbObj.getRow("""
        INSERT INTO pens_feeds VALUES(DEFAULT, %s, %s, %s, 0, %s) RETURNING id;""",
        (rq['source_pen'], row[0], row[1], total))[0]
      source_feed_group_id = dbObj.getRow("""
        INSERT INTO g_ev_feeds VALUES(DEFAULT, %s, %s, %s, %s) RETURNING id;""",
        (source_data[0], rq['source_pen'], row[1], source_feed_id))
      dbObj.execute("INSERT INTO g_ev_stock_feeds VALUES(DEFAULT, %s, %s);",
                    (source_id, source_feed_group_id))
      target_feed_id = dbObj.getRow("""
        INSERT INTO pens_feeds VALUES(DEFAULT, %s, %s, %s, %s, 0) RETURNING id;""",
        (rq['target_pen'], row[0], row[1], total))[0]
      target_feed_group_id = dbObj.getRow("""
        INSERT INTO g_ev_feeds VALUES(DEFAULT, %s, %s, %s, %s) RETURNING id;""",
        (target_group[0], rq['target_pen'],  row[1], target_feed_id))
      dbObj.execute("INSERT INTO g_ev_stock_feeds VALUES(DEFAULT, %s, %s);",
                    (target_id, target_feed_group_id))
      dbObj.execute("INSERT INTO pens_feeds_move VALUES(DEFAULT, %s, %s, %s, %s);",
                    (source_feed_id, rq['source_pen'], target_feed_id, rq['target_pen']))
  dbObj.execute("INSERT INTO g_ev_stock_move VALUES(DEFAULT, %s, %s);", (source_id, target_id))
  return produ_inventory(dbObj, rq)


def insert_pen_sale(dbObj, rq):
  if rq['date'] > datetime.now(cr_tz).strftime("%Y-%m-%d"):
    raise Exception("error: fecha mayor a fecha actual!")
  count = int(rq['units'])
  if count <= 0:
    raise Exception("error: salida debe ser mayor a 0!")
  source_data = dbObj.getRow("""
    SELECT group_id,
           (SELECT MAX(date) FROM groups_events WHERE group_id=e.group_id AND pen_id=e.pen_id),
           (SELECT MIN(date) FROM g_ev_stock WHERE group_id=e.group_id AND pen_id=e.pen_id),
           (SELECT SUM(ingress-egress-deaths) FROM g_ev_stock WHERE group_id=e.group_id),
           (SELECT CURRENT_DATE - ROUND(SUM((ingress - egress - deaths) *
                                            (CURRENT_DATE - date_birth))::NUMERIC /
                                        SUM(ingress - egress - deaths)::NUMERIC)::INTEGER
            FROM g_ev_stock WHERE group_id=e.group_id) AS balanced_birth,
           (SELECT CURRENT_DATE - ROUND(SUM((ingress - egress - deaths) *
                                            (CURRENT_DATE - date_wean))::NUMERIC /
                                        SUM(ingress - egress - deaths)::NUMERIC)::INTEGER
            FROM g_ev_stock WHERE group_id=e.group_id) AS balanced_wean
    FROM groups_events e WHERE pen_id=%s ORDER BY id DESC LIMIT 1""", (rq['source_pen'], ))
  if str(source_data[2]) > rq['date']:
    raise Exception("error: fecha inicial en corral mayor a fecha evento!")
  if source_data[3] < count:
    raise Exception("error: salida mayor a inventario disponible!")
  if source_data[3] == count and str(source_data[1]) > rq['date']:
    raise Exception("error: salida anterior a ultimo evento!")
  dbObj.execute("INSERT INTO g_ev_stock VALUES(DEFAULT, %s, %s, %s, 0, %s, 0, NULL, %s, %s);",
      (source_data[0], rq['source_pen'], rq['date'], count, source_data[4], source_data[5]))
  if source_data[3] == count:
    dbObj.execute("UPDATE groups SET date_final=%s WHERE id=%s;", (rq['date'], source_data[0]))
  return produ_inventory(dbObj, rq)


def insert_pen_death(dbObj, rq):
  if rq['date'] > datetime.now(cr_tz).strftime("%Y-%m-%d"):
    raise Exception("error: fecha mayor a fecha actual!")
  count = int(rq['units'])
  if count <= 0:
    raise Exception("error: muertos debe ser mayor a 0!")
  death = dbObj.getRow("SELECT id FROM deaths WHERE death=%s", (rq['death'], ))
  if not death:
    raise Exception("error: ingrese una muerte valida!")
  source_data = dbObj.getRow("""
    SELECT group_id,
           (SELECT MAX(date) FROM groups_events WHERE group_id=e.group_id AND pen_id=e.pen_id),
           (SELECT MIN(date) FROM g_ev_stock WHERE group_id=e.group_id AND pen_id=e.pen_id),
           (SELECT SUM(ingress-egress-deaths) FROM g_ev_stock WHERE group_id=e.group_id),
           (SELECT CURRENT_DATE - ROUND(SUM((ingress - egress - deaths) *
                                            (CURRENT_DATE - date_birth))::NUMERIC /
                                        SUM(ingress - egress - deaths)::NUMERIC)::INTEGER
            FROM g_ev_stock WHERE group_id=e.group_id) AS balanced_birth,
           (SELECT CURRENT_DATE - ROUND(SUM((ingress - egress - deaths) *
                                            (CURRENT_DATE - date_wean))::NUMERIC /
                                        SUM(ingress - egress - deaths)::NUMERIC)::INTEGER
            FROM g_ev_stock WHERE group_id=e.group_id) AS balanced_wean
    FROM groups_events e WHERE pen_id=%s ORDER BY id DESC LIMIT 1""", (rq['source_pen'], ))
  if str(source_data[2]) > rq['date']:
    raise Exception("error: fecha inicial en corral mayor a fecha evento!")
  if source_data[3] < count:
    raise Exception("error: muertos mayor a inventario disponible!")
  if source_data[3] == count and str(source_data[1]) > rq['date']:
    raise Exception("error: salida anterior a ultimo evento!")
  dbObj.execute("""
    INSERT INTO g_ev_stock VALUES(DEFAULT, %s, %s, %s, 0, 0, %s, %s, %s, %s);""",
    (source_data[0],rq['source_pen'],rq['date'], count, death[0], source_data[4], source_data[5]))
  if source_data[3] == count:
    dbObj.execute("UPDATE groups SET date_final=%s WHERE id=%s;", (rq['date'], source_data[0]))
  return produ_inventory(dbObj, rq)


def insert_pen_disease(dbObj, rq):
  if rq['date'] > datetime.now(cr_tz).strftime("%Y-%m-%d"):
    raise Exception("error: fecha mayor a fecha actual!")
  count = int(rq['units'])
  if count <= 0:
    raise Exception("error: enfermos debe ser mayor a 0!")
  source_data = dbObj.getRow("""
    SELECT group_id,
           (SELECT MIN(date) FROM g_ev_stock WHERE group_id=e.group_id AND pen_id=e.pen_id),
           (SELECT SUM(ingress-egress-deaths) FROM g_ev_stock WHERE group_id=e.group_id)
    FROM groups_events e WHERE pen_id=%s ORDER BY id DESC LIMIT 1""", (rq['source_pen'], ))
  if str(source_data[1]) > rq['date']:
    raise Exception("error: fecha inicial en corral mayor a fecha evento!")
  if source_data[2] < count:
    raise Exception("error: enfermos mayor a inventario disponible!")
  dbObj.execute("INSERT INTO g_ev_diseases VALUES(DEFAULT, %s, %s, %s, %s, %s, %s);",
    (source_data[0], rq['source_pen'], rq['date'], count, rq['disease'], rq['medication']))
  return produ_inventory(dbObj, rq)


def insert_pen_weight(dbObj, rq):
  if rq['date'] > datetime.now(cr_tz).strftime("%Y-%m-%d"):
    raise Exception("error: fecha mayor a fecha actual!")
  count = int(rq['units'])
  if count <= 0:
    raise Exception("error: enfermos debe ser mayor a 0!")
  source_data = dbObj.getRow("""
    SELECT group_id,
           (SELECT MIN(date) FROM g_ev_stock WHERE group_id=e.group_id AND pen_id=e.pen_id),
           (SELECT SUM(ingress-egress-deaths) FROM g_ev_stock WHERE group_id=e.group_id)
    FROM groups_events e WHERE pen_id=%s ORDER BY id DESC LIMIT 1""", (rq['source_pen'], ))
  if str(source_data[1]) > rq['date']:
    raise Exception("error: fecha inicial en corral mayor a fecha evento!")
  if source_data[2] < count:
    raise Exception("error: pesados mayor a inventario disponible!")
  dbObj.execute("INSERT INTO g_ev_weights VALUES(DEFAULT, %s, %s, %s, %s, %s);",
                (source_data[0], rq['source_pen'], rq['date'], count, rq['weight']))
  return produ_inventory(dbObj, rq)


def insert_pen_note(dbObj, rq):
  if rq['date'] > datetime.now(cr_tz).strftime("%Y-%m-%d"):
    raise Exception("error: fecha mayor a fecha actual!")
  source_data = dbObj.getRow("""
    SELECT group_id,
           (SELECT MIN(date) FROM g_ev_stock WHERE group_id=e.group_id AND pen_id=e.pen_id)
    FROM groups_events e WHERE pen_id=%s ORDER BY id DESC LIMIT 1""", (rq['source_pen'], ))
  if str(source_data[1]) > rq['date']:
    raise Exception("error: fecha inicial en corral mayor a fecha evento!")
  dbObj.execute("INSERT INTO g_ev_notes VALUES(DEFAULT, %s, %s, %s, %s);",
                (source_data[0], rq['source_pen'], rq['date'], rq['note']))
  return produ_inventory(dbObj, rq)


#################################### PRODU FEED #########################################
def produ_feeds(dbObj, rq):
  return dbObj.getRows("""
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
    SELECT p.id,
           (SELECT pen FROM pens WHERE rgt>(lft+1) AND lft<p.lft AND rgt>p.rgt
            ORDER BY lft DESC LIMIT 1) AS house,
           f.feed, f.initial, f.ingress, f.egress, f.initial + f.ingress - f.egress
    FROM pens p JOIN feed_inventory f ON p.id=f.pen_id
    ORDER BY house, feed;""", (rq['d1'], rq['d1'], rq['d1'], rq['d2']))


def select_feed_history(dbObj, rq):
  return dbObj.getRows("""
    SELECT id, date, ingress, egress,
           CASE WHEN ingress > 0 THEN
             COALESCE(
               (SELECT (SELECT pen FROM pens WHERE rgt>(lft+1) AND lft<p.lft AND rgt>p.rgt
                        ORDER BY lft DESC LIMIT 1)
                FROM pens_feeds_move m JOIN pens p ON m.pen_of=p.id
                WHERE id_to=pf.id),
                'Fabrica'
             )
           ELSE
             COALESCE(
               (SELECT (SELECT pen FROM pens WHERE rgt>(lft+1) AND lft<p.lft AND rgt>p.rgt
                        ORDER BY lft DESC LIMIT 1)
                FROM pens_feeds_move m JOIN pens p ON m.pen_to=p.id
                WHERE id_of=pf.id),
               (SELECT CONCAT_WS('-', (SELECT pen FROM pens WHERE rgt>(lft+1) AND lft<p.lft AND
                                         rgt>p.rgt ORDER BY lft DESC LIMIT 1), p.pen)
                FROM g_ev_feeds e JOIN pens p ON e.pen_id=p.id
                WHERE pens_feeds_id=pf.id)
             )
           END 
    FROM pens_feeds pf
    WHERE date>=%s AND date<=%s AND pen_id=%s AND feed_id=(SELECT id FROM feeds WHERE feed=%s)
    ORDER BY date, id;""", (rq['d1'], rq['d2'], rq['pen_id'], rq['feed']))


def delete_feed_event(dbObj, rq):
  move = dbObj.getRow("SELECT id_to, id_of FROM pens_feeds_move WHERE id_to=%s OR id_of=%s;",
                      (rq['id'], rq['id']))
  if move:
    other = move[0] if int(rq['id']) == move[1] else move[1]
    group = dbObj.getRow("""SELECT group_id FROM g_ev_feeds
                            WHERE pens_feeds_id=%s OR pens_feeds_id=%s;""", (rq['id'], other))
    if group:
      raise Exception("error: alimentacion asociada a grupo: %s!" % group[0])
    dbObj.execute("DELETE FROM pens_feeds WHERE id=%s", (other, ))
  dbObj.execute("DELETE FROM pens_feeds WHERE id=%s", (rq['id'], ))
  return produ_feeds(dbObj, rq)


#################################### PRODU STOCK #########################################
def produ_stock(dbObj, rq):
  return dbObj.getRows("""
  SELECT g.id,
         (SELECT (SELECT CONCAT_WS('-',
                           (SELECT pen FROM pens WHERE rgt>(lft+1) AND lft<p.lft AND rgt>p.rgt
                            ORDER BY lft DESC LIMIT 1), pen)
                  FROM pens p WHERE id=groups_events.pen_id)
          FROM groups_events WHERE group_id=g.id AND date<=%(d2)s
          ORDER BY id DESC LIMIT 1) AS house_pen,
         (SELECT SUM(total * days) / SUM(total)::NUMERIC
          FROM (SELECT (ingress -
                        CASE WHEN SUM(ingress-egress-deaths) OVER()=0 AND MAX(id) OVER()=id
                             THEN 0 ELSE egress + deaths END) AS total,
                       COALESCE(g.date_final, %(d2)s) - date_birth AS days
                FROM g_ev_stock WHERE group_id=g.id AND date<=%(d2)s) t),
         (SELECT SUM((SELECT SUM(ingress-egress) FROM pens_feeds WHERE id=ef.pens_feeds_id))
          FROM g_ev_feeds ef WHERE group_id=g.id AND date<=%(d2)s),
         (SELECT CONCAT_WS('_', SUM(CASE WHEN date<%(d1)s THEN ingress-egress-deaths ELSE 0 END),
                                SUM(CASE WHEN date>=%(d1)s AND
                                              NOT EXISTS(SELECT id FROM groups_events
                                                         WHERE group_id=g_ev_stock.group_id AND
                                                               id=(SELECT id_of
                                                                   FROM g_ev_stock_move
                                                                   WHERE id_to=g_ev_stock.id))
                                         THEN ingress ELSE 0 END),
                                SUM(CASE WHEN date>=%(d1)s AND
                                              NOT EXISTS(SELECT id FROM groups_events
                                                         WHERE group_id=g_ev_stock.group_id AND
                                                               id=(SELECT id_to
                                                                   FROM g_ev_stock_move
                                                                   WHERE id_of=g_ev_stock.id))
                                         THEN egress ELSE 0 END),
                                SUM(CASE WHEN date>=%(d1)s THEN deaths ELSE 0 END))
          FROM g_ev_stock WHERE group_id=g.id AND date<=%(d2)s)
    FROM groups g
    WHERE date_initial<=%(d2)s AND (date_final>=%(d1)s OR date_final IS NULL)
    ORDER BY house_pen;""", {"d1":rq['d1'],"d2":rq['d2']}) 


def select_group_history(dbObj, rq):
  return dbObj.getRows("""
    SELECT id, date,
           CONCAT_WS('_', tableoid::regclass::name,
                     (SELECT 'move' FROM groups_events WHERE group_id=e.group_id AND
                        id=(SELECT id_of FROM g_ev_stock_move WHERE id_to=e.id)),
                     (SELECT 'move' FROM groups_events WHERE group_id=e.group_id AND
                        id=(SELECT id_to FROM g_ev_stock_move WHERE id_of=e.id))),
           g_ev_cols_function(tableoid::regclass::name, id)
    FROM groups_events e WHERE date>=%s AND date<=%s AND group_id=%s
    ORDER BY date, id;""", (rq['d1'], rq['d2'], rq['group_id']))


def delete_group_event(dbObj, rq):
  group_data = dbObj.getRow("""
    SELECT group_id, tableoid::regclass::name,
           (SELECT date_final FROM groups WHERE id=e.group_id),
           (SELECT MAX(id) FROM groups_events WHERE group_id=e.group_id AND
              tableoid::regclass::name IN ('g_ev_stock', 'insert_pen_sale', 'insert_pen_death'))
    FROM groups_events e WHERE id=%s;""", (rq['id'], ))
  if group_data[2]:
    if int(rq['id']) == group_data[3]:
      dbObj.execute("UPDATE groups SET date_final=NULL WHERE id=%s", (group_data[0], ))
    else:
      raise Exception("error: grupo cerrado!")
  if group_data[1] == 'g_ev_feeds':
    rq['id'] = dbObj.getRow("DELETE FROM g_ev_feeds WHERE id=%s RETURNING pens_feeds_id",
                            (rq['id'], ))[0]
    delete_feed_event(dbObj, rq)
  elif group_data[1] == 'g_ev_stock':
    move = dbObj.getRow("SELECT id_to, id_of FROM g_ev_stock_move WHERE id_to=%s OR id_of=%s;",
                        (rq['id'], rq['id']))
    if move:
      other = move[0] if int(rq['id']) == move[1] else move[1]
      feeds_data = dbObj.getRows("""
        SELECT ev_feed_id, (SELECT pens_feeds_id FROM g_ev_feeds WHERE id=sf.ev_feed_id)
        FROM g_ev_stock_feeds sf WHERE ev_stock_id IN(%s, %s);""", (rq['id'], other))
      if feeds_data:
        dbObj.execute("DELETE FROM g_ev_stock_feeds WHERE ev_feed_id IN %s;",
                      (tuple([f[0] for f in feeds_data]), ))
        dbObj.execute("DELETE FROM g_ev_feeds WHERE id IN %s;",
                      (tuple([f[0] for f in feeds_data]), ))
        dbObj.execute("DELETE FROM pens_feeds WHERE id IN %s;",
                      (tuple([f[1] for f in feeds_data]), ))
      dbObj.execute("DELETE FROM g_ev_stock_move WHERE id_to=%s OR id_of=%s;",
                    (rq['id'], rq['id']))
      group_id = dbObj.getRow("DELETE FROM groups_events WHERE id=%s RETURNING group_id",
                              (other, ))[0]
      dbObj.execute("UPDATE groups SET date_final=NULL WHERE id=%s", (group_id, ))
    dbObj.execute("DELETE FROM groups_events WHERE id=%s", (rq['id'], ))
  else:
    dbObj.execute("DELETE FROM groups_events WHERE id=%s", (rq['id'], ))
  return produ_stock(dbObj, rq)
