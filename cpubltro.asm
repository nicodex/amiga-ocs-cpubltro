; SPDX-FileCopyrightText: 2024 Nico Bendlin <nico@nicode.net>
; SPDX-License-Identifier: CC0-1.0
;-----------------------------------------------------------------------------
;
;                  Racing The Beam on the Amiga without RAM
;
;	Target requirements:
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
;                   ROM header / CPU exception vector table
;
;         OVL is asserted on RESET and the ROM is also visible at $0.
;         The CPU uses vector[1] for the initial PC and vector[0] for
;         the initial (S)SP - but the Amiga ROMs include a ROM ID tag
;         and a jump instruction here (some firmwares just jump to $2
;         after mapping a flash ROM). So we have to init (S)SP later.
;
;         Because the ROM overlay is never disabled, this is also the
;         active CPU exception vector table. The reserved vectors are
;         used for meta information (Resident tag). For compatibility
;         reasons the initial Reset PC (ColdStart) is at offset $00D2
;         (which breaks the FPCP Operand Error exception vector #52).
;
RomBase:
; VEC_RESETSP=0 VEC_RESETPC=1
	IFEQ	ROM_SIZE-(512*1024)
		dc.l   	ROM_512K
	ELSE
		dc.l   	ROM_256K
	ENDC
		dc.l   	ColdStart
; VEC_BUSERR=2 	; ROM header: diag pattern ($0000FFFF)
; VEC_ADDRERR=3	; ROM header: Kick version,revision
; VEC_ILLEGAL=4	; ROM header: Exec version,revision
; VEC_ZERODIV=5	; ROM header: System serial number
; VEC_CHK=6    	; ROM header: Copyright, ROM/Exec strings...
; VEC_TRAP=7 VEC_PRIV=8 VEC_TRACE=9 VEC_LINE10=10 VEC_LINE11=11
		dcb.l  	1-2+11,Exception
; VEC_RESV12=12
		; Release ROM footer checksum = 0
	IFEQ	ROM_SIZE-(512*1024)
		dc.l   	$B01330E3
	ELSE
		dc.l   	$66940722
	ENDC
; VEC_COPROC=13 VEC_FORMAT=14 VEC_UNINT=15
		dcb.l  	1-13+15,Exception
; VEC_RESV16=16 VEC_RESV17=17 VEC_RESV18=18 VEC_RESV19=19
; VEC_RESV20=20 VEC_RESV21=21 VEC_RESV22=22 VEC_RESV23=23
; VEC_SPUR=24
RomResStr:
		dc.b   	'cpubltro',0,0
RomResTag:
		dc.w   	$4AFC    	; RT_MATCHWORD (RTC_MATCHWORD)
		dc.l   	RomResTag	; RT_MATCHTAG
		dc.l   	RomResEnd	; RT_ENDSKIP
		dc.b   	$00      	; RT_FLAGS (RTW_NEVER)
		dc.b   	0        	; RT_VERSION
		dc.b   	0        	; RT_TYPE (NT_UNKNOWN)
		dc.b   	0        	; RT_PRI
		dc.l   	RomResStr	; RT_NAME
		dc.l   	RomResIDs	; RT_IDSTRING
		dc.l   	Exception	; RT_INIT
; VEC_INT1=25 VEC_INT2=26 VEC_INT3=27 VEC_INT4=28 VEC_INT5=29 VEC_INT6=30
; VEC_INT7=31 VEC_SYS=32 VEC_TRAP1=33 VEC_TRAP2=34 VEC_TRAP3=35 VEC_TRAP4=36
; VEC_TRAP5=37 VEC_TRAP6=38 VEC_TRAP7=39 VEC_TRAP8=40 VEC_TRAP9=41
; VEC_TRAP10=42 VEC_TRAP11=43 VEC_TRAP12=44 VEC_TRAP13=45 VEC_TRAP14=46
; VEC_TRAP15=47 VEC_FPBRUC=48 VEC_FPIR=49 VEC_FPDIVZ=50 VEC_FPUNDER=51
		dcb.l  	1-25+51,Exception
; VEC_FPOE=52
ColdReset:
		reset  	  	; ColdStart - 2 (software reset)
ColdStart:
		bra.b  	0$	; Legacy compatibility ($__00D2)
; VEC_FPOVER=53 VEC_FPNAN=54 VEC_FPUNSUP=55
; VEC_MMUCFG=56 VEC_MMUILL=57 VEC_MMUACC=58
		dcb.l  	1-53+58,Exception
; VEC_RESV59=59
0$:		bra.w  	RomEntry
; VEC_UNIMPEA=60 VEC_UNIMPII=61
		dcb.l  	1-60+61,Exception
; VEC_RESV62=62 VEC_RESV63=63
;
;   Well, this should not happen, since all chipset interrupts are disabled
;   and the CPU interrupt priority level only allows NMI... I'm pretty sure
;   there's someone out there who wants to try out their cool NMI switch...
;
Exception:
		lea    	(0$,pc),sp
		rte
0$:		dc.w   	%0010011100000000  	; general SR (S, IPL=7)
; VEC_USER=64 [192]	; expected to be unused by Amiga hardware
2$:		dc.l   	ColdStart          	; general PC
6$:		dc.w   	(%0000<<12)!(31*4) 	; MC68010 format!offset
		dcb.b  	(*-RomBase)&%0010,0	; long align
		dcb.b  	(*-RomBase)&%0100,0	; long long align
		dcb.b  	(*-RomBase)&%1000,0	; paragraph align
RomResIDs:
		dc.b   	'cpubltro.rom 0.3 (15.11.2024)',13,10,0
		dc.b   	'(c) 2024 Nico Bendlin <nico@nicode.net>',10
		dc.b   	'No Rights Reserved.',0
		dc.b   	'https://github.com/nicodex/amiga-ocs-cpubltro',0
		dcb.b  	(*-RomBase)&%0001,0
		dcb.b  	(*-RomBase)&%0010,0
		dcb.b  	(*-RomBase)&%0100,0
		dcb.b  	(*-RomBase)&%1000,0

;-----------------------------------------------------------------------------
;
;                               ROM entry point
;
;  It has to be decided which memory area will/would be used as the initial
;  supervisor stack. There is neither a specified, nor a safe memory region.
;  Initial Bootstrap/Kickstart supervisor stack pointers:
;    - $040000 A1000 Bootstrap, Kickstart 1.2/1.3
;    - $020000 Kickstart 0.7/1.0/1.1
;    - $000400 A3000 Bootstrap, Kickstart 2.x/3.x
;  The latter address is right at the end of the CPU exception vector table.
;  Since the stack grows down into the 192 User Interrupt exception vectors
;  (expected to be unused by Amiga hardware), the reset impact is minimized
;  (Kickstart will try to find/reuse the previous exec.library after reset).
;
;  Special case: The Non-Maskable Interrupt (NMI) cannot be suppressed, and
;  the CPU will push the exception frame to the supervisor stack before the
;  exception vector is called. Because writing to any memory is not desired,
;  the supervisor stack is placed in ROM (exception frame/information lost).
;  Even if this ROM is run from a KICK floppy disk on the A1000, the loaded
;  ROM is write-protected (on reset the A1K Bootstrap is visible at $F80000
;  and the $FC0000 WCS/WOM is writable -- a write access to $F80000-$FBFFFF
;  enables the WCS/WOM write protection and Kickstart mirroring at $F80000).
;
RomEntry:
		lea    	(RomEntry,pc),sp
		;
		; disable/clear all interrupts
		;
		;  SR: 	#%TTSM-III---XNZVC
		move.w 	#%0010011100000000,sr	; supervisor mode, IPL = 7
		lea    	($DFF000),a0         	; _custom
		move.w 	#$7FFF,d0            	; #~INTF_SETCLR
		move.w 	d0,($09A,a0)         	; (intena,_custom)
		move.w 	d0,($09C,a0)         	; (intreq,_custom)
		;
		; disable all DMA
		;
	;	move.w 	#$7FFF,d0   	; #~DMAF_SETCLR
		move.w 	d0,($096,a0)	; (dmacon,_custom)
		;
		; {this would} disable the ROM overlay
		;
		;   For Gary-based systems the OVL-pin is set as output
		;   and the /OVL-bit is cleared to disable the overlay.
		;   On Gayle-based systems (some extension cards emulate
		;   a Gayle, e.g. to add/provide IDE disks) the overlay
		;   is disabled with a write access to a CIA-A register.
		;
	;	move.b 	#CIAF_LED!CIAF_OVERLAY,(_ciaa+ciaddra)
	;	bclr.b 	#CIAB_OVERLAY,(_ciaa+ciapra)

;-----------------------------------------------------------------------------
;
;                    PAL LoRes 320x256x3 interlaced screen
;
MY_DIW_W  	EQU	320
MY_DIW_H  	EQU	256
MY_DIW_L  	EQU	129	; $81 = LoRes (DDFSTRT + 8.5) * 2
MY_DIW_T  	EQU	44 	; $2C = NTSC/PAL default
MY_DIW_R  	EQU	MY_DIW_L+MY_DIW_W                 	; $[1]C1
MY_DIW_B  	EQU	MY_DIW_T+MY_DIW_H                 	; $[1]2C
MY_DIWSTRT	EQU	(MY_DIW_T<<8)!MY_DIW_L            	; $2C81
MY_DIWSTOP	EQU	((MY_DIW_B&$FF)<<8)!(MY_DIW_R&$FF)	; $2CC1
MY_DDFSTRT	EQU	(MY_DIW_L-17)/2 ; -(8.5 * 2)      	; $38
MY_DDFSTOP	EQU	MY_DDFSTRT+((MY_DIW_W-16)/2)      	; $D0
MY_BPLCON0	EQU	%0011001000000100    	; (3<<PLNCNTSHFT)!COLORON!LACE
MY_BPLxMOD	EQU	(-(MY_DIW_W/8))&$FFFF	; reset after every scanline
MY_DIWLONG	EQU	(MY_DIWSTRT<<16)!MY_DIWSTOP
MY_DDFLONG	EQU	(MY_DDFSTRT<<16)!MY_DDFSTOP
MY_MODLONG	EQU	(MY_BPLxMOD<<16)!MY_BPLxMOD
		;
		; wait for first line (>= 256, < 256)
		;
		moveq  	#0,d0
	;	lea    	($DFF000),a0  	; _custom
0$:		btst.b 	d0,($004+1,a0)  ; (vposr:V8,_custom)
		beq.b  	0$
1$:		btst.b 	d0,($004+1,a0)  ; (vposr:V8,_custom)
		bne.b  	1$
		;
		; initialize display
		;
		move.l 	#MY_DIWLONG,($08E,a0)	; (diwstrt/diwstop,_custom)
		move.l 	#MY_DDFLONG,($092,a0)	; (ddfstrt/ddfstop,_custom)
		moveq  	#3-1,d1
	;	moveq  	#0,d0
		lea    	($0E0,a0),a1         	; (bpl1pt-bpl3pt,_custom)
2$:		move.l 	d0,(a1)+
		dbf    	d1,2$
		move.w 	#MY_BPLCON0,($100,a0)	; (bplcon0,_custom)
	;	moveq  	#0,d0
		move.l 	d0,($102,a0)         	; (bplcon1/bplcon2,_custom)
		move.l 	#MY_MODLONG,($108,a0)	; (bpl1mod/bpl2mod,_custom)
		moveq  	#((1<<3)*2/4)-1,d1
		lea    	($180,a0),a1         	; (color00-color07,_custom)
	;	moveq  	#0,d0
3$:		move.l 	d0,(a1)+
		dbf    	d1,3$
		;
		; Enable bitplane DMA.
		;
		move.w 	#$8000!$0200!$0100,($096,a0)	; (dmacon,_custom)

;-----------------------------------------------------------------------------
;
;                   Draw routine uses every register but D0
;
MY_IMG_BYTES	EQU	4*2+(MY_DIW_H*(2*4+(MY_DIW_W/8*2)))
	IFEQ	ROM_SIZE-(512*1024)
MY_IMG_COUNT	EQU	11*2
	ELSE
MY_IMG_COUNT	EQU	11
	ENDC
	;	moveq  	#0,d0
DrawLoop:
		lea    	($DFF000),a0  	; _custom
		;
		; wait for first line (>= 256, < 256)
		;
		moveq  	#0,d1
0$:		btst.b 	d1,($004+1,a0)   	; (vposr:V8,_custom)
		beq.b  	0$
1$:		btst.b 	d1,($004+1,a0)   	; (vposr:V8,_custom)
		bne.b  	1$
		; wait for VHPOS change before reading LOF (ICS)
		move.w 	($006,a0),d1     	; (vhposr,_custom)
2$:		cmp.w  	($006,a0),d1     	; (vhposr,_custom)
		beq.b  	2$
		moveq  	#1,d1
		; insert short/even field bit in counter
		btst.b 	#15-8,($004+0,a0)	; (vposr:LOF,_custom)
		bne.b  	3$
		or.b   	d1,d0
3$:		;
		; select current frame image (two fields)
		;
		lea    	(DrawData,pc),a6
		move.l 	d0,d2
		lsr.l  	d1,d2
		mulu.w 	#MY_IMG_BYTES,d2
		adda.l 	d2,a6
		; advance/reset reset field counter
		addq.l 	#1,d0
		cmpi.w  #(MY_IMG_COUNT<<1),d0
		blo.b  	4$
		moveq  	#0,d0
4$:		; load initial image palette colors
		lea    	($180,a0),a1  	; (color00,_custom)
		moveq  	#4-1,d2
5$:		move.w 	(a6),d1
		swap   	d1
		move.w 	(a6)+,d1
		move.l 	d1,(a1)+
		dbf    	d2,5$
		;
		; sync to MY_DIW_T - 1 / time slot $DA/$DB
		;
MY_SYNC_MAX	EQU	($DA+(9/2))-(-1+4+2+2+7)            	; $D0
MY_SYNC_POS	EQU	MY_SYNC_MAX-(-2+4+2+5)-(4+2+4)-(4-3)	; $BC
MY_SYNC_MIN	EQU	MY_SYNC_POS+(-1+4+2+3)+(4-3)-1      	; $C5-1
	IFNE	(MY_SYNC_MAX!MY_SYNC_POS!MY_SYNC_MIN)&1
	FAIL	"Sync position odd, review the code."
	ENDC
MY_SYNC_TAB	EQU	(1<<4)-2
	IFLT	MY_SYNC_TAB-(MY_SYNC_MAX-MY_SYNC_MIN)
	FAIL	"Sync table overflow, review the code."
	ENDC
		lea    	($006,a0),a1	; (vhposr,_custom)
		lea    	($112,a0),sp	; (bpl2dat/bpl3dat,_custom)
		move.w 	#((MY_DIW_T-1)<<8)!MY_SYNC_POS,d2
		move.w 	#((MY_DIW_T-1)<<8)!(MY_SYNC_MAX-MY_SYNC_TAB),d3
		move.w 	#MY_SYNC_TAB,d4
6$:		move.w 	(a1),d1     	; .r.p
		cmp.w  	d2,d1       	; .p
		blo.b  	6$          	; [.]..p/..p.p (continue/branch)
		move.w 	(a1),d1     	; .r.p
		sub.w  	d3,d1       	; .p
		and.w  	d4,d1       	; .p
		jmp    	(7$,pc,d1.w)	; ....p.p
7$:
	REPT	MY_SYNC_TAB/2
		nop
	ENDR
		;
		; completely unrolled draw loop
		;
	REPT	MY_DIW_H
		movem.l	(a6)+,d1-a5	; $DA-$30 .p(.R.r){13}.R.p
		move.l 	d7,(a0)    	; $31-$36 .W.w.p     	; 6/7> Cn
		move.l 	(a6)+,(sp)+	; $37-$41 .R.r.-W.w.p	;  13>  0
		pea    	(a1);-(sp) 	; $42-$47    .p.W.w  	;   8>  1
		move.l 	(a6)+,(sp)+	; $48-$51  .R.r.W.w.p	;  14>  2
		pea    	(a2);-(sp) 	; $52-$57    .p.W.w  	;   9>  3
		move.l 	(a6)+,(sp)+	; $58-$61  .R.r.W.w.p	;  15>  4
		pea    	(a3);-(sp) 	; $62-$67    .p.W.w  	;  10>  5
		move.l 	(a6)+,(sp)+	; $68-$71  .R.r.W.w.p	;  16>  6
		pea    	(a4);-(sp) 	; $72-$77    .p.W.w  	;  11>  7
		move.l 	(a6)+,(sp)+	; $78-$11  .R.r.W.w.p	;  17>  8
		pea    	(a5);-(sp) 	; $82-$87    .p.W.w  	;  12>  9
		move.l 	(a6)+,(sp) 	; $88-$91  .R.r.W.w.p	;  18> 10
		movea.l	d4,a1      	; $92-$93    .p      	; > 3
		move.l 	d1,(sp)    	; $94-$99      .W.w.p	;   0> 11
		movea.l	d5,a2      	; $9A-$9B    .p      	; > 4
		move.l 	d2,(sp)    	; $9C-$A1      .W.w.p	;   1> 12
		movea.l	d6,a3      	; $A2-$A3    .p      	; > 5
		move.l 	d3,(sp)+   	; $A4-$A9      .W.w.p	;   2> 13
		pea    	(a1);-(sp) 	; $AA-$AF    .p.W.w  	;   3> 14
		move.l 	(a6)+,(sp)+	; $B0-$B9  .R.r.W.w.p	;  19> 15
		pea    	(a2);-(sp) 	; $BA-$BF    .p.W.w  	;   4> 16
		move.l 	(a6)+,(sp)+	; $C0-$C9  .R.r.W.w.p	;  20> 17
		pea    	(a3);-(sp) 	; $CA-$CF    .p.W.w  	;   5> 18
		move.l 	(a6)+,(sp) 	; $D0-$D9  .R.r.W.w.p	;  21> 19
	ENDR
		lea    	(RomEntry,pc),sp
		bra.w  	DrawLoop
		dcb.b  	(*-RomBase)&%0010,ROM_FILL
DrawData:
	INCLUDE	"cpubltro.i"
	IFNE	*-DrawData-(MY_IMG_BYTES*MY_IMG_COUNT)
	FAIL	"Unexpected draw data size, review the code/data."
	ENDC

RomResEnd:

;
; Kickety-Split
;
;   2.04-like compatibility hack for legacy code that jumps to $FC0002
;
;	IFGT	ROM_SIZE-(256*1024)
;		dcb.b  	(256*1024)-(*-RomBase),ROM_FILL
;KickSplit:
;		dc.l   	ROM_256K 	; VEC_RESETSP
;		dc.l   	ColdStart	; VEC_RESETPC
;		;
;		; not part of the legacy Kickety-Split
;		;
;		dcb.l  	1-2+51,Exception
;		reset  	  	; Legacy compatibility ($FC00D0)
;		bra.b  	0$	; Legacy compatibility ($FC00D2)
;		dcb.l  	1-53+58,Exception
;0$:		bra.w  	KickSplit+2
;		dcb.l  	1-60+64,Exception
;	ENDC

;
; ROM footer
;
;   $FFFFE8: ROM checksum (not used, to be updated by the build process)
;   $FFFFEC: ROM size (not used, intended to be used for software reset)
;   $FFFFF0: CPU Autovector interrupt exception vector indices (MC68000)
;
		dcb.b  	ROM_SIZE-(8*2)-(2*4)-(*-RomBase),ROM_FILL
RomFooter:
		dc.l   	$00000000	; ROM checksum
		dc.l   	ROM_SIZE 	; ROM size
		dc.b   	0,24	; Spurious Interrupt
		dc.b   	0,25	; Autovector Level 1 (TBE, DSKBLK, SOFTINT)
		dc.b   	0,26	; Autovector Level 2 (PORTS)
		dc.b   	0,27	; Autovector Level 3 (COPER, VERTB, BLIT)
		dc.b   	0,28	; Autovector Level 4 (AUD2, AUD0, AUD3, AUD1)
		dc.b   	0,29	; Autovector Level 5 (RBF, DSKSYNC)
		dc.b   	0,30	; Autovector Level 6 (EXTER, INTEN)
		dc.b   	0,31	; Autovector Level 7 (NMI)

	END
