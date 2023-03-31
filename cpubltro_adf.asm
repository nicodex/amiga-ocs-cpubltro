; SPDX-FileCopyrightText: 2023 Nico Bendlin <nico@nicode.net>
; SPDX-License-Identifier: CC0-1.0
;
;	Pack 256K ROM as Kickstart disk for Amiga 1000 bootstrap.
;
;	> vasmm68k_mot -Fbin -o cpubltro.adf cpubltro_adf.asm
;
	IDNT	CPUBLTRO_ADF

Sector0:
		dc.b	'KICK'
		dcb.b	512-4,0

RomImage:
	INCBIN	cpubltro.rom

DiskSpare:
		dcb.b	80*2*11*512-(*-Sector0),0

	END
