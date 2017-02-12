

VIRTUALENV_DIR=timesheet_venv
PIP=$(VIRTUALENV_DIR)/bin/pip
PYTHON=$(VIRTUALENV_DIR)/bin/python
DCOMPOSE=$(VIRTUALENV_DIR)/bin/docker-compose
DCOMPOSE_PGRES_DIR=./postgres_timesheet_data
$(VIRTUALENV_DIR):
	pyvenv $(VIRTUALENV_DIR)
	$(PIP) install -U pip

clean:	docker-stop
	rm -fr $(VIRTUALENV_DIR)
	rm -fr $(DCOMPOSE_PGRES_DIR)

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
# INITDB=initdb -h $(DOCKER_IP) -p $(DOCKER_POSTGRES_PORT) 
# CREATEDB=createdb -h $(DOCKER_IP) -p $(DOCKER_POSTGRES_PORT) 

# should use docker incantation actually
POSTGRES?=/Users/svanellewee/appz/postgres/9.6.1/
PG_RESTORE=$(POSTGRES)/bin/pg_restore -U timesheet -h $(DOCKER_IP) -p $(DOCKER_POSTGRES_PORT)
PG_DUMP=$(POSTGRES)/bin/pg_dump -U timesheet -h $(DOCKER_IP) -p $(DOCKER_POSTGRES_PORT)

destroydb:
	$(PSQL) -U postgres -c "DROP DATABASE IF EXISTS timesheet;"
	$(PSQL) -U postgres -c "DROP USER IF EXISTS timesheet;"

createdb:
	$(PSQL) -U postgres -c "CREATE DATABASE timesheet;"
	$(PSQL) -U postgres -c "CREATE USER timesheet PASSWORD 'password';"
	$(PSQL) -U postgres -c "GRANT ALL ON DATABASE timesheet TO timesheet;"
	# replacing public with "util", less generic name, more explicit
	$(PSQL) -U postgres -c "DROP SCHEMA IF EXISTS public;"  
	$(PSQL) -U postgres -c "DROP SCHEMA IF EXISTS util;"
	$(PSQL) -U postgres -c "CREATE SCHEMA IF NOT EXISTS util;"

resetdb: destroydb createdb

psql:
	$(PSQL) -U timesheet

schema: resetdb
	@$(PSQL) -U timesheet -f schema.sql -v schema=$(PROJECT)

restore: resetdb
	$(PG_RESTORE) -C -d timesheet "$(BACKUP)"

psql:
	$(PSQL) -U timesheet


NEW_TIMESHEET=$$(echo timesheet_`date +'%y.%m.%d_%H:%M:%S'`.sql)
backup:
	$(PG_DUMP)  -Fc timesheet > $(NEW_TIMESHEET)
	# $(PYTHON) mailer.py $(NEW_TIMESHEET)


clockin:
	@echo "Clock-in: $(REASON) $(PROJECT)"
	@$(PSQL) -U timesheet -c "SELECT $(PROJECT).clockin('$(REASON)');"

clockout:
	@echo "Clock-in: $(REASON)"
	@$(PSQL) -U timesheet -c "SELECT $(PROJECT).clockout('$(REASON)');"

note:
	@echo "adding note: $(REASON)"
	@$(PSQL) -U timesheet -c "SELECT $(PROJECT).add_note('$(REASON)');"


all-tasks-complete:
	@$(PSQL) -U timesheet -c "SELECT * FROM $(PROJECT).all_completed_tasks;"

all-tasks:
	@$(PSQL) -U timesheet -c "SELECT * FROM $(PROJECT).all_tasks;"

today:
	@echo "How today looks like:"
	@$(PSQL) -U timesheet -c "SELECT * FROM $(PROJECT).today;"

