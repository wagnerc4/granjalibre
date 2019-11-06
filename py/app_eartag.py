#! /usr/bin/env python
from httplib import HTTPConnection
from urllib import urlencode
from json import loads, dumps
from time import sleep
from datetime import datetime
from pytz import timezone
from sqlite3 import connect
import serial


url = "173.255.217.7"
activity = "activity_1"

db_file = "/root/temperatures.db"

ser = serial.Serial('/dev/ttyAMA0')
ser.open()


"""
CREATE TABLE temperatures (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  eartag CHAR(10) NOT NULL,
  temperature NUMERIC NOT NULL,
  ts INTEGER NOT NULL,
  sync INTEGER NOT NULL
);
"""


class dbObj:
  conn = None
  cur = None
  def __init__(self, dbname):
    try:
      self.conn = connect(dbname)
      self.cur = self.conn.cursor()
    except Exception as e:
      raise Exception("db conn error: " + str(e))
  def execute(self, sql, args=None):
    try:
      self.cur.execute(sql, args or ())
    except Exception as e:
      self.conn.rollback()
      raise Exception("db exec error: " + str(e))
  def getRow(self, sql, args=None):
    self.execute(sql, args)
    return self.cur.fetchone()
  def getRows(self, sql, args=None):
    self.execute(sql, args)
    return self.cur.fetchall()
  def __del__(self):
    self.conn.commit()
    self.cur.close()
    self.conn.close()


def read_serial():
  iw = ser.inWaiting()
  return ser.read(iw) if iw > 0 else ""


def to_celsius(s):
  return round((float(s)-32.0)*(5.0/9.0), 2)


def insert_temperatures(dbObj, temperatures):
  for temperature in temperatures:
    dbObj.execute("INSERT INTO temperatures VALUES(NULL, ?, ?, ?, 0);",
      (temperature[0], temperature[1],
       datetime.now(timezone('America/Costa_Rica')).strftime("%s")))


def sync_temperatures(dbObj):
  rows = dbObj.getRows("""
    SELECT id, eartag, ts, temperature FROM temperatures
    WHERE sync=0 AND ts>(SELECT IFNULL(MAX(ts),0)
                         FROM temperatures WHERE sync=1);""")
  conn = HTTPConnection(url)
  conn.request('POST', '/app2/sync_temperatures',
               urlencode({"activity":activity, "temperatures":dumps(rows)}),
               {"Accept":"text/plain",
                "Content-type":"application/x-www-form-urlencoded"})
  rs = conn.getresponse()
  if rs.status == 500:
    raise Exception("server error: " + rs.read())
  else:
    ids = loads(rs.read())
    if len(ids):
      dbObj.execute("""UPDATE temperatures SET sync=1
                       WHERE id IN (%s);""" % str(ids)[1:-1])
  conn.close()


while True:
  try:
    db = dbObj(db_file)
    rows = filter(None, read_serial().split(";"))
    temperatures = [(row[2:12], to_celsius(row[13:18])) for row in rows]
    print temperatures
    if len(temperatures):
      insert_temperatures(db, temperatures)
      sync_temperatures(db)
  except Exception as e:
    print str(e)
  finally:
    try:
      del obj
    except:
      pass
  sleep(60)



## server.py ##
#from bottle import route, request, response

#def sync_temperatures(dbObj, rq):
#  ids, rows = [], loads(rq['temperatures'])
#  for row in rows:  # id, eartag, ts, temperature
#    _id = dbObj.getRow("""INSERT INTO ev_temperature VALUES(%s,
#                            (SELECT id FROM animals_eartags WHERE eartag=%s),
#                             %s, 0, %s) RETURNING id;""", tuple(row))
#    ids.append(_id[0])
#  return ids

#@route('/app2/sync_temperatures', method='POST')
#def sync_temperatures_handler():
#  response.set_header('Access-Control-Allow-Origin', '*')
#  try:
#    rs = sync_temperatures(dbObj, request.forms)
#  except Exception as e:
#    response.status = 500
#    rs = "sync error -> " + str(e)
#  return rs



### raspberry pi configuration ###
"""
dpkg-reconfigure locales "en_US.UTF-8"
dpkg-reconfigure tzdata

apt-get remove vim-common aptitude-common
apt-get install firmware-atheros wireless-tools wpasupplicant
apt-get install emacs-nox screen chkconfig htop sqlite3
apt-get install python-minimal python-serial python-tz python-pysqlite2

## serial ##
/boot/cmdline.txt
dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait logo.nologo

## gpio ##
apt-get install gcc make python-dev git-core

wget http://www.airspayce.com/mikem/bcm2835/bcm2835-1.39.tar.gz
tar zxvf bcm2835-1.39.tar.gz
cd bcm2835-1.39/
./configure
make
make check
make install

cd ~
git clone https://github.com/klobyone/PyBCM2835.git
cd PyBCM2835/
python setup.py build
python setup.py install

## time module ##
apt-get install i2c-tools

/etc/modules
  i2c-bcm2708
  i2c-dev
  rtc-ds1307
/etc/modprobe.d/raspi-blacklist.conf
  # blacklist spi-bcm2708
  # blacklist i2c-bcm2708

reboot

# /root/i2c_p5.py
# i2cdetect -y 0
# echo ds1307 0x68 > /sys/class/i2c-adapter/i2c-0/new_device
# hwclock --set --date="2013-05-17 08:00:00"
# hwclock -r  # read from rtc
# hwclock -s  # sync to pc

/etc/rc.local
  /root/ds1307_p5.py
  /root/eartag.py &
"""
