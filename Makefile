VENV_DIR=venv
PYTHON=$(VENV_DIR)/bin/python
PIP=$(VENV_DIR)/bin/pip

POSTGRES?=/Users/svanellewee/appz/postgres/9.6.1/
INITDB=$(POSTGRES)/bin/initdb
CREATEDB=$(POSTGRES)/bin/createdb
PG_CTL=$(POSTGRES)/bin/pg_ctl
PSQL=$(POSTGRES)/bin/psql
TIMESHEET_DB=./timesheet_db
PG_DUMP=$(POSTGRES)/bin/pg_dump
PG_RESTORE=$(POSTGRES)/bin/pg_restore

$(VENV_DIR):
	virtualenv --no-site-packages $@
	$(PIP) install --upgrade pip
	$(PIP) install supervisor PyYAML autopep8 nose coverage flake8 -e git+https://github.com/docker/compose@1.8.1#egg=docker-compose

pyvenv: | $(VENV_DIR)


bootstrap: pyvenv 

shutdown:
	@echo "Clock-out: SHUTDOWN"
	@$(PSQL) timesheet -c "SELECT timesheet.clockout('Shutdown');"
	$(PYTHON) mailer.py $(NEW_TIMESHEET)
	sudo shutdown now

sleep:
	@$(PSQL) timesheet -c "SELECT timesheet.clockout('Sleep');"
	$(PYTHON) mailer.py $(NEW_TIMESHEET)
	osascript -e 'tell application "System Events" to sleep'

$(TIMESHEET_DB):
	$(INITDB) -D $@

startpg: $(TIMESHEET_DB)
	$(PG_CTL) -D $(TIMESHEET_DB) -l outputlog.log start
	sleep 1

createdb: startpg
	sleep 2
	$(CREATEDB) timesheet


schema: 
	@$(PSQL) timesheet -f schema.sql

stoppg:
	@$(PG_CTL) -D $(TIMESHEET_DB) -l outputlog.log stop


status:
	@$(PG_CTL) -D $(TIMESHEET_DB) status

psql:
	$(PSQL) timesheet

clean:  stoppg
	rm -fr $(TIMESHEET_DB)

NEW_TIMESHEET=$$(echo timesheet_`date +'%y.%m.%d_%H:%M:%S'`.sql)
backup:
	$(PG_DUMP) -Fc timesheet > $(NEW_TIMESHEET)
	$(PYTHON) mailer.py $(NEW_TIMESHEET)

restore: createdb
	$(PG_RESTORE) -C -d timesheet "$(BACKUP)"

clockin:
	@echo "Clock-in: $(REASON)"
	@$(PSQL) timesheet -c "SELECT timesheet.clockin('$(REASON)');"

clockout:
	@echo "Clock-in: $(REASON)"
	@$(PSQL) timesheet -c "SELECT timesheet.clockout('$(REASON)');"

note:
	@echo "adding note: $(REASON)"
	@$(PSQL) timesheet -c "SELECT timesheet.add_note('$(REASON)');"

current-task:
	@$(PSQL) timesheet -c "SELECT * FROM timesheet.period p, timesheet.description d WHERE d.period_id=p.period_id  ORDER BY p.period_id DESC LIMIT 1;"


all-tasks-complete:
	@$(PSQL) timesheet -c "SELECT p.period_id, start_time, stop_time, description, note FROM timesheet.period p, timesheet.description d, timesheet.notes n WHERE d.period_id=p.period_id AND n.period_id=p.period_id ORDER BY p.period_id;"

all-tasks:
	@$(PSQL) timesheet -c "SELECT * FROM timesheet.period p, timesheet.description d WHERE d.period_id=p.period_id ORDER BY p.period_id;"

today:
	@echo "How today looks like:"
	@$(PSQL) timesheet -c "SELECT  p.period_id, p.start_time, p.stop_time, age(COALESCE(p.stop_time, NOW()), p.start_time) how_long, d.description FROM timesheet.period p, timesheet.description d WHERE DATE(start_time) = current_date AND d.period_id=p.period_id"
