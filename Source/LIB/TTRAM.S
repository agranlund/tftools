;--------------------------------------------------------------
; TTRAM.S
;
;	TTRAM_GetInstalled
;	TTRAM_Detect
;	TTRAM_Install
;
;	depends on COOKIE.S
;
;
; This file is distributed under the GPL v2 or at your
; option any later version.  See LICENSE.TXT for details.
;
; Anders Granlund, 2019
;--------------------------------------------------------------
TTRL_MEMBOTTOM		EQU	$01000000
TTRL_MEMMAXSIZE		EQU	128
TTRL_FASTRAMMAGIC	EQU	$1357bd13
TTRL_FASTRAMCOOKIE	EQU	$5f465242

;--------------------------------------------------------------
    section bss
;--------------------------------------------------------------
gTTRL_RamTop		ds.l 1		; fastram top
gTTRL_BushandlerOld	ds.l 1		; old bus error handler

;--------------------------------------------------------------
    section text
;--------------------------------------------------------------



;--------------------------------------------------------------
TTRAM_GetInstalled:
; returns:
;	d0: size
;	d1: ram top
;	d2: ram bottom
;--------------------------------------------------------------
	cmp.l 	#TTRL_FASTRAMMAGIC,$5a8.w	; Ask bios for fastram magic
	bne	.err
	move.l	#TTRL_MEMBOTTOM,d2
	move.l	$5a4.w,d1			; Ask bios for fastram top
	cmp.l	d2,d1				; Verify it is in TT ram range
	ble	.err
	move.l	d1,d0
	sub.l	d2,d0
	move.l	d1,gTTRL_RamTop
	rts		
.err:	moveq.l	#0,d0
	moveq.l	#0,d1
	moveq.l	#0,d2
	move.l	#0,gTTRL_RamTop
	rts


;--------------------------------------------------------------
TTRAM_Detect:
; returns:
;	d0: size
;	d1: ram top
;	d2: ram bottom
;--------------------------------------------------------------
	bsr 	.detect
	cmp.l	#TTRL_MEMBOTTOM,gTTRL_RamTop
	ble	.fail
	move.l	#TTRL_MEMBOTTOM,d2		; d2 = ram bottom
	move.l	gTTRL_RamTop,d1			; d1 = ram top
	move.l	d1,d0
	sub.l	d2,d0				; d0 = size
	rts
.fail:	move.l	#0,d0
	move.l	#0,d1
	move.l	#0,d2	
	rts
.detect:
	move.l	#0,gTTRL_RamTop
	cmp.l 	#TTRL_FASTRAMMAGIC,$5a8.w	; Ask bios for fastram magic
	bne	.probe
	move.l	$5a4.w,gTTRL_RamTop		; Ask bios for fastram top
	cmp.l	#TTRL_MEMBOTTOM,gTTRL_RamTop	; Verify it's in TT ram range
	ble	.probe
	rts
.probe:	move.l	sp,a6				; save old stack pointer
	move.l	$8,gTTRL_BushandlerOld		; save old bus handler
	move.l	#.err,$8			; install new bus handler
	move.l	#TTRL_MEMBOTTOM,gTTRL_RamTop
	move.w	#TTRL_MEMMAXSIZE,d3
.loop:	movea.l	(gTTRL_RamTop),a2
	move.l	(a2),d4				; bus error test

	add.l	#1234,d4			; write/readback test
	move.l	d4,(a2)
	dc.b	$4e,$7a,$00,$02			; get cache register
	or.l	#$808,d0			; clear cache
	dc.b	$4e,$7b,$00,$02			; set cache register	
	cmp.l	(a2),d4
	bne	.done

	add.l	#$00100000,gTTRL_RamTop		; check 1MB intervals
	sub.w	#1,d3
	tst.w	d3
	bne	.loop
.done:	move.l	gTTRL_BushandlerOld,$8		; restore bus handler
	rts
.err:	move.l	a6,sp				; restore stack to before bus error
	bra	.done				; stop probing for memory


;--------------------------------------------------------------
TTRAM_Install:
; inputs:
;	d0: size
;--------------------------------------------------------------
	move.l	d0,-(sp)			; size
	move.l	#TTRL_MEMBOTTOM,-(sp)		; start
	move.w	#20,-(sp)			; maddalt(size, start)
	trap	#1				; 
	add.l	#6,sp				; keep size on stack
	tst.l	d0				; tos supports altram?
	bne	.fail

	move.w	#0,-(sp)			; allocate st-ram only
	move.l	#$10000,-(sp)			; 64Kb			
	move.w	#68,-(sp)			; Mxalloc
	trap	#1
	addq.l	#8,sp
	tst.l	d0				; failed to allocate?
	beq	.fail
	cmp.l	#-32,d0				; mxalloc not available?
	beq	.fail

	move.l	d0,d1				; 64Kb fastram buffer
	move.l	#$5f465242,d0			; '_FRB'
	bsr 	CK_WriteJar			; write cookie

	move.l	(sp)+,d0
	move.l	#TTRL_MEMBOTTOM,d1	
	add.l	d0,d1				; d1 = memtop
	move.l	d1,$5a4.w			; write fastram top
	move.l	#TTRL_FASTRAMMAGIC,$5a8.w	; write fastram magic
	rts
.fail:	addq.l	#4,sp
	moveq.l	#0,d0
	rts

