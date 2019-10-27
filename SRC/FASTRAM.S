;--------------------------------------------------------------
; FASTRAM.S
;
;	Fastram utility for TerribleFire accelerator.
;	Registers Fastram, FRB and PMMU table.
;
;
; This file is distributed under the GPL v2 or at your
; option any later version.  See LICENSE.TXT for details.
;
; Anders Granlund, 2019
;--------------------------------------------------------------
	include "LIB\SYS.S"
	include "LIB\CPU.S"
	include "LIB\MMU030.S"
	include "LIB\COOKIE.S"
	include "LIB\TTRAM.S"

;--------------------------------------------------------------
section bss
;--------------------------------------------------------------

;--------------------------------------------------------------
section data
;--------------------------------------------------------------
sAlreadyInstalled	dc.b	13,10,"TT-RAM already registered",0
sNoRam			dc.b	13,10,"TT-RAM not found",0
sRamFound		dc.b	13,10,"TT-RAM registered: ",0
sMB			dc.b	"MB",13,10,0

;--------------------------------------------------------------
section text
;--------------------------------------------------------------


;--------------------------------------------------------------
Main
;--------------------------------------------------------------
	lea	MainSU(pc),a0
	bsr	SYS_SupervisorCall
	tst.l	d0
	bne	InstallTSR
	rts
InstallTSR:
	bra	SYS_QuitKeepResidentMallocOnly
	rts

MainSU:
	bsr	CPU_Get
	cmp.l	#20,d0
	bge	CpuOk				; CPU at least 68020?
	clr.l	d0
	rts
CpuOk:
	bsr	TTRAM_GetInstalled		; check if tt-ram was already installed by TOS
	tst.l	d0
	beq	DetectRam
	clr.l	d0 
	rts
DetectRam:
	bsr	TTRAM_Detect			; detecting amount of tt-ram
	tst.l	d0
	bne	Install
	lea	sNoRam(pc),a0			; no tt-ram detected.
	bsr	SYS_Print
	clr.l	d0
	rts
Install:
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

	bsr	CPU_Get
	cmp.l	#30,d0				; CPU is 68030?
	bne	InstallDone

	move.l	#0,d0
	bsr	MMU030_Install			; configure PMMU as TT/Falcon

	;bsr	CPU_CacheClear			; flush cache

InstallDone:
	move.l	#1,d0				; keep frb resident
	rts


