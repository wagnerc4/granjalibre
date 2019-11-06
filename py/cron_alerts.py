#!/usr/bin/env python3
from sys import argv
from pytz import timezone
from datetime import datetime
from db import wrapper


cr_tz = timezone('America/Costa_Rica')


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


def check_alerts(dbObj, rq):
  cron_id = rq['cron_id']
  date = datetime.now(cr_tz).strftime("%Y-%m-%d")
  alerts = dbObj.getRows("""
    SELECT id, type,
           (SELECT query FROM querys WHERE id=a.query_id),
           (SELECT ARRAY_AGG(target) FROM alerts_targets WHERE alert_id=a.id)
    FROM alerts a
    WHERE cron_id=%s AND
          NOT EXISTS(SELECT id FROM alerts_done WHERE id=a.id AND last_day=%s);""",(cron_id,date))
  for alert in alerts:
    for target in alert[3]:
      try:
        result = dbObj.getRow(alert[2].replace('\\\\', '\n'), {"target":target})
        if alert[1] == "sms" and result:
          send_sms(target.replace('+506', ''), result[0])
          dbObj.execute("INSERT INTO alerts_done VALUES(%s, %s);", (alert[0], date))
        if alert[1] == "calendar":
          dbObj.execute("INSERT INTO alerts_done VALUES(%s, %s);", (alert[0], date))
      except Exception as e:
        send_sms('88474554', 'alert error -> ' + str(e)[:130])


wrapper(check_alerts, {"schema":"activity_2", "privilege":"update", "cron_id":argv[1]})
