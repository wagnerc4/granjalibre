// string functions
String.leftPad=function(val,size,ch){
  var result=new String(val);
  while(result.length<size){result=ch+result;}
  return result;
};

String.rightPad=function(val,size,ch){
  var result=new String(val);
  while(result.length<size){result=result+ch;}
  return result;
};

String.prototype.escape = function() {
  return this.replace(/[áéíóúñ\n]/g, function(c) { return "&#" + c.charCodeAt(0) + ";"; });
};

function stripHtml(str) { return str.replace(/<\/?\w(?:[^"'>]|"[^"]*"|'[^']*')*>/g, ''); }

function upperFirst(str) { return str.charAt(0).toUpperCase() + str.substring(1); }

// date functions
Date.prototype.toSql = function() {
  return this.getFullYear() + '-' +
         String.leftPad(this.getMonth() + 1, 2, '0') + '-' +
         String.leftPad(this.getDate(), 2, '0');
};

Date.prototype.toLocal = function() {
  return String.leftPad(this.getDate(), 2, '0') + '/' +
         String.leftPad(this.getMonth() + 1, 2, '0') + '/' +
         this.getFullYear();
};

Date.prototype.toHour = function() { return String(this).match(/(\d{2})\:(\d{2})\:(\d{2})/)[0]; };

function sqlToLocal(str) { return str?str.replace(/^(\d{4})\-(\d{2})\-(\d{2})/,'$3/$2/$1'):''; }

function localToSql(str) { return str?str.replace(/^(\d{2})\/(\d{2})\/(\d{4})/,'$3-$2-$1'):''; }

Date.prototype.getWeek = function (dowOffset) {
  dowOffset = typeof(dowOffset) == 'int' ? dowOffset : 0;
  var newYear = new Date(this.getFullYear(),0,1);
  var day = newYear.getDay() - dowOffset;
  day = (day >= 0 ? day : day + 7);
  var daynum = Math.floor((this.getTime() - newYear.getTime() - (this.getTimezoneOffset()-newYear.getTimezoneOffset())*60000)/86400000) + 1;
  var weeknum;
  if(day < 4) {
    weeknum = Math.floor((daynum+day-1)/7) + 1;
    if(weeknum > 52) {
      nYear = new Date(this.getFullYear() + 1,0,1);
      nday = nYear.getDay() - dowOffset;
      nday = nday >= 0 ? nday : nday + 7;
      weeknum = nday < 4 ? 1 : 53;
    }
  } else {
    weeknum = Math.floor((daynum+day-1)/7);
  }
  return weeknum;
};

function addDays(date, days) {
  date.setDate(date.getDate() + parseInt(days, 10));
  return date;
}

function getDays(diff) { return Math.floor(diff/86400000); }

function getMinutes(diff) { return Math.floor(diff/60000); }

function strToDate(str) {
  str = sqlToLocal(str)
  var a=str.split('/');
  return new Date(a[2], a[1]-1, a[0]);
}

// number functions
function formatCurrency(num, dec) {
  if(!num || isNaN(num)) return;
  sign = (num == (num = Math.abs(num)));
  num = num.toFixed(dec).toString();
  for (var i=num.length-(4+(dec?dec:-1)); i>0; i=i-3)
    num = num.substring(0,i)+','+num.substring(i);
  return ((sign?'':'-') + num);
}

function parseFix(v) { return parseFloat(v.toFixed(2)); }

//////////////////////////////// table ///////////////////////////////
/*
function setRow(rowtmp) {
  var row=[];
  for (var k in rowtmp) {
    row.push((typeof(rowtmp[k])=='function')?rowtmp[k]():rowtmp[k]);
  }
  return "<td class='first'>"+row.join("</td><td>")+"</td>";
}

function arrayToTable(tmp) {
  var rows=[], len=tmp.length;
  for (var i=0; i<len; ++i) {
    rows.push('<tr>', setRow(tmp[i]), '</tr>');
  }
  return rows.join('');
}
*/

function arrayToTreeTable(id, tmp, levels) {
  var parents=[0,1], len=tmp.length;
  var rows=["<tr id='"+id+"-1' class='parent'><td class='first'>", tmp[0].join("</td><td>"), "</td></tr>"];
  for (i=1; i<len; ++i){
    var level=parseInt(levels[i], 10);
    parents[level+1] = i+1;
    parents = parents.slice(0, level+2);
    rows.push("<tr id='"+id+"-"+(i+1)+"' class='"+(tmp[i][0].match(/bold/)?'parent ':'')+(level?"child-of-"+id+"-"+parents.slice(-2, -1):'')+"'><td class='first'>", tmp[i].join("</td><td>"), "</td></tr>");
  }
  return rows.join('');
}

/*
function arrayFilter(a, i, w){
  var j=0;
  while (j<a.length) {
    if (String(a[j][i] || ' ').toLowerCase().indexOf(w) > -1) ++j;
    else a.splice(j,1);
  }
  return a;
}
*/
//function treeMap(levels){
//  var parents=[0,1], jsmap=[0];
//  for (i=1, il=levels.length; i<il;i++){
//    var level=parseInt(levels[i], 10);
//    jsmap.push(parents[level]);
//    parents[level+1] = i+1;
//    parents = parents.slice(0, level+2);
//  }
//  return jsmap;
//}

//////////////////////////////////////////////
function newTab(pd) {
  txt = '<html><head>';
  txt += '<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />';
  txt += '<link rel="stylesheet" href="css/monthly.css">';
  txt += '<style>input {display:none}</style>';
  txt += '<style>.table {border-collapse: collapse; border-style: hidden;}</style>';
  txt += '<style>.table th {border-top:1px solid #ccc; border-bottom:1px solid #ccc;}</style>';
  txt += '<style>.table th, .table td {text-align:right; vertical-align:top; padding:.3em;}</style>';
  txt += '<style>.table th:first-child, .table td:first-child {text-align:left}</style>';
  txt += '</head><body style="max-width:800px;">';
  txt += '<table><tr><td style="width:550px; vertical-align:middle;">';
  txt += print_header;
  txt += '</td><td style="width:150px;">';
  txt += '<img src="logos/' + logo + '" />';
  txt += '</td></tr></table>';
  txt += pd['title'];
  txt += pd['content'];
  txt += '</body></html>';
  OpenWindow=window.open('', '');
  OpenWindow.document.write(txt);
  OpenWindow.document.close();
}

/*
function newTab(pd) {
  txt = '<html><head>';
  txt += '<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />';
  txt += '<link rel="stylesheet" href="css/bootstrap.min.css">';
  txt += '<link rel="stylesheet" href="css/monthly.css">';
  txt += '<style>input {display:none}</style>';
  txt += '<style>th, td {text-align:right; vertical-align:top;}</style>';
  txt += '<style>th:first-child, td:first-child {text-align:left}</style>';
  txt += '</head><body><div class="container">';
  txt += '<table><tr><td style="width:50%; min-width:500px; vertical-align:middle;">';
  txt += print_header;
  txt += '</td><td style="width:50%;">';
  txt += '<img src="logos/' + logo + '" />';
  txt += '</td></tr></table>';
  txt += pd['title'];
  txt += pd['content'];
  txt += '</div></body></html>';
  OpenWindow=window.open('', '');
  OpenWindow.document.write(txt);
  OpenWindow.document.close();
}
*/

function newTabChk(pd) {
  txt = '<html><head>';
  txt += '<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />';
  txt += '</head><body>';
  txt += pd['content'];
  txt += '</body></html>';
  OpenWindow=window.open('', '');
  OpenWindow.document.write(txt);
  OpenWindow.document.close();
}

function download(content, filename) {
  var a = document.createElement('a'),
      blob = new Blob([content], {'type':'application/octet-stream'});
  a.href = window.URL.createObjectURL(blob);
  //a.href = 'data:text/plain;charset=utf-8,' + encodeURIComponent(content);
  a.download = filename;
  a.click();
}

function downloadPDF(content, filename) {
  var a = document.createElement('a'),
      blob = new Blob([content], {'type':'application/pdf'});
  a.href = window.URL.createObjectURL(blob);
  a.download = filename;
  a.click();
}

function exportXLS(head, body) {
  var rows = [];  // [head.join(';')];
  for (var k in body){
    var row = $.map(body[k], function(n){ return n?stripHtml(String(n).replace(/,/g, "")):""; });
//    rows.push(row.join(';'));
    rows.push('<td>'+row.join('</td><td>')+'</td>');
  }

//  var a = document.createElement('a');
//  a.href = 'data:text/csv;charset=UTF-8,' + encodeURIComponent(rows.join('\n'));
//  a.download = "file.csv";
//  a.click();

  var MSDocType   = 'excel';  // 'word'
  var MSDocExt    = (MSDocType == 'excel') ? 'xls' : 'doc';
  var MSDocSchema = 'xmlns:x="urn:schemas-microsoft-com:office:' + MSDocType + '"';
  var docData = '<table>' +
                '<thead><th>' + head.join('</th><th>') + '</th></thead>' +
                '<tbody><tr>' + rows.join('</tr><tr>') + '</tr></tbody>' +
                '</table>';
  var docFile = '<html xmlns:o="urn:schemas-microsoft-com:office:office" ' + MSDocSchema + ' xmlns="http://www.w3.org/TR/REC-html40">';
  docFile += '<meta http-equiv="content-type" content="application/vnd.ms-' + MSDocType + '; charset=UTF-8">';
  docFile += "<head>";
  if ( MSDocType === 'excel' ) {
    docFile += "<!--[if gte mso 9]>";
    docFile += "<xml>";
    docFile += "<x:ExcelWorkbook>";
    docFile += "<x:ExcelWorksheets>";
    docFile += "<x:ExcelWorksheet>";
    docFile += "<x:Name>";
    docFile += "page1";
    docFile += "</x:Name>";
    docFile += "<x:WorksheetOptions>";
    docFile += "<x:DisplayGridlines/>";
    docFile += "</x:WorksheetOptions>";
    docFile += "</x:ExcelWorksheet>";
    docFile += "</x:ExcelWorksheets>";
    docFile += "</x:ExcelWorkbook>";
    docFile += "</xml>";
    docFile += "<![endif]-->";
  }
  docFile += "<style>br {mso-data-placement:same-cell;}</style>";
  docFile += "</head>";
  docFile += "<body>";
  docFile += docData;
  docFile += "</body>";
  docFile += "</html>";

  // console.log(docFile);

  blob = new Blob([docFile], {type: 'application/vnd.ms-' + MSDocType});
  saveAs(blob, 'file.' + MSDocExt);
}

/////////////////////// blockUI //////////////////////////
$.extend($.blockUI.defaults, {
  baseZ: 10000,
  message: " ",
  css: {top:"50%", left:"50%"},
  onBlock: function () {
    var $blockOverlay = $(".blockUI.blockOverlay").not(".has-spinner");
    var $blockMsg = $blockOverlay.next(".blockMsg");
    $blockOverlay.addClass("has-spinner");
    new Spinner({color:"#fff"}).spin($blockMsg.get(0));
  }
});

/////////////////////// request //////////////////////////
function request(url, pd, response) {
//  if(navigator.onLine) {
  pd.append("token", token);
  $.blockUI();
  $.ajax({type: "POST",
          url: url,
          data: pd,
          contentType: false,
          processData: false,
          dataType: "json"})
    .done(function(rs){ response(rs); })
    .fail(function(jqXHR, textStatus){
      var error = jqXHR.responseText;
      if (error.indexOf("session error") < 0) alert(error);
      else window.location.reload(true);
    })
    .always(function(){ $.unblockUI(); });
}

function request_pdf(url, pd, response) {
//  if(navigator.onLine) {
  pd.append("token", token);
  $.blockUI();
  $.ajax({type: "POST",
          url: url.replace(/db$/, 'pdf'),
          data: pd,
          contentType: false,
          processData: false,
          xhrFields: {responseType: 'blob'}})
    .done(function(blob){ response(blob); })
    .fail(function(jqXHR, textStatus){
      var error = jqXHR.responseText;
      if (error.indexOf("session error") < 0) alert(error);
      else window.location.reload(true);
    })
    .always(function(){ $.unblockUI(); });
}

// window.addEventListener('offline', function(){ alert("Sin coneccion!"); });

/*
function request_html(url, pd, response) {
  //pd.push({"name": "token", "value": token});
  //$.blockUI();
  $.ajax({type: "POST", url: url, data: pd, dataType: "html"})
    .done(function(rs){ response(rs); })
    .fail(function(jqXHR, textStatus){ alert(jqXHR.responseText); });
    //.always(function(){ $.unblockUI(); });
}

function post(url, pd) {
  pd["token"] = token;
  var inputs = $.map(pd, function(v, k){ return "<input type='hidden' name='"+k+"' value='"+v+"'>"; });
  $('<form action="'+url+'" method="post">'+inputs.join('')+'</form>').appendTo('body').submit().remove();
}
*/
