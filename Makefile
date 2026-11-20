B := build

SRC := stage1/ailc.ai stage1/tables.ai

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

# The compiler, stage1/ailc.ai, in three generations: built by the seed
# (ailc1), by that (ailc, the compiler everything else uses) and by itself
# (ailc2). The seed may be an older compiler that writes other code for
# the same source, so ailc1 need not be the same file as ailc; ailc and
# ailc2 are both written by the current compiler and must be, which
# tests/self.sh checks. ailc1 and ailc are one program in two
# translations and must behave alike, which it and tests/fuzz.sh check.
# stage1/ailc.ai names its tables with use "stage1/tables.ai", a path that
# the compiler opens from the directory make runs in.
$(B)/ailc1: $(SRC) $(B)/ailc0
	$(call compile,$(B)/ailc0)

$(B)/ailc: $(SRC) $(B)/ailc1
	$(call compile,$(B)/ailc1)

$(B)/ailc2: $(SRC) $(B)/ailc
	$(call compile,$(B)/ailc)

# Each run names its compiler, so an AILC in the environment of make
# changes nothing.
test: $(B)/ailc $(B)/ailc2
ifeq ($(T),)
	@f=0; AILC=$(B)/ailc tests/run.sh || f=1; AILC=$(B)/ailc tests/io.sh || f=1; \
	tests/make.sh || f=1; tests/tables.sh || f=1; AILC=$(B)/ailc tests/insn.sh || f=1; \
	AILC=$(B)/ailc AILC2=$(B)/ailc1 tests/bytes.sh || f=1; tests/self.sh || f=1; \
	tests/fuzz.sh 300 1 || f=1; python3 tools/randvars.py $(B)/ailc 200 1 || f=1; \
	python3 tools/randvars.py $(B)/ailc 200 2 top || f=1; exit $$f
else
	@f=0; AILC=$(B)/ailc tests/run.sh $(T) || f=1; tests/self.sh $(T) || f=1; exit $$f
endif

# A longer fuzz than the one in make test: N sources from SEED.
fuzz: $(B)/ailc
	tests/fuzz.sh $(or $(N),20000) $(or $(SEED),1)

clean:
	rm -rf $(B)

.PHONY: all test fuzz clean
