;--------------------------------------------------------------------------
; BLITOFF.S
;
;	Blitter utility for TerribleFire accelerator.
;	Disables blitter for applications running outside of ST-RAM
;
; This file is distributed under the GPL v2, or at your option any
; later version.  See LICENSE.TXT for details.
;
; Version history:
;
; 1.1:  minor bugfixes.
; 1.0:	initial release.
;
; Anders Granlund, 2019
;
;--------------------------------------------------------------------------
	include "LIB\SYS.S"
	include "LIB\COOKIE.S"
	include "LIB\TTRAM.S"
	include "LIB\BLITTER.S"

;--------------------------------------------------------------
COOKIE_MAGIC	EQU	$424f4646	; 'BOFF'

OPT_DEBUG	SET	0		; debug mode + symbols
;--------------------------------------------------------------

;	COMMENT	HEAD=6

	IFNE	OPT_DEBUG
	OPT	XDEBUG
	ENDC


;--------------------------------------------------------------
section data
;--------------------------------------------------------------
sVersion		dc.b	13,10,$1b,'p',"BlitterOff v1.1 active",$1b,'q',13,10,0

;--------------------------------------------------------------
section bss
;--------------------------------------------------------------
gKeepResident		ds.b	1

;--------------------------------------------------------------
section text
;--------------------------------------------------------------
gPrevTrap14		ds.l	1
gStatus			ds.w	1

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

	; Check for blitter hardware
	bsr	BLIT_Detect
	tst.l	d0
	bne	BlitterOk
	rts
BlitterOk:

	; Check if already installed
	bsr	CheckCookie
	tst.l	d0
	bne	CookieOk
	rts
CookieOk:

	; no point running this unless we have fastram
	IFNE	OPT_DEBUG
	bsr	TTRAM_GetInstalled
	tst.l	d0
	bne	TTRamPresent
	rts
	ENDC
TTRamPresent:

	; turn off blitter
	move.w	#0,-(sp)
	move.w	#64,-(sp)
	trap	#14
	addq.l	#4,sp
	move.l	#0,gStatus
	move.w	#3,gStatus

	; replace xbios handler
	pea	Trap14(pc)
	move.w	#$2E,-(sp)		; xbios ($0B8 / 4)
	move.w	#5,-(sp)
	trap	#13			; setexec
	addq.l	#8,sp
	move.l	d0,gPrevTrap14

	; write cookie
	move.l	#COOKIE_MAGIC,d0
	move.l	#gStatus,d1
	bsr 	CK_WriteJar

	move.b	#1,gKeepResident
	rts

;--------------------------------------------------------------
Trap14:
;--------------------------------------------------------------
	move	usp,a0
	btst    #5,(sp)			; Already supervisor?
	beq.s   Trap14Handle
	lea     6(sp),a0
	tst.w   $59e.w			; Long stackframes?
	beq.s   Trap14Handle
	addq.l  #2,a0			; 2 more parameters for long stackframe
Trap14Handle:           
	move.w  (a0)+,d0		; d0 = xbios function number
	cmp.w   #64,d0
	beq.s   Trap14_Blitmode		; Blitmode
Trap14DoOld:
	movea.l gPrevTrap14(PC),a0	; call previous trap handler
	jmp	(a0)

;--------------------------------------------------------------
Trap14_Blitmode:
;--------------------------------------------------------------
	move.w	(a0),d0
	bmi	BlitModeGet		; dont set when mode is negative
	;and.w	#1,d0
	;move.w	d0,gStatus		; store requested status
	bra	BlitModeIgnore
BlitModeGet:
	move.l	-8(a0),d0
	cmp.l	#$A00000,d0		; no blitter for callers outside ST-RAM
	bcc	BlitModeIgnore
	cmp.l	#Main,d0		; or from before us
	bcs	BlitModeIgnore
	move.w	gStatus,d0		; blitter status
	rte
BlitModeIgnore:
	move.w	#0,d0			; blitter not present
	rte


;--------------------------------------------------------------
CheckCookie:
; returns:
;	d0: 0 or 1
;--------------------------------------------------------------
	move.l	#COOKIE_MAGIC,d1
	move.l	$5a0,d0			; has cookies?
	beq	_checkcookie_ok
	move.l	d0,a0
	clr.l	d0
_checkcookie_loop:
	tst.l	(a0)			; end of cookies?
	beq	_checkcookie_ok
	cmp.l	(a0),d1			; compare cookie name
	beq	_checkcookie_fail
	addq.l	#8,a0
	bra	_checkcookie_loop
_checkcookie_ok:
	move.l	#1,d0	
	rts
_checkcookie_fail:
	clr.l	d0
	rts


