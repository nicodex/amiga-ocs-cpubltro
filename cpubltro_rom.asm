; SPDX-FileCopyrightText: 2023 Nico Bendlin <nico@nicode.net>
; SPDX-License-Identifier: CC0-1.0
;
;	CPU drawing 256K ROM without any memory writes (Proof of Concept)
;
;	Target: PAL OCS/ECS with 7(4+2)-bitplane anomaly
;	(Agnus: 4-bitplane DMAs, Denise: 6-bitplane EHB,
;	 BPL5DAT/BPL6DAT can/have to be filled with CPU)
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
	ORG	$00FC0000

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
		dc.w	$1111,$4EF9 ; (RESET SP) 256K ROM ID, JMP
		dc.l	ColdStart   ; (RESET PC)

;
; Dummy ROM header to make some ROM parsers happy.
;
RomHeader:
		dc.l	$0000FFFF   ; diag pattern
		dc.w	0,0         ; Kick version,revision
		dc.w	0,0         ; Exec version,revision
		dc.l	-1          ; System serial number
		dc.b	0           ; Kick strings
		dc.b	'CPU Blit Read-Only ROM',0
		dc.b	'Copyright (c) 2023 ',0
		dc.b	'Nico Bendlin ',0
		dc.b	'No Rights Reserved.',0
		dc.b	'Test ROM ',0
RomTagName:
		dc.b	'cpubltro.rom',0
RomTagIdString:
		dc.b	'cpubltro 0.0 (31.03.2023)',13,10,0
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
		; Force default ColdReset/ColdStart offsets.
		dcb.b	($00D0-(*-RomBase)),0
ColdReset:
		reset   ; second reset (ColdReboot)
;
; ROM entry point
;
ColdStart:
		; Disable ROM overlay (Gary or Gayle).
		lea	($00BFE001).l,a5    ; _ciaa
		; Note: Theoretically not required in this test,
		; even the supervisor stack should never be used
		; since all exceptions are disabled. However,
		; there is no exception vector table here
		; (maybe in another proof of concept ...),
		; so we use what is currently in the RAM.
		move.b	#3,($200,a5)        ; (ciaddra,_ciaa) ; Gayle /OVL
		bclr.b	#0,(a5)             ; #CIAB_OVERLAY,(ciapra,_ciaa)
		; Disable/clear all DMAs/interrupts.
		; SR reg: TTSM-III---XNZVC
		move.w	#%0010011100000000,sr
		lea	($00DFF000).l,a6    ; _custom
		move.w	#$7FFF,d0           ; ~INTF_SETCLR / ~DMAF_SETCLR
		move.w	d0,($09A,a6)        ; (intena,_custom)
		move.w	d0,($09C,a6)        ; (intreq,_custom)
		move.w	d0,($096,a6)        ; (dmacon,_custom)
		; Initialize (supervisor) stack.
		lea	($00002000).l,sp    ; twice 040 page size
InitScreen:
		; Wait for line 0 (>= 256, < 256).
0$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		beq.b	0$
1$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		bne.b	1$
		; 384x284/768x568 LoRes (81 = ($20 + 8.5) * 2)
		move.w	#(27<<8)|81,($08E,a6)                       ; (diwstrt,_custom)
		move.w	#((27+284-256)<<8)|(81+384-256),($090,a6)   ; (diwstop,_custom)
		move.w	#(81-17)/2,($092,a6)                        ; (ddfstrt,_custom)
		move.w	#(81-17+384-16)/2,($094,a6)                 ; (ddfstop,_custom)
		move.w	#(7<<12)|$0200,($100,a6)                    ; (7<<PLNCNTSHFT)|COLORON,(bplcon0,_custom)
		; Reset bitplane pointers at the end of every line
		; (avoid accessing strobe registers by bitplane DMA).
		move.w	#-(384/8),($108,a6)     ; (bpl1mod,_custom)
		move.w	#-(384/8),($10A,a6)     ; (bpl2mod,_custom)
		; Initialize bitplane pointers/data.
		moveq	#0,d0
		move.l	d0,($102,a6)    ; (bplcon1/bplcon2,_custom)
		move.l	d0,($0E0,a6)    ; (bplpt+0*4,_custom)
		move.l	d0,($0E4,a6)    ; (bplpt+1*4,_custom)
		move.l	d0,($0E8,a6)    ; (bplpt+2*4,_custom)
		move.l	d0,($0EC,a6)    ; (bplpt+3*4,_custom)
		move.l	d0,($0F0,a6)    ; (bplpt+4*4,_custom) ; unused
		move.l	d0,($0F4,a6)    ; (bplpt+5*4,_custom) ; unused
		; 'Intro' BPL5DAT/BPL6DAT pattern.
		move.w	#%1010101010101010,($118,a6)    ; (bpldat+4*2,_custom)
		move.w	#%1111111100000000,($11A,a6)    ; (bpldat+5*2,_custom)
		; Two effective colors (only BPL5DAT + half-bright BPL6DAT).
		moveq	#(32/2)-1,d0
		lea	($180,a6),a0        ; (color,_custom)
2$:		move.w	#$005A,(16*2,a0)    ; (color+16*2,_custom,i*2)
		move.w	#$0AAA,(a0)+        ; (color+0*2,_custom,i*2)
		dbf	d0,2$
		; Enable (only) bitplane DMA.
		move.w	#$8000|$0200|$0100,($096,a6)    ; DMAF_SETCLR|DMAF_MASTER|DMAF_RASTER,(dmacon,_custom)
MainInit:
		; Wait a while to show the 'Intro' pattern.
		moveq	#16,d1
	;	moveq	#-1,d0
0$:		btst.b	#15-8,($004,a6) ; (vposr:15,_custom)
		dbf	d0,0$
		dbf	d1,0$

		; Clear BPL5DAT/BPL6DAT (only background color).
		moveq	#0,d0
		lea	($118,a6),a4    ; (bpldat+4*2,_custom)
		move.w	d0,(a4)         ; (bpldat+4*2,_custom)
		move.w	d0,($11A,a6)    ; (bpldat+5*2,_custom)
MainLoop:
		; Wait for line 0 (>= 256, < 256).
0$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		beq.b	0$
1$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		bne.b	1$

		;
		; Let's see how fast we can fill BPL5DAT and how often the
		; register is fetched. Taking screenshots on real hardware
		; allows us to translate color patterns back to a timing.
		;
		; The loop is not unrolled to test the difference between
		; the MC68000 and the MC68010 (small loop optimization).
		; Note that the MC68020+ instruction cache is expected to
		; be disabled on reset, and should not be active here.
		;
		; This loop is not synchronized with horizontal blanking
		; to test how many iterations are done outside of the
		; bitplane DMA. This will result in flickering pixels
		; between odd and even fields if the numbers do not match.
		;
		move.w	#$1000,d0
2$:		move.w	d0,(a4) ; (bpldat+4*2,_custom)
		dbf	d0,2$

		; Clear BPL5DAT (only background color).
		moveq	#0,d0
		move.w	d0,(a4) ; (bpldat+4*2,_custom)
		; Test for LMB pressed to leave the main loop.
		btst.b	#6,(a5) ; #CIAB_GAMEPORT0,(ciapra,_ciaa)
		bne.b	MainLoop

MainExit:
		; Wait for line 0 (>= 256, < 256).
0$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		beq.b	0$
1$:		btst.b	#0,($004+1,a6)  ; (vposr:0,_custom)
		bne.b	1$
		; 'Extro' BPL5DAT/BPL6DAT pattern (while LMB pressed).
		move.w	#%0101010101010101,($118,a6)    ; (bpldat+4*2,_custom)
		move.w	#%0000000011111111,($11A,a6)    ; (bpldat+5*2,_custom)
		; Wait for LMB release.
2$:		btst.b	#6,(a5) ; #CIAB_GAMEPORT0,(ciapra,_ciaa)
		beq.b	2$
		; Disable all DMAs.
		move.w	#$7FFF,($096,a6)    ; ~DMAF_SETCLR,(dmacon,_custom)

		; Software reset (start over again).
	CNOP	0,4 ; RESET and JMP instruction have to share a longword
ColdReboot:
		lea	($01000000).l,a0    ; ROM end
		suba.l	(-$0014,a0),a0      ; ROM size ($00FFFFEC).l
		movea.l	($0004,a0),a0       ; ROM ColdStart
		subq.l	#2,a0               ; second reset
		reset                       ; first reset
		jmp	(a0)                ; executed by prefetch

RomTagEnd:
		dcb.b	$01000000-(8*2)-(2*4)-(*-RomBase)-$00FC0000,~0
RomFooter:
		dc.l	$00000000           ; ROM checksum (to be updated)
		dc.l	$01000000-$00FC0000 ; ROM size (for software reset)
AutoVecInt:
		; CPU Autovector interrupt exception vector indices (68000).
		; Note: unused most significant byte is used as 'signature'.
		dc.b	'c',24  ; Spurious Interrupt
		dc.b	'p',25  ; Level 1 Interrupt Autovector
		dc.b	'u',26  ; Level 2 Interrupt Autovector
		dc.b	'b',27  ; Level 3 Interrupt Autovector
		dc.b	'l',28  ; Level 4 Interrupt Autovector
		dc.b	't',29  ; Level 5 Interrupt Autovector
		dc.b	'r',30  ; Level 6 Interrupt Autovector
		dc.b	'o',31  ; Level 7 Interrupt Autovector

	IFNE	*-RomBase-($01000000-$00FC0000)
	FAIL	"Unexpected ROM size, review the code."
	ENDC

	END
