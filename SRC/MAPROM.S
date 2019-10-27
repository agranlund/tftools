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
; 1.2:  Early exit if TOS is not at $E00000
;       Allocate new MMU table instead of assuming old one at $700
;
; 1.1:	Remap 512Kb instead of 1MB, leaving $E80000-$EFFFFF untouched
;
; 1.0:	initial release. Remaps $E00000-$EFFFFF to TT-RAM 
;
; Anders Granlund, 2019
;
;
;
; TODO:
;  - TOS2.06: Cannot read floppy if cache is enabled.
;
;--------------------------------------------------------------------------
	include "LIB\SYS.S"
	include "LIB\CPU.S"
	include "LIB\MMU030.S"
	include "LIB\COOKIE.S"
	include "LIB\TTRAM.S"

COOKIE_PMMU	EQU	$504d4d55

;--------------------------------------------------------------
section bss
;--------------------------------------------------------------
gKeepResident		ds.b	1

;--------------------------------------------------------------
section data
;--------------------------------------------------------------
sVersion		dc.b	13,10,$1b,'p',"Maprom v1.2 active",$1b,'q',13,10,0


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
	bra	SYS_QuitKeepResidentMallocOnly
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

	; check rom size and start address
	move.l	$4f2,a0				; a0 = _sysbase
	move.w	2(a0),d0			; d0 = tos version number
	move.l	#$30000,d3			; d3 = 192Kb (Tos 1.xx)
	cmp.w	#$200,d0
	blt	RomSizeDone
	move.l	#$40000,d3			; d3 = 256Kb (Tos 2.xx)
	cmp.w	#$300,d0	
	blt	RomSizeDone
	move.l	#$80000,d3			; d3 = 512Kb (Tos 3.xx / 4.xx)
RomSizeDone:
	move.l	8(a0),a3			; a3 = TOS start addr
	cmp.l	#$e00000,a3			; We only support rom at 0x00E00000
	beq	RomAddrOk
	rts
RomAddrOk:

	; check for / install tt-ram
	move.l	a3,-(sp)
	move.l	d3,-(sp)
	bsr	TTRAM_GetInstalled		; tt-ram already installed?
	tst.l	d0
	bne	RamExists
DetectRam:
	bsr	TTRAM_Detect			; detect tt-ram
	tst.l	d0
	bne	InstallRam
	addq.l	#8,sp
	rts
InstallRam:
	bsr	TTRAM_Install			; install tt-ram + frb
	move.b	#1,gKeepResident		; keep resident
RamExists:
	move.l	(sp)+,d3
	move.l	(sp)+,a3

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
	and.l 	#$FFFF8000,d0

	move.l	d0,-(sp)
	;bsr	CPU_CacheDisable
	move.l	#0,d0				; d0=0 indicates allocate new buffer
	bsr	MMU030_Install			; configure PMMU as TT/Falcon
	tst.l	d0
	bne	MmuAllocatedOk
	move.l	(sp)+,d0
	rts
MmuAllocatedOk:
	move.l	d0,a5				; a5 = MMU table base address
	move.l	(sp)+,d0

	; copy rom to tt-ram
	move.l	d0,a4
	lsr.l	#2,d3				; d3 = num longs to copy
CopyRomToRam:
	move.l	(a3)+,(a4)+
	subq.l	#1,d3
	bne	CopyRomToRam

	; Set relocation page flags
	move.l	#5,d4				; d4 = PAGE | WRITE_PROTECT
;	cmp.l	#"ETOS",$E0002C
;	beq	MmuFlagsDone
;	or.l	#$40,d4				; CACHE_INHIBIT on Atari TOS
MmuFlagsDone:

	; create TID table for 0x00E00000 - 0x00EFFFFF
	move.l	d0,d1
	or.l	d4,d1				; d1 = relocate address | flags
	move.l	a4,d0
	move.l	#16,d3				; d3 = 16 entires (512Kb)
CreateTID1a:
	move.l	d1,(a4)+
	add.l	#$8000,d1
	sub.l	#1,d3
	bne	CreateTID1a
	move.l	#$E80041,d1			; d1 = no relocation | PAGE | CACHE_INHIBIT
	move.l	#16,d3				; d3 = 16 entries (512Kb)
CreateTID1b:	
	move.l	d1,(a4)+
	add.l	#$8000,d1
	sub.l	#1,d3
	bne	CreateTID1b
	or.l	#2,d0				; map 0xE00000-0xEFFFFF to table TID1
	move.l	d0,$f8(a5)			; at offset 0xf8 in TIA table
	dc.b	$F0,$00,$24,$00			; pflusha

MmuSetupDone:
	move.l	#COOKIE_PMMU,d0			; Write 'PMMU' cookie
	move.l	#0,d1
	bsr 	CK_WriteJar

	;bsr	CPU_CacheClear			; clear cache

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




