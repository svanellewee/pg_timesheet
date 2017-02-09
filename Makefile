# VENV_DIR=venv
# PYTHON=$(VENV_DIR)/bin/python
# PIP=$(VENV_DIR)/bin/pip

POSTGRES?=/Users/svanellewee/appz/postgres/9.6.1/
INITDB=$(POSTGRES)/bin/initdb
CREATEDB=$(POSTGRES)/bin/createdb
PG_CTL=$(POSTGRES)/bin/pg_ctl
PSQL=$(POSTGRES)/bin/psql
TIMESHEET_DB=./timesheet_db
PG_DUMP=$(POSTGRES)/bin/pg_dump
PG_RESTORE=$(POSTGRES)/bin/pg_restore

# $(VENV_DIR):
# 	virtualenv --no-site-packages $@
# 	$(PIP) install --upgrade pip
# 	$(PIP) install supervisor PyYAML autopep8 nose coverage flake8 -e git+https://github.com/docker/compose@1.8.1#egg=docker-compose

# pyvenv: | $(VENV_DIR)


# bootstrap: pyvenv 

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

clean-the-database:  stoppg
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


all-tasks-complete:
	@$(PSQL) timesheet -c "SELECT * FROM timesheet.all_completed_tasks;"

all-tasks:
	@$(PSQL) timesheet -c "SELECT * FROM timesheet.all_tasks;"

today:
	@echo "How today looks like:"
	@$(PSQL) timesheet -c "SELECT * FROM timesheet.today;"


VIRTUALENV_DIR=timesheet_venv
PIP=$(VIRTUALENV_DIR)/bin/pip
PYTHON=$(VIRTUALENV_DIR)/bin/python
$(VIRTUALENV_DIR):
	pyvenv $(VIRTUALENV_DIR)
	$(PIP) install -U pip

clean:
	rm -fr $(VIRTUALENV_DIR)

depends: $(VIRTUALENV_DIR)
	$(PIP) install aiopg aiohttp
