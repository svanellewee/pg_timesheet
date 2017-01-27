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
       tags timesheet.HSTORE,
       PRIMARY KEY(description_id),
       FOREIGN KEY(period_id) REFERENCES timesheet.period(period_id) ON DELETE CASCADE
);


-- DROP TABLE IF EXISTS timesheet.notes;
CREATE TABLE IF NOT EXISTS timesheet.notes (
       notes_id SERIAL,
       note TEXT NOT NULL,
       period_id INTEGER NOT NULL,
       tags timesheet.HSTORE,
       PRIMARY KEY(notes_id),
       FOREIGN KEY(period_id) REFERENCES timesheet.period(period_id) ON DELETE CASCADE
);

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
  INSERT INTO notes(period_id, note)
       VALUES (_period_id, '_');
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
    UPDATE notes
       SET note=_note
     WHERE notes.period_id=_period_id;
    RETURN now;
END;
$$ LANGUAGE plpgsql;


ALTER TABLE timesheet.description DROP COLUMN tags;
ALTER TABLE timesheet.description CREATE COLUMN tags text[];
