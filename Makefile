.POSIX:
.PHONY:

CRYSTAL = crystal
CRFLAGS =
OPTS =

all: .PHONY
	rm -rf .github/workflows .github/actions
	$(CRYSTAL) i $(CRFLAGS) bin/gha.cr -- $(OPTS)
