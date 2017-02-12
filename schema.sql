-- Schema setup
CREATE SCHEMA IF NOT EXISTS :schema;
SET search_path TO :schema;

-- Assuming schema created


-- basic unit of timesheet
-- DROP TABLE IF EXISTS :schema.period CASCADE;
CREATE TABLE IF NOT EXISTS :schema.period (
       period_id SERIAL,
       start_time TIMESTAMP WITH TIME ZONE,
       stop_time TIMESTAMP WITH TIME ZONE,
       PRIMARY KEY(period_id)
);


-- DROP TABLE IF EXISTS :schema.description;
CREATE TABLE IF NOT EXISTS :schema.description (
       description_id SERIAL,
       description TEXT NOT NULL,
       period_id INTEGER NOT NULL,
       tags text[] not null default '{}',
       PRIMARY KEY(description_id),
       FOREIGN KEY(period_id) REFERENCES :schema.period(period_id) ON DELETE CASCADE
);
-- ALTER TABLE :schema.description ADD COLUMN tags text[] NOT NULL DEFAULT '{}';
-- INDEX INDEX description_tags USING gin(tags);
-- DROP TABLE IF EXISTS :schema.notes;
CREATE TABLE IF NOT EXISTS :schema.notes (
       notes_id SERIAL,
       note TEXT NOT NULL,
       period_id INTEGER NOT NULL,
       PRIMARY KEY(notes_id),
       FOREIGN KEY(period_id) REFERENCES :schema.period(period_id) ON DELETE CASCADE
);

-- ALTER TABLE :schema.notes ADD COLUMN created_at TIMESTAMP WITH TIME ZONE;
-- ALTER TABLE :schema.notes ALTER COLUMN created_at SET DEFAULT NOW();

CREATE OR REPLACE FUNCTION :schema.mysum(a int, b int) RETURNS INT AS $$
DECLARE r int;
BEGIN
  /* insert some code here */
  r := a + b;
  RETURN r * 2;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

DROP FUNCTION IF EXISTS :schema.clockin(description TEXT);
CREATE OR REPLACE FUNCTION :schema.clockin(description TEXT) RETURNS timestamp AS $$
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


DROP FUNCTION IF EXISTS :schema.clockout(_note TEXT);
CREATE OR REPLACE FUNCTION :schema.clockout(_note TEXT)
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


DROP FUNCTION IF EXISTS :schema.add_note(_note TEXT);
CREATE OR REPLACE FUNCTION :schema.add_note(_note TEXT)
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



DROP VIEW IF EXISTS :schema.today;
CREATE OR REPLACE VIEW :schema.today AS
	SELECT  p.period_id,
		format('%s -- %s', start_time, coalesce(stop_time::TEXT, 'Unfinished')) period,		
		age(COALESCE(p.stop_time, NOW()), p.start_time) how_long,
		d.description,
		array_agg(note) notes
	   FROM :schema.period p
     INNER JOIN :schema.description d ON d.period_id=p.period_id
LEFT OUTER JOIN :schema.notes n ON n.period_id=p.period_id
	  WHERE DATE(start_time) = current_date
       GROUP BY p.period_id, d.description
       ORDER BY p.start_time;

DROP VIEW IF EXISTS :schema.all_completed_tasks;
CREATE OR REPLACE VIEW :schema.all_completed_tasks AS
  SELECT p.period_id,
	 format('%s -- %s', start_time, coalesce(stop_time::TEXT, 'Unfinished')) period,
	 d.description,
	 array_agg(note) notes
    FROM :schema.period p, :schema.description d, :schema.notes n
   WHERE d.period_id=p.period_id AND n.period_id=p.period_id
GROUP BY p.period_id, d.description
ORDER BY p.period_id;

DROP VIEW IF EXISTS :schema.all_tasks;
CREATE OR REPLACE VIEW :schema.all_tasks AS
	 SELECT p.period_id,
		format('%s -- %s', start_time, coalesce(stop_time::TEXT, 'Unfinished')) period,
		d.description,
		array_agg(note) notes
	   FROM :schema.period p
     INNER JOIN :schema.description d ON d.period_id=p.period_id
LEFT OUTER JOIN :schema.notes n ON n.period_id=p.period_id
       GROUP BY p.period_id, d.description
       ORDER BY p.period_id;


