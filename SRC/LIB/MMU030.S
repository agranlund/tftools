
;--------------------------------------------------------------
; MMU030.S
;
;	MMU030_Install
;	MMU030_IsInUse
;	MMU030_SetInUSe
;
; This file is distributed under the GPL v2 or at your
; option any later version.  See LICENSE.TXT for details.
;
; This file is derived from work done by the EmuTOS team.
; http://emutos.sourceforge.net
;
; Anders Granlund, 2019
;--------------------------------------------------------------

;--------------------------------------------------------------
	section bss
;--------------------------------------------------------------
gMMU030_CRP		ds.l	2
gMMU030_TC		ds.l	1
gMMU030_TTR0	ds.l	1
gMMU030_TTR1	ds.l	1

;--------------------------------------------------------------
	section text
;--------------------------------------------------------------

PMMU030_TABLE_TIA	equ $00
PMMU030_TABLE_TIB1	equ $40
PMMU030_TABLE_TIB2	equ $80
PMMU030_TABLE_TIC	equ $C0

PMMU030_TABLE	MACRO
		move.l	d0,d1
		add.l	#\1,d1
		or.l	#2,d1
		move.l	d1,(a0)+
		ENDM

PMMU030_PAGE	MACRO
		move.l	#\1+$01,(a0)+
		ENDM

PMMU030_PAGE_CI	MACRO
		move.l	#\1+$01+$40,(a0)+
		ENDM


;--------------------------------------------------------------
MMU030_Install:
; input: d0 = base address, or 0 to allocate
; return: d0 = tia table location
;--------------------------------------------------------------
	tst.l	d0
	bne		.ramOK
	move.w	#3,-(sp)			; prefer tt-ram
	move.l	#$200,-(sp)			; 256 + 256 bytes for allignment
	move.w	#68,-(sp)			; Mxalloc
	trap	#1
	addq.l	#8,sp
	tst.l	d0
	bne		.ramOK
	rts
.ramOK:
	add.l	#$FF,d0
	and.l	#-$100,d0
	move.l	a0,-(sp)
	move.l	d1,-(sp)
	move.l	d0,a0			; a0 = curr address

	; PMMU030_TABLE_TIA: 0x00000000-0xffffffff
        PMMU030_TABLE	PMMU030_TABLE_TIB1	; 0x00000000-0x0fffffff -> table tib1
        PMMU030_PAGE 	$10000000		; 0x10000000-0x7fffffff -> same physaddr, allow cache
        PMMU030_PAGE	$20000000
        PMMU030_PAGE	$30000000
        PMMU030_PAGE	$40000000
        PMMU030_PAGE	$50000000
        PMMU030_PAGE	$60000000
        PMMU030_PAGE	$70000000
        PMMU030_PAGE_CI	$80000000		; 0x80000000-0xefffffff -> same physaddr, cache inhibit 
        PMMU030_PAGE_CI	$90000000
        PMMU030_PAGE_CI	$a0000000
        PMMU030_PAGE_CI	$b0000000
        PMMU030_PAGE_CI	$c0000000
        PMMU030_PAGE_CI	$d0000000
        PMMU030_PAGE_CI	$e0000000
        PMMU030_TABLE	PMMU030_TABLE_TIB2	; 0xf0000000-0xffffffff -> table tib2

	; PMMU030_TABLE_TIB1: 0x00000000-0x0fffffff
        PMMU030_TABLE	PMMU030_TABLE_TIC	; 0x00000000-0x00ffffff -> table tic
        PMMU030_PAGE	$01000000		; 0x01000000-0x0fffffff, same physaddr, allow cache
        PMMU030_PAGE	$02000000
        PMMU030_PAGE	$03000000
        PMMU030_PAGE	$04000000
        PMMU030_PAGE	$05000000
        PMMU030_PAGE	$06000000
        PMMU030_PAGE	$07000000
        PMMU030_PAGE	$08000000
        PMMU030_PAGE	$09000000
        PMMU030_PAGE	$0a000000
        PMMU030_PAGE	$0b000000
        PMMU030_PAGE	$0c000000
        PMMU030_PAGE	$0d000000
        PMMU030_PAGE	$0e000000
        PMMU030_PAGE	$0f000000

	; PMMU030_TABLE_TIB2: 0xf0000000-0xffffffff
        PMMU030_PAGE_CI	$f0000000		; 0xf0000000-0xfeffffff -> same physaddr, cache inhibit 
        PMMU030_PAGE_CI	$f1000000
        PMMU030_PAGE_CI	$f2000000
        PMMU030_PAGE_CI	$f3000000
        PMMU030_PAGE_CI	$f4000000
        PMMU030_PAGE_CI	$f5000000
        PMMU030_PAGE_CI	$f6000000
        PMMU030_PAGE_CI	$f7000000
        PMMU030_PAGE_CI	$f8000000
        PMMU030_PAGE_CI	$f9000000
        PMMU030_PAGE_CI	$fa000000
        PMMU030_PAGE_CI	$fb000000
        PMMU030_PAGE_CI	$fc000000
        PMMU030_PAGE_CI	$fd000000
        PMMU030_PAGE_CI	$fe000000
        PMMU030_TABLE	PMMU030_TABLE_TIC	; 0xf0000000-0xffffffff -> table tic

	; PMMU030_TABLE_TIC: 0x00000000-0x00ffffffff

		IFEQ OPT_STRAM_CI
	        PMMU030_PAGE	$00000000
	        PMMU030_PAGE	$00100000
	        PMMU030_PAGE	$00200000
	        PMMU030_PAGE	$00300000
		ENDC
		IFNE OPT_STRAM_CI
	        PMMU030_PAGE_CI	$00000000		; cache inhibit st-ram
	        PMMU030_PAGE_CI	$00100000		; cache inhibit st-ram
	        PMMU030_PAGE_CI	$00200000		; cache inhibit st-ram
	        PMMU030_PAGE_CI	$00300000		; cache inhibit st-ram
		ENDC
        PMMU030_PAGE	$00400000
        PMMU030_PAGE	$00500000
        PMMU030_PAGE	$00600000
        PMMU030_PAGE	$00700000
        PMMU030_PAGE	$00800000
        PMMU030_PAGE	$00900000
        PMMU030_PAGE	$00a00000
        PMMU030_PAGE	$00b00000
        PMMU030_PAGE_CI	$00c00000		; cache inhibit usual gfxcard range
        PMMU030_PAGE_CI	$00d00000		; cache inhibit usual gfxcard range
        PMMU030_PAGE	$00e00000
        PMMU030_PAGE_CI	$00f00000		; cache inhibit usual hardware regs

	move.l	d0,gMMU030_CRP+4
	move.l	#$80000002,gMMU030_CRP
	move.l	#$80f04445,gMMU030_TC		; enable, pagesize 32k, IS=0, TIA=4, TIB=4, TIC=4, TID=5
	move.l	#$017e8107,gMMU030_TTR0		; 0x01000000-0x7fffffff, cache allowed
	move.l	#$807e8507,gMMU030_TTR1		; 0x80000000-0xfeffffff, cache inhibited

	dc.l	$f0394c00,gMMU030_CRP		; pmove addr,crp
	dc.l	$f0394000,gMMU030_TC		; pmove addr,tc
	dc.l	$f0390800,gMMU030_TTR0		; pmove addr,ttr0
	dc.l	$f0390c00,gMMU030_TTR1		; pmove addr,ttr1
	dc.l	$f0002400			; pflusha
	
	move.l	(sp)+,d1
	move.l	(sp)+,a0
	rts

