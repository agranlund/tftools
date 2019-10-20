
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
section data
;--------------------------------------------------------------
PMMU030_CRP:	dc.l $80000002,PMMU030_TABLE_TIA	; no limit, short desc, addr $700
PMMU030_TC:	dc.l $80f04445 				; enable, pagesize 32k, IS=0, TIA=4, TIB=4, TIC=4, TID=5
PMMU030_TTR0:	dc.l $017e8107 				; 0x01000000-0x7fffffff, cache allowed
PMMU030_TTR1:	dc.l $807e8507 				; 0x80000000-0xfeffffff, cache inhibited


;--------------------------------------------------------------
section text
;--------------------------------------------------------------

PMMU030_TABLE_TIA	equ $700
PMMU030_TABLE_TIB1	equ $740
PMMU030_TABLE_TIB2	equ $780
PMMU030_TABLE_TIC	equ $7C0

PMOVE030_TC	MACRO
		dc.l	$f0394000,\1	; pmove addr,tc
		ENDM

PMOVE030_CRP	MACRO
		dc.l	$f0394c00,\1	; pmove addr,crp
		ENDM

PMOVE030_TTR0	MACRO
		dc.l	$f0390800,\1	; pmove addr,ttr0
		ENDM

PMOVE030_TTR1	MACRO
		dc.l	$f0390c00,\1	; pmove addr,ttr1
		ENDM

PFLUSH030	MACRO
		dc.l	$f0002400	; pflusha
		ENDM

PMMU030_TABLE	MACRO
		move.l	#\1+$02,(a0)+
		ENDM

PMMU030_PAGE	MACRO
		move.l	#\1+$01,(a0)+
		ENDM

PMMU030_PAGE_CI	MACRO
		move.l	#\1+$01+$40,(a0)+
		ENDM


;--------------------------------------------------------------
MMU030_Install
;--------------------------------------------------------------
	lea.l		PMMU030_TABLE_TIA,a0

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
        PMMU030_PAGE	$00000000		; 0xff000000-0xffefffff -> 0x00000000-0x00efffff, allow cache
        PMMU030_PAGE	$00100000
        PMMU030_PAGE	$00200000
        PMMU030_PAGE	$00300000
        PMMU030_PAGE	$00400000
        PMMU030_PAGE	$00500000
        PMMU030_PAGE	$00600000
        PMMU030_PAGE	$00700000
        PMMU030_PAGE	$00800000
        PMMU030_PAGE	$00900000
        PMMU030_PAGE	$00a00000
        PMMU030_PAGE	$00b00000
        PMMU030_PAGE	$00c00000
        PMMU030_PAGE	$00d00000
        PMMU030_PAGE	$00e00000
        PMMU030_PAGE_CI	$00f00000		; 0xfff00000-0xffffffff -> 0x00f00000-0x00ffffff, cache inhibit

	PMOVE030_CRP	PMMU030_CRP
	PMOVE030_TC	PMMU030_TC
	PMOVE030_TTR0	PMMU030_TTR0
	PMOVE030_TTR1	PMMU030_TTR1
	PFLUSH030

	rts

