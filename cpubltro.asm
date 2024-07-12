; SPDX-FileCopyrightText: 2024 Nico Bendlin <nico@nicode.net>
; SPDX-License-Identifier: CC0-1.0
;-----------------------------------------------------------------------------
;
;		CPU drawing test ROM without any memory writes
;
;	Target:
;	  - Chipset with 7-bitplane anomaly (ICS, OCS, ECS)
;	    (Agnus 4-bitplane DMAs, Denise 6-bitplane DMAs,
;	    BPL5DAT/BPL6DAT can/have to be filled with CPU)
;	  - Motorola 68000/68010 CPU @ 7 MHz (fixed timing)
;	  - PAL on reset (NTSC possible, but needs rewrite)
;
; > vasmm68k_mot -Fbin -DROM_SIZE=262144 -o cpubltro-0fc.rom cpubltro.asm
; > vasmm68k_mot -Fbin -DROM_SIZE=524288 -o cpubltro-0f8.rom cpubltro.asm
;
	IDNT	CPUBLTRO_ROM

	MACHINE	68000
	FPU	0
	FAR
	OPT	P+ 	; position independent code
	OPT	D- 	; debug symbols off
	OPT	O- 	; all optimizations off
	OPT	OW+	; show optimizations on
	OPT	A+ 	; absolute to PC-relative

	IFND	ROM_SIZE
ROM_SIZE	EQU	256*1024
	ELSE
	IFNE	ROM_SIZE-(256*1024)
	IFNE	ROM_SIZE-(512*1024)
	FAIL	"ROM_SIZE has to be 262144 or 524288."
	ENDC
	ENDC
	ENDC
ROM_256K	EQU	($1111<<16)!$4EF9	; 256K ROM ID, JMP (ABS).L
ROM_512K	EQU	($1114<<16)!$4EF9	; 512K ROM ID, JMP (ABS).L
ROM_FILL	EQU	~0               	; EPROM/Flash optimization

	SECTION	cpubltro,CODE
	ORG	$01000000-ROM_SIZE

;-----------------------------------------------------------------------------
;
;		ROM header / CPU exception vector table
;
;	OVL is asserted on RESET and the ROM is also visible at $0.
;	The CPU uses vector[1] for the initial PC and vector[0] for
;	the initial (S)SP - but the Amiga ROMs include a ROM ID tag
;	and a jump instruction here (some firmwares just jump to $2
;	after mapping a flash ROM). So we have to init (S)SP later.
;
;	Because the ROM overlay is never disabled, this is also the
;	active CPU exception vector table. The reserved vectors are
;	used for meta information (Resident tag). For compatibility
;	reasons the initial Reset PC (ColdStart) is at offset $00D2
;	(which breaks the FPCP Operand Error exception vector #52).
;
RomBase:
; VEC_RESETSP=0 VEC_RESETPC=1
	IFEQ	ROM_SIZE-(512*1024)
		dc.l	ROM_512K
	ELSE
		dc.l	ROM_256K
	ENDC
		dc.l	ColdStart
; VEC_BUSERR=2 	; ROM diag pattern ($0000FFFF)
; VEC_ADDRERR=3	; ROM Kick version,revision
; VEC_ILLEGAL=4	; ROM Exec version,revision
; VEC_ZERODIV=5	; ROM System serial number
; VEC_CHK=6    	; Copyright, ROM/Exec strings...
; VEC_TRAP=7 VEC_PRIV=8 VEC_TRACE=9 VEC_LINE10=10 VEC_LINE11=11
		dcb.l	1-2+11,Exception
; VEC_RESV12=12
		; Release ROM footer checksum = 0
	IFEQ	ROM_SIZE-(512*1024)
		dc.l	$C73A8A47
	ELSE
		dc.l	$7B012D60
	ENDC
; VEC_COPROC=13 VEC_FORMAT=14 VEC_UNINT=15
		dcb.l	1-13+15,Exception
; VEC_RESV16=16 VEC_RESV17=17 VEC_RESV18=18 VEC_RESV19=19
; VEC_RESV20=20 VEC_RESV21=21 VEC_RESV22=22 VEC_RESV23=23
; VEC_SPUR=24
RomResStr:
		dc.b	'cpubltro',0,0
RomResTag:
		dc.w	$4AFC    	; RT_MATCHWORD (RTC_MATCHWORD)
		dc.l	RomResTag	; RT_MATCHTAG
		dc.l	RomResEnd	; RT_ENDSKIP
		dc.b	$00      	; RT_FLAGS (RTW_NEVER)
		dc.b	0        	; RT_VERSION
		dc.b	0        	; RT_TYPE (NT_UNKNOWN)
		dc.b	0        	; RT_PRI
		dc.l	RomResStr	; RT_NAME
		dc.l	RomResIDs	; RT_IDSTRING
		dc.l	Exception	; RT_INIT
; VEC_INT1=25 VEC_INT2=26 VEC_INT3=27 VEC_INT4=28 VEC_INT5=29 VEC_INT6=30
; VEC_INT7=31
; VEC_SYS=32 VEC_TRAP1=33 VEC_TRAP2=34 VEC_TRAP3=35 VEC_TRAP4=36 VEC_TRAP5=37
; VEC_TRAP6=38 VEC_TRAP7=39 VEC_TRAP8=40 VEC_TRAP9=41 VEC_TRAP10=42
; VEC_TRAP11=43 VEC_TRAP12=44 VEC_TRAP13=45 VEC_TRAP14=46 VEC_TRAP15=47
; VEC_FPBRUC=48 VEC_FPIR=49 VEC_FPDIVZ=50 VEC_FPUNDER=51
		dcb.l	1-25+51,Exception
; VEC_FPOE=52
ColdReset:
		reset	  	; ColdStart - 2 (software reset)
ColdStart:
		bra.b	0$	; Legacy compatibility ($__00D2)
; VEC_FPOVER=53 VEC_FPNAN=54 VEC_FPUNSUP=55
; VEC_MMUCFG=56 VEC_MMUILL=57 VEC_MMUACC=58
		dcb.l	1-53+58,Exception
; VEC_RESV59=59
0$:		bra.w	RomEntry
; VEC_UNIMPEA=60 VEC_UNIMPII=61
		dcb.l	1-60+61,Exception
; VEC_RESV62=62 VEC_RESV63=63
;
;   Well, this should not happen, since all chipset interrupts are disabled
;   and the CPU interrupt priority level only allows NMI - but who knows...
;
Exception:
		lea 	(0$,pc),sp
		rte
0$:		dc.w	%0010011100000000      	; general SR (S, IPL=7)
; VEC_USER=64 [192]
2$:		dc.l	ColdStart              	; general PC
6$:	;	dc.w	(%0000<<12)!(VEC_XXX*4)	; MC68010 format!offset
		dcb.l	1-65+255,ROM_FILL
	IFNE	(256*4)-(*-RomBase)
	FAIL	"Unexpected CPU vector table size, review the code."
	ENDC

;-----------------------------------------------------------------------------
;
;		ROM entry point
;
RomEntry:
;
; Initialize the (supervisor) stack.
;
;   It has to be decided which memory area will/would be used as the initial
;   supervisor stack. There is neither a specified, nor a safe memory region.
;   Initial Bootstrap/Kickstart supervisor stack pointers:
;   - $040000 A1000 Bootstrap, Kickstart 1.2/1.3
;   - $020000 Kickstart 0.7/1.0/1.1
;   - $000400 A3000 Bootstrap, Kickstart 2.x/3.x
;   The latter address is right at the end of the CPU exception vector table.
;   Since the stack grows down into the 192 User Interrupt exception vectors
;   (expected to be unused by Amiga hardware), the reset impact is minimized
;   (Kickstart will try to find/reuse the previous exec.library after reset).
;
;   This project does not want to write to anything the chipset registers.
;   Therefore, the stack will/cannot be used at all.
;
;   Special case: The Non-Maskable Interrupt (NMI) cannot be suppressed, and
;   the CPU will push the exception frame to the supervisor stack before the
;   exception vector is called. Because writing to any memory is not desired,
;   the supervisor stack is placed in ROM (exception frame/information lost).
;   Even if this ROM is run from a KICK floppy disk on the A1000, the loaded
;   ROM is write-protected (on reset the A1K Bootstrap is visible at $F80000
;   and the $FC0000 WCS/WOM is writable -- a write access to $F80000-$FBFFFF
;   enables the WCS/WOM write protection and Kickstart mirroring at $F80000).
;
		lea 	(RomEntry,pc),sp

;
; Disable/clear all interrupts.
;
		;  SR:	#%TTSM-III---XNZVC
		move.w	#%0010011100000000,sr	; supervisor mode, IPL = 7
		lea 	($DFF000),a6         	; _custom
		move.w	#$7FFF,d0            	; #~INTF_SETCLR
		move.w	d0,($09A,a6)         	; (intena,_custom)
		move.w	d0,($09C,a6)         	; (intreq,_custom)
;
; Disable all DMA.
;
	;	move.w	#$7FFF,d0   	; #~DMAF_SETCLR
		move.w	d0,($096,a6)	; (dmacon,_custom)

;
; {this would} Disable the ROM overlay.
;
;   For Gary-based systems the OVL-pin is set as output
;   and the /OVL-bit is cleared to disable the overlay.
;   On Gayle-based systems (some extension cards emulate
;   a Gayle, e.g. to add/provide IDE disks) the overlay
;   is disabled with a write access to a CIA-A register.
;
	;	move.b	#CIAF_LED!CIAF_OVERLAY,(_ciaa+ciaddra)
	;	bclr.b	#CIAB_OVERLAY,(_ciaa+ciapra)

MainInit:
	;	lea 	($DFF000),a6	; _custom
		lea 	($118,a6),a5	; (bpl5dat,_custom)
	;	lea 	(MainImage,pc),a4
		suba.l	a3,a3       	; zero

		; Wait for first line (>= 256, < 256)
0$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		beq.b	0$
1$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		bne.b	1$

		;
		; PAL LoRes 352x280x(6-4) (12,320 bytes/bitplane)
		;
MY_DIW_W	EQU	352	; (1 + 20 + 1) * 16
MY_DIW_H	EQU	280	; 16 + 256 + 8
MY_DIW_L	EQU	113	; (0x38 + 8.5) * 2 - 16
MY_DIW_T	EQU	28 	; 0x2C - 16
MY_DIW_R	EQU	MY_DIW_L+MY_DIW_W
MY_DIW_B	EQU	MY_DIW_T+MY_DIW_H
MY_DIWSTRT	EQU	(MY_DIW_T<<8)!MY_DIW_L
MY_DIWSTOP	EQU	((MY_DIW_B&$FF)<<8)!(MY_DIW_R&$FF)
MY_DDFSTRT	EQU	(MY_DIW_L-17)/2	; -8.5 * 2
MY_DDFSTOP	EQU	MY_DDFSTRT+((MY_DIW_W-16)/2)
MY_BPLCON0	EQU	%0111001000000100	; (7<<PLNCNTSHFT)!COLORON!LACE
MY_BPLxMOD	EQU	-(MY_DIW_W/8)    	; reset after every scanline
		move.w	#MY_DIWSTRT,($08E,a6)	; (diwstrt,_custom)
		move.w	#MY_DIWSTOP,($090,a6)	; (diwstop,_custom)
		move.w	#MY_DDFSTRT,($092,a6)	; (ddfstrt,_custom)
		move.w	#MY_DDFSTOP,($094,a6)	; (ddfstop,_custom)
		moveq	#6-1,d0
		lea 	($0E0,a6),a0         	; (bpl1pt,_custom)
2$:		move.l	a3,(a0)+
		dbf 	d0,2$
		move.w	#MY_BPLCON0,($100,a6)	; (bplcon0,_custom)
		move.l	a3,($102,a6)         	; (bplcon1/bplcon2,_custom)
		move.w	#MY_BPLxMOD,($108,a6)	; (bpl1mod,_custom)
		move.w	#MY_BPLxMOD,($10A,a6)	; (bpl2mod,_custom)
		move.l	a3,(a5)              	; (bpl5dat/bpl6dat,_custom)
		; Two colors (BPL5DAT) and half-bright (BPL6DAT)
		moveq	#(32/2)-1,d0
		lea 	($180,a6),a0         	; (color00,_custom)
3$:		move.w	#$005A,(16*2,a0)     	; (color16,_custom,i*2)
		move.w	#$0AAA,(a0)+         	; (color00,_custom,i*2)
		dbf 	d0,3$

		; Enable bitplane DMA (DMAF_SETCLR!DMAF_MASTER!DMAF_RASTER)
		move.w	#$8000!$0200!$0100,($096,a6)	; (dmacon,_custom)

MainLoop:
		; Wait for first line (>= 256, < 256)
0$:		btst.b	#0,($004+1,a6)	; (vposr:0,_custom)
		beq.b	0$
1$:		btst.b	#0,($004+1,a6)	; (vposr:0,_custom)
		bne.b	1$

		;
		; Initialize image source data pointer
		;
		lea 	(MainImage,pc),a4
		; Sync to VPOS (top - 1) and HPOS $E0/$E1
MY_SYNC_MAX	EQU	$E1-(2+4+4+4+4+4+7)+4	; +(Agnus - Denise HPOS)
MY_SYNC_MIN	EQU	MY_SYNC_MAX-(126-2-2)	; max bpl.b displacement
	IFNE	(MY_SYNC_MIN!MY_SYNC_MAX)&1
	FAIL	"Odd sync range, review the code."
	ENDC
		lea 	($006,a6),a0                        ; (vhposr,_custom)
2$:		move.w	(a0),d0                             ; .r.p        ; +2
		subi.w	#((MY_DIW_T-1)<<8)!MY_SYNC_MIN,d0   ; .p.p        ; +4
		bmi.b	2$                                  ; (..p.p)...p ; +4
		andi.w	#~1,d0                              ; .p.p        ; +4
		subi.w	#MY_SYNC_MAX-MY_SYNC_MIN,d0         ; .p.p        ; +4
		bpl.b	3$                                  ; (..p.p)...p ; +4
		jmp 	(3$,pc,d0.w)                        ; ....p.p     ; +7
	REPT	(MY_SYNC_MAX-MY_SYNC_MIN)/2
		nop 	                                    ; .p          ; +2
	ENDR
3$:		; unrolled draw loop (no time left for HSync code)
	REPT	MY_DIW_H
		movem.l	(a4)+,d0-a2	; $E[0]1-$2F .p.[-]R(.r.R){11}.p
		move.l	d0,(a5)    	; -1 $30-$35 .W.w.p
		move.l	(a4)+,(a5) 	;  1 $36-$3F .R.r.W.w.p
		move.l	d1,(a5)    	;  2 $40-$45 .W.w.p
		move.l	(a4)+,(a5) 	;  3 $46-$4F .R.r.W.w.p
		move.l	d2,(a5)    	;  4 $50-$55 .W.w.p
		move.l	(a4)+,(a5) 	;  5 $56-$5F .R.r.W.w.p
		move.l	d3,(a5)    	;  6 $60-$65 .W.w.p
		move.l	(a4)+,(a5) 	;  7 $66-$6F .R.r.W.w.p
		move.l	d4,(a5)    	;  8 $70-$75 .W.w.p
		move.l	(a4)+,(a5) 	;  9 $76-$7F .R.r.W.w.p
		move.l	d5,(a5)    	; 10 $80-$85 .W.w.p
		move.l	(a4)+,(a5) 	; 11 $86-$8F .R.r.W.w.p
		move.l	d6,(a5)    	; 12 $90-$95 .W.w.p
		move.l	(a4)+,(a5) 	; 13 $96-$9F .R.r.W.w.p
		move.l	d7,(a5)    	; 14 $A0-$A5 .W.w.p
		move.l	(a4)+,(a5) 	; 15 $A6-$AF .R.r.W.w.p
		move.l	a0,(a5)    	; 16 $B0-$B5 .W.w.p
		move.l	(a4)+,(a5) 	; 17 $B6-$BF .R.r.W.w.p
		move.l	a1,(a5)    	; 18 $C0-$C5 .W.w.p
		move.l	(a4)+,(a5) 	; 19 $C6-$CF .R.r.W.w.p
		move.l	a2,(a5)    	; 20 $D0-$D5 .W.w.p
		move.l	(a4)+,(a5) 	; +1 $D6-$DF .R.r.W.w.p
	ENDR
		move.l	a3,(a5)	; (bpl5dat/bpl6dat,_custom)
		beq.w	MainLoop

	INCLUDE	"cpubltro.i"
	IFNE	*-MainImage-(MY_DIW_W*MY_DIW_H*2/8)
	FAIL	"Unexpected image size, review the code/data."
	ENDC

RomResIDs:
		dc.b	'cpubltro.rom 0.2 (07.07.2024)',13,10,0
		dc.b	'(c) 2024 Nico Bendlin <nico@nicode.net>',0
		dc.b	'No Rights Reserved.',0
RomResEnd:

;
; Kickety-Split
;
;   2.04-like compatibility hack for legacy code that jumps to $FC0002
;
	IFGT	ROM_SIZE-(256*1024)
		dcb.b	(256*1024)-(*-RomBase),ROM_FILL
KickSplit:
		dc.l	ROM_256K 	; VEC_RESETSP
		dc.l	ColdStart	; VEC_RESETPC
		; not part of the legacy Kickety-Split
		dcb.l	1-2+51,Exception
		reset	  	; Legacy compatibility ($FC00D0)
		bra.b	0$	; Legacy compatibility ($FC00D2)
		dcb.l	1-53+58,Exception
0$:		bra.w	KickSplit+2
		dcb.l	1-60+255,Exception
	ENDC

;
; ROM footer
;
;   $FFFFE8: ROM checksum (not used, to be updated by the build process)
;   $FFFFEC: ROM size (not used, intended to be used for software reset)
;   $FFFFF0: CPU Autovector interrupt exception vector indices (MC68000)
;
		dcb.b	ROM_SIZE-(8*2)-(2*4)-(*-RomBase),ROM_FILL
RomFooter:
		dc.l	$00000000	; ROM checksum
		dc.l	ROM_SIZE 	; ROM size
		dc.b	0,24	; Spurious Interrupt
		dc.b	0,25	; Autovector Level 1 (TBE, DSKBLK, SOFTINT)
		dc.b	0,26	; Autovector Level 2 (PORTS)
		dc.b	0,27	; Autovector Level 3 (COPER, VERTB, BLIT)
		dc.b	0,28	; Autovector Level 4 (AUD2, AUD0, AUD3, AUD1)
		dc.b	0,29	; Autovector Level 5 (RBF, DSKSYNC)
		dc.b	0,30	; Autovector Level 6 (EXTER, INTEN)
		dc.b	0,31	; Autovector Level 7 (NMI)

	END
