B := build

all: $(patsubst examples/%.ai,$(B)/%,$(wildcard examples/*.ai)) $(B)/ailc1

$(B)/ailc: stage0/ailc.s
	@mkdir -p $(B)
	as -o $(B)/ailc.o $<
	ld -o $@ $(B)/ailc.o

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

# stage1, the compiler written in AIL: built by stage0, then by itself.
# tests/stage1.sh checks that the two are the same file.
# stage1/ailc.ai names its tables with use "stage1/tables.ai", a path that
# the compiler opens from the directory make runs in.
$(B)/ailc1: stage1/ailc.ai stage1/tables.ai $(B)/ailc
	$(call compile,$(B)/ailc)

$(B)/ailc2: stage1/ailc.ai stage1/tables.ai $(B)/ailc1
	$(call compile,$(B)/ailc1)

# Each run names its compiler, so an AILC in the environment of make cannot
# turn the stage0 runs into stage1 runs.
test: $(B)/ailc $(B)/ailc1 $(B)/ailc2
ifeq ($(T),)
	@f=0; AILC=$(B)/ailc tests/run.sh || f=1; AILC=$(B)/ailc tests/io.sh || f=1; \
	tests/tables.sh || f=1; tests/stage1.sh || f=1; \
	AILC=$(B)/ailc1 tests/run.sh || f=1; AILC=$(B)/ailc1 tests/io.sh || f=1; exit $$f
else
	@f=0; AILC=$(B)/ailc tests/run.sh $(T) || f=1; tests/stage1.sh $(T) || f=1; \
	AILC=$(B)/ailc1 tests/run.sh $(T) || f=1; exit $$f
endif

# stage1/tables.ai is generated from the tables of stage0, their one
# definition; tests/tables.sh fails when it is out of date.
tables:
	tools/tables.sh > stage1/tables.ai.tmp && mv stage1/tables.ai.tmp stage1/tables.ai

clean:
	rm -rf $(B)

.PHONY: all test tables clean
