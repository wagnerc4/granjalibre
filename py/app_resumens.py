from re import sub
from json import loads, dumps
from decimal import Decimal
from datetime import date
from base64 import b64encode
from subprocess import Popen, PIPE
from cairosvg import svg2png
from py.db import jsonEncoder
from py.utilities import unescape, set_cell, thous
# from pandas import DataFrame, pivot_table
import numpy as np


def agg_fns(k, v):
  return thous(round({"count": lambda x: len(x),
                      "avg": lambda x: np.mean(x),
                      "sum": lambda x: np.sum(x),
                      "min": lambda x: np.min(x),
                      "max": lambda x: np.max(x),
                      "std": lambda x: np.std(x)}[k](v), 2))


def set_rows_ajax(dbObj, rq, sql):
  parameters = ()
  sql = sub(r'(?!\w|\))\s(?!\w|[\(\*])', r'', sql).strip()
  dbObj.execute(sql + " LIMIT 1;")
  cols = dbObj.getDescription()
  for k, v in loads(rq['filter']).items():
    sql = sql + (' AND ' if len(parameters) else ' WHERE ') + cols[int(k)] + '::TEXT ILIKE %s'
    parameters = parameters + ('%%%s%%' % v, )
  if rq['sort_dir'].lower() not in ('asc', 'desc'):
    raise Exception('bad sort direction!')
  sql = sql + (" ORDER BY %s %s" % (cols[int(rq['sort_col'])], rq['sort_dir']))
  sql = sql + (" LIMIT %s OFFSET %s;" % (int(rq['lines']), (int(rq['page'])-1)*int(rq['lines'])))
  try:
    rows = dbObj.getRows(sub('^SELECT', 'SELECT COUNT(*) OVER(),', sql), parameters)
    return {"count":rows[0][0], "rows":[row[1:] for row in rows]}
  except Exception as e:
    return {"count":0, "rows":[]}


############################# CONTENT #############################
'''
defs = [{"type":"table", "defs":[{"head":"col1", "foot":"sum", "class":"xxx", "value":"r[1]/100"},
                                 {"head":"col2", ...}]},
        {"type":"pivot", "defs":{"data":{}, "index":[], "values":[], "columns":[], "aggfunc":[]}},
        {"type":"graph", "defs":{"data":{}, "graph":{}}},
        {"type":"resumen", "defs":[]}]
'''
def set_table(defs, rows):
  body = []
  foot = [[], []]
  values = {}
  for row in rows:
    tmp = []
    for i in range(len(defs)):
      tmp.append(set_cell(defs[i]['value'], row) if 'value' in defs[i] else row[i])
      if 'foot' in defs[i] and tmp[i]:
        if i not in values:
          values[i] = []
        values[i].append(tmp[i] if isinstance(tmp[i], str) else float(tmp[i]))
      if 'class' in defs[i]:
        if defs[i]['class'] == 'image':
          tmp[i] = '<img src="images/%s" />' % tmp[i]
        elif not tmp[i] or tmp[i] == '':
          tmp[i] = '<span class="'+ defs[i]['class'] +'"></span>'
        else:
          tmp[i] = sub('([^,]+)', '<span class="'+ defs[i]['class'] +'">\\1</span>', str(tmp[i]))
      else:
        if isinstance(tmp[i], int):
          tmp[i] = tmp[i]
        elif isinstance(tmp[i], float) or isinstance(tmp[i], Decimal):
          tmp[i] = thous(round(tmp[i], 2))
        elif isinstance(tmp[i], str):
          tmp[i] = unescape(tmp[i]).replace('\\\\', '<br />')
        else:
          tmp[i] = str(tmp[i]) if tmp[i] else '-'
    body.append(tmp)
  if bool(values):
    foot = [[agg_fns(defs[i]['foot'], values[i]) if 'foot' in defs[i] and i in values else '' \
             for i in range(len(defs))],
            [defs[i]['foot'] if 'foot' in defs[i] else '' for i in range(len(defs))]]
  return {"head": [d['head'] for d in defs], "body": body, "foot": foot}


def set_table_js(defs, rows):
  p = Popen(['py/app_resumens_rows.js'], stdin=PIPE, stdout=PIPE, stderr=PIPE)
  out, err = p.communicate(input=('%s_%s' % (dumps(defs), dumps(rows,cls=jsonEncoder))).encode())
  if err:
    raise Exception('node set rows error!')
  return loads(out.decode())


def set_crosstable(defs, rows):
  body = []
  groups = []
  values = {}
  values_order = []
  value_last = ''
  for row in rows:
    if row[1] and row[1] not in groups: groups.append(row[1])
    if row[0] not in values:
      values[row[0]] = {}
      values_order.append(row[0])
    values[row[0]][row[1] or 'total'] = row[2]
  if len(groups) > 1:
    groups.append('total')
  if len(groups) > 0:
    for k in values_order:
      first = [sub('_.+', '', k) if sub('_.+', '', k) != value_last else '',
              sub('.+_', '', k) if '_' in k else '']
      body.append(first + [values[k][g] if g in values[k] else '' for g in groups])
      value_last = sub('_.+', '', k)
  return {"head": ['', ''] + groups if len(groups) > 0 else [],
          "body": body, "foot": [[], []]}


def set_pivot(defs, rows):
  #values = {}
  #for row in rows:
  #  for k in defs["data"]:
  #    val = set_cell(defs["data"][k], row)
  #    if isinstance(val, float) or isinstance(val, Decimal):
  #      val = round(val, 2)
  #    if k not in values:
  #      values[k] = []
  #    values[k].append(val)
  #p = pivot_table(DataFrame(values, dtype=float), fill_value=0,
  #                index=defs["index"], values=defs["values"], aggfunc=defs["aggfunc"],
  #                columns=defs["columns"] if 'columns' in defs else [])
  #width = (len(defs["index"]) + len(defs["values"])) * 100
  #return {"width": width, "table": p.to_html().replace('<table border="1" class="dataframe">',
  #                                                     '<table class="table table-striped">')}
  groups = {}
  key = defs['index']
  keys = defs['values']
  aggs = defs['aggfunc']
  data = defs["data"]
  for row in rows:
    values = {k: set_cell(data[k], row) for k in data}
    if values[key] not in groups: groups[str(values[key])] = {k:[] for k in keys}
    for k in keys:
      if values[k]: groups[str(values[key])][k].append(values[k])
  table = '<tr><th>%s</th></tr>' % '</th><th>'.join([''] + keys)
  for group in sorted(groups):
    row = [group] + [agg_fns(aggs[k], groups[group][k]) for k in keys]
    table += '<tr><td>%s</td></tr>' % '</td><td>'.join(map(str, row))
  width = (1 + len(defs["values"])) * 100
  return {"width": width, "table": '<table class="table table-striped">%s</table>' % table}


def set_graph(defs, rows):
  values = []
  for row in rows:
    tmp = {}
    for k in defs["data"]:
      val = set_cell(defs["data"][k], row)
      if isinstance(val, date):
        val = str(val)
      if isinstance(val, Decimal):
        val = float(val)
      if isinstance(val, float):
        val = round(val, 2)
      tmp[k] = val
    values.append(tmp)
  if 'vega-lite' in defs['graph']['$schema']:
    defs['graph']['data'] = {"values":values}
    p1 = Popen(['/usr/lib/node_modules/vega-lite/bin/vl2vg'], stdin=PIPE, stdout=PIPE, stderr=PIPE)
    vg, err = p1.communicate(input=dumps(defs['graph']).encode())
    if err:
      raise Exception('vl graph error!')
  else:
    defs['graph']['data'].append({"name":"table", "values":values})
    vg = dumps(defs['graph']).encode()
  p2 = Popen(['/usr/lib/node_modules/vega-cli/bin/vg2svg'], stdin=PIPE, stdout=PIPE, stderr=PIPE)
  svg, err = p2.communicate(input=vg)
  if err:
    raise Exception('vg graph error!')
  if 'pdf' in defs:
    graph = 'data:image/png;base64,%s' % str(b64encode(svg2png(svg)))[2:-1]
  else:
    graph = 'data:image/svg+xml;base64,%s' % str(b64encode(svg))[2:-1]
  width = defs['graph']['width'] if 'width' in defs['graph'] else 200
  return {"graph": graph, "width": width}


def set_resumen(defs, rows):
  body = []
  for row in defs:
    tmp = []
    for i in range(len(row)):
      tmp.append(set_cell(row[i], rows) if row[i] != '' else '')
      if isinstance(tmp[i], int):
        tmp[i] = thous(tmp[i])
      elif isinstance(tmp[i], float) or isinstance(tmp[i], Decimal):
        tmp[i] = thous(round(tmp[i], 2))
    body.append(tmp)
  return body


def set_content(defs, rows):
  if 'head' in defs[0]:
    head = []
    foot = []
    for d in defs:
      if 'head' in d:
        head.append(d['head'])
        foot.append(d['foot'] if 'foot' in d else '')
    rows = set_table_js(defs, rows)
    tmp = [{"type":"table", "data":{"head":head, "body":rows['body'],
                                    "foot":[rows['foot'][0], foot]}},
           {"type":"resumen", "data":rows['foot'][1:]}]
  else:
    tmp = [{"type":d['type'],
            "data":{"table": set_table,
                    "pivot": set_pivot,
                    "graph": set_graph,
                    "crosstable": set_crosstable,
                    "resumen": set_resumen}[d['type']](d['defs'], rows)} for d in defs]
  return tmp


############################# QUERYS #############################
def select_querys_schema_titles(dbObj, rq):
  return {"schema": dbObj.getRows("""
                      SELECT c.relname AS table,
                             (SELECT STRING_AGG(attname, ',') FROM pg_catalog.pg_attribute
                              WHERE attrelid=c.oid AND attnum > 0 AND NOT attisdropped) AS columns
                      FROM pg_catalog.pg_class c
                      JOIN pg_catalog.pg_namespace n ON c.relnamespace=n.oid
                      WHERE c.relkind IN ('r', 'v') AND n.nspname=%s
                      ORDER BY c.relname;""", (rq['schema'], )),
          "titles": dbObj.getRows("""SELECT code, title, MAX(LENGTH(code)) OVER()
                                     FROM querys ORDER BY code;""")}


def select_querys_data(dbObj, rq):
  return dbObj.getRow("SELECT * FROM querys WHERE code=%s;", (rq['code'], ))


def select_query(dbObj, rq):
  rows = dbObj.getRows(rq['query'], rq)
  cols = dbObj.getDescription()
  defs = loads(rq['defs']) if sub('\s', '', rq['defs']) != '[]' else \
         [{"type":"table", "defs":[{"head":c} for c in cols]}]
  return set_content(defs, rows)


def select_query_saved(dbObj, rq):
  row = dbObj.getRow("SELECT query, defs, title FROM querys WHERE code=%s;", (rq['code'], ))
  rows = dbObj.getRows(row[0].replace('\\\\', '\n'), rq)
  cols = dbObj.getDescription()
  defs = loads(row[1].replace('\\\\', '\n')) if row[1] != '[]' else \
         [{"type":"table", "defs":[{"head":c} for c in cols]}]
  if 'pdf' in rq:
    for d in defs:
      if d['type'] == 'graph':
        d['defs']['pdf'] = True
  return {"code": rq['code'], "title": row[2], "content": set_content(defs, rows)}


def insert_query(dbObj, rq):
  dbObj.execute("INSERT INTO querys VALUES (DEFAULT, %s, %s, %s, %s);",
                (rq['query'], rq['defs'], rq['code'], rq['title']))
  return select_querys_schema_titles(dbObj, rq)


def update_query(dbObj, rq):
  dbObj.execute("UPDATE querys SET query=%s, defs=%s, title=%s WHERE code=%s;",
                (rq['query'], rq['defs'], rq['title'], rq['code']))
  return select_querys_schema_titles(dbObj, rq)


def delete_query(dbObj, rq):
  dbObj.execute("DELETE FROM querys WHERE code=%s;", (rq['code'], ))
  return select_querys_schema_titles(dbObj, rq)
