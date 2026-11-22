B := build

SRC := compiler/ailc.aiw compiler/diag.aiw compiler/lex.aiw compiler/names.aiw compiler/pkg.aiw \
       compiler/expr.aiw compiler/emit.aiw compiler/tables.aiw

all: $(patsubst examples/%.aiw,$(B)/%,$(wildcard examples/*.aiw)) $(B)/ailc $(B)/ail

# The seed: the released compiler that seed/MANIFEST pins, from a local
# copy or fetched, refused unless its checksum is the manifest's.
$(B)/ailc0: seed/MANIFEST tools/seed.sh
	@mkdir -p $(B)
	tools/seed.sh $@

# $(call compile,<compiler>): compile $< to $@.
# Build into a temporary file so a failed compile never leaves a target
# that looks up to date. The file is unique to this recipe, so two makes
# building the same target do not take it from each other; mktemp creates
# it unreadable by others, hence the full mode.
define compile
@echo "$(1) < $< > $@"
@tmp=$$(mktemp $@.tmp.XXXXXX) || exit 1; \
trap 'rm -f "$$tmp"' EXIT; trap 'exit 1' HUP INT TERM; \
$(1) < $< > "$$tmp" && chmod 755 "$$tmp" && mv "$$tmp" $@
endef

$(B)/%: examples/%.aiw $(B)/ailc
	$(call compile,$(B)/ailc)

# The tools written in AIL: tools/<name>.aiw is build/tools/<name>, compiled
# by the compiler after the bootstrap, which needs none of them. A tool
# names the files of its functions with use, paths from the directory make
# runs in; each is a prerequisite in the line of the tool below, so that an
# edit of a shared file builds its callers again (tests/tools.sh compares
# those lines with the use statements). The source of the tool stays the
# first prerequisite, the one the recipe compiles.
TOOLS := $(patsubst tools/%.aiw,$(B)/tools/%,$(wildcard tools/*.aiw))

tools: $(TOOLS)

$(B)/tools/%: tools/%.aiw $(B)/ailc
	@mkdir -p $(@D)
	$(call compile,$(B)/ailc)

TL := lib/std/io.aiw lib/std/bytes.aiw lib/std/file.aiw

$(B)/tools/hashcol: lib/std/io.aiw
$(B)/tools/indent: $(TL) tools/lib/dent.aiw
$(B)/tools/fuse $(B)/tools/infix: $(TL) tools/lib/scan.aiw tools/lib/flow.aiw tools/lib/dent.aiw
$(B)/tools/randvars: $(TL) lib/std/proc.aiw tools/lib/rng.aiw

# The command ail (docs/cli.md), compiled like a tool: cli/ail.aiw is the
# source the recipe compiles and names the others with use.
$(B)/ail: cli/ail.aiw cli/manifest.aiw cli/tool.aiw $(TL) lib/std/proc.aiw $(B)/ailc
	$(call compile,$(B)/ailc)

# The compiler, compiler/ailc.aiw, in three generations: built by the seed
# (ailc1), by that (ailc, the compiler everything else uses) and by itself
# (ailc2). The seed may be an older compiler that writes other code for
# the same source, so ailc1 need not be the same file as ailc; ailc and
# ailc2 are both written by the current compiler and must be, which
# tests/self.sh checks. ailc1 and ailc are one program in two
# translations and must behave alike, which it and tests/fuzz.sh check.
# compiler/ailc.aiw names the other files with use "compiler/<name>.aiw",
# paths that the compiler opens from the directory make runs in. It is
# the first of SRC because the recipes compile $<.
$(B)/ailc1: $(SRC) $(B)/ailc0
	$(call compile,$(B)/ailc0)

$(B)/ailc: $(SRC) $(B)/ailc1
	$(call compile,$(B)/ailc1)

$(B)/ailc2: $(SRC) $(B)/ailc
	$(call compile,$(B)/ailc)

# Each run names its compiler, so an AILC in the environment of make
# changes nothing.
test: all $(B)/ailc2 $(TOOLS)
ifeq ($(T),)
	@f=0; AILC=$(B)/ailc tests/run.sh || f=1; AILC=$(B)/ailc tests/io.sh || f=1; \
	AILC=$(B)/ailc tests/pkg.sh || f=1; tests/cli.sh || f=1; \
	tests/make.sh || f=1; tests/tables.sh || f=1; AILC=$(B)/ailc tests/insn.sh || f=1; \
	AILC=$(B)/ailc AILC2=$(B)/ailc1 tests/bytes.sh || f=1; tests/self.sh || f=1; \
	tests/fuzz.sh 300 1 || f=1; AILC=$(B)/ailc tests/infix.sh || f=1; AILC=$(B)/ailc tests/indent.sh || f=1; \
	tests/tools.sh || f=1; AILC=$(B)/ailc tests/randvars.sh || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 1 || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 2 top || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 3 async || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 4 asyncs || f=1; exit $$f
else
	@f=0; AILC=$(B)/ailc tests/run.sh $(T) || f=1; tests/self.sh $(T) || f=1; exit $$f
endif

# A longer fuzz than the one in make test: N sources from SEED.
fuzz: $(B)/ailc
	tests/fuzz.sh $(or $(N),20000) $(or $(SEED),1)

clean:
	rm -rf $(B)

.PHONY: all tools test fuzz clean
