#!/usr/bin/env python3
from time import sleep
from subprocess import call

# call("psql granjalibre -f db_main_tables.sql", shell=True)

for i in range(1, 7, 1):
  print(i)
  sleep(1)
  # call("psql granjalibre -v activity='%s' -f db_ajustes.sql" % i, shell=True)
  # call("psql granjalibre -v activity='%s' -f db_production_tables.sql" % i, shell=True)
  # call("psql granjalibre -v activity='%s' -f db_reproduction_tables.sql" % i, shell=True)
  call("psql granjalibre -v activity='%s' -f db_update.sql" % i, shell=True)
  call("psql granjalibre -v activity='%s' -f db_users.sql" % i, shell=True)
