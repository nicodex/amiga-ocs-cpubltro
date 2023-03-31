# SPDX-FileCopyrightText: 2023 Nico Bendlin <nico@nicode.net>
# SPDX-License-Identifier: CC0-1.0

# GNU Make: <https://www.gnu.org/software/make/>
# vasm    : <http://www.compilers.de/vasm.html>
# romtool : <https://pypi.org/project/amitools/>
# FS-UAE  : <https://fs-uae.net/>

AMIGA_TOOLCHAIN ?= /opt/amiga
VASM ?= $(AMIGA_TOOLCHAIN)/bin/vasmm68k_mot
VASM_OPTS ?= -quiet -wfail -x
ROMTOOL ?= /usr/bin/env romtool
FSUAE ?= /usr/bin/env fs-uae
RM = rm -f

all: cpubltro.rom cpubltro.adf

.PHONY: all clean check test test-adf

cpubltro.rom : cpubltro_rom.asm
	$(VASM) -Fbin $(VASM_OPTS) -o $@ $<
	-$(ROMTOOL) copy --fix-checksum $@ $@

cpubltro.adf : cpubltro_adf.asm cpubltro.rom
	$(VASM) -Fbin $(VASM_OPTS) -o $@ $<

clean:
	$(RM) cpubltro.rom
	$(RM) cpubltro.adf

check: cpubltro.rom
	$(ROMTOOL) info $<

test: cpubltro_rom.fs-uae cpubltro.rom
	-$(ROMTOOL) romtool info cpubltro.rom
	$(FSUAE) $<

test-adf: cpubltro_adf.fs-uae cpubltro.adf
	$(FSUAE) $<

