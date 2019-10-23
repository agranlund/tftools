;--------------------------------------------------------------------------
; MAPROM.S
;
;	Fastram utility for TerribleFire accelerator.
;	Loads contents of TOS ROMs into FastRAM.
;
; This file is distributed under the GPL v2, or at your option any
; later version.  See LICENSE.TXT for details.
;
; Version history:
;
; 1.1:	Remap 512Kb instead of 1MB, leaving $E80000-$EFFFFF untouched
;
; 1.0:	initial release. Remaps $E00000-$EFFFFF to TT-RAM 
;
; Anders Granlund, 2019
;--------------------------------------------------------------------------
	include "LIB\SYS.S"
	include "LIB\CPU.S"
	include "LIB\TTRAM.S"
	include "LIB\MMU030.S"
	include "LIB\COOKIE.S"

COOKIE_PMMU	EQU	$504d4d55

;--------------------------------------------------------------
section bss
;--------------------------------------------------------------
gKeepResident		ds.b	1

;--------------------------------------------------------------
section data
;--------------------------------------------------------------
sVersion		dc.b	13,10,$1b,'p',"Maprom v1.1 active",$1b,'q',13,10,0


;--------------------------------------------------------------
section text
;--------------------------------------------------------------


;--------------------------------------------------------------
Main
;--------------------------------------------------------------
	move.b	#0,gKeepResident
	lea	MainSU(pc),a0
	bsr	SYS_SupervisorCall
	tst.b	gKeepResident
	bne	MainSuccess
	rts
MainSuccess:
	lea	sVersion(pc),a0
	bsr	SYS_Print	
	bra	SYS_QuitKeepResident
	rts

MainSU:
	bsr	CPU_Get
	cmp.l	#30,d0				; CPU must be 68030
	beq	CpuOk
	rts
CpuOk:
	bsr	CheckMmuCookie			; PMMU cookie must not already exist 
	tst.l	d0
	bne	MmuOk
	rts
MmuOk:
	bsr	TTRAM_GetInstalled		; tt-ram already installed?
	tst.l	d0
	bne	RamExists
DetectRam:
	bsr	TTRAM_Detect			; detect tt-ram
	tst.l	d0
	bne	InstallRam
	rts
InstallRam:
	;movem.l d0-d2/a0-a2,-(sp)
	;lea	sRamFound(pc),a0	
	;bsr	SYS_Print			; display amount of tt-ram
	;swap	d0
	;ror.l	#4,d0				; in MB
	;bsr	SYS_PrintLong
	;lea	sMB(pc),a0
	;bsr	SYS_Print	
	;movem.l (sp)+,d0-d2/a0-a2
	bsr	TTRAM_Install			; install tt-ram + frb
	bsr	MMU030_Install			; configure PMMU as TT/Falcon
	move.b	#1,gKeepResident		; keep resident
RamExists:

	; check rom size and start address
	move.l	$4f2,a0				; a0 = _sysbase
	move.w	2(a0),d0			; d0 = tos version number
	move.l	#$fc0000,a3			; Tos 1.xx = 192Kb at 0xFC0000
	move.l	#$30000,d3
	cmp.w	#$200,d0
	blt	RomSizeDone
	move.l	#$e00000,a3			; Tos 2.xx = 256Kb at 0xE00000
	move.l	#$40000,d3
	cmp.w	#$300,d0	
	blt	RomSizeDone
	move.l	#$e00000,a3			; Tos 3.xx : 512Kb at 0xE00000
	move.l	#$80000,d3			; Tos 4.xx : 512Kb at 0xE00000
RomSizeDone:
	cmp.l	#$e00000,a3			; We only support rom at 0x00E00000
	beq	RomAddrOk
	rts

RomAddrOk:
	; allocate ram for rom buffer
	move.w	#1,-(sp)			; allocate alt-ram only
	move.l	d3,d4
	add.l	#$8400,d4			; size + 32k + 1k
	move.l	d4,-(sp)			
	move.w	#68,-(sp)			; Mxalloc
	trap	#1
	addq.l	#8,sp
	tst.l	d0				; memory allocated?
	bne	RamAllocatedOk
	rts
RamAllocatedOk:
	add.l 	#$7FFF,d0			; allign for 32k pages
	and 	#$8000,d0

	; copy rom to tt-ram
	move.l 	d0,a4				; a4 = dst, a3 = src
	lsr.l	#2,d3				; d3 = num longs to copy
CopyRomToRam:
	move.l	(a3)+,(a4)+
	subq.l	#1,d3
	bne	CopyRomToRam

	; create TID table for 0x00E00000 - 0x00EFFFFF
	move.l	d0,d1
	or.l	#5,d1				; d1 = relocate adress | PAGE | WRITEPROTECT
	move.l	a4,d0
	move.l	#16,d3				; d3 = 16 entires (512Kb)
CreateTID1a:
	move.l	d1,(a4)+
	add.l	#$8000,d1
	sub.l	#1,d3
	bne	CreateTID1a
	move.l	#$E80001,d1			; d1 = no relocation | PAGE
	move.l	#16,d3				; d3 = 16 entries (512Kb)
CreateTID1b:	
	move.l	d1,(a4)+
	add.l	#$8000,d1
	sub.l	#1,d3
	bne	CreateTID1b
	or.l	#2,d0				; map 0xE00000-0xEFFFFF to table TID1
	move.l	d0,$7f8				; at offset 0xf8 in default TIA table
	dc.b	$F0,$00,$24,$00			; pflusha

MmuSetupDone:
	move.l	#COOKIE_PMMU,d0			; Write 'PMMU' cookie
	move.l	#0,d1
	bsr 	CK_WriteJar

	move.b	#1,gKeepResident		; keep resident
	rts

	

;--------------------------------------------------------------
CheckMmuCookie:
; returns:
;	d0: 0 or 1
;--------------------------------------------------------------
	move.l	#COOKIE_PMMU,d1		; 'PMMU'
	move.l	$5a0,d0			; has cookies?
	beq	_checkmmu_ok
	move.l	d0,a0
	clr.l	d0
_checkmmu_loop:
	tst.l	(a0)			; end of cookies?
	beq	_checkmmu_ok
	cmp.l	(a0),d1			; compare cookie name
	beq	_checkmmu_fail
	addq.l	#8,a0
	bra	_checkmmu_loop
_checkmmu_ok:
	move.l	#1,d0	
	rts
_checkmmu_fail:
	clr.l	d0
	rts




