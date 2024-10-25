# GNU Make: <https://www.gnu.org/software/make/>
# vasm    : <http://www.compilers.de/vasm.html>
# romtool : <https://pypi.org/project/amitools/>

AMIGA_TOOLCHAIN ?= /opt/amiga
VASM ?= $(AMIGA_TOOLCHAIN)/bin/vasmm68k_mot
VASM_OPTS ?= -quiet -wfail -x
ROMTOOL ?= /usr/bin/env romtool
WINE ?= /usr/bin/env wine
WINUAE_ZIP ?= WinUAE5300.zip
WINUAE_URL ?= https://download.abime.net/winuae/releases/$(WINUAE_ZIP)

all: cpubltro-0fc.rom cpubltro-a1k.adf cpubltro-0f8.rom cpubltro-0f8.bin

.PHONY: all clean distclean check check1 check2 test test1

cpubltro.i: cpubltro.py cpubltro.png
	python3 $<

cpubltro-0fc.rom : cpubltro.asm cpubltro.i
	$(VASM) -Fbin -DROM_SIZE=262144 $(VASM_OPTS) -o $@ $<
	-$(ROMTOOL) copy --fix-checksum $@ $@

cpubltro-a1k.adf : cpubltro-a1k.asm cpubltro-0fc.rom
	$(VASM) -Fbin $(VASM_OPTS) -o $@ $<

cpubltro-0f8.rom : cpubltro.asm cpubltro.i
	$(VASM) -Fbin -DROM_SIZE=524288 $(VASM_OPTS) -o $@ $<
	-$(ROMTOOL) copy --fix-checksum $@ $@

cpubltro-0f8.bin: cpubltro-0f8.rom
	dd conv=swab if=$< of=$@

clean:
	rm -f cpubltro.i
	rm -f cpubltro-0fc.rom cpubltro-a1k.adf
	rm -f cpubltro-0f8.rom cpubltro-0f8.bin

distclean:
	rm -rf .idea
	rm -rf winuae
	rm -f cpubltro.i

check: check1 check2

check1: cpubltro-0fc.rom
	$(ROMTOOL) info $<

check2: cpubltro-0f8.rom
	$(ROMTOOL) info $<

winuae/$(WINUAE_ZIP):
	mkdir -p winuae && cd winuae && wget $(WINUAE_URL)

winuae/winuae.exe: | winuae/$(WINUAE_ZIP)
	cd winuae && unzip $(WINUAE_ZIP)

test: test1

test1: cpubltro-0fc.rom | winuae/winuae.exe
	cd winuae && $(WINE) winuae.exe -s use_gui=false \
		-s kickstart_rom_file="Z:$(subst /,\,$(abspath $<))" \
		-s boot_rom_uae=disabled \
		-s ntsc=false \
		-s genlock=false \
		-s chipset=ocs \
		-s chipset_compatible=A1000 \
		-s a1000ram=true \
		-s ics_agnus=true \
		-s agnusmodel=a1000 \
		-s denisemodel=a1000 \
		-s cycle_exact=true \
		-s cpu_type=68000 \
		-s cpu_model=68000 \
		-s cpu_speed=real \
		-s cpu_multiplier=2 \
		-s cpu_compatible=true \
		-s cpu_24bit_addressing=true \
		-s cpu_cycle_exact=true \
		-s cpu_memory_cycle_exact=true \
		-s fastmem_size=0 \
		-s chipmem_size=0 \
		-s gfx_display=0 \
		-s gfx_width=720 \
		-s gfx_height=568 \
		-s gfx_width_windowed=720 \
		-s gfx_height_windowed=568 \
		-s gfx_lores=true \
		-s gfx_resolution=lores \
		-s gfx_lores_mode=normal \
		-s gfx_flickerfixer=false \
		-s gfx_linemode=double2 \
		-s gfx_center_horizontal=none \
		-s gfx_center_vertical=none \
		-s gfx_api=directdraw \
		-s gfx_api_options=hardware \
		-s win32.start_not_captured=true \
		-s win32.nonotificationicon=true

