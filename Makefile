B := build

all: $(B)/hello

$(B)/ailc: stage0/ailc.s
	@mkdir -p $(B)
	as -o $(B)/ailc.o $<
	ld -o $@ $(B)/ailc.o

$(B)/%: examples/%.ai $(B)/ailc
	$(B)/ailc < $< > $@
	chmod +x $@

test: $(B)/ailc
	@tests/run.sh $(T)

clean:
	rm -rf $(B)

.PHONY: all test clean
