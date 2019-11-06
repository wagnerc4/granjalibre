#!/usr/bin/env node
// Set Rows
////////////////////////// utilities ////////////////////////////
String.leftPad=function(val,size,ch){
  var result=new String(val);
  while(result.length<size){result=ch+result;}
  return result;
};

Date.prototype.toLocal = function() {
  return String.leftPad(this.getDate(), 2, '0') + '/' +
         String.leftPad(this.getMonth() + 1, 2, '0') + '/' +
         this.getFullYear();
};

global.sqlToLocal = function(str) { return str?str.replace(/^(\d{4})\-(\d{2})\-(\d{2})/,'$3/$2/$1'):''; };

global.addDays = function(date, days) {
  date.setDate(date.getDate() + parseInt(days, 10));
  return date;
};

global.getDays = function(diff) { return Math.floor(diff/86400000); };

global.formatCurrency = function(num, dec) {
  if(!num || isNaN(num)) return;
  sign = (num == (num = Math.abs(num)));
  num = num.toFixed(dec).toString();
  for (var i=num.length-(4+(dec?dec:-1)); i>0; i=i-3)
    num = num.substring(0,i)+','+num.substring(i);
  return ((sign?'':'-') + num);
};
//////////////////////////////////////////////////////////////////

var fs = require('fs'),
    JSONfn = require('/usr/lib/node_modules/json-fn'),
    specFile = '/dev/stdin';

fs.readFile(specFile, 'utf8', function(err, text) {
  if (err) throw err;
  var defs = JSONfn.parse(text.replace(/_\[.+/, '')),
      body = JSONfn.parse(text.replace(/.+\]_/, '')),
      rows = JSONfn.stringify(set_rows(defs, body));
  process.stdout.write(rows);
});


function set_rows(defs, body) {
  var raws = [], rows = [], last = [[]], values = {},
      foot = defs[defs.length - 1] instanceof Array?defs.pop():[];
  for (var k in body) {
    var raw=[], row=[];
    for (var i=0; i<defs.length; ++i) {
      raw[i] = defs[i].value?defs[i].value(body[k]):body[k][i];
      if (defs[i].foot && raw[i]) {
        if (!values[i]) values[i] = [];
        values[i].push(raw[i]);
      }
      if (defs[i].class) {
        if (defs[i].class != "no_format") {
          if (defs[i].class == 'image') {
            row[i] = '<img src="images/' + raw[i] + '" />';
          } else {
            // TODO red_empty
            // row[i] = String(raw[i] || '').replace(/([^,]+)/g, '<span class="' + defs[i].class + '">$1</span>');
            row[i] = '<span class="'+defs[i].class+'">' +
                       String(raw[i] || '').replace(/\,/g,
                                                    '</span>, <span class="'+defs[i].class+'">') +
                     '</span>';
          }
        } else {
          row[i] = raw[i];
        }
      } else {
        if (typeof(raw[i]) == "number"){
          row[i] = formatCurrency(raw[i], 2);
        } else if (typeof(raw[i]) == "string") {
          row[i] = raw[i]?raw[i].replace(/\\\\/g, '<br />'):'';
        } else {
          row[i] = raw[i];
        }
      }
      if (typeof(row[i])=="number" && row[i]<0) {
        row[i] = '<span style="background:red;">' + row[i] + '</span>';
      }
    }
    raws.push(raw);
    rows.push(row);
  }
  for (var i=0; i<defs.length; ++i) {
    if (defs[i].foot) {
      if (!values[i]) values[i] = [0];
      switch(defs[i].foot) {
        case "sum": last[0][i] = values[i].reduce(function(a,b){ return a + b; }); break;
        case "avg": last[0][i] = values[i].reduce(function(a,b){ return a + b; }) / values[i].length; break;
        case "min": last[0][i] = values[i].reduce(function(a,b){ return (a < b)?a:b; }); break;
        case "max": last[0][i] = values[i].reduce(function(a,b){ return (a > b)?a:b; }); break;
        case "count": last[0][i] = values[i].length; break;
        default: last[0][i] = defs[i].foot;
      }
      last[0][i] = formatCurrency(last[0][i], (defs[i].foot == "count")?0:2);
    } else {
      last[0][i] = "";
    }
  }
  for (var i in foot) {
    var row=[];
    for (var j in foot[i]) {
      row[j] = foot[i][j] instanceof Object?formatCurrency(foot[i][j](raws), 2):foot[i][j];
    }
    last.push(row);
  }
  return {"body":rows, "foot":last};
}
