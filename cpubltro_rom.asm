; SPDX-FileCopyrightText: 2023 Nico Bendlin <nico@nicode.net>
; SPDX-License-Identifier: CC0-1.0
;
;	CPU drawing 256K ROM without any memory writes (Proof of Concept)
;
;	Target:
;	  - PAL OCS/ECS with 7(4+2)-bitplane anomaly
;	    (Agnus: 4-bitplane DMAs, Denise: 6-bitplane EHB,
;	    BPL5DAT/BPL6DAT can/have to be filled with CPU)
;	  - Motorola 68000/68010 CPU @ 7 MHz
;
;	> vasmm68k_mot -Fbin -o cpubltro.rom cpubltro_rom.asm
;
	IDNT	CPUBLTRO_ROM

	MACHINE	68000
	FPU	0
	FAR
	OPT	P+      ; position independent code
	OPT	D-      ; debug symbols
	OPT	O-      ; all optimizations
	OPT	OW+     ; show optimizations
	OPT	A+      ; absolute to PC-relative

	SECTION	cpubltro,CODE
	ORG	$FC0000

;
; RESET vectors
;
; OVL is asserted on reset and the ROM is also visible at #0.
; The CPU uses vector[1] for the initial PC and vector[0] for
; the initial (S)SP. But the Amiga ROMs include a ROM ID tag
; and a jump instruction here (some firmwares just jump to #2
; after mapping a flash ROM). So we have to init (S)SP later.
;
RomBase:
		dc.w	$1111,$4EF9     ; 256K ROM ID, JMP (VEC_RESETSP)
		dc.l	ColdStart       ; VEC_RESETPC

;
; Dummy ROM header to make some ROM parsers happy.
;
RomHeader:
		dc.l	$0000FFFF       ; diag pattern (VEC_BUSERR)
		dc.w	0,2             ; Kick version,revision (VEC_ADDRERR)
		dc.w	0,0             ; Exec version,revision (VEC_ILLEGAL)
		dc.l	-1              ; System serial number (VEC_ZERODIV)
		dc.b	0               ; Kick strings (VEC_CHK,...)
		dc.b	'CPU Blit Read-Only ROM',0
		dc.b	'Copyright (c) 2023 ',0
		dc.b	'Nico Bendlin ',0
		dc.b	'No Rights Reserved.',0
		dc.b	'Test ROM ',0
RomTagName:
		dc.b	'cpubltro.rom',0
RomTagIdString:
		dc.b	'cpubltro 0.2 (07.07.2023)',13,10,0
		dcb.b	*&1,0       ; align to word
;
; Dummy ROM resident tag to make some ROM parsers happy.
;
RomTag:		dc.w	$4AFC       ; RTC_MATCHWORD
		dc.l	RomTag
		dc.l    RomTagEnd
		dc.b    $02         ; RTF_SINGLETASK
		dc.b    0           ; RT_VERSION
		dc.b    0           ; NT_UNKNOWN
		dc.b    127         ; RT_PRI
		dc.l    RomTagName
		dc.l    RomTagIdString
		dc.l    ColdReset

;
; Force default ColdReset/ColdStart offsets (compatibility).
;
		dcb.b	($00D0-(*-RomBase)),0
ColdReset:
		reset   ; second reset (ColdReboot)
;
; ROM entry point
;
ColdStart:
		;
		; Disable/clear all interrupts.
		;
		;  SR:	#%TTSM-III---XNZVC
		move.w	#%0010011100000000,sr   ; supervisor mode, IPL = 7
		lea	($DFF000),a6            ; _custom
		move.w	#$7FFF,d0               ; #~INTF_SETCLR
		move.w	d0,($09A,a6)            ; (intena,_custom)
		move.w	d0,($09C,a6)            ; (intreq,_custom)
		;
		; Disable all DMA.
		;
	;	move.w	#$7FFF,d0       ; #~DMAF_SETCLR
		move.w	d0,($096,a6)    ; (dmacon,_custom)
		;
		; Initialize the (supervisor) stack.
		;
		;   We have to decide which memory to use for the
		;   intial supervisor stack. There is neither a
		;   specified, nor a safe region (some examples:
		;   - $040000 A1000 bootstrap, Kickstart 1.2/1.3
		;   - $020000 Kickstart 0.7/1.0/1.1
		;   - $000400 A3000 bootstrap, Kickstart 2.x/3.x
		;   the latter address is right at the end of the
		;   CPU exception vector table, which ends with 192
		;   (expected to be unused) user exception vectors).
		;
		;   However, the overlay is not disabled in this test
		;   to 'protect' the memory from accedential writes.
		;   Therefore the stack is (by intention) not usable.
		;
		lea	($000400).l,sp
		;
		; {this would} Disable the ROM overlay.
		;
		;   For Gary-based systems we set the OVL-pin as output
		;   and clear the /OVL-bit to disable the ROM overlay.
		;   On Gayle-based systems (some extension cards emulate
		;   a Gayle, e.g. to add/provide IDE disks) the overlay
		;   is disabled with the first write to a CIA-A register.
		;
	;	move.b	#$03,($BFE201)  ; #CIAF_LED|CIAF_OVERLAY,(_ciaa+ciaddra)
	;	bclr.b	#$00,($BFE001)  ; #CIAB_OVERLAY,(_ciaa+ciapra)

InitScreen:
		; Wait for line 0 (>= 256, < 256).
0$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		beq.b	0$
1$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		bne.b	1$

		; PAL LoRes 352x280x(6-4) (12,320 bytes/bitplane)
MY_DIW_W	EQU	352     ; (1 + 20 + 1) * 16
MY_DIW_H	EQU	280     ; 16 + 256 + 8
MY_DIW_L	EQU	113     ; (0x38 + 8.5) * 2 - 16
MY_DIW_T	EQU	28      ; 0x2C - 16
MY_DIW_R	EQU	MY_DIW_L+MY_DIW_W
MY_DIW_B	EQU	MY_DIW_T+MY_DIW_H
MY_DIWSTRT	EQU	(MY_DIW_T<<8)|MY_DIW_L
MY_DIWSTOP	EQU	((MY_DIW_B&$FF)<<8)|(MY_DIW_R&$FF)
MY_DDFSTRT	EQU	(MY_DIW_L-17)/2 ; -8.5 * 2
MY_DDFSTOP	EQU	MY_DDFSTRT+((MY_DIW_W-16)/2)
MY_BPLCON0	EQU	%0111001000000000       ; (7<<PLNCNTSHFT)|COLORON
MY_BPLCON1	EQU	%0000000000000000
MY_BPLCON2	EQU	%0000000000000000
MY_BPLCON3	EQU	%0000110000000000
MY_BPLxMOD	EQU	-(MY_DIW_W/8)   ; reset after every scanline
MY_INITBPL	EQU	(%1100110000110011<<16)|%1111000000001111
MY_EXITBPL	EQU	(%0011001111001100<<16)|%0000111111110000
		move.w	#MY_DIWSTRT,($08E,a6)   ; (diwstrt,_custom)
		move.w	#MY_DIWSTOP,($090,a6)   ; (diwstop,_custom)
		move.w	#MY_DDFSTRT,($092,a6)   ; (ddfstrt,_custom)
		move.w	#MY_DDFSTOP,($094,a6)   ; (ddfstop,_custom)
		move.l	sp,($0E0,a6)    ; (bpl1pt,_custom)
		move.l	sp,($0E4,a6)    ; (bpl2pt,_custom)
		move.l	sp,($0E8,a6)    ; (bpl3pt,_custom)
		move.l	sp,($0EC,a6)    ; (bpl4pt,_custom)
		move.l	sp,($0F0,a6)    ; (bpl5pt,_custom) ; unused
		move.l	sp,($0F4,a6)    ; (bpl6pt,_custom) ; unused
		move.w	#MY_BPLCON0,($100,a6)   ; (bplcon0,_custom)
		move.w	#MY_BPLCON1,($102,a6)   ; (bplcon1,_custom)
		move.w	#MY_BPLCON2,($104,a6)   ; (bplcon2,_custom)
		move.w	#MY_BPLCON3,($106,a6)   ; (bplcon3,_custom)
		move.w	#MY_BPLxMOD,($108,a6)   ; (bpl1mod,_custom)
		move.w	#MY_BPLxMOD,($10A,a6)   ; (bpl2mod,_custom)
		move.l	#MY_INITBPL,($118,a6)   ; (bpl5dat{bpl6dat},_custom)
		; Two effective colors (only BPL5DAT + half-bright BPL6DAT).
		moveq	#(32/2)-1,d0
		lea	($180,a6),a0            ; (color00,_custom)
2$:		move.w	#$005A,(16*2,a0)        ; (color16,_custom,i*2)
		move.w	#$0AAA,(a0)+            ; (color00,_custom,i*2)
		dbf	d0,2$

		; Enable bitplane DMA (DMAF_SETCLR|DMAF_MASTER|DMAF_RASTER).
		move.w	#$8000|$0200|$0100,($096,a6)    ; (dmacon,_custom)
MainInit:
		; Wait a while to show the 'Intro' pattern.
		moveq	#16,d1
	;	moveq	#-1,d0  ; already -1.w from previous dbf
0$:		btst.b	#15-8,($004,a6) ; (vposr:15,_custom) ; dummy read
		dbf	d0,0$
		dbf	d1,0$

		; Initialize BPL5DAT/BPL6DAT pointer.
		lea	($118,a6),a5    ; (bpl5dat{bpl6dat},_custom)
		move.l	#(0<<16)|0,(a5) ; (bpl5dat{bpl6dat},_custom)
MainLoop:
		; Wait for line 0 (>= 256, < 256).
0$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		beq.b	0$
1$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		bne.b	1$

		; Initialize image source data pointer
		lea	(MainImage,pc),a4
		; Sync to VPOS (top - 1) and HPOS $E0/$E1.
MY_SYNC_MAX	EQU	$E1-(2+4+4+4+4+4+7)+4   ; +(Agnus - Denise HPOS)
MY_SYNC_MIN	EQU	MY_SYNC_MAX-(126-2-2)   ; max bpl.b displacement
	IFNE	(MY_SYNC_MIN|MY_SYNC_MAX)&1
	FAIL	"Odd sync range, review the code."
	ENDC
		lea	($006,a6),a0    ; (vhposr,_custom)
2$:		move.w	(a0),d0                                 ; .r.p       r+2
		subi.w	#((MY_DIW_T-1)<<8)|MY_SYNC_MIN,d0       ; .p.p        +4
		bmi.b	2$                                      ; (..p.p)...p +4
		andi.w	#~1,d0                                  ; .p.p        +4
		subi.w	#MY_SYNC_MAX-MY_SYNC_MIN,d0             ; .p.p        +4
		bpl.b	3$                                      ; (..p.p)...p +4
		jmp	(3$,pc,d0.w)                            ; ....p.p     +7
	REPT	(MY_SYNC_MAX-MY_SYNC_MIN)/2
		nop                                             ; .p
	ENDR
3$:
		; Unrolled draw loop (no time left for HSync code).
	REPT	MY_DIW_H
		movem.l	(a4)+,d0-a2     ; $E[0]1-$2F .p.[-]R(.r.R){11}.p
		move.l	d0,(a5)         ; -1 $30-$35 .W.w.p
		move.l	(a4)+,(a5)      ;  1 $36-$3F .R.r.W.w.p
		move.l	d1,(a5)         ;  2 $40-$45 .W.w.p
		move.l	(a4)+,(a5)      ;  3 $46-$4F .R.r.W.w.p
		move.l	d2,(a5)         ;  4 $50-$55 .W.w.p
		move.l	(a4)+,(a5)      ;  5 $56-$5F .R.r.W.w.p
		move.l	d3,(a5)         ;  6 $60-$65 .W.w.p
		move.l	(a4)+,(a5)      ;  7 $66-$6F .R.r.W.w.p
		move.l	d4,(a5)         ;  8 $70-$75 .W.w.p
		move.l	(a4)+,(a5)      ;  9 $76-$7F .R.r.W.w.p
		move.l	d5,(a5)         ; 10 $80-$85 .W.w.p
		move.l	(a4)+,(a5)      ; 11 $86-$8F .R.r.W.w.p
		move.l	d6,(a5)         ; 12 $90-$95 .W.w.p
		move.l	(a4)+,(a5)      ; 13 $96-$9F .R.r.W.w.p
		move.l	d7,(a5)         ; 14 $A0-$A5 .W.w.p
		move.l	(a4)+,(a5)      ; 15 $A6-$AF .R.r.W.w.p
		move.l	a0,(a5)         ; 16 $B0-$B5 .W.w.p
		move.l	(a4)+,(a5)      ; 17 $B6-$BF .R.r.W.w.p
		move.l	a1,(a5)         ; 18 $C0-$C5 .W.w.p
		move.l	(a4)+,(a5)      ; 19 $C6-$CF .R.r.W.w.p
		move.l	a2,(a5)         ; 20 $D0-$D5 .W.w.p
		move.l	(a4)+,(a5)      ; +1 $D6-$DF .R.r.W.w.p
	ENDR

		; Clear BPL5DAT/BPL6DAT ('background' color).
		move.l	#(0<<16)|0,(a5)     ; (bpl5dat{bpl6dat},_custom)

		; Test for LMB pressed to leave the main loop.
		btst.b	#6,($BFE001)        ; #CIAB_GAMEPORT0,(_ciaa+ciapra)
		bne.w	MainLoop

MainExit:
		; Wait for line 0 (>= 256, < 256).
0$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		beq.b	0$
1$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		bne.b	1$

		; 'Extro' pattern (while LMB pressed).
		move.l	#MY_EXITBPL,(a5)        ; (bpl5dat{bpl6dat},_custom)
		; Wait for LMB release.
2$:		btst.b	#6,($BFE001)    ; #CIAB_GAMEPORT0,(_ciaa+ciapra)
		beq.b	2$

		; Disable all DMAs.
		move.w	#$7FFF,($096,a6)        ; ~DMAF_SETCLR,(dmacon,_custom)
		bra.w	ColdReboot

	INCLUDE	"cpubltro_img.i"
	IFNE	*-MainImage-(MY_DIW_W*MY_DIW_H*2/8)
	FAIL	"Unexpected image size, review the code/data."
	ENDC

		; Software reset (start over again).
	CNOP	0,4 ; RESET and JMP instruction have to share a longword
ColdReboot:
		lea	($01000000),a0  ; ROM end
		suba.l	(-$0014,a0),a0  ; ROM size ($FFFFEC)
		movea.l	($0004,a0),a0   ; ROM ColdStart
		subq.l	#2,a0           ; second reset
		reset                   ; first reset
		jmp	(a0)            ; executed by prefetch

RomTagEnd:
		; Fill the unused part with all 1's (Flash optimization,
		; on many chips this reduces/avoids writes after erase).
		dcb.b	$01000000-(8*2)-(2*4)-(*-RomBase)-$FC0000,~0
RomFooter:
		dc.l	$00000000               ; ROM checksum (to be updated)
		dc.l	$01000000-$FC0000       ; ROM size (for software reset)
AutoVecInt:
		; CPU Autovector interrupt exception vector indices (68000).
		; Note: MSB is unused (but 0 to make some ROM parsers happy)
		dc.w	24      ; VEC_SPUR (spurious interrupt)
		dc.w	25      ; VEC_INT1 (TBE, DSKBLK, SOFTINT)
		dc.w	26      ; VEC_INT2 (PORTS)
		dc.w	27      ; VEC_INT3 (COPER, VERTB, BLIT)
		dc.w	28      ; VEC_INT4 (AUD2, AUD0, AUD3, AUD1)
		dc.w	29      ; VEC_INT5 (RBF, DSKSYNC)
		dc.w	30      ; VEC_INT6 (EXTER, INTEN)
		dc.w	31      ; VEC_INT7 (NMI)

	IFNE	*-RomBase-($01000000-$FC0000)
	FAIL	"Unexpected ROM size, review the code."
	ENDC

	END
