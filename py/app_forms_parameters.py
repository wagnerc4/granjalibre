###################### VARIABLES #######################
def select_variables(dbObj, rq):
  return dbObj.getRows("SELECT var, val FROM variables;")


def update_variable(dbObj, rq):
  return dbObj.execute("UPDATE variables SET val=%s WHERE var=%s;",
                       (rq["val"], rq["var"]))


###################### RACES #######################
def select_races(dbObj, rq):
  return dbObj.getRows("SELECT * FROM races ORDER BY race;")


def insert_race(dbObj, rq):
  dbObj.execute("INSERT INTO races VALUES (DEFAULT, %s, 1);", (rq["race"], ))
  return select_races(dbObj, rq)


def update_race(dbObj, rq):
  dbObj.execute("UPDATE races SET active=ABS(active-1) WHERE id=%s;", (rq["id"], ))
  return select_races(dbObj, rq)


###################### DEATHS #######################
def select_deaths(dbObj, rq):
  return dbObj.getRows("SELECT * FROM deaths ORDER BY death;")


def insert_death(dbObj, rq):
  dbObj.execute("INSERT INTO deaths VALUES (DEFAULT, %s, %s, 1);", (rq["death"], rq["type"]))
  return select_deaths(dbObj, rq)


def update_death(dbObj, rq):
  dbObj.execute("UPDATE deaths SET active=ABS(active-1) WHERE id=%s;", (rq["id"], ))
  return select_deaths(dbObj, rq)


###################### PENS #######################
def select_pens(dbObj, rq):
  return dbObj.getRows("""
    SELECT (SELECT pen FROM pens WHERE lft=MIN(p.lft)) AS place,
           n.pen AS house,
           (SELECT COUNT(*)-1 FROM pens WHERE lft>n.lft AND rgt<n.rgt) AS pens       
    FROM pens n, pens p WHERE n.lft BETWEEN p.lft AND p.rgt
    GROUP BY n.id HAVING COUNT(*) = 2 ORDER BY n.lft;""")


def insert_pens(dbObj, rq):
  pens = int(rq['pens'])
  if pens < 1:
    raise Exception("error: numero de corrales debe ser mayor a 0!")
  rgt = dbObj.getRow("SELECT COALESCE((SELECT rgt FROM pens WHERE rgt<>lft+1 AND pen=%s), 0);",
                     (rq['place'], ))[0]
  if rgt > 0:
    house = dbObj.getRow("""SELECT (SELECT MAX(rgt) FROM pens
                                    WHERE rgt>(lft+1) AND lft<p.lft AND rgt>p.rgt)
                            FROM pens p WHERE pen=%s;""", (rq['house'], ))
    if house and house[0] == rgt:
      raise Exception("error: el galeron ya existe!")
    dbObj.execute("UPDATE pens SET lft=lft+%s WHERE lft>=%s;", ((pens * 2) + 4, rgt))
    dbObj.execute("UPDATE pens SET rgt=rgt+%s WHERE rgt>=%s;", ((pens * 2) + 4, rgt))
    dbObj.execute("INSERT INTO pens VALUES(DEFAULT, %s, %s, %s);",
                  (rq['house'], rgt, (pens * 2) + 3 + rgt))
    for n in range(pens+1):
      dbObj.execute("INSERT INTO pens VALUES(DEFAULT, %s, %s, %s);",
                    (n, (n * 2) + 1 + rgt, (n * 2) + 2 + rgt))
  else:
    rgt = dbObj.getRow("SELECT COALESCE(MAX(rgt), 0) FROM pens;")[0];
    dbObj.execute("INSERT INTO pens VALUES(DEFAULT, %s, %s, %s);",
                  (rq['place'], 1 + rgt, (pens * 2) + 6 + rgt))
    dbObj.execute("INSERT INTO pens VALUES(DEFAULT, %s, %s, %s);",
                  (rq['house'], 2 + rgt, (pens * 2) + 5 + rgt))
    for n in range(pens+1):
      dbObj.execute("INSERT INTO pens VALUES(DEFAULT, %s, %s, %s);",
                    (n, (n * 2) + 3 + rgt, (n * 2) + 4 + rgt))
  return select_pens(dbObj, rq)


###################### WEEK FEEDS #######################
def select_week_feeds(dbObj, rq):
  return dbObj.getRows("SELECT * FROM week_feeds ORDER BY id;")


def insert_week_feed(dbObj, rq):
  dbObj.execute("""INSERT INTO week_feeds
                   SELECT COALESCE(MAX(id), 0)+1, %s, %s FROM week_feeds;""",
                (rq["weight"], rq["feed_type"]))
  return select_week_feeds(dbObj, rq)


def update_week_feed(dbObj, rq):
  dbObj.execute("UPDATE week_feeds SET weight=%s, feed_type=%s WHERE id=%s;",
                (rq["weight"], rq["feed_type"], rq["id"]))
  return select_week_feeds(dbObj, rq)


###################### PRICES #######################
def select_feeds(dbObj, rq):
  return dbObj.getRows("SELECT * FROM feeds ORDER BY feed;")


def insert_feed(dbObj, rq):
  dbObj.execute("INSERT INTO feeds VALUES (DEFAULT, %s, %s, TRUE);",
                (rq["feed"], rq["description"]))
  return select_feeds(dbObj, rq)


def update_feed(dbObj, rq):
  dbObj.execute("UPDATE feeds SET active=NOT active WHERE id=%s;", (rq["id"], ))
  return select_feeds(dbObj, rq)


###################### RECORDS #######################
