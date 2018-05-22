#!/usr/bin/env python3
from sys import path
path.append('/var/www/granja')  # /home/wagner/tmp/paginas/granja

from re import sub
from io import BytesIO, BufferedReader
from db import wrapper
from app_print import set_pdf, print_header, print_resumen, print_repro_resumen

from telegram import (KeyboardButton, ReplyKeyboardMarkup, ReplyKeyboardRemove)
from telegram.ext import (Updater, CommandHandler, MessageHandler, Filters)

SCHEMA = None
commands = {'reproduccion': {'description': 'resumen', 'code':''},
            'produccion': {'description': 'inventario',
                            'code':'resumens_1_produ_stock'},
            'improductivas': {'description': 'inventario',
                               'code':'resumens_1_repro_stock_unproductives'},
            'servidas': {'description': 'inventario',
                          'code':'resumens_1_repro_stock_services'},
            'productivas': {'description': 'inventario',
                             'code':'resumens_1_repro_stock_productives'},
            'camadas': {'description': 'inventario',
                         'code':'resumens_1_repro_stock_litters'}}


def get_help_text():
  help_text = ["/%s: %s" % (key, commands[key]['description']) for key in commands]
  return 'Comandos disponibles: \n' + '\n'.join(help_text)


def get_user_id(dbObj, rq):
  user = dbObj.getRow('SELECT id FROM workers WHERE bot=%s;', (rq['uid'], ))
  return -1 if not user else user[0]


def set_user_id(dbObj, rq):
  user = dbObj.getRow('UPDATE workers SET bot=%s WHERE phone=%s RETURNING id;',
                      (rq['uid'],  '+' + sub('\D', '', rq['phone'])))
  return -1 if not user else user[0]


def handle_commands(bot, update, args):
  chat_id = update.message.chat.id
  command = update.message.text[1::]
  bot.send_chat_action(chat_id, 'typing')
  user_id = wrapper(get_user_id, {"schema":SCHEMA, "privilege":"select",
                                  "uid":update.message.from_user.id})
  if user_id < 0:
    contact_keyboard = KeyboardButton(text="enviar_contacto", request_contact=True)
    reply_markup = ReplyKeyboardMarkup([[contact_keyboard]])
    bot.send_message(chat_id=chat_id, text="Acceso no permitido!", reply_markup=reply_markup)
  else:
    header = wrapper(print_header, {"schema":SCHEMA, "privilege":"select", "user_id":user_id})
    if 'reproduccion' in command:
      if len(args) < 1:
        update.message.reply_text('Mantener presionado el comando y luego escribir ' + \
                                  'fecha inicio y fecha final')
      elif len(args) != 2:
        update.message.reply_text('Escribir fecha inicial y fecha final.')
      else:
        d1, d2 = tuple(args)
        if sub('\d{4}\-\d{2}\-\d{2}', '', d1) != '':
          update.message.reply_text('Fecha inicial mal escrita. ej. yyyy-mm-dd')
        elif sub('\d{4}\-\d{2}\-\d{2}', '', d2) != '':
          update.message.reply_text('Fecha final mal escrita. ej. yyyy-mm-dd')
        else:
          content = wrapper(print_repro_resumen, {"schema":SCHEMA, "privilege":"select",
                                                  "d1":d1, "d2":d2})
          pdf = BytesIO(set_pdf(header[0], content[0]))
          pdf.name = 'doc.pdf'
          bot.send_document(chat_id, BufferedReader(pdf))
    else:
      content = wrapper(print_resumen, {"schema":SCHEMA, "privilege":"select",
                                        "user_id":user_id, "code":commands[command]['code']})
      pdf = BytesIO(set_pdf(header[0], content[0]))
      pdf.name = 'doc.pdf'
      bot.send_document(chat_id, BufferedReader(pdf))


def handle_contact(bot, update):
  chat_id = update.message.chat.id
  bot.send_chat_action(chat_id, 'typing')
  user_id = wrapper(set_user_id, {"schema":SCHEMA, "privilege":"update",
                                  "uid":update.message.contact.user_id,
                                  "phone":update.message.contact.phone_number})
  if user_id < 0:
    bot.send_message(chat_id, "Error en verificacion contacto, telefono no autorizado!")
  else:
    bot.send_message(chat_id, "Verificacion contacto completa!")
    bot.send_message(chat_id, get_help_text(), reply_markup=ReplyKeyboardRemove())


def help(bot, update):
  update.message.reply_text(get_help_text())


def error(bot, update, error):
  update.message.reply_text('Error: %s' % error)


def main(schema, token):
  global SCHEMA
  SCHEMA = schema
  updater = Updater(token)
  dp = updater.dispatcher
  dp.add_handler(CommandHandler(commands.keys(), handle_commands, pass_args=True))
  dp.add_handler(MessageHandler(Filters.contact, handle_contact))
  dp.add_handler(MessageHandler(Filters.command, help))
  dp.add_handler(MessageHandler(Filters.text, help))
  dp.add_error_handler(error)
  updater.start_polling()
  updater.idle()


# if __name__ == '__main__':
#   main('activity_1', 'TOKEN')
