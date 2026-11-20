B := build

all: $(patsubst examples/%.ai,$(B)/%,$(wildcard examples/*.ai))

$(B)/ailc: stage0/ailc.s
	@mkdir -p $(B)
	as -o $(B)/ailc.o $<
	ld -o $@ $(B)/ailc.o

# Build into a temporary file so a failed compile never leaves a target
# that looks up to date.
$(B)/%: examples/%.ai $(B)/ailc
	$(B)/ailc < $< > $@.tmp
	chmod +x $@.tmp
	mv $@.tmp $@

test: $(B)/ailc
ifeq ($(T),)
	@tests/run.sh; a=$$?; tests/io.sh; b=$$?; [ $$a -eq 0 ] && [ $$b -eq 0 ]
else
	@tests/run.sh $(T)
endif

clean:
	rm -rf $(B)

.PHONY: all test clean
