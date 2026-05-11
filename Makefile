DIST_DIR ?= $(CURDIR)/dist

.PHONY: all
all:
	$(MAKE) -C src all DIST_DIR=$(DIST_DIR)

.PHONY: prune
prune:
	$(MAKE) -C src prune

.PHONY: clean
clean: prune
	$(MAKE) -C src clean DIST_DIR=$(DIST_DIR)
	rm -rf $(DIST_DIR)

.PHONY: release
release: clean all

