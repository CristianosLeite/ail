B := build

all: $(B)/hello

$(B)/ailc: stage0/ailc.s
	@mkdir -p $(B)
	as -o $(B)/ailc.o $<
	ld -o $@ $(B)/ailc.o

$(B)/%: examples/%.ai $(B)/ailc
	$(B)/ailc < $< > $@
	chmod +x $@

test: $(B)/hello
	@[ "$$($(B)/hello)" = "hello world" ] && echo ok

clean:
	rm -rf $(B)

.PHONY: all test clean
