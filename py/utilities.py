# coding=utf-8
from re import sub
from math import floor
from decimal import Decimal
from pytz import timezone
from datetime import date, datetime, timedelta
from py.simpleeval import EvalWithCompoundTypes as SimpleEval


cr_tz = timezone('America/Costa_Rica')


mapping = {
  "&#225;": "á",
  "&#233;": "é",
  "&#237;": "í",
  "&#243;": "ó",
  "&#250;": "ú",
  "&#241;": "ñ"
}


def unescape(s):
  return sub(r'(&#\d{3};)', lambda x: mapping[x.group()], s)


def get_days(x):
  return floor(x/86400)


def add_days(x, y):
  # x = x if isinstance(x, date) else datetime.strptime(x, "%Y-%m-%d")
  return x + timedelta(days=y)


def sql_ts(x):
  return datetime.strptime(x, "%Y-%m-%d").strftime("%s")


#def sql_lote(x):
#  return datetime.strptime(x, "%Y-%m-%d").strftime("%j")


def sql_local(x):
  return datetime.strptime(x, "%Y-%m-%d").strftime("%d-%m-%Y")


def ts_sql(x):
  return datetime.fromtimestamp(x).strftime("%Y-%m-%d")


def ts_week(x):
  return int(datetime.fromtimestamp(x).strftime("%W"))


def now_ts():
  return int(datetime.now(cr_tz).strftime("%s"))


def thous(x):
  return sub(r'(\d{3})(?=\d)', r'\1,', str(x)[::-1])[::-1]


# def format_currency(x, y):
#   return thous(round(x, y))


def set_cell(fn, row):
  s = SimpleEval()
  s.names = {"r":row}
  s.functions = {"str":str, "int":int, "float":float, "sum":sum, "enumerate":enumerate,
                 "get_days":get_days, "add_days":add_days, "sql_local":sql_local,
                 "ts_sql":ts_sql, "ts_week":ts_week, "now_ts":now_ts}
  try:
    return s.eval(fn)
  except Exception as e:
    return fn


'''
from simpleeval import simple_eval

def safe_lambda(x, y):
  return lambda z: simple_eval(y, names={x:z})

list(filter(safe_lambda('x', 'x > 2'), [1, 2, 3, 4, 5, 6]))

f = simple_eval("sum(list(map(safe_lambda('x', 'x[1] if x[0] == 1 else 0'), r)))",
                names={"r":[[1, 2], [1, 3], [2, 4], [2, 5]]},
                functions={"sum":sum, "list":list, "map":map, "safe_lambda":safe_lambda})
'''
