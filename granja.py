#!/usr/bin/env python3
from bottle import app, run, route, static_file, template, request, response
from py.db import wrapper
from py.session import Session
from py.app_forms_calendar import *
from py.app_forms_parameters import *
from py.app_forms_reproduction import *
from py.app_forms_production import *
from py.app_settings import *
from py.utilities import unescape


def get_activity_id_name(dbObj, rq):
  return tuple(dbObj.getRow("SELECT id, activity FROM public.activities WHERE url=%s;",
                            (rq['url'], )))


################## PATHS ###################
@route('/<activity>/<directory:re:.+>/<filename:re:.+>')
def paths_handler(activity, directory, filename):
  return static_file(filename, directory)


#################### MAIN ####################
@route('/<activity>/', template='index.html')
def home_handler(activity):
  session = Session()
  schema_id, name = wrapper(get_activity_id_name, {"url":activity})
  return dict(rs={"app":"login", "unescape":unescape, "path":activity, "header":name,
                  "token":wrapper(session.insert, {"session_data":{}})})


@route('/<activity>/', template='index.html', method='POST')
def admin_handler(activity):
  session = Session(request.forms['token'])
  try:
    wrapper(session.select, {})
    wrapper(session.delete, {})
    schema_id, name = wrapper(get_activity_id_name, {"url":activity})
    request.forms['schema'] = 'activity_%s' % schema_id
    data = wrapper(worker_login, request.forms)
    session_data = {"schema":'activity_%s' % schema_id, "privilege":data["privilege"],
                    "worker_id":data["id"], "worker":data["worker"]}
    template_data = {"app":"main", "unescape":unescape, "path":activity,
      "token": wrapper(session.insert, {"session_data":session_data}),
      "worker":data["worker"], "privilege":data["privilege"],
      "header":name,  # "print_header":data["print_header"], "logo":data["logo"],
      "resumens_data": wrapper(get_resumens_data, session_data, True),
      "menus": wrapper(get_menus, session_data), "files": wrapper(get_files, session_data)}
  except Exception as e:
    template_data = {"app":"error", "error": str(e), "unescape":unescape,
                     "token":"", "header":name}
  return dict(rs=template_data)


@route('/<activity>/db', method='POST')
def db_handler(activity):
  session = Session(request.forms['token'])
  try:
    request.forms.update(wrapper(session.select, {}))
    rs = wrapper(globals()[request.forms['action']], request.forms, True)
  except Exception as e:
    response.status = 500
    rs = "db error -> " + str(e)
  return rs


'''
@route('/<activity>/pdf', method='POST')
def pdf_handler(activity):
  session = Session(request.forms['token'])
  try:
    request.forms.update(wrapper(session.select, {}))
    rs = wrapper(print_pdf, request.forms, False)
    response.content_type = 'application/pdf'
  except Exception as e:
    response.status = 500
    rs = "db error -> " + str(e)
  return rs


@route('/<activity>/sms', method='POST')
def sms_handler(activity):
  response.set_header('Access-Control-Allow-Origin', '*')
  try:
    schema_id, name = wrapper(get_activity_id_name, {"url":activity})
    request.forms['privilege'] = 'select'
    request.forms['schema'] = 'activity_%s' % schema_id
    rs = wrapper(response_sms, request.forms, True)
  except Exception as e:
    rs = "sms error -> " + str(e)
  return rs


@route('/<activity>/sync_temperatures', method='POST')
def sync_temperatures_handler(activity):
  response.set_header('Access-Control-Allow-Origin', '*')
  try:
    schema_id, name = wrapper(get_activity_id_name, {"url":activity})
    request.forms['privilege'] = 'select'
    request.forms['schema'] = 'activity_%s' % schema_id
    rs = wrapper(sync_temperatures, request.forms, True)
  except Exception as e:
    response.status = 500
    rs = "sync error -> " + str(e)
  return rs
'''


###########################################
if __name__ == "__main__":
  run(host='127.0.0.1', port=9005, reloader=True)
else:
  application = app()
