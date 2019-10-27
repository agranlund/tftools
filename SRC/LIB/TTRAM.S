
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
TTRL_MEMMAXSIZE		EQU	256
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
	bne	_ttrl_detectins_err
_ttrl_detectins1
	move.l	#TTRL_MEMBOTTOM,d2
	move.l	$5a4.w,d1			; Ask bios for fastram top
	cmp.l	d2,d1				; Verify it is in TT ram range
	ble	_ttrl_detectins_err
	move.l	d1,d0
	sub.l	d2,d0
	rts		
_ttrl_detectins_err
	move.l	#0,d0
	move.l	#0,d1
	move.l	#0,d2
	rts


;--------------------------------------------------------------
TTRAM_Detect:
; returns:
;	d0: size
;	d1: ram top
;	d2: ram bottom
;--------------------------------------------------------------
	bsr 	_ttrl_detectram_su
	cmp.l	#TTRL_MEMBOTTOM,gTTRL_RamTop
	ble	_TTRL_DetectRamFail
	move.l	#TTRL_MEMBOTTOM,d2		; d2 = ram bottom
	move.l	gTTRL_RamTop,d1			; d1 = ram top
	move.l	d1,d0
	sub.l	d2,d0				; d0 = size
	rts
_TTRL_DetectRamFail:
	move.l	#0,d0
	move.l	#0,d1
	move.l	#0,d2	
	rts
_ttrl_detectram_su:
	move.l	#0,gTTRL_RamTop
	cmp.l 	#TTRL_FASTRAMMAGIC,$5a8.w	; Ask bios for fastram magic
	bne	_ttrl_detectram_probe
	move.l	$5a4.w,gTTRL_RamTop		; Ask bios for fastram top
	cmp.l	#TTRL_MEMBOTTOM,gTTRL_RamTop	; Verify it's in TT ram range
	ble	_ttrl_detectram_probe
	rts
_ttrl_detectram_probe:
	; Probe hardware for TT ram
	move.l	sp,a6				; save old stack pointer
	move.l	$8,gTTRL_BushandlerOld		; save old bus handler
	move.l	#_ttrl_detectram_bushandler,$8	; install new bus handler
	move.l	#TTRL_MEMBOTTOM,gTTRL_RamTop
	move.w	#TTRL_MEMMAXSIZE,d3
_ttrl_detectram_loop:
	movea.l	(gTTRL_RamTop),a2
	move.l	#$deadface,(a2)			; write test
	move.l	(a2),d0
	cmp.l	#$deadface,d0			; read test
	bne	_ttrl_detectram_done
	add.l	#$00100000,gTTRL_RamTop		; check 1MB intervals
	sub.w	#1,d3
	tst.w	d3
	bne	_ttrl_detectram_loop
_ttrl_detectram_done:
	move.l	gTTRL_BushandlerOld,$8		; restore bus handler
	rts
_ttrl_detectram_bushandler:
	move.l	a6,sp				; restore stack to before bus error
	bra	_ttrl_detectram_done		; stop probing for memory


;--------------------------------------------------------------
TTRAM_Install:
; inputs:
;	d0: size
;--------------------------------------------------------------
	move.l	#TTRL_MEMBOTTOM,d1	
	add.l	d0,d1				; d1 = memtop
	move.l	d1,$5a4.w			; write fastram top
	move.l	#TTRL_FASTRAMMAGIC,$5a8.w	; write fastram magic
	move.l	d0,-(sp)			; size
	move.l	#TTRL_MEMBOTTOM,-(sp)		; start
	move.w	#20,-(sp)			; maddalt(size, start)
	trap	#1				; 
	add.l	#10,sp

	move.w	#0,-(sp)			; allocate st-ram only
	move.l	#$10000,-(sp)			; 64Kb			
	move.w	#68,-(sp)			; Mxalloc
	trap	#1
	addq.l	#8,sp
	move.l	d0,d1				; 64Kb fastram buffer
	move.l	#$5f465242,d0			; '_FRB'
	bsr 	CK_WriteJar			; write cookie
	rts
