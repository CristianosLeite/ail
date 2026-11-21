B := build

SRC := compiler/ailc.aw compiler/diag.aw compiler/lex.aw compiler/names.aw \
       compiler/expr.aw compiler/emit.aw compiler/tables.aw

all: $(patsubst examples/%.aw,$(B)/%,$(wildcard examples/*.aw)) $(B)/ailc

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

$(B)/%: examples/%.aw $(B)/ailc
	$(call compile,$(B)/ailc)

# The algorithm programs name their harness with use, so they are built
# again when it changes.
$(patsubst %,$(B)/%,quicksort mergesort heapsort bsearch hashtab graph ndelem ndreduce ndmatmul): bench/algo/harness.aw

# Their kernels are files of lib/algo/.
$(patsubst %,$(B)/%,quicksort mergesort heapsort isort): lib/algo/sort.aw
$(B)/bsearch: lib/algo/search.aw
$(B)/hashtab: lib/algo/hash.aw
$(B)/graph: lib/algo/graph.aw

# The array programs also name the library of arrays.
$(patsubst %,$(B)/%,ndelem ndreduce ndmatmul): lib/nd/array.aw lib/nd/elem.aw
$(patsubst %,$(B)/%,ndreduce ndmatmul): lib/nd/reduce.aw

# The tools written in AIL: tools/<name>.aw is build/tools/<name>, compiled
# by the compiler after the bootstrap, which needs none of them. A tool
# names the files of its functions with use, paths from the directory make
# runs in; each is a prerequisite in the line of the tool below, so that an
# edit of a shared file builds its callers again (tests/tools.sh compares
# those lines with the use statements). The source of the tool stays the
# first prerequisite, the one the recipe compiles.
TOOLS := $(patsubst tools/%.aw,$(B)/tools/%,$(wildcard tools/*.aw))

tools: $(TOOLS)

$(B)/tools/%: tools/%.aw $(B)/ailc
	@mkdir -p $(@D)
	$(call compile,$(B)/ailc)

TL := lib/io.aw lib/bytes.aw lib/file.aw

$(B)/tools/hashcol: lib/io.aw
$(B)/tools/indent: $(TL) tools/lib/dent.aw
$(B)/tools/fuse $(B)/tools/infix: $(TL) tools/lib/scan.aw tools/lib/flow.aw tools/lib/dent.aw
$(B)/tools/randvars: $(TL) lib/proc.aw tools/lib/rng.aw
$(B)/tools/perf: $(TL) lib/proc.aw tools/lib/rng.aw tools/lib/fmt.aw
$(B)/tools/tokens: $(TL) tools/lib/fmt.aw tools/lib/o200k.aw
$(B)/tools/par: $(TL) lib/proc.aw tools/lib/fmt.aw

# The compiler, compiler/ailc.aw, in three generations: built by the seed
# (ailc1), by that (ailc, the compiler everything else uses) and by itself
# (ailc2). The seed may be an older compiler that writes other code for
# the same source, so ailc1 need not be the same file as ailc; ailc and
# ailc2 are both written by the current compiler and must be, which
# tests/self.sh checks. ailc1 and ailc are one program in two
# translations and must behave alike, which it and tests/fuzz.sh check.
# compiler/ailc.aw names the other files with use "compiler/<name>.aw",
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
	tests/make.sh || f=1; tests/tables.sh || f=1; AILC=$(B)/ailc tests/insn.sh || f=1; \
	AILC=$(B)/ailc AILC2=$(B)/ailc1 tests/bytes.sh || f=1; tests/self.sh || f=1; \
	tests/fuzz.sh 300 1 || f=1; AILC=$(B)/ailc tests/infix.sh || f=1; AILC=$(B)/ailc tests/indent.sh || f=1; \
	tests/par.sh || f=1; AILC=$(B)/ailc tests/async.sh || f=1; tests/algo.sh || f=1; tests/tools.sh || f=1; AILC=$(B)/ailc tests/randvars.sh || f=1; tests/tokens.sh || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 1 || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 2 top || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 3 async || f=1; exit $$f
else
	@f=0; AILC=$(B)/ailc tests/run.sh $(T) || f=1; tests/self.sh $(T) || f=1; exit $$f
endif

# A longer fuzz than the one in make test: N sources from SEED.
fuzz: $(B)/ailc
	tests/fuzz.sh $(or $(N),20000) $(or $(SEED),1)

clean:
	rm -rf $(B)

.PHONY: all tools test fuzz clean
