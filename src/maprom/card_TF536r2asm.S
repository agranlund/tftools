    .text
    .even

#define VEC(x) .long 0,0,0; .globl x; x:


// * ----------------------------------------------------------------------
// * dummy dma irq handler
// * ----------------------------------------------------------------------
VEC(_vecDmaIrq_None)
	move.b	#0x7F,0xFA11.w              // * clear in-service bit
    rte


// * ----------------------------------------------------------------------
// * end-of-dma interrupt
// * ----------------------------------------------------------------------
.MACRO DmaVector siz shadowreg shadowram
VEC(_vecDmaIrq_TF536r2_\siz)
	movem.l	a0-a1/d0-d2,-(sp)           // * save regs

	// * clear caches
	.word	0x4e7a,0x0002				// * movec cacr,d0
	ori.w	#0x0808,d0					// * flush
	.word   0x4e7b,0x0002				// * movec d0,cacr

	// * get start address by reading from shadow-regs
	move.l	#0x8608+\shadowreg,a0
	movep.l	1(a0),d0
	btst	#31,d0						// * check if valid
	bne		.vdskip\siz
	lsr.l	#8,d0						// * d0 = start address

	// * get end address by reading the current DMA address counter
	move.l	#0x00FF8608,a1
	movep.l	1(a1),d1
	lsr.l	#8,d1						//  * d1 = end address

	// * try to figure out if this interrupt is relevant
	cmp.l	d1,d0						// * skip if start >= end
	bhs.s	.vdskip\siz
	sub.l	d0,d1						// * d1 = byte count

	// * invalidate shadow-reg
	move.b	#0xFF,0x8609+\shadowreg

	// * prepare to copy from st-ram to shadow-ram
	move.l	d0,a0						// * a0 = src ptr
	or.l	#\shadowram,d0
	move.l	d0,a1						// * a1 = dst ptr

	// * disable reads from shadow-ram
	move.b	0xFD10.w,d0					// * save tf536 settings in d0
	or.b	#0x8,0xFD10.w				// * disable ram L2

	// * and copy
	lsr.l	#4,d1						// * d1 = number of 16byte iterations
	cmp.l	#0,d1
	bne		.vdcopystart\siz			// * copy at least one iteration if count was < 16. shoouldn't really happen.
.vdcopyloop\siz:
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
.vdcopystart\siz:
	dbra	d1,.vdcopyloop\siz			// * decrement and jump if -1

	// * restore tf536 settings and return
	move.b	d0,0xFD10.w
.vdskip\siz:
	movem.l	(sp)+,a0-a1/d0-d2           // * restore regs
	move.b	#0x7F,0xFA11.w              // * clear in-service bit
	rte
.ENDM

	DmaVector  64 0x04BF0000 0x04C00000
	DmaVector 128 0x08BF0000 0x08C00000





#if 0
    .long	0   				    	// XBRA Magic
    .long	0	    		    		// XBRA ID
    .long	0		        			// XBRA Prev
_vecDmaIrq_TF536r2_64:
	movem.l	a0-a1/d0-d2,-(sp)           // * save regs

	// * clear caches
	.word	0x4e7a,0x0002				// * movec cacr,d0
	ori.w	#0x0808,d0					// * flush
	.word   0x4e7b,0x0002				// * movec d0,cacr

	// * get start address by reading from shadow-regs
	move.l	#0x04BF8608,a0
	movep.l	1(a0),d0
	btst	#31,d0						// * check if valid
	bne		.vd64skip
	lsr.l	#8,d0						// * d0 = start address

	// * get end address by reading the current DMA address counter
	move.l	#0x00FF8608,a1
	movep.l	1(a1),d1
	lsr.l	#8,d1						//  * d1 = end address

	// * try to figure out if this interrupt is relevant
	cmp.l	d1,d0						// * skip if start >= end
	bhs.s	.vd64skip
	sub.l	d0,d1						// * d1 = byte count

	// * invalidate shadow-reg
	move.b	#0xFF,0x04BF8609

	// * prepare to copy from st-ram to shadow-ram
	move.l	d0,a0						// * a0 = src ptr
	or.l	#0x04C00000,d0
	move.l	d0,a1						// * a1 = dst ptr

	// * disable reads from shadow-ram
	move.b	0xFD10.w,d0					// * save tf536 settings in d0
	or.b	#0x8,0xFD10.w				// * disable ram L2

	// * and copy
	lsr.l	#4,d1						// * d1 = number of 16byte iterations
	cmp.l	#0,d1
	bne		.vd64copy_start				// * copy at least one iteration if count was < 16. shoouldn't really happen.
.vd64copy_loop:
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
.vd64copy_start:
	dbra	d1,.vd64copy_loop			// * decrement and jump if -1

	// * restore tf536 settings and return
	move.b	d0,0xFD10.w
.vd64skip:
	movem.l	(sp)+,a0-a1/d0-d2           // * restore regs
	move.b	#0x7F,0xFA11.w              // * clear in-service bit
	rte
#endif

