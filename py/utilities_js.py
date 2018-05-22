# 'formatCurrency': lambda n, d: thous(round(n, d)),
# 'getDays':  lambda x: floor(x/86400000),
from js2py import eval_js, EvalJs


eval_js("""
String.leftPad=function(val,size,ch){
  var result=new String(val);
  while(result.length<size){result=ch+result;}
  return result;
};

Date.prototype.toSql = function() {
  return this.getFullYear() + '-' +
         String.leftPad(this.getMonth() + 1, 2, '0') + '-' +
         String.leftPad(this.getDate(), 2, '0');
};
""")


context = EvalJs({
'getDays': eval_js("function getDays(diff) { return Math.floor(diff/86400000); }"),
'addDays': eval_js("""
function addDays(date, days) {
  date.setDate(date.getDate() + parseInt(days, 10));
  return date;
}
"""),
'formatCurrency': eval_js("""
function formatCurrency(num, dec) {
  if(!num || isNaN(num)) return;
  sign = (num == (num = Math.abs(num)));
  num = num.toFixed(dec).toString();
  for (var i=num.length-(4+(dec?dec:-1)); i>0; i=i-3)
    num = num.substring(0,i)+','+num.substring(i);
  return ((sign?'':'-') + num);
}
"""),
'eventsDic': {
  "ev_entry_female": {"name":"ingreso hembra", "cols":["raza", "camada", "nacimiento", "pedigree"]},
  "ev_entry_male": {"name":"ingreso macho", "cols":["raza", "camada", "nacimiento", "pedigree"]},
  "ev_entry_semen": {"name":"ingreso semen", "cols":["raza", "camada", "nacimiento", "pedigree"]},
  "ev_sale_semen": {"name":"salida semen", "cols":[]},
  "ev_sale": {"name":"salida", "cols":["causa"]},
  "ev_heat": {"name":"celo sin servicio", "cols":["lordosis"]},
  "ev_service": {"name":"servicio", "cols":["padrote", "cubriciones",
                                            "lordosis", "calidad"]},
  "ev_check_pos": {"name":"diagnostico +", "cols":["examen"]},
  "ev_check_neg": {"name":"diagnostico -", "cols":["examen"]},
  "ev_abortion": {"name":"aborto", "cols":["inducido"]},
  "ev_farrow": {"name":"parto", "cols":["camada", "machos", "hembras", "peso",
                            "muertos", "momias", "hernias", "criptorquideos",
                            "distocia", "retencion", "inducido", "asistido"]},
  "ev_death": {"name":"baja", "cols":["causa", "animales"]},
  "ev_foster": {"name":"adopcion -", "cols":["hacia", "animales", "peso"]},
  "ev_adoption": {"name":"adopcion +", "cols":["desde", "animales", "peso"]},
  "ev_partial_wean": {"name":"destete parcial", "cols":["animales", "peso"]},
  "ev_wean": {"name":"destete", "cols":["animales", "peso"]},
  "ev_semen": {"name":"estraccion", "cols":["volumen", "concentracion",
                                            "motilidad", "dosis"]},
  "ev_ubication": {"name":"ubicacion", "cols":["ubicacion"]},
  "ev_feed": {"name":"alimentacion", "cols":["peso"]},
  "ev_condition": {"name":"condicion", "cols":["condicion", "peso", "grasa"]},
  "ev_milk": {"name":"leche", "cols":["peso", "calidad"]},
  "ev_dry": {"name":"secado", "cols":[]},
  "ev_temperature": {"name":"temperatura", "cols":["temperatura"]},
  "ev_treatment": {"name":"tratamiento", "cols":["medicamento", "dosis",
                                           "frecuencia", "dias", "ruta"]},
  "ev_palpation": {"name":"palpacion", "cols":["palpacion"]},
  "ev_note": {"name":"nota", "cols":["nota"]}
}
})
