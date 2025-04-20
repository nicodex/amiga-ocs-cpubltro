# GNU Make: <https://www.gnu.org/software/make/>
# vasm    : <http://www.compilers.de/vasm.html>
# romtool : <https://pypi.org/project/amitools/>

AMIGA_TOOLCHAIN ?= /opt/amiga
VASM ?= $(AMIGA_TOOLCHAIN)/bin/vasmm68k_mot
VASM_OPTS ?= -quiet -wfail -x
ROMTOOL ?= /usr/bin/env romtool
WINE ?= /usr/bin/env wine
WINUAE_ZIP ?= WinUAE5310.zip
WINUAE_URL ?= https://download.abime.net/winuae/releases/$(WINUAE_ZIP)
PYTHON_BIN ?= /usr/bin/env python3

all: cpubltro.rom cpubltro.adf

.PHONY: all clean distclean check test

images/ptrdata.i: images/pointer.png
	(cd images && $(PYTHON_BIN) ptrdata.py)

images/balldata.i: images/balleast/image000.png images/ballwest/image000.png
	(cd images && $(PYTHON_BIN) sprdata.py)

cpubltro.rom : cpubltro.asm images/ptrdata.i images/balldata.i
	$(VASM) -Fbin $(VASM_OPTS) -o $@ $<
	-$(ROMTOOL) copy --fix-checksum $@ $@

cpubltro.adf : cpubltro.adf.asm cpubltro.rom
	$(VASM) -Fbin $(VASM_OPTS) -o $@ $<

clean:
	rm -f images/ptrdata.i
	rm -f images/balldata.i
	rm -f cpubltro.rom cpubltro.adf

distclean:
	rm -rf .idea
	rm -rf winuae

check: cpubltro.rom
	$(ROMTOOL) info $<

winuae/$(WINUAE_ZIP):
	mkdir -p winuae && cd winuae && wget $(WINUAE_URL)

winuae/winuae.exe: | winuae/$(WINUAE_ZIP)
	cd winuae && unzip $(WINUAE_ZIP)

test: cpubltro.rom | winuae/winuae.exe
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
		-s gfx_width=1920 \
		-s gfx_height=1080 \
		-s gfx_width_windowed=784 \
		-s gfx_height_windowed=636 \
		-s gfx_lores=true \
		-s gfx_resolution=lores \
		-s gfx_lores_mode=normal \
		-s gfx_flickerfixer=false \
		-s gfx_linemode=double \
		-s gfx_center_horizontal=smart \
		-s gfx_center_vertical=smart \
		-s gfx_api=direct3d \
		-s gfx_api_options=hardware \
		-s gfx_overscanmode=tv_normal \
		-s gfx_fullscreen_amiga=true \
		-s win32.start_not_captured=false \
		-s win32.nonotificationicon=true \
		2> /dev/null


