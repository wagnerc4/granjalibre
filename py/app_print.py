from re import sub
from json import loads
from datetime import datetime, timedelta
from pytz import timezone
from xhtml2pdf import pisa
from io import StringIO, BytesIO

#from email.mime.application import MIMEApplication
#from email.mime.multipart import MIMEMultipart
#from email.mime.text import MIMEText
#from smtplib import SMTP

from py.app_forms_reproduction import repro_resumen
from py.app_settings import select_query_saved
from py.utilities import unescape, thous
from py.utilities_js import context


cr_tz = timezone('America/Costa_Rica')  # datetime.now(cr_tz)


def set_pdf(header, content):
  html = '<html><head>' + \
         '<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />' + \
         '<style>.table {border-collapse: collapse; border-style: hidden;}</style>' + \
         '<style>.table th {border-top:1px solid #ccc; border-bottom:1px solid #ccc;}</style>' + \
         '<style>.table th, .table td {text-align:right; vertical-align:top;}</style>' + \
         '<style>.table th:first-child, .table td:first-child {text-align:left}</style>' + \
         '</head><body>' + \
         header + \
         content + \
         "Fecha (hora): %s" % datetime.now(cr_tz).strftime("%Y-%m-%d (%H:%M:%S)") + \
         '</body></html>'
  #resultFile = open('/home/wagner/doc.pdf', 'w+b')
  #pisaStatus = pisa.CreatePDF(html, dest=resultFile)
  #resultFile.close()
  pdf = BytesIO()
  status = pisa.CreatePDF(StringIO(html), dest=pdf)
  if status.err:
    raise Exception('Error en impresion pdf!')
  return pdf.getvalue()


def print_header(dbObj, rq):
  activity = dbObj.getRow("SELECT activity FROM public.activities WHERE id=%s;",
                          (sub('activity_', '', rq['schema']), ))[0]
  header = '<table><tr><td style="width:550px; vertical-align:middle;">' + \
           '<h1 style="font-size:300%">Granja Libre - ' + unescape(activity) + '</h1>' + \
           '</td><td style="width:150px;">' + \
           '<img src="../logos/vaca.png" />' + \
           '</td></tr></table>'
  return [header]


def print_resumen(dbObj, rq):
  data = select_query_saved(dbObj, rq)
  defs = loads(data['defs'])
  table = "<table class='table table-striped' style='font-size:150%'>"
  table += "  <caption><h2>%s</h2>%s%s</caption>" % (data['title'],
                                                       '-' + rq['d1'] if 'd1' in rq else '',
                                                       ',' + rq['d2'] if 'd2' in rq else '')
  table += "  <thead>"
  table += "    <tr><th>%s</th></tr>" % '</th><th>'.join([d['head'] for d in defs])
  table += "  </thead>"
  table += "  <tbody>"
  # last=[[]], sums=[], mins=[], maxs=[]
  for row in data['rows']:
    tmp = []
    for i in range(len(defs)):
      tmp.append(context.eval(defs[i]['value'])(row) if 'value' in defs[i] else row[i])
      tmp[i] = thous(tmp[i]) if isinstance(tmp[i], float) else str(tmp[i])
    table += "  <tr><td>%s</td></tr>" % '</td><td>'.join(tmp)
  table += "  </tbody>"
  # table += "  <tfoot></tfoot>"
  table += "</table>"
  return [table]


#def print_pdf(dbObj, rq):
#  return set_pdf(print_header(dbObj, rq)[0], print_resumen(dbObj, rq)[0])


#def print_email(dbObj, rq):
#  email_oficina = dbObj.getRow("""
#     SELECT (SELECT email_oficina FROM personas WHERE id=documentos.persona_id) AS persona
#     FROM documentos WHERE id=%s""", (rq['a_id'], ))[0]
#  if not email_oficina:
#    raise Exception('Email oficina no esta definido!')
#  activity = dbObj.getRow("SELECT activity FROM public.activities WHERE id=%s;",
#                          (sub('activity_', '', rq['schema']), ))[0]
#  pdf_data = print_pdf(dbObj, rq)
#  msg = MIMEMultipart()
#  msg['Subject'] = '%s' % activity
#  msg['From'] = 'contabilidad@granjalibre.com'
#  msg['To'] = email_oficina
#  msg.attach(MIMEText('''
#***  No conteste a este mensaje ya que no recibirá ninguna respuesta.  ***
#Muchas Gracias.
#  ''', 'plain'))
#  pdf = MIMEApplication(pdf_data, _subtype='pdf')
#  pdf.add_header('Content-Disposition', 'attachment', filename='fct.pdf')
#  msg.attach(pdf)
#  s = SMTP('localhost')
#  s.send_message(msg)
#  s.quit()


################################## CUSTOM ##################################
def print_repro_resumen(dbObj, rq):
  rows = repro_resumen(dbObj, rq)
  table = "<table style='border-collapse: collapse; font-size:200%'>"
  table += "  <caption>"
  table += "    <strong>Resumen Reproduccion</strong> - %s, %s" % (rq['d1'], rq['d2'])
  table += "  </caption>"
  table += "  <thead>"
  table += "    <tr><th width='250'></th>"
  table += "        <th width='125'>Paridad</th>"
  table += "        <th width='150'>Totales</th></tr>"
  table += "  </thead>"
  table += "  <tbody>"
  for row in rows:
    table += "<tr><td style='text-align:%s;'>%s</td></tr>" % \
             ('left' if 'strong' in row[0] else 'right',
              "</td><td style='text-align: right;'>".join([str(r) for r in row]))
  table += "  </tbody>"
  table += "</table>"
  return [table]
