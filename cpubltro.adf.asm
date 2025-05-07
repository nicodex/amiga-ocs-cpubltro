;-----------------------------------------------------------------------------
;
;	Pack 256K ROM as Kickstart disk for Amiga 1000 bootstrap.
;
; > vasmm68k_mot -Fbin -o cpubltro.adf cpubltro.adf.asm
;
	IDNT	CPUBLTRO_ADF

Sector0:
		dc.b	'KICK'
		dcb.b	512-4,0

	INCBIN	cpubltro.rom

		dcb.b	80*2*11*512-(*-Sector0),0

	END
