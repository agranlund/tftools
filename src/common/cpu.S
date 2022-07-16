
	.text

	.globl	_disableInterrupts
	.globl	_restoreInterrupts
	.globl	_safeRead8

	.globl	_jump
	.globl	_flushCache020
	.globl	_flushCache040
	.globl	_getCACR
	.globl	_setCACR
	.globl	_getSR
	.globl	_setSR
	.globl	_getVBR
	.globl	_setVBR

_jump:
	move.l	4(sp),a0
	move.l	a0,-(sp)
	rts

_flushCache000:
	rts

_flushCache020:
	nop
	.word	0x4e7a,0x0002		// movec cacr,d0
	ori.w	#0x0808,d0			// flush
	.word   0x4e7b,0x0002		// movec d0,cacr
	movec	d0,cacr
	nop
	rts

_flushCache040:
	nop
    .word 	0xf4f8				// cpusha bc
	nop
	rts

_getCACR:
	.word	0x4e7a,0x0002		// movec cacr,d0
	rts

_setCACR:
	.word	0x4e7a,0x0002		// movec cacr,d0
	move.l	4(sp),d1			// d1 = requested cacr
	ori.w	#0x0808,d1			// flush
	.word   0x4e7b,0x1002		// movec d1,cacr
	rts

_getSR:
	move.w	sr,d0
	rts

_setSR:
	move.l	4(sp),d1
	move.w	sr,d0
	move.w	d1,sr
	rts

_getVBR:
	.word 0x4e7a,0x0801			// movec vbr,d0
	rts

_setVBR:
	move.l	4(sp),d0
	.word 0x4e7b,0x0801			// movec d0,vbr
	rts



_disableInterrupts:
	move.w	sr,d0
	move.w	d0,d1
	or.w	#0x700,d1
	move.w	d1,sr
	rts

_restoreInterrupts:
	move.w	sr,d0
	and.w	#0xF0FF,d0
	move.l	4(sp),d1
	and.w	#0x0700,d1
	or.w	d1,d0
	move.w	d0,sr
	rts

_safeRead8:
	move.l	4(sp),a0			//; a0 = src addr
	moveq	#0,d0				//; d0 = return value
	move.l	0x8,-(sp)			//; save old berr handler
	move.l	sp,a1				//; a1 = old stack ptr
	move.l	#.sr8err,0x8		//; install new bus handler
	move.b	(a0),d0				//; try read
	move.l	(sp)+,0x8			//; restore original berr handler
	rts
.sr8err:
	move.l	a1,sp				//; restore stack to before bus error
	move.l	(sp)+,0x8			//; restore original berr handler
	rts

