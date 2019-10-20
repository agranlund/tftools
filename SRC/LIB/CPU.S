
;--------------------------------------------------------------
; CPU.S
;
;	CPU_Get
;	CPU_Is030
;
;
; This file is distributed under the GPL v2 or at your
; option any later version.  See LICENSE.TXT for details.
;
; Anders Granlund, 2019
;--------------------------------------------------------------

section text

;--------------------------------------------------------------
CPU_Get
; returns:
;	d0: cpu type (0,10,20,30,40,60)
;--------------------------------------------------------------
	move.l	#$5f435055,d1		; '_CPU'
	move.l	$5A0,d0			; has cookies?
	beq	_cpu_get_fail
	move.l	d0,a0
	clr.l	d0
_cpu_get_loop:
	tst.l	(a0)			; end of cookies?
	beq	_cpu_get_fail
	cmp.l	(a0),d1			; compare cookie name
	beq	_cpu_get_found
	addq.l	#8,a0
	bra	_cpu_get_loop
_cpu_get_found:
	move.l	4(a0),d0		
	rts
_cpu_get_fail:
	move.l	#0,d0
	rts

