from psycopg2 import connect
# from sqlite3 import connect
from json import dumps, JSONEncoder
from decimal import Decimal
from datetime import date
#from subprocess import call


class jsonEncoder(JSONEncoder):
  def default(self, obj):
    if isinstance(obj, Decimal): return float(obj)
    elif isinstance(obj, date): return str(obj)
    # return super(jsonEncoder, self).default(obj)
    return JSONEncoder.default(self, obj)


class dbObj:
  conn = None
  cur = None
  def __init__(self, privilege):
    try:
      self.conn = connect("dbname='granjalibre' user='%s_user'" % privilege)
      # self.conn = connect(dbname)
      self.cur = self.conn.cursor()
    except Exception as e:
      raise Exception("db conn error: " + str(e))
  def rollback(self):
    self.conn.rollback()
  def execute(self, sql, args=None):
    try:
      self.cur.execute(sql, args)
    except Exception as e:
      raise Exception("db exec error: " + str(e))
  def setSearchPath(self, schema):
    self.execute("SET search_path TO %s;", (schema, ))
  def getRow(self, sql, args=None):
    self.execute(sql, args)
    return self.cur.fetchone()
  def getRows(self, sql, args=None):
    self.execute(sql, args)
    return self.cur.fetchall()
  def getRowsAssoc(self, sql, args=None):
    self.execute(sql, args)
    cols, tmp = self.cur.description, self.cur.fetchall()
    cols_len = len(cols)
    #return [{cols[i][0]:row[i] for i in range(cols_len)} for row in tmp]
    rows = []
    for line in tmp:
      row = {}
      for i in range(0, cols_len, 1): row[cols[i][0]] = line[i]
      rows.append(row)
    return rows
  def getDescription(self):
    return [cn[0] for cn in self.cur.description]
  def __del__(self):
    self.conn.commit()
    self.cur.close()
    self.conn.close()


#def create_activity(id):
#  call("psql granjalibre -v activity='%i' -f %s" % (id, 'py/db_reproduction.sql'), shell=True)
#  call("psql granjalibre -v activity='%i' -f %s" % (id, 'py/db_production.sql'), shell=True)


def wrapper(func, rq, dump=False):
  try:
    obj = dbObj(rq['privilege'] if 'privilege' in rq else 'select')
    obj.setSearchPath(rq['schema'] if 'schema' in rq else 'public')
    rs = func(obj, rq)
  except Exception as e:
    try:
      obj.rollback()
    except:
      pass
    raise e
  finally:
    try:
      del obj
    except:
      pass
  return dumps(rs, cls=jsonEncoder) if dump else rs
