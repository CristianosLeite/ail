B := build

SRC := stage1/ailc.ai stage1/tables.ai

all: $(patsubst examples/%.ai,$(B)/%,$(wildcard examples/*.ai)) $(B)/ailc

# The seed: the released compiler that seed/MANIFEST pins, from a local
# copy or fetched, refused unless its checksum is the manifest's.
$(B)/ailc0: seed/MANIFEST tools/seed.sh
	@mkdir -p $(B)
	tools/seed.sh $@

# The compiler in assembly, kept as the reference that the compiler in
# AIL is compared with.
$(B)/stage0: stage0/ailc.s
	@mkdir -p $(B)
	as -o $(B)/stage0.o $<
	ld -o $@ $(B)/stage0.o

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

# The compiler, stage1/ailc.ai, in three generations: built by the seed
# (ailc1), by that (ailc, the compiler everything else uses) and by itself
# (ailc2). The seed may be an older compiler that writes other code for
# the same source, so ailc1 need not be the same file as ailc; ailc and
# ailc2 are both written by the current compiler and must be, which
# tests/stage1.sh checks.
# stage1/ailc.ai names its tables with use "stage1/tables.ai", a path that
# the compiler opens from the directory make runs in.
$(B)/ailc1: $(SRC) $(B)/ailc0
	$(call compile,$(B)/ailc0)

$(B)/ailc: $(SRC) $(B)/ailc1
	$(call compile,$(B)/ailc1)

$(B)/ailc2: $(SRC) $(B)/ailc
	$(call compile,$(B)/ailc)

# Each run names its compiler, so an AILC in the environment of make cannot
# turn the stage0 runs into stage1 runs.
test: $(B)/stage0 $(B)/ailc $(B)/ailc2
ifeq ($(T),)
	@f=0; AILC=$(B)/stage0 tests/run.sh || f=1; AILC=$(B)/stage0 tests/io.sh || f=1; \
	tests/make.sh || f=1; tests/tables.sh || f=1; tests/stage1.sh || f=1; \
	AILC=$(B)/stage0 tests/insn.sh || f=1; AILC=$(B)/ailc tests/insn.sh || f=1; \
	AILC=$(B)/stage0 AILC2=$(B)/ailc tests/bytes.sh || f=1; tests/fuzz.sh 300 1 || f=1; \
	AILC=$(B)/ailc tests/run.sh || f=1; AILC=$(B)/ailc tests/io.sh || f=1; exit $$f
else
	@f=0; AILC=$(B)/stage0 tests/run.sh $(T) || f=1; tests/stage1.sh $(T) || f=1; \
	AILC=$(B)/ailc tests/run.sh $(T) || f=1; exit $$f
endif

# A longer differential fuzz than the one in make test: N sources from SEED.
fuzz: $(B)/stage0 $(B)/ailc
	tests/fuzz.sh $(or $(N),20000) $(or $(SEED),1)

clean:
	rm -rf $(B)

.PHONY: all test fuzz clean
