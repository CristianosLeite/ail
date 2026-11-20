B := build

SRC := compiler/ailc.ai compiler/diag.ai compiler/lex.ai compiler/names.ai \
       compiler/expr.ai compiler/emit.ai compiler/tables.ai

all: $(patsubst examples/%.ai,$(B)/%,$(wildcard examples/*.ai)) $(B)/ailc

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

$(B)/%: examples/%.ai $(B)/ailc
	$(call compile,$(B)/ailc)

# The tools written in AIL: tools/<name>.ai is build/tools/<name>, compiled
# by the compiler after the bootstrap, which needs none of them. A tool
# names the files of its functions with use, paths from the directory make
# runs in; each is a prerequisite in the line of the tool below, so that an
# edit of a shared file builds its callers again (tests/tools.sh compares
# those lines with the use statements). The source of the tool stays the
# first prerequisite, the one the recipe compiles.
TOOLS := $(patsubst tools/%.ai,$(B)/tools/%,$(wildcard tools/*.ai))

tools: $(TOOLS)

$(B)/tools/%: tools/%.ai $(B)/ailc
	@mkdir -p $(@D)
	$(call compile,$(B)/ailc)

TL := lib/io.ai lib/bytes.ai lib/file.ai

$(B)/tools/hashcol: lib/io.ai
$(B)/tools/fuse $(B)/tools/infix: $(TL) tools/lib/scan.ai tools/lib/flow.ai
$(B)/tools/randvars: $(TL) lib/proc.ai tools/lib/rng.ai
$(B)/tools/perf: $(TL) lib/proc.ai tools/lib/rng.ai tools/lib/fmt.ai
$(B)/tools/tokens: $(TL) tools/lib/fmt.ai tools/lib/o200k.ai

# The compiler, compiler/ailc.ai, in three generations: built by the seed
# (ailc1), by that (ailc, the compiler everything else uses) and by itself
# (ailc2). The seed may be an older compiler that writes other code for
# the same source, so ailc1 need not be the same file as ailc; ailc and
# ailc2 are both written by the current compiler and must be, which
# tests/self.sh checks. ailc1 and ailc are one program in two
# translations and must behave alike, which it and tests/fuzz.sh check.
# compiler/ailc.ai names the other files with use "compiler/<name>.ai",
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
test: $(B)/ailc $(B)/ailc2 $(TOOLS)
ifeq ($(T),)
	@f=0; AILC=$(B)/ailc tests/run.sh || f=1; AILC=$(B)/ailc tests/io.sh || f=1; \
	tests/make.sh || f=1; tests/tables.sh || f=1; AILC=$(B)/ailc tests/insn.sh || f=1; \
	AILC=$(B)/ailc AILC2=$(B)/ailc1 tests/bytes.sh || f=1; tests/self.sh || f=1; \
	tests/fuzz.sh 300 1 || f=1; AILC=$(B)/ailc tests/infix.sh || f=1; \
	tests/par.sh || f=1; tests/tools.sh || f=1; AILC=$(B)/ailc tests/randvars.sh || f=1; tests/tokens.sh || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 1 || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 2 top || f=1; exit $$f
else
	@f=0; AILC=$(B)/ailc tests/run.sh $(T) || f=1; tests/self.sh $(T) || f=1; exit $$f
endif

# A longer fuzz than the one in make test: N sources from SEED.
fuzz: $(B)/ailc
	tests/fuzz.sh $(or $(N),20000) $(or $(SEED),1)

clean:
	rm -rf $(B)

.PHONY: all tools test fuzz clean
