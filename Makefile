TOPDIR?=$(realpath .)

include $(TOPDIR)/Config.mk

DIRS=conf scripts
BIN=kool-server kool-agent
GODEPS=\
	github.com/lib/pq \
	github.com/gorilla/mux \
	github.com/codegangsta/negroni

all:
	@$(MAKE) kool-server
	@$(MAKE) start-environment

install: $(BIN)
	@echo "\\033[1;35m+++ Installing system\\033[39;0m"
	@for i in $(DIRS) ; do $(MAKE) -C $$i install ; done
	@mkdir -p $(BIN_DIR)
	@for i in $(BIN); do \
		cp bin/$$i $(BIN_DIR); \
	done
	@echo "\\033[1;35m+++ System installed\\033[39;0m"

clean: stop-environment
	@$(RM) $(RUN_DIR)
	@$(RM) $(RPM_DIR)/x86_64

start-environment: install postgresql-start

stop-environment: postgresql-stop

$(RUN_DIR):
	@$(MKDIR) $(RUN_DIR)
	@$(MAKE) install

postgresql-start: $(RUN_DIR)
	@echo "\\033[1;35m+++ Starting postgres\\033[39;0m"
	@if [ ! -f $(RUN_DIR)/postmaster.pid ]; then \
		rm -rf $(PGSQL_DATA) > /dev/null; \
		mkdir -p $(PGSQL_LOGDIR); \
		$(PGSQL_BIN)/initdb --pgdata=$(PGSQL_DATA) --auth="ident" > /dev/null; \
		$(PGSQL_BIN)/postgres -c config_file=${CONF_DIR}/postgresql.conf -k $(PGSQL_DATA) -D $(PGSQL_DATA) 1> $(PGSQL_LOG) < /dev/null 2>&1 & \
		echo $$! > $(RUN_DIR)/postmaster.pid; \
		while ! $(USR_BIN)/psql -h $(PGSQL_DATA) -p $(PGSQL_PORT) -c "select current_timestamp" template1 > /dev/null 2>&1; do \
			/bin/sleep 1; \
			echo -n "\\033[1;35m.\\033[39;0m"; \
		done; \
		$(USR_BIN)/createdb -h $(PGSQL_DATA) -p $(PGSQL_PORT) $(DATABASE); \
		$(USR_BIN)/psql -q -h $(PGSQL_DATA) -p $(PGSQL_PORT) $(DATABASE) -f $(PGSQL_SCHEMA) > /dev/null 2>&1; \
		for i in $(PGSQL_DATA_FILES); do \
			$(USR_BIN)/psql -q -h $(PGSQL_DATA) -p $(PGSQL_PORT) $(DATABASE) -f $$i > /dev/null 2>&1; \
		done; \
	fi

postgresql-stop:
	@if [ -f $(RUN_DIR)/postmaster.pid ]; then \
		echo -n "\\033[1;35m+++ Stopping postgres\\033[39;0m "; \
		while kill -INT `cat $(RUN_DIR)/postmaster.pid` 2>/dev/null; do echo -n "\\033[1;35m.\\033[39;0m "; sleep 1; done; echo; \
	fi

kool-server: deps
	GOPATH=${PROJECT} go install kool-server

kool-agent: deps
	GOPATH=${PROJECT} go install kool-agent

deps: ${GODEPS}
github.com/% :
	GOPATH=${PROJECT} go get $@

help:
	@echo "\033[1;35mmake all\\033[39;0m - build, install and bring up the regress environment."

info:
	@echo "To connect to postgresql database: \033[1;35mpsql -h $(PGSQL_DATA) -p $(PGSQL_PORT) $(DATABASE)\\033[39;0m"

rpm-build:
	rpmbuild --quiet --nobuild --rcfile ${RPM_DIR}/rpmrc --macros=/usr/lib/rpm/macros:${RPM_DIR}/rpmmacros ${RPM_DIR}/kool-server.spec 2>&1 | grep error; if [ $$? == 0 ] ; then exit 1; fi
	rpmbuild -bb --rcfile ${RPM_DIR}/rpmrc --target x86_64-linux --macros=/usr/lib/rpm/macros:${RPM_DIR}/rpmmacros --buildroot=${TOPDIR}/dest/kool-server ${RPM_DIR}/kool-server.spec
