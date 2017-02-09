-- Schema setup
-- DROP SCHEMA IF EXISTS public;
CREATE SCHEMA IF NOT EXISTS timesheet;
CREATE EXTENSION IF NOT EXISTS hstore SCHEMA timesheet;

-- basic unit of timesheet
-- DROP TABLE IF EXISTS timesheet.period CASCADE;
CREATE TABLE IF NOT EXISTS timesheet.period (
       period_id SERIAL,
       start_time TIMESTAMP WITH TIME ZONE,
       stop_time TIMESTAMP WITH TIME ZONE,
       PRIMARY KEY(period_id)
);


-- DROP TABLE IF EXISTS timesheet.description;
CREATE TABLE IF NOT EXISTS timesheet.description (
       description_id SERIAL,
       description TEXT NOT NULL,
       period_id INTEGER NOT NULL,
       tags text[] not null default '{}';
       PRIMARY KEY(description_id),
       FOREIGN KEY(period_id) REFERENCES timesheet.period(period_id) ON DELETE CASCADE
);
ALTER TABLE timesheet.description ADD COLUMN tags text[] NOT NULL DEFAULT '{}';
-- INDEX INDEX description_tags USING gin(tags);
-- DROP TABLE IF EXISTS timesheet.notes;
CREATE TABLE IF NOT EXISTS timesheet.notes (
       notes_id SERIAL,
       note TEXT NOT NULL,
       period_id INTEGER NOT NULL,
       PRIMARY KEY(notes_id),
       FOREIGN KEY(period_id) REFERENCES timesheet.period(period_id) ON DELETE CASCADE
);

ALTER TABLE timesheet.notes ADD COLUMN created_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE timesheet.notes ALTER COLUMN created_at SET DEFAULT NOW();

CREATE OR REPLACE FUNCTION timesheet.mysum(a int, b int) RETURNS INT AS $$
DECLARE r int;
BEGIN
  /* insert some code here */
  r := a + b;
  RETURN r * 2;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

DROP FUNCTION IF EXISTS timesheet.clockin(description TEXT);
CREATE OR REPLACE FUNCTION timesheet.clockin(description TEXT) RETURNS timestamp AS $$
DECLARE now timestamp = NOW();
	_period_id INTEGER;
	total_active INTEGER;
BEGIN
  SET search_path=timesheet;
  SELECT count(1) FROM period WHERE stop_time IS NULL INTO total_active;
  IF total_active > 0 THEN
     RAISE EXCEPTION 'Already clocked in';
  END IF;
  INSERT INTO period(start_time)
       VALUES (now)
    RETURNING period_id INTO _period_id;
  INSERT INTO description(period_id, description)
       VALUES (_period_id, description);
  RETURN now;
END;
$$ LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS timesheet.clockout(_note TEXT);
CREATE OR REPLACE FUNCTION timesheet.clockout(_note TEXT)
   RETURNS timestamp AS $$
DECLARE now timestamp = NOW();
        _period_id INTEGER;
BEGIN
   SET search_path=timesheet;
   UPDATE period
      SET stop_time=now
    WHERE period.start_time IS NOT NULL AND
          period.stop_time IS NULL
    RETURNING period_id
    INTO _period_id;
    INSERT INTO notes(period_id, note)
       VALUES (_period_id, _note);
    RETURN now;
END;
$$ LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS timesheet.add_note(_note TEXT);
CREATE OR REPLACE FUNCTION timesheet.add_note(_note TEXT)
   RETURNS INTEGER AS $$
DECLARE now timestamp = NOW();
        _period_id INTEGER;
	_notes_id INTEGER;
BEGIN
   SET search_path=timesheet;
   SELECT period_id FROM period
    WHERE period.start_time IS NOT NULL AND
          period.stop_time IS NULL
    INTO _period_id;
   
   INSERT INTO notes(period_id, note)
      VALUES (_period_id, _note)
   RETURNING notes_id
   INTO _notes_id;
   RETURN _notes_id;
END;
$$ LANGUAGE plpgsql;



DROP VIEW timesheet.today;
CREATE OR REPLACE VIEW timesheet.today AS
SELECT  p.period_id,
        format('%s -- %s', start_time, coalesce(stop_time::TEXT, 'Unfinished')) period,		
        age(COALESCE(p.stop_time, NOW()), p.start_time) how_long,
        d.description,
        array_agg(note) notes
   FROM timesheet.period p
  INNER JOIN timesheet.description d ON d.period_id=p.period_id
  LEFT OUTER JOIN timesheet.notes n ON n.period_id=p.period_id
  WHERE DATE(start_time) = current_date
  GROUP BY p.period_id, d.description
  ORDER BY p.start_time;

DROP VIEW timesheet.all_completed_tasks;
CREATE OR REPLACE VIEW timesheet.all_completed_tasks AS
SELECT p.period_id,
       format('%s -- %s', start_time, coalesce(stop_time::TEXT, 'Unfinished')) period,
       d.description,
       array_agg(note) notes
  FROM timesheet.period p, timesheet.description d, timesheet.notes n
 WHERE d.period_id=p.period_id AND n.period_id=p.period_id
 GROUP BY p.period_id, d.description
 ORDER BY p.period_id;

DROP VIEW timesheet.all_tasks;
CREATE OR REPLACE VIEW timesheet.all_tasks AS
SELECT p.period_id,
       format('%s -- %s', start_time, coalesce(stop_time::TEXT, 'Unfinished')) period,
       d.description,
       array_agg(note) notes
  FROM timesheet.period p
 INNER JOIN timesheet.description d ON d.period_id=p.period_id
 LEFT OUTER JOIN timesheet.notes n ON n.period_id=p.period_id
  GROUP BY p.period_id, d.description
 ORDER BY p.period_id;


