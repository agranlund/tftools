;--------------------------------------------------------------
; MAPROM.S
;
;	Fastram utility for TerribleFire accelerator.
;	Loads contents of TOS ROMs into FastRAM.
;
; This file is distributed under the GPL v2 or at your
; option any later version.  See LICENSE.TXT for details.
;
; Anders Granlund, 2019
;--------------------------------------------------------------
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
gRomBuffer		ds.l	1

;--------------------------------------------------------------
section data
;--------------------------------------------------------------
sSuccess		dc.b	13,10,"ROM mapped to TT-RAM",0
sNoRam			dc.b	13,10,"Not enough TT-RAM",0
sRamFound		dc.b	13,10,"TT-RAM detected: ",0
sMB			dc.b	"MB",0

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
	bne	SYS_QuitKeepResident
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
	;lea	sNoRam(pc),a0			; no tt-ram detected.
	;bsr	SYS_Print
	rts
InstallRam:
	movem.l d0-d2/a0-a2,-(sp)
	lea	sRamFound(pc),a0	
	bsr	SYS_Print			; display amount of tt-ram
	swap	d0
	ror.l	#4,d0				; in MB
	;lsl.l	#6,d0				; in KB
	bsr	SYS_PrintLong
	lea	sMB(pc),a0
	bsr	SYS_Print	
	movem.l (sp)+,d0-d2/a0-a2
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

	; allocate ram
	move.w	#1,-(sp)			; allocate alt-ram only
	move.l	d3,d4
	add.l	#$8000,d4
	move.l	d4,-(sp)			; size + 32k
	move.w	#68,-(sp)			; Mxalloc
	trap	#1
	addq.l	#8,sp
	tst.l	d0				; memory allocated?
	bne	RamAllocatedOk
	;lea	sNoRam(pc),a0			; unable to allocate ram
	;bsr	SYS_Print
	rts
RamAllocatedOk:
	add.l 	#$7FFF,d0			; allign for 32k pages
	and 	#$8000,d0
	move.l 	d0,gRomBuffer			; store ptr to rombuffer

	; copy rom -> ram
	move.l	a3,a0
	exg.l	d0,a4				; a4 = dst, a3 = src
	move.l	d3,d0
	lsr.l	#2,d0				; d0 = num longs to copy
CopyToRam:
	move.l	(a3)+,(a4)+
	subq.l	#1,d0
	bne	CopyToRam

	; configure mmu
	move.l	gRomBuffer,d0
	or	#5,d0				; page + writeprotect flags
	; ptestr #2,([8,a0]),#7,a0
	dc.b	$F0,$30,$9F,$12,$01,$71,$00,$00,$00,$08
	move.l d0,(a0)
	; pflusha
	dc.b	$F0,$00,$24,$00
	move.l	#COOKIE_PMMU,d0			; Write 'PMMU' cookie
	move.l	#0,d1
	bsr 	CK_WriteJar

	lea	sSuccess(pc),a0
	bsr	SYS_Print

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




