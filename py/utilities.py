# coding=utf-8
from re import sub, search
from json import JSONEncoder
from decimal import Decimal
from datetime import date, datetime


class jsonEncoder(JSONEncoder):
  def default(self, obj):
    if isinstance(obj, Decimal): return float(obj)
    elif isinstance(obj, date): return str(obj)
    # return super(jsonEncoder, self).default(obj)
    return JSONEncoder.default(self, obj)


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


def thous(x):
  return sub(r'(\d{3})(?=\d)', r'\1,', str(x)[::-1])[::-1]


def sql_local(x):
  return sub(r'^(\d{4})\-(\d{2})\-(\d{2})', r'\3-\2-\1', x)


#def sql_local(x):
#  return datetime.strptime(x, "%Y-%m-%d").strftime("%d-%m-%Y")

def sql_ts(x):
  return datetime.strptime(x, "%Y-%m-%d").strftime("%s")

#def sql_lote(x):
#  return datetime.strptime(x, "%Y-%m-%d").strftime("%j")


'''
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def send_sms(phone, msg):
  url = "https://bulksms.vsms.net/eapi/submission/send_sms/2/2.0"
  values = {'username':'wagnerc4', 'password':'xxx',
            'msisdn':"{0}{1}".format(506, phone), 'message':msg}
  rs = urlopen(Request(url, urlencode(values).encode('ascii')))
  result = rs.read().decode('utf-8').split('|')
  status_code = result[0]
  status_string = result[1]
  if status_code != '0':
    raise Exception("SMS error: %s: %s" % (status_code, status_string))
  else:
    return result[2]  # batch ID (message sent)
'''
