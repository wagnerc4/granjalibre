# CALENDARIO
def select_calendar(dbObj, rq):
  if "title" in rq:
    return dbObj.getRowsAssoc("""
      INSERT INTO calendar VALUES(DEFAULT, %s, %s, %s, %s, %s)
      RETURNING id, color, title AS name, start_date AS startdate, end_date AS enddate;""",
      (rq['worker'], rq['color'], rq['title'], rq['start_date'], rq['end_date']))
  else:
    return dbObj.getRowsAssoc("""
      WITH events AS (SELECT * FROM calendar
                      WHERE start_date>=%s AND start_date<=%s OR
                            end_date>=%s AND end_date<=%s)
      SELECT id, color, title AS name, start_date AS startdate, end_date AS enddate
      FROM events WHERE worker=%s OR color IS NULL;""",
      (rq['start_date'], rq['end_date'], rq['start_date'], rq['end_date'], rq['worker']))
