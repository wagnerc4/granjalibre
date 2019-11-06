from psycopg2 import connect
from json import JSONEncoder, dumps
from decimal import Decimal
from datetime import date


class jsonEncoder(JSONEncoder):
  def default(self, obj):
    if isinstance(obj, Decimal): return float(obj)
    elif isinstance(obj, date): return str(obj)
    return JSONEncoder.default(self, obj)


class dbObj:
  conn = None
  cur = None
  def __init__(self, privilege):
    try:
      self.conn = connect("dbname='granjalibre' user='%s_user'" % privilege)
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
    cols, rows = self.cur.description, self.cur.fetchall()
    return [{cols[i][0]:row[i] for i in range(len(cols))} for row in rows]
  def getDescription(self):
    return [cn[0] for cn in self.cur.description]
  def __del__(self):
    self.conn.commit()
    self.cur.close()
    self.conn.close()


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
