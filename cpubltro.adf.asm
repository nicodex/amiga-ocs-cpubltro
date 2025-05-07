;-----------------------------------------------------------------------------
;
;	Pack 256K ROM as Kickstart disk for Amiga 1000 bootstrap.
;
; > vasmm68k_mot -Fbin -DROM_NTSC=1 -o cpubltro-ntsc.adf cpubltro.adf.asm
; > vasmm68k_mot -Fbin -DROM_NTSC=0 -o cpubltro-pal.adf cpubltro.adf.asm
;
	IFND	ROM_NTSC
ROM_NTSC	EQU	0
	ENDC

	IDNT	CPUBLTRO_ADF

Sector0:
		dc.b	'KICK'
		dcb.b	512-4,0

	IFNE	ROM_NTSC
	INCBIN	cpubltro-ntsc.rom
	ELSE
	INCBIN	cpubltro-pal.rom
	ENDC

		dcb.b	80*2*11*512-(*-Sector0),0

	END
