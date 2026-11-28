B := build

SRC := compiler/ailc.aiw compiler/diag.aiw compiler/lex.aiw compiler/names.aiw compiler/pkg.aiw \
       compiler/expr.aiw compiler/emit.aiw compiler/tables.aiw lib/std/num.aiw

all: $(patsubst examples/%.aiw,$(B)/%,$(wildcard examples/*.aiw)) $(B)/ailc $(B)/ail $(B)/tools/indent

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

$(B)/%: examples/%.aiw $(B)/ailc
	$(call compile,$(B)/ailc)

# The tools written in AIL: tools/<name>.aiw is build/tools/<name>, compiled
# by the compiler after the bootstrap, which needs none of them. A tool
# names the files of its functions with use, paths from the directory make
# runs in; each is a prerequisite in the line of the tool below, so that an
# edit of a shared file builds its callers again (tests/tools.sh compares
# those lines with the use statements). The source of the tool stays the
# first prerequisite, the one the recipe compiles.
TOOLS := $(patsubst tools/%.aiw,$(B)/tools/%,$(wildcard tools/*.aiw))

tools: $(TOOLS)

$(B)/tools/%: tools/%.aiw $(B)/ailc
	@mkdir -p $(@D)
	$(call compile,$(B)/ailc)

TL := lib/std/io.aiw lib/std/bytes.aiw lib/std/file.aiw

$(B)/tools/hashcol: lib/std/io.aiw
$(B)/tools/ndgen: lib/std/io.aiw lib/std/bytes.aiw
$(B)/tools/indent: $(TL) tools/lib/dent.aiw
$(B)/tools/fuse $(B)/tools/infix: $(TL) tools/lib/scan.aiw tools/lib/flow.aiw tools/lib/dent.aiw
$(B)/tools/randvars: $(TL) lib/std/proc.aiw tools/lib/rng.aiw

# The command ail (docs/cli.md), compiled like a tool: cli/ail.aiw is the
# source the recipe compiles and names the others with use.
$(B)/ail: cli/ail.aiw cli/manifest.aiw cli/tool.aiw cli/deps.aiw $(TL) lib/std/proc.aiw $(B)/ailc
	$(call compile,$(B)/ailc)

# The runtime (docs/runtime.md): the services of the platform, written in
# AIL. The compiler has its source as data lines and compiles it with
# every program, rt.aiw in front of the program and state.aiw behind it.
# What the compiler is built for: compiler/$(TARGET)/target.aiw says how
# an executable of that platform is made and rt/$(TARGET) is its
# runtime. The source names both through packages, "target" and "rt",
# which each compiler that compiles it is told here.
TARGET := linux-x86_64
RTDIR := rt/$(TARGET)
RTSRC := $(B)/rt/$(TARGET)/source.aiw
PKGS := target=compiler/$(TARGET) rt=$(B)/rt/$(TARGET)
TSRC := compiler/$(TARGET)/target.aiw

$(RTSRC): $(RTDIR)/rt.aiw $(RTDIR)/state.aiw rt/source.sh
	@mkdir -p $(@D)
	{ rt/source.sh rtsrc $(RTDIR)/rt.aiw && rt/source.sh rttail $(RTDIR)/state.aiw; } > $@.tmp && mv $@.tmp $@

# The compiler for another platform than the one it runs on: Windows on
# x86-64. build/ailc-windows-x86_64 runs here and writes executables of
# Windows, with the runtime of rt/windows-x86_64 in them. Its target is
# a directory of the build: the file of compiler/windows-x86_64 and the
# import tables, which imports.sh writes from the list of the functions
# of Windows that the runtime calls; the runtime is told where the
# address of each is by consts in front of its source.
WT := windows-x86_64
WTDIR := $(B)/target/$(WT)
WPKGS := target=$(WTDIR) rt=$(B)/rt/$(WT)

$(WTDIR)/target.aiw: compiler/$(WT)/target.aiw
	@mkdir -p $(@D)
	cp $< $@

$(WTDIR)/imports.aiw: compiler/$(WT)/imports.list compiler/$(WT)/imports.sh
	@mkdir -p $(@D)
	compiler/$(WT)/imports.sh data < $< > $@.tmp && mv $@.tmp $@

$(B)/rt/$(WT)/source.aiw: rt/$(WT)/rt.aiw rt/$(WT)/state.aiw compiler/$(WT)/imports.list compiler/$(WT)/imports.sh rt/source.sh
	@mkdir -p $(@D)
	{ compiler/$(WT)/imports.sh consts < compiler/$(WT)/imports.list && cat rt/$(WT)/rt.aiw; } > $(@D)/rt.aiw
	{ rt/source.sh rtsrc $(@D)/rt.aiw && rt/source.sh rttail rt/$(WT)/state.aiw; } > $@.tmp && mv $@.tmp $@

# It is built with everything else: an installation has it, for
# "ail build --target windows-x86_64" (docs/cli.md).
all: $(B)/ailc-$(WT)

$(B)/ailc-$(WT): $(SRC) $(WTDIR)/target.aiw $(WTDIR)/imports.aiw $(B)/rt/$(WT)/source.aiw $(B)/ailc
	$(call compile,$(B)/ailc $(WPKGS))

# AIL for Windows itself (docs/cli.md): the command, the compiler and the
# formatter as programs of Windows, each compiled here by the compiler
# for Windows. The compiler is the one tests/win.sh shows to compile
# itself to the same file there.
WAIL := $(B)/$(WT)/ail.exe $(B)/$(WT)/ailc.exe $(B)/$(WT)/indent.exe

$(B)/$(WT)/ail.exe: cli/ail.aiw cli/manifest.aiw cli/tool.aiw cli/deps.aiw $(TL) lib/std/proc.aiw $(B)/ailc-$(WT)
	@mkdir -p $(@D)
	$(call compile,$(B)/ailc-$(WT))

$(B)/$(WT)/ailc.exe: $(SRC) $(WTDIR)/target.aiw $(WTDIR)/imports.aiw $(B)/rt/$(WT)/source.aiw $(B)/ailc-$(WT)
	@mkdir -p $(@D)
	$(call compile,$(B)/ailc-$(WT) $(WPKGS))

$(B)/$(WT)/indent.exe: tools/indent.aiw $(TL) tools/lib/dent.aiw $(B)/ailc-$(WT)
	@mkdir -p $(@D)
	$(call compile,$(B)/ailc-$(WT))

# an example for Windows: build/windows-x86_64/<name>.exe
$(B)/$(WT)/%.exe: examples/%.aiw $(B)/ailc-$(WT)
	@mkdir -p $(@D)
	$(call compile,$(B)/ailc-$(WT))

# The compiler, compiler/ailc.aiw, in three generations: built by the seed
# (ailc1), by that (ailc, the compiler everything else uses) and by itself
# (ailc2). The seed may be an older compiler that writes other code for
# the same source, so ailc1 need not be the same file as ailc; ailc and
# ailc2 are both written by the current compiler and must be, which
# tests/self.sh checks. ailc1 and ailc are one program in two
# translations and must behave alike, which it and tests/fuzz.sh check.
# compiler/ailc.aiw names the other files with use "compiler/<name>.aiw",
# paths that the compiler opens from the directory make runs in. It is
# the first of SRC because the recipes compile $<.
$(B)/ailc1: $(SRC) $(TSRC) $(RTSRC) $(B)/ailc0
	$(call compile,$(B)/ailc0 $(PKGS))

$(B)/ailc: $(SRC) $(TSRC) $(RTSRC) $(B)/ailc1
	$(call compile,$(B)/ailc1 $(PKGS))

$(B)/ailc2: $(SRC) $(TSRC) $(RTSRC) $(B)/ailc
	$(call compile,$(B)/ailc $(PKGS))

# Each run names its compiler, so an AILC in the environment of make
# changes nothing.
test: all $(B)/ailc2 $(TOOLS) $(B)/ailc-$(WT) $(WAIL)
ifeq ($(T),)
	@f=0; AILC=$(B)/ailc tests/run.sh || f=1; AILC=$(B)/ailc tests/io.sh || f=1; \
	AILC=$(B)/ailc tests/pkg.sh || f=1; tests/cli.sh || f=1; tests/install.sh || f=1; \
	tests/make.sh || f=1; tests/tables.sh || f=1; AILC=$(B)/ailc tests/rt.sh || f=1; tests/win.sh || f=1; AILC=$(B)/ailc tests/insn.sh || f=1; \
	AILC=$(B)/ailc AILC2=$(B)/ailc1 tests/bytes.sh || f=1; tests/self.sh || f=1; \
	tests/fuzz.sh 300 1 || f=1; AILC=$(B)/ailc tests/infix.sh || f=1; AILC=$(B)/ailc tests/indent.sh || f=1; \
	tests/tools.sh || f=1; AILC=$(B)/ailc tests/randvars.sh || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 1 || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 2 top || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 3 async || f=1; \
	$(B)/tools/randvars $(B)/ailc 200 4 asyncs || f=1; exit $$f
else
	@f=0; AILC=$(B)/ailc tests/run.sh $(T) || f=1; tests/self.sh $(T) || f=1; exit $$f
endif

# A longer fuzz than the one in make test: N sources from SEED.
fuzz: $(B)/ailc
	tests/fuzz.sh $(or $(N),20000) $(or $(SEED),1)

# An installation (docs/cli.md): the command in bin/, and in lib/ail/
# what it looks for there, the compiler, the compiler for Windows, the
# formatter, the library and the manifest of AIL. DESTDIR is put before PREFIX, for a package that
# is put together in another place than it is installed to.
PREFIX ?= /usr/local
VERSION := $(shell sed -n 's/^version //p' Ailfile)

install: all
	tools/install.sh $(B) "$(DESTDIR)$(PREFIX)"

# The same files as one file to pass on, for x86-64 Linux:
# build/ail-<version>-x86_64-linux.tar.gz, which unpacks into a
# directory of that name with bin/ and lib/ in it.
DIST := ail-$(VERSION)-x86_64-linux
# and for x86-64 Windows, with the programs of Windows in the same
# places: build/ail-<version>-x86_64-windows.tar.gz, which the tar of
# Windows unpacks.
WDIST := ail-$(VERSION)-x86_64-windows

dist: all $(WAIL)
	rm -rf $(B)/$(DIST) $(B)/$(WDIST)
	tools/install.sh $(B) $(B)/$(DIST)
	tar -C $(B) --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 -czf $(B)/$(DIST).tar.gz $(DIST)
	tools/install.sh $(B) $(B)/$(WDIST) windows
	tar -C $(B) --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 -czf $(B)/$(WDIST).tar.gz $(WDIST)
	rm -rf $(B)/$(DIST) $(B)/$(WDIST)
	@echo $(B)/$(DIST).tar.gz
	@echo $(B)/$(WDIST).tar.gz

clean:
	rm -rf $(B)

.PHONY: all tools test fuzz install dist clean
