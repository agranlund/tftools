
;--------------------------------------------------------------
; CPU.S
;
;	CPU_Get
;	CPU_CacheDisable
;	CPU_CacheClear
;
; This file is distributed under the GPL v2 or at your
; option any later version.  See LICENSE.TXT for details.
;
; Anders Granlund, 2019
;--------------------------------------------------------------

	section text

;--------------------------------------------------------------
CPU_Get:
; returns:
;	d0.w: cpu type (0,10,20,30,40,60)
;--------------------------------------------------------------
	move.l	a0,-(sp)
	move.l	d1,-(sp)
	move.l	$5A0,d0			; has cookies?
	beq	.fail
	move.l	d0,a0
	move.l	#'_CPU',d1
.loop:
	tst.l	(a0)			; end of cookies?
	beq	.fail
	cmp.l	(a0),d1			; compare cookie name
	beq	.found
	addq.l	#8,a0
	bra	.loop
.found:
	move.w	6(a0),d0		
	move.l	(sp)+,d1
	move.l	(sp)+,a0
	rts
.fail:
	moveq.l	#0,d0
	move.l	(sp)+,d1
	move.l	(sp)+,a0
	rts

;--------------------------------------------------------------
CPU_CacheDisable:
;--------------------------------------------------------------
	move.l	d0,-(sp)
	move.w	sr,-(sp)
	ori.w	#$0700,sr
	dc.b	$4e,$7a,$00,$02		; movec.l cacr,d0
	move.l	#$808,d0		; disable cache
	dc.b	$4e,$7b,$00,$02		; movec.l d0,cacr
	move.w	(sp)+,sr
	move.l	(sp)+,d0
	rts

;--------------------------------------------------------------
CPU_CacheClear:
;--------------------------------------------------------------
	move.l	d0,-(sp)
	bsr	CPU_Get
	cmp.w	#20,d0
	bcc	.cpuOK
	move.l	(sp)+,d0
	rts
.cpuOK:
	move.w	sr,-(sp)
	ori.w	#$0700,sr
	dc.b	$4e,$7a,$00,$02		; get cache register
	or.l	#$808,d0
	dc.b	$4e,$7b,$00,$02		; set cache register
	move.w	(sp)+,sr
	move.l	(sp)+,d0
	rts
	
