B := build

all: $(patsubst examples/%.ai,$(B)/%,$(wildcard examples/*.ai))

$(B)/ailc: stage0/ailc.s
	@mkdir -p $(B)
	as -o $(B)/ailc.o $<
	ld -o $@ $(B)/ailc.o

# Build into a temporary file so a failed compile never leaves a target
# that looks up to date. The file is unique to this recipe, so two makes
# building the same example do not take it from each other; mktemp creates
# it unreadable by others, hence the full mode.
$(B)/%: examples/%.ai $(B)/ailc
	@echo "$(B)/ailc < $< > $@"
	@tmp=$$(mktemp $@.tmp.XXXXXX) || exit 1; \
	trap 'rm -f "$$tmp"' EXIT; trap 'exit 1' HUP INT TERM; \
	$(B)/ailc < $< > "$$tmp" && chmod 755 "$$tmp" && mv "$$tmp" $@

test: $(B)/ailc
ifeq ($(T),)
	@tests/run.sh; a=$$?; tests/io.sh; b=$$?; [ $$a -eq 0 ] && [ $$b -eq 0 ]
else
	@tests/run.sh $(T)
endif

clean:
	rm -rf $(B)

.PHONY: all test clean
