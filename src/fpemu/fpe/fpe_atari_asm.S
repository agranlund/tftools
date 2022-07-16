/*
 * Copyright (c) 2022 Anders Granlund
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

//#define FPESTART	move.w	#0x2700,sr
#define FPESTART

#define SUPPORT_RELOCATED_TOS1	1

	.globl	_getVbr
	.globl	_setVbr

	.globl	_fpe_vec_lf
	.globl	_fpe_vec_lf_tos1
	.globl	_fpe_vec_lf_tos1r
	.globl	_fpe_vec_sf
	.globl	_fpe_vec_sf_tos1
	.globl	_fpe_vec_sf_tos1r
	.globl	_oldfline
	.globl 	_fpu_emulate
	.globl	_tos1bot
	.globl	_tos1top

	.bss
	.even

_tos1bot:	ds.l 1
_tos1top:	ds.l 1
_oldfline:	ds.l 1
stackbot:	ds.l 128*4
stacktop:

	.text
	.even


//------------------------------------------------------
//
// lineF vector - long stack frames (68010+)
//
//------------------------------------------------------


//------------------------------------------------------
// TOS1 in ROM
//------------------------------------------------------
xbra_lf1:		.long	0					// XBRA Magic
xbra_lf1_id:	.long	0					// XBRA ID
xbra_lf1_prev:	.long	0					// XBRA Prev
_fpe_vec_lf_tos1:
	FPESTART
	cmp.l	#0x00FC0000,2(sp)
	blt.s	_fpe_vec_lf
	cmp.l	#0x01000000,2(sp)
	bge.s	_fpe_vec_lf
	move.l	xbra_lf1_prev,-(sp)				// push previous vector
	rts										// and jump

//------------------------------------------------------
// TOS1 relocated
//------------------------------------------------------
xbra_lf1r:		.long	0					// XBRA Magic
xbra_lf1r_id:	.long	0					// XBRA ID
xbra_lf1r_prev:	.long	0					// XBRA Prev
_fpe_vec_lf_tos1r:
	FPESTART
	move.l	d0,-(sp)						// save regs
	move.l	6(sp),d0						// get caller address
	cmp.l	_tos1bot,d0						// from before tos rom?
	blt.s	fpe_vec_lf_tos1r_ok
	cmp.l	_tos1top,d0						// from after tos rom?
	bge.s	fpe_vec_lf_tos1r_ok
	move.l	(sp)+,d0
	move.l	xbra_lf1r_prev,-(sp)			// push previous vector
	rts										// and jump
fpe_vec_lf_tos1r_ok:
	move.l	(sp)+,d0
	btst    #5,(sp)
	beq.s	fpe_vec_lf_user
	bra.s	fpe_vec_lf_super

//------------------------------------------------------
// TOS2+
//------------------------------------------------------
xbra_lf:		.long	0					// XBRA Magic
xbra_lf_id:		.long	0					// XBRA ID
xbra_lf_prev:	.long	0					// XBRA Prev
_fpe_vec_lf:
	FPESTART
	btst    #5,(sp)
	beq.s	fpe_vec_lf_user

	//---------------------------------------
	// Supervisor
	//---------------------------------------
fpe_vec_lf_super:
	move.l	a5,-(sp)						// save a5 to real stack
	move.l	a6,-(sp)						// save a6 to real stack
	move.l	sp,a5
	add.l	#16,a5							// a5 = exception frame
	move.l	#stacktop,a6					// a6 = emulator stack
	move.w	-(a5),-(a6)						// format
	move.l	-(a5),-(a6)						// pc
	move.w	-(a5),-(a6)						// sr
	clrl	-(a6)							// stackadj
	movem.l	#0xFFFF,-(a6)					// registers
	move.l	(sp)+,56(a6)					// move saved a6 to emulator stack
	move.l	(sp)+,52(a6)					// move saved a5 to emulator stack
	addq.l	#8,sp							// discard stack frame
	move.l	sp,60(a6)						// save sp from before exception to emulator stack frame
	move.l	a6,sp							// emulator stack is now active

	move.l	a6,-(sp)
	jbsr	_fpu_emulate					// fpu_emulate((frame*)sp)
	lea		4(sp),sp

	move.l	sp,a6
	move.l	60(a6),sp						// real stack is now active
	move.l	#stacktop,a5					
	move.w	-(a5),-(sp)						// push format
	move.l	-(a5),-(sp)						// push pc
	move.w	-(a5),-(sp)						// push sr
	cmp.l	#0,d0
	bne.s	fpe_vec_super_fail
fpe_vec_super_success:
	movem.l	(a6),#0x7FFF					// restore most regs
	rte		
fpe_vec_super_fail:
	movem.l	(a6),#0x7FFF					// restore most regs
	move.l	xbra_lf_prev,-(sp)				// push previous vector
	rts										// and jump

	//---------------------------------------
	// Usermode
	//---------------------------------------
fpe_vec_lf_user:
	clrl	-(sp)							// stack adjust
	movem.l	#0xFFFF,-(sp)					// save all regs
	move.l	usp,a0							// get usp
	move.l	a0,60(sp)						// save to frame

	move.l	sp,-(sp)
	jbsr	_fpu_emulate					// fpu_emulate((frame*)sp)
	lea		4(sp),sp						// restore stack

	move.l	60(sp),a0						// get usp from frame
	move.l	a0,usp							// restore it
	cmp.l	#0,d0
	bne.s	fpe_vec_lf_user_fail
fpe_vec_lf_user_success:
	movem.l	(sp)+,#0x7FFF					// restore most regs
	addq.l	#8,sp							// pop SP and stack adjust
	rte								
fpe_vec_lf_user_fail:
	movem.l	(sp)+,#0x7FFF					// restore most regs
	addq.l	#8,sp							// pop SP and stack adjust
	move.l	xbra_lf_prev,(sp)					// push old vector
	rte										// and jump




//------------------------------------------------------
//
// lineF vector - short stack frames (68000)
//
//------------------------------------------------------ 


//------------------------------------------------------
// TOS1 in ROM
//------------------------------------------------------
xbra_sf1:		.long	0					// XBRA Magic
xbra_sf1_id:	.long	0					// XBRA ID
xbra_sf1_prev:	.long	0					// XBRA Prev
_fpe_vec_sf_tos1:
	FPESTART
	cmp.l	#0x00FC0000,2(sp)
	blt.s	_fpe_vec_sf
	cmp.l	#0x01000000,2(sp)
	bge.s	_fpe_vec_sf
	move.l	xbra_sf1_prev,-(sp)				// push previous vector
	rts										// and jump

//------------------------------------------------------
// TOS1 relocated
//------------------------------------------------------
xbra_sf1r:		.long	0					// XBRA Magic
xbra_sf1r_id:	.long	0					// XBRA ID
xbra_sf1r_prev:	.long	0					// XBRA Prev
_fpe_vec_sf_tos1r:
	FPESTART
	move.l	d0,-(sp)						// save regs
	move.l	6(sp),d0						// get caller address
	cmp.l	_tos1bot,d0						// from before tos rom?
	blt.s	fpe_vec_sf_tos1r_ok
	cmp.l	_tos1top,d0						// from after tos rom?
	bge.s	fpe_vec_sf_tos1r_ok
	move.l	(sp)+,d0						// restore regs
	move.l	xbra_sf1r_prev,-(sp)			// store previous vector
	rts										// and jump
fpe_vec_sf_tos1r_ok:
	move.l	(sp)+,d0
	btst    #5,(sp)
	beq.s	fpe_vec_sf_user
	bra.s	fpe_vec_sf_super

//------------------------------------------------------
// TOS2+
//------------------------------------------------------
xbra_sf:		.long	0					// XBRA Magic
xbra_sf_id:		.long	0					// XBRA ID
xbra_sf_prev:	.long	0					// XBRA Prev
_fpe_vec_sf:
	FPESTART
	btst    #5,(sp)
	beq.s	fpe_vec_sf_user
	//---------------------------------------
	// Supervisor
	//---------------------------------------
fpe_vec_sf_super:
	move.l	a5,-(sp)						// save a5 to real stack
	move.l	a6,-(sp)						// save a6 to real stack
	move.l	sp,a5
	add.l	#14,a5							// a5 = exception frame
	move.l	#stacktop,a6					// a6 = emulator stack
	move.w	#0,-(a6)						// fake format
	move.l	-(a5),-(a6)						// pc
	move.w	-(a5),-(a6)						// sr
	clrl	-(a6)							// stackadj
	movem.l	#0xFFFF,-(a6)					// registers
	move.l	(sp)+,56(a6)					// move saved a6 to emulator stack
	move.l	(sp)+,52(a6)					// move saved a5 to emulator stack
	addq.l	#6,sp							// discard stack frame
	move.l	sp,60(a6)						// save sp from before exception to emulator stack frame
	move.l	a6,sp							// emulator stack is now active

	move.l	sp,-(sp)
	jbsr	_fpu_emulate					// fpu_emulate((frame*)sp)
	lea		4(sp),sp

	move.l	sp,a6
	move.l	60(a6),sp						// real stack is now active
	move.l	#stacktop-2,a5					
	move.l	-(a5),-(sp)						// push pc
	move.w	-(a5),-(sp)						// push sr
	cmp.l	#0,d0							// failed?
	bne.s	fpe_vec_sf_super_fail
fpe_vec_sf_super_success:	
	movem.l	(a6),#0x7FFF					// restore most regs
	rte								
fpe_vec_sf_super_fail:
	movem.l	(a6),#0x7FFF					// restore most regs
	move.l	xbra_sf_prev,-(sp)				// push old vector
	rts										// and jump

	//---------------------------------------
	// Usermode
	//---------------------------------------
fpe_vec_sf_user:
	subq.l	#8,sp
	move.w	#0,6(sp)						// fake format
	move.l	10(sp),2(sp)					// pc
	move.w	8(sp),(sp)						// sr
	clrl	-(sp)							// stack adjust
	movem.l	#0xFFFF,-(sp)					// save all regs
	move.l	usp,a0							// get usp
	move.l	a0,60(sp)						// save to frame

	move.l	sp,-(sp)
	jbsr	_fpu_emulate					// fpu_emulate((frame*)sp)
	lea		4(sp),sp						// restore stack

	move.l	60(sp),a0						// get usp from frame
	move.l	a0,usp							// restore it
	cmp.l	#0,d0							// failed?
	bne.s	fpe_vec_sf_user_fail
fpe_vec_sf_user_success:
	movem.l	(sp)+,#0x7FFF					// restore most regs
	addq.l	#8,sp							// pop SP and stack adjust
	move.w	(sp),8(sp)						// restore sr
	move.l	2(sp),10(sp)					// restore pc
	addq.l	#8,sp							// get rid of fake frame
	rte
fpe_vec_sf_user_fail:
	movem.l	(sp)+,#0x7FFF					// restore most regs
	addq.l	#8,sp							// pop SP and stack adjust
	move.w	(sp),8(sp)						// restore sr
	move.l	2(sp),10(sp)					// restore pc
	addq.l	#8,sp							// get rid of fake frame
	move.l	xbra_sf_prev,-(sp)				// push old vector
	rts										// and jump
