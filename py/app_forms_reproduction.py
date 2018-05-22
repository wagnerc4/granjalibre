from re import sub
from json import loads
from py.utilities import sql_ts


###################### ANIMALS #######################
def getFarmActivity(dbObj, rq):
  return dbObj.getRows("""
    SELECT CONCAT_WS(' -> ', farm, id)
    FROM (SELECT id, public.farm_name(a.id) AS farm
          FROM public.activities a
          WHERE spiece=(SELECT spiece FROM public.activities
                        WHERE id=REGEXP_REPLACE(CURRENT_SCHEMA(),
                                                '\D+','')::INTEGER)) t
    WHERE farm ILIKE %s ORDER BY farm LIMIT 5;""", ('%%%s%%' % rq['val'], ))


def getAnimal(dbObj, rq):
  return dbObj.getRows("""
    SELECT CONCAT_WS(' -> ', animal, ubication), death
    FROM (SELECT animal,
            (SELECT ubication FROM ev_ubication WHERE animal_id=a.id
             ORDER BY id DESC LIMIT 1) AS ubication,
            COALESCE((SELECT ts FROM ev_sale WHERE animal_id=a.id),
              (SELECT ts FROM ev_sale_semen WHERE animal_id=a.id)) AS death
          FROM animals a) t
    WHERE animal ILIKE %s OR ubication ILIKE %s
    ORDER BY death DESC LIMIT 10;""", ('%%%s%%' % rq['val'], '%%%s%%' % rq['val']))


def getMale(dbObj, rq):
  return dbObj.getRows("""
    SELECT animal
    FROM animals a
    WHERE EXISTS(SELECT id FROM ev_entry_male WHERE animal_id=a.id) AND
          NOT EXISTS(SELECT id FROM ev_sale WHERE animal_id=a.id) AND
          animal ILIKE %s OR
          EXISTS(SELECT id FROM ev_entry_semen WHERE animal_id=a.id) AND
          NOT EXISTS(SELECT id FROM ev_sale_semen WHERE animal_id=a.id) AND
          animal ILIKE %s
    ORDER BY animal LIMIT 5;""", ('%%%s%%' % rq['val'], '%%%s%%' % rq['val']))


def getFemaleAdoptive(dbObj, rq):
  return dbObj.getRows("""
    SELECT a.animal FROM animals a JOIN ev_farrow f ON a.id=f.animal_id
    WHERE NOT EXISTS(SELECT id FROM ev_wean WHERE animal_id=a.id AND id>f.id) AND
          a.animal ILIKE %s ORDER BY a.animal LIMIT 5;""", ('%%%s%%' % rq['val'], ))


######################################################################


def validateLitter(dbObj, rq):
  return dbObj.getRow("SELECT * FROM litter_info_function(%s, %s);",
                      (sub(r'.+(?=\d+$)', r'', rq["farm_search"]), rq['litter']))


def a_insert(dbObj, rq):
  dbObj.execute("""
    SELECT animal_new_insert_function(%s,%s,%s,%s,%s,%s,%s,%s,%s);""",
    (sql_ts(rq['a_entry']), rq['a_name'], rq['a_pedigree'] or None,
     sub(r'.+(?=\d+$)', r'', rq["farm_search"]), rq['a_litter'],
     sql_ts(rq['a_birth']), rq['a_race'], rq['a_sex'], rq['a_parity'] or 0))


def getAnimalsOld(dbObj, rq):
  return dbObj.getRows("""
    SELECT t.id, i.animal, public.farm_name(i.prev_a_id)
    FROM (SELECT DISTINCT(animal_id) AS id FROM public.animals_activities a
          WHERE NOT EXISTS(SELECT id FROM animals WHERE id=a.animal_id)) t,
         public.animal_information(t.id) i
    WHERE i.last_a_id=REGEXP_REPLACE(CURRENT_SCHEMA(),'\D+','')::INTEGER;""")


def insertAnimalOld(dbObj, rq):
  dbObj.execute("SELECT animal_old_insert_function(%s);", (rq['id'], ))


def getAnimalsSemen(dbObj, rq):
  return dbObj.getRows("""
    SELECT t.id, i.animal, public.farm_name(i.last_a_id)
    FROM (SELECT id FROM public.animals_semen a
          WHERE NOT EXISTS(SELECT id FROM animals WHERE id=a.id)) t,
         public.animal_information(t.id) i
    WHERE (SELECT spiece FROM public.activities WHERE id=i.last_a_id) =
          (SELECT spiece FROM public.activities
           WHERE id=REGEXP_REPLACE(CURRENT_SCHEMA(), '\D+', '')::INTEGER);""")


def insertAnimalSemen(dbObj, rq):
  dbObj.execute("SELECT animal_semen_insert_function(%s, %s);",
                (rq['id'], sql_ts(rq['ts'])))


######################################################################


def getGenealogy(dbObj, rq):
  return dbObj.getRows("""
    SELECT * FROM animal_genealogy_function(
      (SELECT id FROM animals WHERE animal=%s));""", (rq['animal'], ))


def get_temperatures(dbObj, rq):
  return dbObj.getRows("""
    SELECT ts::BIGINT * 1000,
      (SELECT temperature FROM ev_temperature WHERE id=events.id),
      CASE WHEN tableoid::regclass::name = 'ev_dry'
        THEN 0 ELSE (SELECT weight FROM ev_milk WHERE id=events.id) END,
      CASE WHEN tableoid::regclass::name NOT IN ('ev_temperature', 'ev_milk')
        THEN tableoid::regclass::name END
    FROM events
    WHERE animal_id=(SELECT id FROM animals WHERE animal=%s) AND
          tableoid IN ('ev_heat'::regclass::oid,
                       'ev_service'::regclass::oid,
                       'ev_abortion'::regclass::oid,
                       'ev_farrow'::regclass::oid,
                       'ev_death'::regclass::oid,
                       'ev_semen'::regclass::oid,
                       'ev_ubication'::regclass::oid,
                       'ev_milk'::regclass::oid,
                       'ev_dry'::regclass::oid,
                       'ev_temperature'::regclass::oid,
                       'ev_treatment'::regclass::oid)
    ORDER BY ts, id;""", (rq['animal'], ))


def getEartag(dbObj, rq):
  return dbObj.getRow("""
    SELECT eartag FROM animals_eartags
    WHERE id=(SELECT id FROM animals WHERE animal=%s);""", (rq['animal'], ))


def setEartag(dbObj, rq):
  dbObj.execute("""
    INSERT INTO animals_eartags
    VALUES((SELECT id FROM animals WHERE animal=%s), %s);""", (rq['animal'], rq['e_name']))


def getSemenFarms(dbObj, rq):
  return dbObj.getRows("""
    SELECT CONCAT_WS(' -> ', public.farm_name(a.activity_id), a.activity_id)
    FROM public.animals_semen_activities a
    WHERE animal_id=(SELECT id FROM animals WHERE animal=%s);""", (rq['animal'], ))


def setSemenStatus(dbObj, rq):
  dbObj.execute("""
    SELECT public.toggle_animals_semen_function(
             (SELECT id FROM animals WHERE animal=%s));""", (rq['animal'], ))


####################### EVENTS ########################
def getConstantHistory(dbObj, rq):
  return dbObj.getRows("""
    SELECT id, tableoid::regclass::name, ts, parity,
           ev_cols_function(tableoid::regclass::name, id)
    FROM events
    WHERE animal_id=(SELECT id FROM animals WHERE animal=%s) AND
          tableoid IN ('ev_feed'::regclass::oid,
                       'ev_condition'::regclass::oid,
                       'ev_milk'::regclass::oid,
                       'ev_temperature'::regclass::oid)
    ORDER BY ts, id;""", (rq['animal'], ))


def getVariableHistory(dbObj, rq):
  return dbObj.getRows("""
    SELECT id, tableoid::regclass::name, ts, parity,
           ev_cols_function(tableoid::regclass::name, id)
    FROM events
    WHERE animal_id=(SELECT id FROM animals WHERE animal=%s) AND
          tableoid NOT IN ('ev_feed'::regclass::oid,
                           'ev_condition'::regclass::oid,
                           'ev_milk'::regclass::oid,
                           'ev_temperature'::regclass::oid)
    ORDER BY ts, id;""", (rq['animal'], ))


def getRules(dbObj, rq):
  return dbObj.getRow("""
    SELECT animal_rules_function(
           (SELECT id FROM animals WHERE animal=%s));""", (rq['animal'], ))


def getAllHistory(dbObj, rq):
  return {"ev_constant": getConstantHistory(dbObj, rq),
          "ev_variable": getVariableHistory(dbObj, rq),
          "rules": getRules(dbObj, rq)[0][1]}


def getHistory(dbObj, rq):
  return {"ev_variable": getVariableHistory(dbObj, rq),
          "rules": getRules(dbObj, rq)[0][1]}


def ev_sale_semen(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_sale_semen
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"])))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_sale(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_sale
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s),
                               %s, 0, (SELECT id FROM deaths WHERE death=%s))
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["death"]))
  dbObj.execute("""INSERT INTO public.animals_activities
                   VALUES(DEFAULT, %s, %s);""",
                (ids[1], sub(r'.+(?=\d+$)', r'', rq["farm_search"]) or None))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_heat(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_heat
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["lordosis"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_service(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_service
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s),
                               %s, 0, (SELECT id FROM animals WHERE animal=%s), %s, %s,%s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["male"],
                      rq["matings"], rq["lordosis"], rq["quality"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_check_pos(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_check_pos
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["test"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_check_neg(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_check_neg
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["test"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_abortion(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_abortion
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), 1 if "inducted" in rq else 0))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_farrow(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_farrow
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s),
                               %s, 0, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["litter"], rq["males"], rq["females"],
                      rq["weight"], rq["deaths"], rq["mummies"], rq["hernias"],rq["cryptorchids"],
                      1 if "dystocia" in rq else 0, 1 if "retention" in rq else 0,
                      1 if "inducted" in rq else 0, 1 if "asisted" in rq else 0))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_death(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_death
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s),
                               %s, 0, (SELECT id FROM deaths WHERE death=%s), %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["death"], rq["animals"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_foster(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_foster
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["animals"], rq["weight"]))
  dbObj.execute("""INSERT INTO ev_adoption
                   VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s, %s);""",
                (rq["mother"], sql_ts(rq["ts"]), rq["animals"], rq["weight"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_adoption(dbObj, rq):
  dbObj.execute("""INSERT INTO ev_foster
                   VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s, %s);""",
                (rq["mother"], sql_ts(rq["ts"]), rq["animals"], rq["weight"]))
  ids = dbObj.getRow("""INSERT INTO ev_adoption
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["animals"], rq["weight"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_partial_wean(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_partial_wean
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["animals"], rq["weight"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_wean(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_wean
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["animals"], rq["weight"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_semen(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_semen
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s),
                               %s, 0, %s, %s, %s, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["volumen"], 
                      rq["concentration"], rq["motility"], rq["dosis"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_ubication(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_ubication
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["ubication"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_feed(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_feed
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["weight"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_condition(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_condition
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s),
                               %s, 0, %s, %s, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["condition"],
                      rq["weight"], rq["backfat"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_milk(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_milk
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["weight"], rq["quality"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_dry(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_dry
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"])))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_temperature(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_temperature
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["temperature"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


################################
def sync_temperatures(dbObj, rq):
  ids, rows = [], loads(rq['temperatures'])
  for row in rows:  # id, eartag, ts, temperature
    _id = dbObj.getRow("""INSERT INTO ev_temperature
                          VALUES(%s, (SELECT id FROM animals_eartags WHERE eartag=%s), %s, 0, %s)
                          RETURNING id;""", tuple(row))
    ids.append(_id[0])
  return ids
###############################


def ev_treatment(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_treatment
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s),
                               %s, 0, %s, %s, %s, %s, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["treatment"],
                      rq["dose"], rq["frecuency"], rq["days"], rq["route"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_palpation(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_palpation
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["palpation"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_note(dbObj, rq):
  ids = dbObj.getRow("""INSERT INTO ev_note
                        VALUES(DEFAULT, (SELECT id FROM animals WHERE animal=%s), %s, 0, %s)
                        RETURNING id, animal_id;""",
                     (rq["animal"], sql_ts(rq["ts"]), rq["note"]))
  return {"ev_variable": dbObj.getRow("SELECT * FROM ev_data_function(%s);", (ids[0], )),
          "rules": dbObj.getRow("SELECT animal_rules_function(%s);", (ids[1], ))[0][1]}


def ev_delete(dbObj, rq):
  dbObj.execute("DELETE FROM events WHERE id=%s;", (rq["id"], ))
  return {"rules": dbObj.getRow("""SELECT animal_rules_function(
                                     (SELECT id FROM animals WHERE animal=%s));""",
                       (rq['animal'], ))[0][1]}


####################### RESUMENS ########################
def repro_resumen(dbObj, rq):
  row = dbObj.getRow("""
WITH data AS(
  SELECT p.relname AS x, ARRAY[COALESCE(ROUND(AVG(e.parity), 2), 0)] ||
    CASE WHEN p.relname='ev_entry_male' THEN ARRAY[COUNT(*)]
         WHEN p.relname='ev_entry_female' THEN ARRAY[COUNT(*)]
         WHEN p.relname='ev_sale' THEN ARRAY[COUNT(*)]
         WHEN p.relname='ev_heat' THEN ARRAY[COUNT(*)]
         WHEN p.relname='ev_service' THEN ARRAY[COUNT(*)]
         WHEN p.relname='ev_check_neg' THEN
           ARRAY[COUNT(*),
                 ROUND(AVG((SELECT (e.ts-MAX(ts))/86400 FROM ev_service
                            WHERE animal_id=e.animal_id AND id<e.id)), 2)]
         WHEN p.relname='ev_abortion' THEN
           ARRAY[COUNT(*),
                 ROUND(AVG((SELECT (e.ts-MAX(ts))/86400 FROM ev_service
                            WHERE animal_id=e.animal_id AND id<e.id)), 2)]
         WHEN p.relname='ev_farrow' THEN
           ARRAY[COUNT(*),
                 SUM((SELECT males+females FROM ev_farrow WHERE id=e.id)),
                 SUM((SELECT deaths FROM ev_farrow WHERE id=e.id)),
                 SUM((SELECT mummies FROM ev_farrow WHERE id=e.id)),
                 SUM((SELECT weight FROM ev_farrow WHERE id=e.id))]
         WHEN p.relname='ev_death' THEN
           ARRAY[SUM((SELECT animals FROM ev_death WHERE id=e.id)),
                 ROUND(AVG((SELECT (e.ts-MAX(ts))/86400 FROM ev_farrow
                            WHERE animal_id=e.animal_id AND id<e.id)), 2)]
         WHEN p.relname='ev_wean' THEN
           ARRAY[COUNT(*),
                 ROUND(AVG((SELECT (e.ts-MAX(ts))/86400 FROM ev_farrow
                            WHERE animal_id=e.animal_id AND id<e.id)), 2),
                 SUM((SELECT animals FROM ev_wean WHERE id=e.id)),
                 SUM((SELECT weight FROM ev_wean WHERE id=e.id))]
         WHEN p.relname='ev_partial_wean' THEN
           ARRAY[COUNT(*),
                 ROUND(AVG((SELECT (e.ts-MAX(ts))/86400 FROM ev_farrow
                            WHERE animal_id=e.animal_id AND id<e.id)), 2),
                 SUM((SELECT animals FROM ev_partial_wean WHERE id=e.id)),
                 SUM((SELECT weight FROM ev_partial_wean WHERE id=e.id))]
    END AS y
  FROM events e JOIN pg_class p ON e.tableoid=p.oid
  WHERE p.relname IN ('ev_entry_male', 'ev_entry_female', 'ev_sale',
                      'ev_heat', 'ev_service', 'ev_check_neg', 'ev_abortion',
                      'ev_farrow', 'ev_death', 'ev_wean', 'ev_partial_wean') AND
        TO_TIMESTAMP(e.ts)::DATE >= %(d1)s AND TO_TIMESTAMP(e.ts)::DATE <= %(d2)s
  GROUP BY p.relname
UNION ALL
  SELECT 'prev_entry_male', ARRAY[0, COUNT(*)]
  FROM ev_entry_male e
  WHERE TO_TIMESTAMP(e.ts)::DATE < %(d1)s AND
        NOT EXISTS(SELECT id FROM ev_sale
                   WHERE animal_id=e.animal_id AND TO_TIMESTAMP(ts)::DATE <= %(d2)s)
UNION ALL
  SELECT 'prev_entry_female',
         ARRAY[ROUND(AVG((SELECT parity FROM events WHERE animal_id=e.animal_id
                          ORDER BY id DESC LIMIT 1)), 2), COUNT(*)]
  FROM ev_entry_female e
  WHERE TO_TIMESTAMP(e.ts)::DATE < %(d1)s AND
        NOT EXISTS(SELECT id FROM ev_sale
                   WHERE animal_id=e.animal_id AND TO_TIMESTAMP(ts)::DATE <= %(d2)s)
) SELECT ARRAY_AGG(x), JSON_AGG(ARRAY_TO_JSON(y)) FROM data;""", {"d1":rq['d1'], "d2":rq['d2']})
  e = {"prev_entry_male": [0, 0],
       "prev_entry_female": [0, 0],
       "ev_entry_female": [0, 0],
       "ev_entry_male": [0, 0],
       "ev_sale": [0, 0],
       "ev_heat": [0, 0],
       "ev_service": [0, 0],
       "ev_check_neg": [0, 0, 0],
       "ev_abortion": [0, 0, 0],
       "ev_farrow": [0, 0, 0, 0, 0, 0],
       "ev_death": [0, 0, 0],
       "ev_wean": [0, 0, 0, 0, 0],
       "ev_partial_wean": [0, 0, 0, 0, 0]}
  for k in e:
    e[k] = row[1][row[0].index(k)] if k in row[0] else e[k]
  return [["<strong style='float:left;'>Detalles de Servicios</strong>", "", ""],
          ["Total Servicios", e['ev_service'][0], e['ev_service'][1]],
          ["Celos sin servicio", e['ev_heat'][0], e['ev_heat'][1]],
          ["Servicios infertiles / dias", e['ev_check_neg'][0], "%s / %s" % (e['ev_check_neg'][1], e['ev_check_neg'][2])],
          ["Fertilidad (%)", "", "%s %%" % round(100 - (e['ev_check_neg'][1] * 100 / (e['ev_service'][1] or 1)), 2)],
          ["<strong style='float:left;'>Detalles de Abortos</strong>", "", ""],
          ["Total Abortos / dias", e['ev_abortion'][0], "%s / %s" % (e['ev_abortion'][1], e['ev_abortion'][2])],
          ["<strong style='float:left;'>Detalles de Partos</strong>", "", ""],
          ["Total Partos", e['ev_farrow'][0], e['ev_farrow'][1]],
          ["N. totales / camada", "", "%s / %s" % (e['ev_farrow'][2] + e['ev_farrow'][3],
                                                   round((e['ev_farrow'][2] + e['ev_farrow'][3]) / (e['ev_farrow'][1] or 1), 2))],
          ["N. vivos / camada", "", "%s / %s" % (e['ev_farrow'][2], round(e['ev_farrow'][2] / (e['ev_farrow'][1] or 1), 2))],
          ["N. muertos / camada", "", "%s / %s" % (e['ev_farrow'][3], round(e['ev_farrow'][3] / (e['ev_farrow'][1] or 1), 2))],
          ["Momias / camada", "", "%s / %s" % (e['ev_farrow'][4], round(e['ev_farrow'][4] / (e['ev_farrow'][1] or 1), 2))],
          ["Peso camada / animal", "", "%s / %s" % (round(e['ev_farrow'][5] / (e['ev_farrow'][1] or 1), 2),
                                                    round(e['ev_farrow'][5] / (e['ev_farrow'][2] or 1), 2))],
          ["<strong style='float:left;'>Detalles de Bajas</strong>", "", ""],
          ["Total Bajas / dias", e['ev_death'][0], "%s / %s" % (e['ev_death'][1], e['ev_death'][2])],
          ["Mortalidad (%)", "", "%s %%" % round(e['ev_death'][1] * 100 / (e['ev_farrow'][2] or 1), 2)],
          ["<strong style='float:left;'>Detalles de Destetes</strong>", "", ""],
          ["Total Destetes / dias", e['ev_wean'][0], "%s / %s" % (e['ev_wean'][1], e['ev_wean'][2])],
          ["Total Parciales / dias", e['ev_partial_wean'][0], "%s / %s" % (e['ev_partial_wean'][1], e['ev_partial_wean'][2])],
          ["Destetados / camada", "", "%s / %s" % (e['ev_wean'][3] + e['ev_partial_wean'][3],
                                                   round((e['ev_wean'][3] + e['ev_partial_wean'][3]) / ((e['ev_wean'][1] + e['ev_partial_wean'][1]) or 1), 2))],
          ["Peso camada / animal", "", "%s / %s" % (round((e['ev_wean'][4] + e['ev_partial_wean'][4]) / ((e['ev_wean'][1] + e['ev_partial_wean'][1]) or 1), 2),
                                                    round((e['ev_wean'][4] + e['ev_partial_wean'][4]) / ((e['ev_wean'][3] + e['ev_partial_wean'][3]) or 1), 2))],
          ["<strong style='float:left;'>Detalles de Inventario</strong>", "", ""],
          ["Total Machos / ingresos", "", "%s / %s" % (e['prev_entry_male'][1] + (e['ev_entry_male'][1]), e['ev_entry_male'][1])],
          ["Total Hembras / ingresos", e['prev_entry_female'][0], "%s / %s" % (e['prev_entry_female'][1] + (e['ev_entry_female'][1]), e['ev_entry_female'][1])],
          ["Salidas", e['ev_sale'][0], e['ev_sale'][1]]]


def repro_resumen_males_usage(dbObj, rq):
  return dbObj.getRows("""
SELECT ts,
       CASE WHEN EXISTS(SELECT id FROM ev_check_neg
                        WHERE animal_id=s.animal_id AND parity=s.parity)
       THEN 1 ELSE 0 END,
       (SELECT animal FROM animals WHERE id=s.male_id)
FROM ev_service s WHERE ts>=%s AND ts<=%s ORDER BY ts ASC;
  """, (sql_ts(rq['d1']), sql_ts(rq['d2'])))




################################################################################


'''
def repro_resumen_fertility(dbObj, rq):
  return dbObj.getRows("""
SELECT s.ts,
       CASE WHEN EXISTS(SELECT id FROM ev_check_neg
                        WHERE animal_id=s.animal_id AND parity=s.parity)
       THEN 1 ELSE 0 END,
       CASE WHEN EXISTS(SELECT id FROM ev_farrow
                        WHERE animal_id=s.animal_id AND parity=s.parity)
       THEN 1 ELSE 0 END
FROM ev_service s WHERE ts>=%s AND ts<=%s ORDER BY ts ASC;
  """, (sql_ts(rq['d1']), sql_ts(rq['d2'])))


def repro_resumen_repetitive(dbObj, rq):
  return dbObj.getRows("""
SELECT parity, COUNT(id) - 1, MIN(ts), MAX(ts)
FROM events
WHERE tableoid IN ('ev_heat'::regclass::oid, 'ev_service'::regclass::oid)
      AND ts>=%s AND ts<=%s
GROUP BY animal_id, parity;
  """, (sql_ts(rq['d1']), sql_ts(rq['d2'])))


def repro_resumen_farrow_service(dbObj, rq):
  return dbObj.getRows("""
WITH services AS(
  SELECT animal_id, parity, MIN(ts) AS min_ts, MAX(ts) AS max_ts
  FROM ev_service GROUP BY animal_id, parity
)
SELECT f.ts, s.min_ts, s.max_ts
FROM ev_farrow f JOIN services s ON f.animal_id=s.animal_id AND
                                    f.parity=s.parity
WHERE f.ts>=%s AND f.ts<=%s;
  """, (sql_ts(rq['d1']), sql_ts(rq['d2'])))


def repro_resumen_litters_deaths(dbObj, rq):
  return dbObj.getRows("""
SELECT ts,
       parity,
       (SELECT death FROM deaths WHERE id=e.death_id),
       (SELECT ubication FROM ev_ubication
        WHERE animal_id=e.animal_id AND id<e.id ORDER BY id DESC LIMIT 1),
       animals
FROM ev_death e WHERE ts>=%s AND ts<=%s ORDER BY ts;
  """, (sql_ts(rq['d1']), sql_ts(rq['d2'])))


def repro_resumen_sales(dbObj, rq):
  return dbObj.getRows("""
SELECT (SELECT (SELECT race FROM races WHERE id=animals.race_id)
          || '_' || animal FROM animals WHERE id=e.animal_id) AS race_animal,
       parity,
       ts,
       CASE WHEN EXISTS(SELECT id FROM ev_entry_female
                        WHERE animal_id=e.animal_id)
       THEN 0 ELSE 1 END,
       (SELECT death FROM deaths WHERE id=e.death_id)
FROM ev_sale e WHERE ts>=%s AND ts<=%s ORDER BY race_animal;
  """, (sql_ts(rq['d1']), sql_ts(rq['d2'])))
'''
