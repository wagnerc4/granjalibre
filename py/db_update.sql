-- psql conta2 -v activity='1' -f db_update.sql


SET search_path TO activity_:activity;


/*
UPDATE querys q SET query=t.query, defs=t.defs, title=t.title
FROM (SELECT code, query, defs, title FROM activity_1.querys) t
WHERE q.code=t.code AND
      q.code IN ('query_tables',
                 'resumens_1_repro_resumen_actives',
                 'resumens_1_repro_resumen_litters',
                 'resumens_1_repro_resumen_males',
                 'resumens_1_repro_stock_litters',
                 'resumens_1_repro_stock_productives',
                 'resumens_1_repro_stock_services',
                 'resumens_1_repro_stock_unproductives',
                 'resumens_partos_nacidos',
                 'resumens_produ_deaths',
                 'resumens_produ_semanal_feed');

INSERT INTO querys SELECT * FROM activity_1.querys t 
WHERE t.code NOT IN(SELECT code FROM querys) AND
      q.code IN ('query_tables',
                 'resumens_1_repro_resumen_actives',
                 'resumens_1_repro_resumen_litters',
                 'resumens_1_repro_resumen_males',
                 'resumens_1_repro_stock_litters',
                 'resumens_1_repro_stock_productives',
                 'resumens_1_repro_stock_services',
                 'resumens_1_repro_stock_unproductives',
                 'resumens_partos_nacidos',
                 'resumens_produ_deaths',
                 'resumens_produ_semanal_feed');
*/
