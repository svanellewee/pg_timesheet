

VIRTUALENV_DIR=timesheet_venv
PIP=$(VIRTUALENV_DIR)/bin/pip
PYTHON=$(VIRTUALENV_DIR)/bin/python
DCOMPOSE=$(VIRTUALENV_DIR)/bin/docker-compose
$(VIRTUALENV_DIR):
	pyvenv $(VIRTUALENV_DIR)
	$(PIP) install -U pip

clean:
	rm -fr $(VIRTUALENV_DIR)

depends: $(VIRTUALENV_DIR)
	$(PIP) install aiopg aiohttp PyYAML docker-compose


DOCKER_IP?=127.0.0.1  # 192.168.99.100 docker machine?
DOCKER_POSTGRES_PORT=54320  # as per docker-compose file

docker-start: depends
	$(DCOMPOSE) pull &&  \
	$(DCOMPOSE) up -d

docker-stop: 
	$(DCOMPOSE) kill && \
	$(DCOMPOSE) rm -f

PSQL=psql -h $(DOCKER_IP) -p $(DOCKER_POSTGRES_PORT) 
INITDB=initdb -h $(DOCKER_IP) -p $(DOCKER_POSTGRES_PORT) 
CREATEDB=createdb -h $(DOCKER_IP) -p $(DOCKER_POSTGRES_PORT) 
TIMESHEET_DB=./timesheet_db


destroydb:
	$(PSQL) -U postgres -c "DROP DATABASE timesheet;"
	$(PSQL) -U postgres -c "DROP USER timesheet;"

createdb:
	$(PSQL) -U postgres -c "CREATE DATABASE timesheet;"
	$(PSQL) -U postgres -c "CREATE USER timesheet PASSWORD 'password';"
	$(PSQL) -U postgres -c "GRANT ALL ON DATABASE timesheet TO timesheet;"

psql:
	$(PSQL) -U timesheet


shutdown:
	@echo "Clock-out: SHUTDOWN"
	@$(PSQL) timesheet -c "SELECT timesheet.clockout('Shutdown');"
	$(PYTHON) mailer.py $(NEW_TIMESHEET)
	sudo shutdown now

sleep:
	@$(PSQL) timesheet -c "SELECT timesheet.clockout('Sleep');"
	$(PYTHON) mailer.py $(NEW_TIMESHEET)
	osascript -e 'tell application "System Events" to sleep'

schema: 
	@$(PSQL) -U timesheet -f schema.sql


psql:
	$(PSQL) timesheet


NEW_TIMESHEET=$$(echo timesheet_`date +'%y.%m.%d_%H:%M:%S'`.sql)
backup:
	$(PG_DUMP) -Fc timesheet > $(NEW_TIMESHEET)
	$(PYTHON) mailer.py $(NEW_TIMESHEET)

restore: 
	$(PG_RESTORE) -C -d timesheet "$(BACKUP)"

clockin:
	@echo "Clock-in: $(REASON)"
	@$(PSQL) -U timesheet -c "SELECT timesheet.clockin('$(REASON)');"

clockout:
	@echo "Clock-in: $(REASON)"
	@$(PSQL) -U timesheet -c "SELECT timesheet.clockout('$(REASON)');"

note:
	@echo "adding note: $(REASON)"
	@$(PSQL) -U timesheet -c "SELECT timesheet.add_note('$(REASON)');"


all-tasks-complete:
	@$(PSQL) -U timesheet -c "SELECT * FROM timesheet.all_completed_tasks;"

all-tasks:
	@$(PSQL) -U timesheet -c "SELECT * FROM timesheet.all_tasks;"

today:
	@echo "How today looks like:"
	@$(PSQL) -U timesheet -c "SELECT * FROM timesheet.today;"

