PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

install:
	@command -v jq >/dev/null || { echo "tf-plan-diff needs jq: https://jqlang.org/download/" >&2; exit 1; }
	install -d $(BINDIR)
	install -m 755 tf-plan-diff $(BINDIR)/tf-plan-diff

uninstall:
	rm -f $(BINDIR)/tf-plan-diff

test:
	tests/run.sh

.PHONY: install uninstall test
