; SPDX-FileCopyrightText: 2025 Nico Bendlin <nico@nicode.net>
; SPDX-License-Identifier: CC0-1.0
;-----------------------------------------------------------------------------
;
;                  Racing The Beam on the Amiga without RAM
;
;	Target requirements:
;	  - Motorola 68000 CPU @ 7 MHz (fixed timing)
;	  - PAL on reset (NTSC would require rewrite)
;
; > vasmm68k_mot -Fbin -o cpubltro.rom cpubltro.asm
;
	IDNT	CPUBLTRO_ROM

	MACHINE	68000
	FPU	0
	FAR
	OPT	P+ 	; position independent code
	OPT	D- 	; debug symbols off
	OPT	O- 	; all optimizations off
	OPT	OW+	; show optimizations on

ROM_SIZE	EQU	256*1024
ROM_256K	EQU	($1111<<16)!$4EF9	; 256K ROM ID, JMP (ABS).L
ROM_FILL	EQU	~0               	; EPROM/Flash optimization

	SECTION	cpubltro,CODE
	ORG	$01000000-ROM_SIZE

;-----------------------------------------------------------------------------
;
;              Kickstart ROM header / CPU exception vector table
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
		dc.l   	ROM_256K          	; VEC_RESETSP
		dc.l   	3$                	; VEC_RESETPC
		dcb.l  	1-2+11,5$         	; VEC_BUSERR-VEC_LINE11
		dc.l   	$E85D7D64         	; VEC_RESV12 (ROM checksum=0)
		dcb.l  	1-13+15,5$        	; VEC_COPROC-VEC_UNINT
0$:		dc.b   	'cpubltro',0,0    	; VEC_RESV16-VEC_SPUR
1$:		dc.w   	$4AFC             	; (RT_MATCHWORD=RTC_MATCHWORD)
		dc.l   	1$                	; (RT_MATCHTAG)
		dc.l   	RomTagEnd         	; (RT_ENDSKIP)
		dc.b   	$00               	; (RT_FLAGS=RTW_NEVER)
		dc.b   	0                 	; (RT_VERSION)
		dc.b   	0                 	; (RT_TYPE=NT_UNKNOWN)
		dc.b   	0                 	; (RT_PRI)
		dc.l   	0$                	; (RT_NAME)
		dc.l   	7$                	; (RT_IDSTRING)
		dc.l   	5$                	; (RT_INIT)
		dcb.l  	1-25+51,5$        	; VEC_INT1-VEC_FPUNDER
2$:		reset  	                  	; VEC_FPOE.w (ColdReset)
3$:		bra.b  	4$                	; VEC_FPOE.w (ColdStart)
		dcb.l  	1-53+58,5$        	; VEC_FPOVER-VEC_MMUACC
4$:		bra.w  	RomEntry          	; VEC_RESV59
		dcb.l  	1-60+61,5$        	; VEC_UNIMPEA-VEC_UNIMPII
5$:		lea    	(6$,pc),sp        	; VEC_RESV62.w
		rte    	                  	; VEC_RESV62.w-VEC_USER[192]
6$:		dc.w   	%0010011100000000 	; (exception ($00,sp))
		dc.l   	2$                	; (exception ($02,sp))
		dc.w   	(%0000<<12)!(31*4)	; (exception ($06,sp))
		dcb.b  	(*-RomBase)&%0010,0
		dcb.b  	(*-RomBase)&%0100,0
		dcb.b  	(*-RomBase)&%1000,0
7$:		dc.b   	'cpubltro.rom 0.4 (19.04.2025)',13,10,0
		dc.b   	'(c) 2025 Nico Bendlin <nico@nicode.net>',10
		dc.b   	'No Rights Reserved.',0
		dc.b   	'https://github.com/nicodex/amiga-ocs'
		dc.b   	'-cpubltro',0
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
		lea    	(RomEntry,pc),SP
		;
		; disable/clear all interrupts/DMA
		;
		;  SR: 	#%TTSM-III---XNZVC
		move.w 	#%0010011100000000,sr	; supervisor mode, IPL = 7
		lea    	($DFF000).L,A6       	; _custom
		move.w 	#$7FFF,d0            	; #~INTF_SETCLR/~DMAF_SETCLR
		move.w 	d0,($09A,A6)         	; (intena,_custom)
		move.w 	d0,($09C,A6)         	; (intreq,_custom)
		move.w 	d0,($096,A6)         	; (dmacon,_custom)
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
;          Constant registers for the rest of the code (upper case)
;
RegInit:
	;	lea    	($DFF000),A6	; _custom
		lea    	($110,A6),A4	; (bpl1dat,_custom)
		lea    	($144,A6),A5	; (spr0data/spr0datb,_custom)
		moveq  	#0,D0       	; zero

;-----------------------------------------------------------------------------
;
;           PAL LoRes 320x180 (v-centered 16:9 for Revision party)
;
ScrInit:
MY_SCR_W  	EQU	320
MY_SCR_H  	EQU	320*9/16
MY_SCR_L  	EQU	129
MY_SCR_T  	EQU	44+((256-MY_SCR_H)/2)
MY_SCR_R  	EQU	MY_SCR_L+MY_SCR_W
MY_SCR_B  	EQU	MY_SCR_T+MY_SCR_H
MY_DIWSTRT	EQU	(MY_SCR_T<<8)!MY_SCR_L
MY_DIWSTOP	EQU	((MY_SCR_B&$FF)<<8)!(MY_SCR_R&$FF)
MY_DIWLONG	EQU	(MY_DIWSTRT<<16)!MY_DIWSTOP
MY_BPLCON0	EQU	%0001001000000000 	; BPU=1,COLORON
MY_BPLCONL	EQU	(MY_BPLCON0<<16)!0	; PFH=0
MY_BPLCON2	EQU	%0000000000100100 	; PFP=SP01/SP23/SP45/SP67/PF
MY_BEAMCON	EQU	%0000000000100000 	; PAL
		;
		; WaitTOF
		;
0$:		btst.b 	D0,($004+1,A6)  ; (vposr:V8,_custom)
		beq.b  	0$
1$:		btst.b 	D0,($004+1,A6)  ; (vposr:V8,_custom)
		bne.b  	1$
		;
		; setup screen/display
		;
		move.l 	#MY_DIWLONG,($08E,A6)	; (diwstrt/diwstop,_custom)
		move.l 	#MY_BPLCONL,($100,A6)	; (bplcon0/bplcon1,_custom)
		move.w 	#MY_BPLCON2,($104,A6)	; (bplcon2,_custom)
		move.w 	#MY_BEAMCON,($1DC,A6)	; (beamcon0,_custom)
		;
		; setup color palette
		;
		move.l 	#$0AAA0A0A,($180,A6) 	; (color00/color01,_custom)
		lea    	(16*2+$180,A6),a0
		moveq  	#(4-1),d1
2$:		move.w 	D0,(a0)+
		move.l 	#$0F000FDD,(a0)+
		move.w 	#$0FFF,(a0)+
		dbf    	d1,2$
		;
		; force long fields
		;
		move.w 	($004,A6),d1  	; (vposr,_custom)
		bmi.s  	3$            	; LOF=15
		ori.w  	#$8000,d1     	; LOF
		move.w 	d1,($02A,A6)  	; (vposw,_custom)
3$:		btst.b 	D0,($004+1,A6)	; (vposr:V8,_custom)
		beq.b  	3$
4$:		btst.b 	D0,($004+1,A6)	; (vposr:V8,_custom)
		bne.b  	4$
		move.w 	($004,A6),d1
		bmi.s  	5$
		ori.w  	#$8000,d1
		move.w 	d1,($02A,A6)
5$:
		;
		; trigger bitplane
		;
		move.w 	D0,(A4)

;-----------------------------------------------------------------------------
;
;                                  Main loop
;
MY_ANIM_LEN	EQU	12*2               	; original NTSC has 14 steps
MY_SPR_SIZE	EQU	(4*7)*(1+112)      	; includes the top skip line
MY_SPRSTRTX	EQU	-((MY_SCR_W-112)/2)	; rotate eastward, move left
MY_SPRSTRTY	EQU	8
MY_SPRMOVEX	EQU	2                  	; positions are in .5 pixels
MY_SPRMOVEY	EQU	2                  	; positions are in .5 pixels
MY_ANIMSTEP	EQU	1                  	; half speed (double frames)
MY_GRAVSTEP	EQU	29
DrwInit:
		;
		; init mouse (data a0)
		;
		move.w 	($00A,A6),a3	; (joy0dat,_custom)
		move   	a3,usp
		move.l 	D0,d6
		;
		; init globe (data a2, skip a7)
		;
		move.l 	D0,d4
		move.w 	#(MY_SPRSTRTY*2),d5
		swap   	d5
		move.w 	#(MY_SPRSTRTX*2),d5
DrwLoop:
		;
		; setup pointer
		;
		move.w 	($00A,A6),d1	; (joy0dat,_custom)
		move   	usp,a3
		move.w 	a3,d2
		movea.w	d1,a3
		move   	a3,usp
		move.b 	d2,d3
		sub.b  	d1,d3
		ext.w  	d3
		sub.w  	d3,d6
		bpl.s  	0$
		move.w 	D0,d6
0$:		swap   	d6
		lsr.w  	#8,d2
		lsr.w  	#8,d1
		move.b 	d2,d3
		sub.b  	d1,d3
		ext.w  	d3
		sub.w  	d3,d6
		bpl.s  	1$
		move.w 	D0,d6
1$:		cmpi.w 	#MY_SCR_H,d6
		ble.s  	2$
		move.w 	#MY_SCR_H,d6
2$:		lea    	(PtrData,pc),a0
		move.w 	d6,d1
		lsl.w  	#2,d1
		suba.w 	d1,a0
		swap   	d6
		cmpi.w 	#MY_SCR_W,d6
		ble.s  	3$
		move.w 	#MY_SCR_W,d6
3$:		move.w 	d6,d2
		addi.w 	#MY_SCR_L,d2
		move.w 	d2,d1
		lsr.w  	#1,d1
		swap   	d1
		move.w 	d2,d1
		andi.w 	#1,d1
		move.l 	d1,($140,A6)	; (spr0pos/spr0ctl,_custom)
GrdCalc:
		;
		; setup grid
		;
		lea    	(GrdData,pc),a1
SprCalc:
		;
		; setup globe
		;
		lea    	(SprSkip,pc),a7
		lea    	(SprData,pc),a2
		move.w 	d4,d1
		mulu   	#MY_SPR_SIZE,d1
		adda.l 	d1,a2
		move.l 	d5,d2
		swap   	d2
		move.w 	d2,d1
		asr.w  	#1,d1
		beq.s  	1$	; top data line = skip
		bpl.s  	0$
		neg.w  	d1
0$:		subq.w 	#1,d1
		add.w  	d1,d1
		suba.w 	d1,a7
1$:		swap   	d2
		asr.w  	#1,d2
		bpl.s  	2$
		neg.w  	d2
		adda.l 	#(MY_ANIM_LEN*MY_SPR_SIZE),a2
2$:		addi.w 	#MY_SCR_L,d2
		move.w 	d2,d1
		lsr.w  	#1,d1
		swap   	d1
		move.w 	d2,d1
		andi.w 	#$0001,d1
		moveq  	#(16>>1),d2
		swap   	d2
		move.l 	d1,($148,A6)	; (spr1pos/spr1ctl,_custom)
		add.l  	d2,d1
		move.l 	d1,($150,A6)	; (spr2pos/spr2ctl,_custom)
		add.l  	d2,d1
		move.l 	d1,($158,A6)	; (spr3pos/spr3ctl,_custom)
		add.l  	d2,d1
		move.l 	d1,($160,A6)	; (spr4pos/spr4ctl,_custom)
		add.l  	d2,d1
		move.l 	d1,($168,A6)	; (spr5pos/spr5ctl,_custom)
		add.l  	d2,d1
		move.l 	d1,($170,A6)	; (spr6pos/spr6ctl,_custom)
		add.l  	d2,d1
		move.l 	d1,($178,A6)	; (spr7pos/spr7ctl,_custom)
PosHorz:
		tst.w  	d5
		bmi.s  	1$
		cmpi.w 	#(((MY_SCR_W-112)*2)-1),d5
		blt.s  	0$
		neg.w  	d5
		bra.s  	PosVert
0$:		addq.w 	#MY_SPRMOVEX,d5
		subq.w 	#MY_ANIMSTEP,d4
		bpl.s  	PosVert
		move.w 	#(MY_ANIM_LEN-MY_ANIMSTEP),d4
		bra.s  	PosVert
1$:		cmpi.w 	#-1,d5
		blt.s  	2$
		neg.w  	d5
		bra.s  	PosVert
2$:		addq.w 	#MY_SPRMOVEX,d5
		addq.w 	#MY_ANIMSTEP,d4
		cmpi.w 	#MY_ANIM_LEN,d4
		blo.s  	PosVert
		move.w 	D0,d4
PosVert:
		moveq  	#MY_SPRMOVEY-1,d1
0$:		swap   	d4
		swap   	d5
		tst.w   d5
		bmi.s  	1$
		addq.w 	#1,d4
		move.l 	D0,d2
		move.w 	d4,d2
		divu   	#MY_GRAVSTEP,d2
		add.w  	d2,d5
		cmpi.w 	#(2*(MY_SCR_H-112)),d5
		ble.s  	4$
		sub.w  	d2,d5
		bra.s  	3$
1$:		subq.w 	#1,d4
		bmi.s  	2$
		move.l 	D0,d2
		move.w 	d4,d2
		divu   	#MY_GRAVSTEP,d2
		add.w  	d2,d5
		bra.s  	4$
2$:		move.w 	D0,d4
3$:		neg.w  	d5
4$:		swap   	d5
		swap   	d4
		dbf    	d1,0$
DrwCalc:
		;
		; init counter
		;
		move.w 	#(MY_SCR_H-1),d7
DrwSync:
		;
		; sync to screen top - 1 / time slot $DE/$DF
		;
		btst.b 	D0,($004+1,A6)
		bne.b  	DrwSync
MY_SYNC_MAX	EQU	($DE+(9/2))-(-1+4+2+4+7)-4
MY_SYNC_POS	EQU	MY_SYNC_MAX-(-2+4+2+5)-(4+2+4)-(4-3)
MY_SYNC_MIN	EQU	MY_SYNC_POS+(-1+4+2+3)+(4-3)-1
	IFNE	(MY_SYNC_MAX!MY_SYNC_POS!MY_SYNC_MIN)&1
	FAIL	"Sync position odd, review the code."
	ENDC
MY_SYNC_TAB	EQU	(1<<4)-2
	IFLT	MY_SYNC_TAB-(MY_SYNC_MAX-MY_SYNC_MIN)
	FAIL	"Sync table overflow, review the code."
	ENDC
		lea    	($006,A6),a3	; (vhposr,_custom)
		move.w 	#((MY_SCR_T-1)<<8)!MY_SYNC_POS,d2
		move.w 	#((MY_SCR_T-1)<<8)!(MY_SYNC_MAX-MY_SYNC_TAB),d3
0$:		move.w 	(a3),d1        	; .r.p
		cmp.w  	d2,d1          	; .p
		blo.b  	0$             	; [.]..p/..p.p (continue/branch)
		move.w 	(a3),d1        	; .r.p
		sub.w  	d3,d1          	; .p
		and.w  	#MY_SYNC_TAB,d1	; .p.p
		jmp    	(1$,pc,d1.w)   	; ....p.p
1$:
	REPT	MY_SYNC_TAB/2
		nop
	ENDR
		lea    	($17C,A6),a3   	; .p.p (spr7dat,_custom)
DrwLine:
		move.l 	(a0)+,(A5)     	; $DE-$05 .R.r.[-]W.w.p (spr0dat)
		move.l 	(a2)+,($14C,A6)	; $06-$11 .R.r.p.W.w.p  (spr1dat)
		move.l 	(a2)+,($154,A6)	; $12-$1D .R.r.p.W.w.p  (spr2dat)
		move.l 	(a2)+,($15C,A6)	; $1E-$29 .R.r.p.W.w.p  (spr3dat)
		move.l 	(a2)+,($164,A6)	; $2A-$35 .R.r.p.W.w.p  (spr4dat)
		move.w 	D0,(A4)        	; $36-$39 .w.p          (bpl0dat)
		move.w 	-(a1),d1       	; $3A-$3E ..r.p         (GrdData)
		move.l 	(a2)+,($16C,A6)	; $3F-$4A .R.r.p.W.w.p  (spr5dat)
		move.l 	(a2)+,($174,A6)	; $4B-$56 .R.r.p.W.w.p  (spr6dat)
		move.w 	d1,(A4)        	; $57-$5A .w.p          (bpl0dat)
		move.w 	(a2)+,d3       	; $5B-$5E .r.p          (SprData)
		move.w 	d1,(A4)        	; $5F-$62 .w.p          (bpl0dat)
		move.w 	d3,(a3)+       	; $63-$66 .w.p          (spr7data)
		move.w 	d1,(A4)        	; $67-$6A .w.p          (bpl0dat)
		move.w 	(a2)+,d3       	; $6B-$6E .r.p          (SprData)
		move.w 	d1,(A4)        	; $6F-$72 .w.p          (bpl0dat)
		move.w 	d3,(a3)        	; $73-$76 .w.p          (spr7datb)
		move.w 	d1,(A4)        	; $77-$7A .w.p          (bpl0dat)
		subq.l 	#2,a3          	; $7B-$7E .p..
		move.w 	d1,(A4)        	; $7F-$82 .w.p          (bpl0dat)
		nop
		nop
		move.w 	d1,(A4)        	; $87-$8A .w.p          (bpl0dat)
		nop
		nop
		move.w 	d1,(A4)        	; $8F-$92 .w.p          (bpl0dat)
		nop
		nop
		move.w 	d1,(A4)        	; $97-$9A .w.p          (bpl0dat)
		nop
		nop
		move.w 	d1,(A4)        	; $9F-$A2 .w.p          (bpl0dat)
		nop
		nop
		move.w 	d1,(A4)        	; $A7-$AA .w.p          (bpl0dat)
		nop
		nop
		move.w 	d1,(A4)        	; $AF-$B2 .w.p          (bpl0dat)
		nop
		nop
		move.w 	d1,(A4)        	; $B7-$BA .w.p          (bpl0dat)
		nop
		nop
		move.w 	d1,(A4)        	; $BF-$C2 .w.p          (bpl0dat)
		nop
		move.w 	#$8000,(A4)    	; $C5-$CA .p.w.p        (bpl0dat)
		nop
		nop
		nop
		nop
		suba.w 	(a7)+,a2       	; $D3-$D8 .r.p..        (SprSkip)
		dbf    	d7,DrwLine     	; $D9-$DD ..p.p   (taken)
		       	               	;    -$DF ..p.p.p (count)

		bra.w  	DrwLoop

;-----------------------------------------------------------------------------
;
;                           Cursor image data (a0)+
;
		dcb.l  	MY_SCR_H,0
PtrData:
	INCLUDE	"images/ptrdata.i"

		dcb.l  	MY_SCR_H-((*-PtrData)/4),0

;-----------------------------------------------------------------------------
;
;                           Grid bitmap data -(a1)
;
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1111111111111111
	REPT	MY_SCR_H/16
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1000000000000000
		dc.w   	%1111111111111111
	ENDR
GrdData:

;-----------------------------------------------------------------------------
;
;                           Sprite skip table (a7)+
;
		;TODO: generate skip table
		dcb.w  	(MY_SCR_H-112),7*4
SprSkip:
		dcb.w  	(1+112),0
		dcb.w  	(MY_SCR_H-112),7*4

;-----------------------------------------------------------------------------
;
;                           Sprite image data (a2)+
;


SprData:
		;TODO: optimize sprite data (line skip)
	INCLUDE	"images/balldata.i"
	IFNE	(*-SprData)-(2*MY_ANIM_LEN*MY_SPR_SIZE)-(4*7)
	FAIL	"Unexpected sprite data size, review the data/code."
	ENDC

;-----------------------------------------------------------------------------
;
;                                   done :)
;
		dcb.b  	(*-RomBase)&%0010,ROM_FILL
RomTagEnd:

;-----------------------------------------------------------------------------
;
;              Kickstart ROM footer / MC68000 Autovector indices
;
;     $FFFFE8 ROM checksum (not used, to be updated by the build process)
;     $FFFFEC ROM size (not used, intended to be used for software reset)
;     $FFFFF0 CPU Autovector interrupt exception vector indices (MC68000)
;
		dcb.b	ROM_SIZE-(2*4)-(8*2)-(*-RomBase),ROM_FILL
		dc.l 	$00000000	; Kickstart ROM checksum
		dc.l 	ROM_SIZE 	; Kickstart ROM size
		dc.b 	0,24	; Spurious Interrupt
		dc.b 	0,25	; Autovector Level 1 (TBE, DSKBLK, SOFTINT)
		dc.b 	0,26	; Autovector Level 2 (PORTS)
		dc.b 	0,27	; Autovector Level 3 (COPER, VERTB, BLIT)
		dc.b 	0,28	; Autovector Level 4 (AUD2, AUD0, AUD3, AUD1)
		dc.b 	0,29	; Autovector Level 5 (RBF, DSKSYNC)
		dc.b 	0,30	; Autovector Level 6 (EXTER, INTEN)
		dc.b 	0,31	; Autovector Level 7 (NMI)

	END
