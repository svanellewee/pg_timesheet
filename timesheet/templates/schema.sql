-- Schema setup

CREATE SCHEMA IF NOT EXISTS common;
CREATE TABLE IF NOT EXISTS common.period (
       period_id SERIAL,
       start_time TIMESTAMP WITH TIME ZONE,
       stop_time TIMESTAMP WITH TIME ZONE,
       PRIMARY KEY(period_id)
);

CREATE SCHEMA IF NOT EXISTS {{ schema_name }};


CREATE TABLE IF NOT EXISTS {{ schema_name }}.description (
       description_id SERIAL,
       description TEXT NOT NULL,
       period_id INTEGER NOT NULL,
       tags text[] not null default '{}',
       PRIMARY KEY(description_id),
       FOREIGN KEY(period_id) REFERENCES common.period(period_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS {{ schema_name }}.notes (
       notes_id SERIAL,
       note TEXT NOT NULL,
       period_id INTEGER NOT NULL,
       PRIMARY KEY(notes_id),
       FOREIGN KEY(period_id) REFERENCES common.period(period_id) ON DELETE CASCADE
);



DROP FUNCTION IF EXISTS {{ schema_name }}.clockin(_description TEXT);
CREATE OR REPLACE FUNCTION {{ schema_name }}.clockin(_description TEXT)
  RETURNS timestamp AS $$
DECLARE now timestamp = NOW();
	_period_id INTEGER;
	total_active INTEGER;
BEGIN
  SET search_path TO {{ schema_name }};
  SELECT count(1) FROM common.period WHERE stop_time IS NULL INTO total_active;
  IF total_active > 0 THEN
     RAISE EXCEPTION 'Already clocked in';
  END IF;
  INSERT INTO common.period(start_time)
       VALUES (now)
    RETURNING period_id INTO _period_id;
  INSERT INTO description(period_id, description)
       VALUES (_period_id, _description);
  RETURN now;
END;
$$ LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS {{ schema_name }}.clockout(_note TEXT);
CREATE OR REPLACE FUNCTION {{ schema_name }}.clockout(_note TEXT)
   RETURNS timestamp AS $$
DECLARE now timestamp = NOW();
        _period_id INTEGER;
BEGIN
   SET search_path TO {{ schema_name }};
   UPDATE common.period
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


DROP FUNCTION IF EXISTS {{ schema_name }}.add_note(_note TEXT);
CREATE OR REPLACE FUNCTION {{ schema_name }}.add_note(_note TEXT)
   RETURNS INTEGER AS $$
DECLARE now timestamp = NOW();
        _period_id INTEGER;
	_notes_id INTEGER;
BEGIN
   SET search_path TO {{ schema_name }};
   SELECT period_id FROM common.period
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



DROP VIEW IF EXISTS {{ schema_name }}.today;
CREATE OR REPLACE VIEW {{ schema_name }}.today AS
	SELECT  p.period_id,
		format('%s -- %s', start_time, coalesce(stop_time::TEXT, 'Unfinished')) period,		
		age(COALESCE(p.stop_time, NOW()), p.start_time) how_long,
		d.description,
		array_agg(note) notes
	   FROM common.period p
     INNER JOIN {{ schema_name }}.description d ON d.period_id=p.period_id
LEFT OUTER JOIN {{ schema_name }}.notes n ON n.period_id=p.period_id
	  WHERE DATE(start_time) = current_date
       GROUP BY p.period_id, d.description
       ORDER BY p.start_time;

DROP VIEW IF EXISTS {{ schema_name }}.all_completed_tasks;
CREATE OR REPLACE VIEW {{ schema_name }}.all_completed_tasks AS
  SELECT p.period_id,
	 format('%s -- %s', start_time, coalesce(stop_time::TEXT, 'Unfinished')) period,
	 d.description,
	 array_agg(note) notes
    FROM common.period p, {{ schema_name }}.description d, {{ schema_name }}.notes n
   WHERE d.period_id=p.period_id AND n.period_id=p.period_id
GROUP BY p.period_id, d.description
ORDER BY p.period_id;

DROP VIEW IF EXISTS {{ schema_name }}.all_tasks;
CREATE OR REPLACE VIEW {{ schema_name }}.all_tasks AS
	 SELECT p.period_id,
		format('%s -- %s', start_time, coalesce(stop_time::TEXT, 'Unfinished')) period,
		d.description,
		array_agg(note) notes
	   FROM common.period p
     INNER JOIN {{ schema_name }}.description d ON d.period_id=p.period_id
LEFT OUTER JOIN {{ schema_name }}.notes n ON n.period_id=p.period_id
       GROUP BY p.period_id, d.description
       ORDER BY p.period_id;


