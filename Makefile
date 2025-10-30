.POSIX:
.PHONY:

CRYSTAL = crystal
CRFLAGS =
OPTS =

all: .PHONY
	$(CRYSTAL) i $(CRFLAGS) bin/gha.cr -- $(OPTS)
