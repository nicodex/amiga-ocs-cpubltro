# GNU Make: <https://www.gnu.org/software/make/>
# vasm    : <http://www.compilers.de/vasm.html>
# romtool : <https://pypi.org/project/amitools/>

AMIGA_TOOLCHAIN ?= /opt/amiga
VASM ?= $(AMIGA_TOOLCHAIN)/bin/vasmm68k_mot
VASM_OPTS ?= -quiet -wfail -x
ROMTOOL ?= /usr/bin/env romtool
WINE ?= /usr/bin/env WINEDEBUG=-all wine
WINE_PWD ?= $(shell $(WINE) start /d $(shell pwd) /wait /b CMD /c CD)
WINUAE_ZIP ?= WinUAE5310.zip
WINUAE_URL ?= https://download.abime.net/winuae/releases/$(WINUAE_ZIP)
PYTHON_BIN ?= /usr/bin/env python3

all: cpubltro-ntsc.rom cpubltro-ntsc.adf cpubltro-pal.rom cpubltro-pal.adf

.PHONY: all \
	check check-ntsc check-pal \
	clean distclean \
	test test-ntsc test-pal test-pal-ntsc

check: check-ntsc check-pal

check-ntsc: cpubltro-ntsc.rom
	-$(ROMTOOL) copy --fix-checksum $< $<
	$(ROMTOOL) info $<

check-pal: cpubltro-pal.rom
	-$(ROMTOOL) copy --fix-checksum $< $<
	$(ROMTOOL) info $<

clean:
	rm -f cpubltro-ntsc.rom cpubltro-ntsc.rom.lst cpubltro-ntsc.adf
	rm -f cpubltro-pal.rom cpubltro-pal.rom.lst cpubltro-pal.adf
	rm -f images/balldata.i
	rm -f images/ntscdata.i
	rm -f images/ptrdata.i

cpubltro-ntsc.adf : cpubltro.adf.asm cpubltro-ntsc.rom
	$(VASM) -Fbin $(VASM_OPTS) -DROM_NTSC=1 -o $@ $<

cpubltro-ntsc.rom : cpubltro.asm images/ptrdata.i images/ntscdata.i
	$(VASM) -Fbin $(VASM_OPTS) -DROM_NTSC=1 -L $@.lst -o $@ $<

cpubltro-pal.adf : cpubltro.adf.asm cpubltro-pal.rom
	$(VASM) -Fbin $(VASM_OPTS) -DROM_NTSC=0 -o $@ $<

cpubltro-pal.rom : cpubltro.asm images/ptrdata.i images/balldata.i
	$(VASM) -Fbin $(VASM_OPTS) -DROM_NTSC=0 -L $@.lst -o $@ $<

distclean: clean
	rm -rf .idea
	rm -rf winuae

images/balldata.i: images/balleast/image000.png images/ballwest/image000.png
	(cd images && $(PYTHON_BIN) sprdata.py --pal)

images/ntscdata.i: images/ntsceast/image000.png images/ntscwest/image000.png
	(cd images && $(PYTHON_BIN) sprdata.py --ntsc)

images/ptrdata.i: images/pointer.png
	(cd images && $(PYTHON_BIN) ptrdata.py)

winuae/$(WINUAE_ZIP):
	mkdir -p winuae && cd winuae && wget $(WINUAE_URL)

winuae/winuae.exe: | winuae/$(WINUAE_ZIP)
	cd winuae && unzip $(WINUAE_ZIP)

WINUAE_GUI ?= false
WINUAE_DBG ?= false
WINUAE_OPT_GUI = \
	-s use_gui=$(WINUAE_GUI) \
	-s use_debugger=$(WINUAE_DBG) \
	-s win32.start_not_captured=$(WINUAE_DBG) \
	-s win32.nonotificationicon=true \

WINUAE_WIDTH ?= 1920
WINUAE_HEIGHT ?= 1080
WINUAE_API ?= direct3d
WINUAE_API_OPT ?= hardware
WINUAE_FULLSCREEN ?= $(if $(WINUAE_DBG:true=),true,false)
WINUAE_OVERSCAN ?= $(if $(WINUAE_DBG:true=),tv_narrow,ultra_csync)
WINUAE_OPT_GFX = \
	-s gfx_display=0 \
	-s gfx_width=$(WINUAE_WIDTH) \
	-s gfx_height=$(WINUAE_HEIGHT) \
	-s gfx_width_windowed=784 \
	-s gfx_height_windowed=636 \
	-s gfx_lores=true \
	-s gfx_resolution=lores \
	-s gfx_lores_mode=normal \
	-s gfx_flickerfixer=false \
	-s gfx_linemode=double \
	-s gfx_center_horizontal=none \
	-s gfx_center_vertical=none \
	-s gfx_api=$(WINUAE_API) \
	-s gfx_api_options=$(WINUAE_API_OPT) \
	-s gfx_overscanmode=$(WINUAE_OVERSCAN) \
	-s gfx_fullscreen_amiga=$(WINUAE_FULLSCREEN) \

WINUAE_OPT_EMU = \
	-s boot_rom_uae=disabled \
	-s uaeboard=disabled_off \
	-s genlock=false \
	-s cycle_exact=true \
	-s display_optimizations=none \

WINUAE_OPT_CPU = \
	-s cpu_type=68000 \
	-s cpu_model=68000 \
	-s cpu_speed=real \
	-s cpu_multiplier=2 \
	-s cpu_compatible=true \
	-s cpu_24bit_addressing=true \
	-s cpu_cycle_exact=true \
	-s cpu_memory_cycle_exact=true \

WINUAE_OPT_A1K = \
	-s chipset=ocs \
	-s fastmem_size=0 \
	-s chipmem_size=0 \
	-s chipset_compatible=A1000 \
	-s a1000ram=true \
	-s ics_agnus=true \
	-s agnusmodel=a1000 \
	-s denisemodel=a1000 \

test: test-ntsc test-pal

test-ntsc: cpubltro-ntsc.rom | winuae/winuae.exe
	cd winuae && $(WINE) winuae.exe \
		$(WINUAE_OPT_GUI) $(WINUAE_OPT_GFX) \
		$(WINUAE_OPT_EMU) $(WINUAE_OPT_CPU) \
		$(WINUAE_OPT_A1K) -s ntsc=true \
		-s kickstart_rom_file='$(WINE_PWD)\$<'

test-pal: cpubltro-pal.rom | winuae/winuae.exe
	cd winuae && $(WINE) winuae.exe \
		$(WINUAE_OPT_GUI) $(WINUAE_OPT_GFX) \
		$(WINUAE_OPT_EMU) $(WINUAE_OPT_CPU) \
		$(WINUAE_OPT_A1K) -s ntsc=false \
		-s kickstart_rom_file='$(WINE_PWD)\$<'

test-pal-ntsc: cpubltro-pal.rom | winuae/winuae.exe
	cd winuae && $(WINE) winuae.exe \
		$(WINUAE_OPT_GUI) $(WINUAE_OPT_GFX) \
		$(WINUAE_OPT_EMU) $(WINUAE_OPT_CPU) \
		$(WINUAE_OPT_A1K) -s ntsc=true \
		-s kickstart_rom_file='$(WINE_PWD)\$<'


