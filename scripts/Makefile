TOPDIR?=$(realpath ..)
include $(TOPDIR)/Config.mk

DIRS  = db
SRCS  =

install:
	@echo "\\033[1;35m+++ Installing conf\\033[39;0m"
	@mkdir -p $(SCRIPTS_DIR)
	@for i in $(DIRS) ; do $(MAKE) -C $$i install ; done
	@for i in $(SRCS); do \
		cp $$i $(SCRIPTS_DIR) ; \
		perl -i -pne 's/%(\w+?)%/$$ENV{$$1}/ge' $(SCRIPTS_DIR)/$$i ; \
	done
	@echo "\\033[1;35m+++ Conf installed\\033[39;0m"
