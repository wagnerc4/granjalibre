from re import sub
from json import loads
from pytz import timezone
from datetime import datetime
from hashlib import md5


cr_tz = timezone('America/Costa_Rica')


############################# QUERYS #############################
def select_querys_titles(dbObj, rq):
  return dbObj.getRows("SELECT code, title, MAX(LENGTH(code)) OVER() FROM querys ORDER BY code;")


def select_querys_data(dbObj, rq):
  return dbObj.getRow("SELECT * FROM querys WHERE code=%s;", (rq['code'], ))


def select_query(dbObj, rq):
  return {"rows": dbObj.getRows(rq['query'], rq),
          "cols": dbObj.getDescription()}


def insert_query(dbObj, rq):
  dbObj.execute("INSERT INTO querys VALUES (DEFAULT, %s, %s, %s, %s, %s, %s, %s);",
                (rq['query'], rq['defs'], rq['code'], rq['title'], rq['graph_type'] or None,
                 rq['graph_x'] or None, rq['graph_y'] or None))
  return select_querys_titles(dbObj, rq)


def update_query(dbObj, rq):
  dbObj.execute("""UPDATE querys SET query=%s, defs=%s, title=%s,
                                     graph_type=%s, graph_x=%s, graph_y=%s WHERE code=%s;""",
                (rq['query'], rq['defs'], rq['title'], rq['graph_type'] or None,
                 rq['graph_x'] or None, rq['graph_y'] or None, rq['code']))
  return select_querys_titles(dbObj, rq)


def delete_query(dbObj, rq):
  dbObj.execute("DELETE FROM querys WHERE code=%s;", (rq['code'], ))
  return select_querys_titles(dbObj, rq)


# RESUMENS
def select_query_saved(dbObj, rq):
  row = dbObj.getRow("""SELECT query, defs, title, graph_type, graph_x, graph_y
                        FROM querys WHERE code=%s;""", (rq['code'], ))
  return {"rows": dbObj.getRows(row[0].replace('\\\\', '\n'), rq),
          "cols": dbObj.getDescription(),
          "defs": row[1].replace('\\\\', '\n'),
          "code": rq['code'],
          "title": row[2],
          "graph_type": row[3],
          "graph_x": row[4],
          "graph_y": row[5],
          "subquery": rq['subquery'] if 'subquery' in rq else None}


############################# CRONS #############################
#def insert_cron(dbObj, rq):
#  dbObj.execute("INSERT INTO crons VALUES(DEFAULT, %s);", (rq['cron'], ))
#  '''
#  from crontab import CronTab
#
#  cron = CronTab()
#  cron.new(command='/bin/speaker-test -t wav -f 1000 -l 1')
#  cron.write()
#
#  cron.remove_all()
#  for job in cron: print(job)
#  '''
#  return select_crons(dbObj, rq)
#
#
#def delete_cron(dbObj, rq):
#  dbObj.execute("DELETE FROM crons WHERE cron=%s;", (rq['cron'], ))
#  return select_crons(dbObj, rq)
#
#
############################# ALERTS #############################
def select_alerts_data(dbObj, rq):
  crons = dbObj.getRow("SELECT ARRAY_AGG(cron) FROM crons;")
  querys = dbObj.getRow("SELECT ARRAY_AGG(code) FROM querys WHERE code LIKE 'alerts_%';")
  return {"crons":crons[0] if crons else [],
          "querys":querys[0] if querys else [],
          #"phones":dbObj.getRows("""
          #           SELECT (SELECT persona FROM personas WHERE id=pt.persona_id) AS persona,
          #                  ARRAY_AGG(telefono || '_' || nota)
          #           FROM personas_telefonos pt GROUP BY persona_id ORDER BY persona;"""),
          "workers":dbObj.getRow("SELECT ARRAY_AGG(worker) FROM workers;")[0]}


def select_alerts(dbObj, rq):
  return dbObj.getRows("""SELECT id,
                                 (SELECT cron FROM crons WHERE id=a.cron_id),
                                 (SELECT code FROM querys WHERE id=a.query_id),
                                 (SELECT ARRAY_AGG(target) FROM alerts_targets
                                  WHERE alert_id=a.id)
                          FROM alerts a WHERE type=%s;""", (rq['type'], ))


def insert_alert(dbObj, rq):
  a_id = dbObj.getRow("""INSERT INTO alerts
                         VALUES(DEFAULT, (SELECT id FROM crons WHERE cron=%s),
                                (SELECT id FROM querys WHERE code=%s), %s)
                         RETURNING id;""", (rq['cron'], rq['query'], rq['type']))[0]
  items = loads(rq['items'])
  for item in items:
    dbObj.execute("INSERT INTO alerts_targets VALUES(DEFAULT, %s, %s);", (a_id, item))
  return select_alerts(dbObj, rq)


def delete_alert(dbObj, rq):
  dbObj.execute("DELETE FROM alerts WHERE id=%s;", (rq['id'], ))
  return select_alerts(dbObj, rq)



# TODO on close notify INSERT INTO alerts_done



############################# ROLES #############################
modules = [
  {"parent":"glb", "title":"Global"},
  {"parent":"glb", "title":"Resumenes", "file":"global_resumens"},
  {"parent":"glb", "title":"Grafico Resumenes", "file":"global_graph"},
  {"parent":"glb", "title":"Asientos", "file":"global_records"},
  # CALENDARIO
  {"parent":"cal", "menu":"forms", "title":"Calendario", "file":"forms_calendar"},
  # REPRODUCTION
  {"parent":"rep", "title":"Reproduccion"},
  {"parent":"rep", "menu":"forms", "title":"Eventos Reproduccion", "file":"forms_reproduction_events"},
  {"parent":"rep", "menu":"forms", "title":"Resumen Reproduccion", "file":"forms_reproduction_resumen"},
  {"parent":"rep", "menu":"forms", "title":"Resumen Uso Padrotes", "file":"forms_reproduction_males_usage"},
  # PRODUCTION
  {"parent":"pro", "title":"Produccion"},
  {"parent":"pro", "menu":"forms", "title":"Eventos Produccion", "file":"forms_production_events"},
  {"parent":"pro", "menu":"forms", "title":"Inventario Animales Produccion", "file":"forms_production_stock"},
  {"parent":"pro", "menu":"forms", "title":"Inventario Alimento Produccion", "file":"forms_production_feed"},
  # PARAMETERS
  {"parent":"par", "title":"Parametros"},
  {"parent":"par", "menu":"forms", "title":"Variables Especie","file":"forms_parameters_variables"},
  {"parent":"par", "menu":"forms", "title":"Razas", "file":"forms_parameters_races"},
  {"parent":"par", "menu":"forms", "title":"Causas Salida", "file":"forms_parameters_deaths"},
  {"parent":"par", "menu":"forms", "title":"Produccion Corrales", "file":"forms_parameters_pens"},
  {"parent":"par", "menu":"forms", "title":"Produccion Consumo", "file":"forms_parameters_week_feeds"},
  {"parent":"par", "menu":"forms", "title":"Precios", "file":"forms_parameters_prices"},
  {"parent":"par", "menu":"forms", "title":"Asientos", "file":"forms_parameters_records"},
  # SETTINGS
  {"parent":"set", "title":"Ajustes"},
  {"parent":"set", "menu":"settings", "title":"Consultas", "file":"settings_querys"},
  {"parent":"set", "menu":"settings", "title":"Alertas", "file":"settings_alerts"},
  {"parent":"set", "menu":"settings", "title":"Roles", "file":"settings_roles"},
  # SETTINGS
  {"parent":"res", "title":"Resumenes"}
]


roles = [
  ["Usuarios", "forms_reproduction_events,forms_production_events,forms_production_feed,forms_production_stock"],
  ["gerencia", "forms_reproduction_events,forms_reproduction_resumen,forms_production_events,forms_production_feed,forms_production_stock,forms_parameters_variables,forms_parameters_races,forms_parameters_deaths,forms_parameters_pens,forms_parameters_week_feeds,forms_parameters_prices,forms_parameters_records,settings_querys,settings_alerts,settings_roles"]
]


def get_resumens(dbObj, rq):
  return dbObj.getRows("""
    SELECT title, code
    FROM querys
    WHERE code ~ '^(forms|resumens|accounting|settings)((?!_subquery).)+$'
    ORDER BY code;""")


def get_resumens_data(dbObj, rq):
  access = dbObj.getRow("SELECT access FROM workers WHERE id=%s;", (rq['worker_id'], ))[0]
  return dbObj.getRowsAssoc("""
    SELECT code, title, defs,
           query LIKE %s AS d1,
           query LIKE %s AS d2,
           query LIKE %s AS v,
           graph_type, graph_x, graph_y
    FROM querys WHERE code IN %s ORDER BY code;""",
    ('%%%%(d1)s%%', '%%%%(d2)s%%', '%%%%(v)s%%', tuple(access.split(','))))


def get_modules_roles(dbObj, rq):
  mods = []
  root = dbObj.getRow("SELECT root FROM workers WHERE id=%s;", (rq['worker_id'], ))[0]
  for module in modules:
    if 'file' in module and module['file'] == 'settings_querys' and not root:
      continue
    mods.append([module['parent'], module['title'],
                 module['file'] if 'file' in module else None])
  resumens = get_resumens(dbObj, rq)
  for resumen in resumens:
    mods.append(['res', resumen[0], resumen[1]])
  return [mods, roles]


def get_menus(dbObj, rq):
  menus = {"forms":[], "resumens":[], "accounting":[], "settings":[]}
  access = dbObj.getRow("SELECT access FROM workers WHERE id=%s;", (rq['worker_id'], ))[0]
  for module in modules:
    if 'menu' in module and module['file'] in access:
      menus[module['menu']].append([module['parent'], module['title'], module['file']])
  resumens = get_resumens(dbObj, rq)
  for resumen in resumens:
    if resumen[1] in access:
      menu, parent = tuple(resumen[1].split('_'))[:2]
      index = len(menus[menu])
      for i in range(len(menus[menu])):
        if (menus[menu][i][0] == parent): index = i + 1
      menus[menu].insert(index, [parent, resumen[0], resumen[1]])
  return menus


def get_files(dbObj, rq):
  files = []
  access = dbObj.getRow("SELECT access FROM workers WHERE id=%s;", (rq['worker_id'], ))[0]
  for module in modules:
    if 'file' in module and module['file'] in access:
      files.append(module['file'])
  return files


# WORKERS
def worker_login(dbObj, rq):
  row = dbObj.getRowsAssoc("""
    SELECT w.id, w.worker, w.privilege, CONCAT_WS('_', a.spiece, a.id) AS activity
    FROM workers w, public.activities a
    WHERE a.id=%s AND w.email=%s AND w.pass=%s;""",
    (sub('activity_', '', rq['schema']), rq['email'].strip(), rq['pass'].strip()))
  if row:
    return row[0]
  else:
    raise Exception("login error: Not autorized user!")


def select_workers(dbObj, rq):
  return dbObj.getRows("""SELECT id, privilege, access, worker, phone, email
                          FROM workers ORDER BY worker;""")


def insert_worker(dbObj, rq):
  dbObj.execute("INSERT INTO workers VALUES(DEFAULT, %s, %s, %s, %s, %s, %s, FALSE, NULL);",
                (rq['usuario'], rq['phone'], rq['email'].strip(),
                 md5(rq['pass'].encode('utf-8')).hexdigest(), rq['_privilege'], rq['roles']))
  return select_workers(dbObj, rq)


def update_worker(dbObj, rq):
  dbObj.execute("""UPDATE workers SET worker=%s, phone=%s, email=%s,
                                    privilege=%s, access=%s WHERE id=%s;""", 
                (rq['usuario'], rq['phone'], rq['email'],
                 rq['_privilege'], rq['roles'], rq['id']))
  if rq['pass'] != '':
    dbObj.execute("UPDATE workers SET pass=%s WHERE id=%s;", 
                  (md5(rq['pass'].encode('utf-8')).hexdigest(), rq['id']))
  return select_workers(dbObj, rq)


def delete_worker(dbObj, rq):
  dbObj.execute("DELETE FROM workers WHERE id=%s;", (rq['id'], ))
  return select_workers(dbObj, rq)
