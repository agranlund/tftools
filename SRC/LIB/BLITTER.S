
;--------------------------------------------------------------
; BLITTER.S
;
;	BLIT_Detect
;
;
; This file is distributed under the GPL v2 or at your
; option any later version.  See LICENSE.TXT for details.
;
; Anders Granlund, 2019
;--------------------------------------------------------------

;--------------------------------------------------------------
section bss
;--------------------------------------------------------------
gBLIT_BushandlerOld	ds.l 1		; old bus error handler

;--------------------------------------------------------------
section text
;--------------------------------------------------------------


;--------------------------------------------------------------
BLIT_Detect:
; returns:
;	d0: 1 or 0
;--------------------------------------------------------------
	move.w	sr,d1
	or.w	#$0700,sr			; disable interrupts
	move.l	#0,d0
	move.l	sp,a2				; save old stack pointer
	move.l	$8,gBLIT_BushandlerOld		; save old bus handler
	move.l	#_blit_bushandler,$8		; install new bus handler
	tst.w	$FF8A00				; access blitter hardware
	move.l	#1,d0				; have blitter
_blit_detect_done:
	move.l	gBLIT_BushandlerOld,$8		; restore bus handler
	move.w	d1,sr				; restore interrupts
	rts
_blit_bushandler:
	move.l	a2,sp				; restore stack to before bus error
	bra	_blit_detect_done		; stop probing for memory


