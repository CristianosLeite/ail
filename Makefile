B := build

all: $(B)/hello

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
	@tests/run.sh $(T)

clean:
	rm -rf $(B)

.PHONY: all test clean
