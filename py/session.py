from time import time
from json import dumps, loads
from hashlib import md5
from random import choice
from string import ascii_letters, digits


class Session:
  token = None
  timeout = 10800
  def __init__(self, token=None):
    self.token = token
  def insert(self, dbObj, rq):
    password = ''.join(choice(ascii_letters + digits) for n in range(30))
    token = md5(password.encode('utf-8')).hexdigest()
    dbObj.execute("INSERT INTO sessions VALUES (%s, %s, %s)",
                  (token, time(), dumps(rq['session_data'])))
    return token
  def select(self, dbObj, rq):
    row = dbObj.getRow("SELECT ts, data FROM sessions WHERE id=%s", (self.token, ))
    if not row or row[0] < (time() - self.timeout):
      raise Exception("session error: Session expired!")
    else:
      dbObj.execute("UPDATE sessions SET ts=%s WHERE id=%s", (time(), self.token))
    return loads(row[1])
  def delete(self, dbObj, rq):
    dbObj.execute("DELETE FROM sessions WHERE id=%s", (self.token, ))
    dbObj.execute("DELETE FROM sessions WHERE ts<%s", (time() - self.timeout, ))
