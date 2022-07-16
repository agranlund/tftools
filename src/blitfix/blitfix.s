;--------------------------------------------------------------------------
; BLITFIX.S
;
;	Blitter utility for TerribleFire accelerator.
;	Enables limited blitter support on machines with TT-RAM
;
;	EmuTOS
;	Atari TOS 2.06 & 3.06
;
; This file is distributed under the GPL v2, or at your option any
; later version.  See license.txt for details.
;
; Version history:
;
; 1.1:	detect alternate nvdi filenames
; 1.0:	initial release.
;
; Anders Granlund, 2019
;
;--------------------------------------------------------------------------
	include "COOKIE.S"


;--------------------------------------------------------------
COOKIE_MAGIC	EQU	$424f4646		; 'BOFF'

OPT_SAFE_VADDR	SET	0				; always check _v_bas_ad ?
OPT_SAFE_TEXT	SET	1				; no blitter if using scratchp
;--------------------------------------------------------------


;--------------------------------------------------------------
	section data
;--------------------------------------------------------------
sVersion		dc.b	13,10,$1b,'p',"BlitterFix v1.2 active",$1b,'q',13,10,0

sPRG_NVDI:		dc.b  	"\AUTO\NVDI",0
sPRG_WARP9:		dc.b  	"\AUTO\WARP9",0
sBlitOffPrgs:	dc.l 	sPRG_NVDI,sPRG_WARP9,0


;--------------------------------------------------------------
	section bss
;--------------------------------------------------------------
gStackTop		ds.l 	256			; 1024 byte stack
gStack			ds.l 	2
gTsrSize		ds.l 	1			; program size for TSR
gKeepResident	ds.b	1
gBlitTempOff	ds.b	1
gLineAvars		ds.l	1
gLogscreen		ds.l	1
gPrevTrap1		ds.l	1
gPrevTrap14		ds.l	1
gBlitStatus		ds.w	1
gTosVersion		ds.w	1
gTosType		ds.b	1			; 0=unknown, 1=atari, 2=emutos
gOldSoftTbl		ds.l	1
gOldHardTbl		ds.l	1
gOldSoftGfx0	ds.l	1
gOldSoftGfx1	ds.l	1
gOldSoftGfx2	ds.l	1
gOldSoftGfx3	ds.l	1
gOldSoftGfx4	ds.l	1
gOldSoftGfx5	ds.l	1
gOldSoftGfx6	ds.l	1
gOldSoftGfx7	ds.l	1
gOldSoftGfx8	ds.l	1
gOldSoftGfx9	ds.l	1
gOldHardGfx0	ds.l	1
gOldHardGfx1	ds.l	1
gOldHardGfx2	ds.l	1
gOldHardGfx3	ds.l	1
gOldHardGfx4	ds.l	1
gOldHardGfx5	ds.l	1
gOldHardGfx6	ds.l	1
gOldHardGfx7	ds.l	1
gOldHardGfx8	ds.l	1
gOldHardGfx9	ds.l	1
gNewHardGfxN	ds.l	10
gNewHardGfxF	ds.l	10


;--------------------------------------------------------------
	section text
;--------------------------------------------------------------

;--------------------------------------------------------------
_entrypoint:
;--------------------------------------------------------------
  	move.l	4(sp),a0				; a0 = basepage
  	lea		gStack(pc),sp			; initalize stack
	move.l	#100,d0					; basepage size
	add.l	#$1000,d0				; 
  	add.l	$c(a0),d0				; text size
  	add.l	$14(a0),d0				; data size
  	add.l	$1c(a0),d0				; bss size
	lea		gTsrSize(pc),a1
	move.l	d0,(a1)
  	move.l	d0,-(sp)				; Mshrink()
	move.l	a0,-(sp)
	clr.w	-(sp)
	move.w	#$4a,-(sp)
	trap	#1
	add.l	#12,sp

	clr.b	gKeepResident
	clr.b	gBlitTempOff
	clr.l	gPrevTrap1
	clr.l	gPrevTrap14
	clr.w	gBlitStatus
	clr.w	gTosVersion
	clr.b	gTosType
	clr.l	gOldSoftTbl
	clr.l	gOldHardTbl

	lea		Main(pc),a0
	bsr		SYS_SupervisorCall
	tst.b	gKeepResident
	bne		MainSuccess
	move.w	#0,-(sp)
	move.w	#76,-(sp) 
	trap	#1						; Pterm(0)
MainSuccess:
	lea		sVersion(pc),a0
	bsr		SYS_Print	
	move.w	#0,-(sp)
	lea		gTsrSize(pc),a0
	move.l	(a0),-(sp)
	move.w	#49,-(sp)
	trap	#1						; Ptermres()

;--------------------------------------------------------------
Main:
;--------------------------------------------------------------
	; Launch check
	move.l	#COOKIE_MAGIC,d0		; Check if already installed
	bsr		CheckCookie
	tst.l	d0
	beq		_CookieOk
	rts
_CookieOk:
	bsr		BLIT_Detect				; Check for blitter
	tst.w	d0
	bne		_BlitterOk
	rts
_BlitterOk:
	bsr		CPU_Get					; Only useful for 020 or better
	cmp.w	#20,d0
	bge		_CpuOk
	rts
_CpuOk:
	bsr		TTRAM_GetInstalled		; Check for fastram
	tst.l	d0
	bne		_RamOk
	rts
_RamOk:
	move.l	$4f2,a0					; a0 = _sysbase
	move.w	2(a0),d0
	move.w	d0,gTosVersion			; store tos version number
	move.b	#0,gTosType				; default to simple mode
	cmp.l	#'ETOS',$2c(a0)			; check if EmuTOS
	bne		_notEmuTos
	move.w	#$FFFF,-(sp)			; check if EmuTOS was built to allow
	move.w	#64,-(sp)				; blitter + fastram.
	trap	#14						; if not, use simple mode to at least 
	addq.l	#4,sp					; allow blitter for program in ST-RAM
	btst	#1,d0
	beq		_TosCheckDone
	move.b	#2,gTosType				; EmuTOS blitter support
	bra		_TosCheckDone	
_notEmuTos:
	move.l	#'MagX',d0				; check for MagiC
	bsr		CheckCookie
	tst.l	d0
	bne		_TosCheckDone
	move.l	#'MiNT',d0				; check for MiNT
	bsr		CheckCookie
	tst.l	d0
	bne		_TosCheckDone
	move.b	#1,gTosType				; check Atari TOS version
	cmp.w	#$306,gTosVersion		; TOS 3.06?
	beq		_TosCheckDone
	cmp.w	#$206,gTosVersion		; TOS 2.06?
	beq		_TosCheckDone
	move.b	#0,gTosType				; use simple mode for unsupported TOS
_TosCheckDone:

	; Fetch pointer to lineA variables
	dc.w	$A000
	nop
	move.l	a0,gLineAvars

	; Setup blitter
	cmp.b	#1,gTosType				; Install gfx routines is Atari TOS
	bne		_SetupBlitter1
	bsr		InstallAtariTosRoutines
_SetupBlitter1
	clr.w	d0
	tst.b	gTosType
	beq		_SetupBlitter2
	move.w	#1,d0
_SetupBlitter2
	move.w	d0,-(sp)				; initial blitter status
	move.w	#64,-(sp)
	trap	#14
	addq.l	#4,sp
	move.w	#3,gBlitStatus			; fake blitter status
	pea		Trap14(pc)				; replace XBios handler
	move.w	#$2E,-(sp)				; trap14
	move.w	#5,-(sp)
	trap	#13
	addq.l	#8,sp
	move.l	d0,gPrevTrap14

	; Setup reset handler
	; todo...

	; Setup prg detection

	pea		Trap1(pc)				; replace Gemdos handler
	move.w	#$21,-(sp)				; trap1
	move.w	#5,-(sp)
	trap	#13
	addq.l	#8,sp
	move.l	d0,gPrevTrap1

_Done:
	move.l	#COOKIE_MAGIC,d0		; write cookie
	move.l	#0,d1
	bsr 	CK_WriteJar
	move.b	#1,gKeepResident		; keep resident
	; flush cache
	move.w	sr,-(sp)				; save sr
	ori.w	#$0700,sr				; disable interrupts
	dc.b	$4e,$7a,$00,$02			; get cache register
	or.l	#$808,d0				; invalidate
	dc.b	$4e,$7b,$00,$02			; set cache register
	move.w	(sp)+,sr				; restore sr
	rts

;--------------------------------------------------------------
Trap1:
;--------------------------------------------------------------
	move	usp,a0
	btst    #5,(sp)					; Already supervisor?
	beq.s   _Trap1Handle
	lea     6(sp),a0
	tst.w   $59e.w					; Long stackframes?
	beq.s   _Trap1Handle
	addq.l  #2,a0					; 2 more parameters for long stackframe
_Trap1Handle:           
	move.w  (a0)+,d0				; d0 = gemdos function number
	cmp.w   #75,d0
	beq.s   Trap1_Pexec				; Pexec
Trap1Prev:
	movea.l gPrevTrap1(PC),a0		; call previous trap handler
	jmp		(a0)

;--------------------------------------------------------------
Trap1_Pexec:
;--------------------------------------------------------------
	tst.w	(a0)+					; mode 0, LOAD_AND_GO ?
	bne		Trap1Prev				; no, use old trap handler
	move.l	(a0),a0					; a0 = name ptr
	move.l	#sBlitOffPrgs,a2
_pexec_loop:
	tst.l	(a2)
	beq		_pexec_done
	move.l	(a2)+,a1
	bsr		CompareStrings
	beq		_trap1_blitoff
	bra		_pexec_loop
_trap1_blitoff:
	add.b	#1,gBlitTempOff			; lie to the program about blitter
_pexec_done
	bra		Trap1Prev				; let old trap handler continue



;--------------------------------------------------------------
Trap14:
;--------------------------------------------------------------
	move	usp,a0
	btst    #5,(sp)					; Already supervisor?
	beq.s   _Trap14Handle
	lea     6(sp),a0
	tst.w   $59e.w					; Long stackframes?
	beq.s   _Trap14Handle
	addq.l  #2,a0					; 2 more parameters for long stackframe
_Trap14Handle:           
	move.w  (a0)+,d0				; d0 = xbios function number
	cmp.w   #64,d0
	beq.s   Trap14_Blitmode			; Blitmode
	cmp.w	#5,d0
	beq		Trap14_Setscreen		; Setscreen
Trap14Prev:
	movea.l gPrevTrap14(PC),a0		; call previous trap handler
	jmp	(a0)

;--------------------------------------------------------------
Trap14_Blitmode:
;--------------------------------------------------------------
	tst.b	gTosType
	beq		_BlitMode0				; unknown tos -> simple Blitter mode
	move.w	(a0),d0					; get or set?
	bpl		Trap14Prev				; set -> original Blitmode() handler
	tst.b	gBlitTempOff			; get -> check if we should hide blitter
	beq		Trap14Prev				; no: use original Blitmode() handler
	sub.b	#1,gBlitTempOff			; yes: say blitter is not present
	move.w	#0,d0
	rte
_BlitMode0:
	move.w	(a0),d0
	bpl		_BlitModeIgnore			; ignore set commands
	move.l	-8(a0),d0
	cmp.l	#$A00000,d0				; no blitter for callers outside ST-RAM
	bcc		_BlitModeIgnore
	cmp.l	#Main,d0				; or from before us
	bcs		_BlitModeIgnore
	move.w	gBlitStatus,d0			; blitter status
	rte
_BlitModeIgnore:
	move.w	#0,d0					; blitter not present
	rte
;--------------------------------------------------------------
Trap14_Setscreen:
;--------------------------------------------------------------
	tst.l	(a0)					; ignore if Logscreen < 0
	bmi.s	Trap14Prev
	move.l	(a0),gLogscreen			; logical screen
	bsr		UpdateAtariTosRoutines	; update custom routines
	bra		Trap14Prev

;--------------------------------------------------------------
InstallAtariTosRoutines:
;--------------------------------------------------------------
	move.l	gLineAvars,a0
	move.l	166(a0),gOldSoftTbl		; keep old soft routines
	move.l	162(a0),gOldHardTbl		; keep old hard routines
	move.l	$44e,gLogscreen			; get logical screen adress

	move.l	gOldSoftTbl,a1			; copy pointers to all original soft routines
	move.l	#gOldSoftGfx0,a2
	move.w	#9,d0
_iatl0:
	move.l	(a1)+,(a2)+
	dbra	d0,_iatl0
	move.l	gOldHardTbl,a1			; copy pointers to all original hard routines
	move.l	#gOldHardGfx0,a2
	move.w	#9,d0
_iatl1:
	move.l	(a1)+,(a2)+
	dbra	d0,_iatl1

	IFNE	OPT_SAFE_VADDR
	move.l	#gNewHardGfxF,a1		; Check logical screen at each call
	move.l	#Gfx0,(a1)+				; 0 - hb_cell
	move.l	#Gfx1,(a1)+				; 1 - hb_scrup
	move.l	#Gfx2,(a1)+				; 2 - hb_scrdn
	move.l	#Gfx3,(a1)+				; 3 - hb_blank
	move.l	#Gfx4,(a1)+				; 4 - hb_bitblt
	move.l	#Gfx5,(a1)+				; 5 - hb_mono
	move.l	#Gfx6,(a1)+				; 6 - hb_rect
	move.l	#Gfx7,(a1)+				; 7 - hb_vline
	move.l	#Gfx8,(a1)+				; 8 - hb_hline
	move.l	#Gfx9,(a1)+				; 9 - hb_text
	move.l	#gNewHardGfxF,162(a0)	; v_bas_ad is tested each call
	ENDC

	IFEQ	OPT_SAFE_VADDR
	move.l	#gNewHardGfxN,a1		; Logical screen in TT-RAM
	move.l	#Gfx0,(a1)+				; 0 - hb_cell
	move.l	gOldSoftGfx1,(a1)+		; 1 - hb_scrup
	move.l	gOldSoftGfx2,(a1)+		; 2 - hb_scrdn
	move.l	gOldSoftGfx3,(a1)+		; 3 - hb_blank
	move.l	#Gfx4,(a1)+				; 4 - hb_bitblt
	move.l	gOldSoftGfx5,(a1)+		; 5 - hb_mono
	move.l	gOldSoftGfx6,(a1)+		; 6 - hb_rect
	move.l	gOldSoftGfx7,(a1)+		; 7 - hb_vline
	move.l	gOldSoftGfx8,(a1)+		; 8 - hb_hline
	move.l	gOldSoftGfx9,(a1)+		; 9 - hb_text
	move.l	#gNewHardGfxF,a1		; Logical screen in ST-RAM
	move.l	#Gfx0,(a1)+				; 0 - hb_cell
	move.l	gOldHardGfx1,(a1)+		; 1 - hb_scrup
	move.l	gOldHardGfx2,(a1)+		; 2 - hb_scrdn
	move.l	gOldHardGfx3,(a1)+		; 3 - hb_blank
	move.l	#Gfx4,(a1)+				; 4 - hb_bitblt
	move.l	#Gfx5,(a1)+				; 5 - hb_mono
	move.l	gOldHardGfx6,(a1)+		; 6 - hb_rect
	move.l	gOldHardGfx7,(a1)+		; 7 - hb_vline
	move.l	gOldHardGfx8,(a1)+		; 8 - hb_hline
	move.l	#Gfx9,(a1)+				; 9 - hb_text
	ENDC

;---------------------------------------------------
UpdateAtariTosRoutines:
;---------------------------------------------------
	IFEQ	OPT_SAFE_VADDR
	move.l	gLineAvars,a0
	tst.b	gLogscreen
	bne		.rtt
	move.l	#gNewHardGfxF,162(a0)	; v_bas_ad in st-ram, or always check
	rts
.rtt
	move.l	#gNewHardGfxN,162(a0)	; v_bas_ad in tt-ram
	ENDC
	rts


;---------------------------------------------------
Gfx0:	;hbcell				*
;---------------------------------------------------
	cmp.l	#$01000000,a0			; chr source
	bcc		_gfx0s
	cmp.l	#$01000000,a1			; dst
	bcc		_gfx0s
	movea.l	gOldHardGfx0,a5
	jmp		(a5)
_gfx0s:
	movea.l	gOldSoftGfx0,a5
	jmp		(a5)

;---------------------------------------------------
Gfx1:	;hb_scrup
;---------------------------------------------------
	IFNE	OPT_SAFE_VADDR
	tst.b	$44e
	bne		_gfx1s
	ENDC
	movea.l	gOldHardGfx1,a5
	jmp		(a5)
_gfx1s:
	movea.l	gOldSoftGfx1,a5
	jmp		(a5)

;---------------------------------------------------
Gfx2:	;hb_scrdn
;---------------------------------------------------
	IFNE	OPT_SAFE_VADDR
	tst.b	$44e
	bne		_gfx2s
	ENDC
	movea.l	gOldHardGfx2,a5
	jmp		(a5)
_gfx2s:
	movea.l	gOldSoftGfx2,a5
	jmp		(a5)

;---------------------------------------------------
Gfx3:	; hb_blank
;---------------------------------------------------
	IFNE	OPT_SAFE_VADDR
	tst.b	$44e
	bne		_gfx3s
	ENDC
	movea.l	gOldHardGfx3,a5
	jmp		(a5)
_gfx3s:
	movea.l	gOldSoftGfx3,a5
	jmp		(a5)

;---------------------------------------------------
Gfx4:	;hb_bitblt			*
;---------------------------------------------------
	tst.b	-58(a6)					; src form
	bne		_gfx4s
	tst.b	-44(a6)					; dst form
	bne		_gfx4s
	movea.l	gOldHardGfx4,a5
	jmp		(a5)
_gfx4s:
	movea.l	gOldSoftGfx4,a5
	jmp		(a5)

;---------------------------------------------------
Gfx5:	;hb_mono			*		
;---------------------------------------------------
	IFNE	OPT_SAFE_VADDR
	tst.b	$44e
	bne		_gfx5s
	ENDC
	tst.b	(a5)					; fbase
	bne		_gfx5s
	movea.l	gOldHardGfx5,a4
	jmp		(a4)
_gfx5s:
	movea.l	gOldSoftGfx5,a4
	jmp		(a4)

;---------------------------------------------------
Gfx6:	;hb_rect
;---------------------------------------------------
	IFNE	OPT_SAFE_VADDR
	tst.b	$44e
	bne		_gfx6s
	ENDC
	movea.l	gOldHardGfx6,a5
	jmp		(a5)
_gfx6s:
	movea.l	gOldSoftGfx6,a5
	jmp		(a5)

;---------------------------------------------------
Gfx7:	; hb_vline
;---------------------------------------------------
	IFNE	OPT_SAFE_VADDR
	tst.b	$44e
	bne		_gfx7s
	ENDC
	movea.l	gOldHardGfx7,a5
	jmp		(a5)
_gfx7s:
	movea.l	gOldSoftGfx7,a5
	jmp		(a5)

;---------------------------------------------------
Gfx8:	;hb_hline
;---------------------------------------------------
	IFNE	OPT_SAFE_VADDR
	tst.b	$44e
	bne		_gfx8s
	ENDC
	movea.l	gOldHardGfx8,a5
	jmp		(a5)
_gfx8s:
	movea.l	gOldSoftGfx8,a5
	jmp		(a5)

;---------------------------------------------------
Gfx9:	;hb_text			*
;---------------------------------------------------
	IFNE	OPT_SAFE_VADDR
	tst.b	$44e
	bne		_gfx9s
	ENDC
	tst.b	$54(a6)					; fbase
	bne		_gfx9s
	IFNE	OPT_SAFE_TEXT
	tst.w	$66(a6)					; scale
	bne		_gfx9s	
	move.w	$5a(a6),d5				; style
	andi.w	#$15,d5 				; thick/skew/outline?
	bne		_gfx9s	
	ENDC
	movea.l	gOldHardGfx9,a5
	jmp		(a5)
_gfx9s:
	movea.l	gOldSoftGfx9,a5
	jmp		(a5)
	



;--------------------------------------------------------------
CompareStrings:
;	input: a0, a1
;	return: d0 = 1 or 0
;--------------------------------------------------------------
	move.l	a0,-(sp)
	move.l	a1,-(sp)
_cslp:
	move.b	(a0)+,d0
	move.b	(a1)+,d1
	cmp.b	#0,d1					; compare up to length of a1
	beq		_cseq
	cmp.b	d0,d1
	bne		_csne
	cmp.b	#0,d0
	bne		_cslp
_cseq:
	clr.w	d0
	bra		_csdn
_csne:
	move.w	#1,d0
_csdn:
	move.l	(sp)+,a1
	move.l	(sp)+,a0
	tst.w	d0
	rts


;--------------------------------------------------------------
CheckCookie:
; input: 	d0 = cookie
; returns:	d0 = 0 or 1
;--------------------------------------------------------------
	move.l	d0,d1
	move.l	$5a0,d0					; has cookies?
	beq		_checkcookie_fail
	move.l	d0,a0
_checkcookie_loop:
	tst.l	(a0)					; end of cookies?
	beq		_checkcookie_fail
	cmp.l	(a0),d1					; compare cookie name
	beq		_checkcookie_ok
	addq.l	#8,a0
	bra		_checkcookie_loop
_checkcookie_ok:
	move.l	#1,d0	
	rts
_checkcookie_fail:
	clr.l	d0
	rts


;--------------------------------------------------------------
CPU_Get:
; returns:
;	d0.w: cpu type (0,10,20,30,40,60)
;--------------------------------------------------------------
	move.l	a0,-(sp)
	move.l	d1,-(sp)
	move.l	$5A0,d0					; has cookies?
	beq	.fail
	move.l	d0,a0
	move.l	#'_CPU',d1
.loop:
	tst.l	(a0)					; end of cookies?
	beq	.fail
	cmp.l	(a0),d1					; compare cookie name
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
BLIT_Detect:
; returns:
;	d0.w: 1 or 0
;--------------------------------------------------------------
	move.l	a2,-(sp)				; save a2
	move.w	sr,-(sp)				; save sr
	move.l	$8,-(sp)				; save old berr handler
	or.w	#$0700,sr				; disable interrupts
	moveq.l	#0,d0					; assume no blitter
	move.l	sp,a2					; save old stack pointer
	move.l	#.fail,$8				; install new bus handler
	tst.w	$FF8A00					; access blitter hardware
	move.w	#1,d0					; have blitter
.done:
	move.l	(sp)+,$8				; restore berr handler
	move.w	(sp)+,sr				; restore interrupts
	move.l	(sp)+,a2				; restore a2
	rts
.fail:
	move.l	a2,sp					; restore stack to before bus error
	bra	.done						; stop probing for memory


;--------------------------------------------------------------
SYS_Print:
;	a0 = string data
;--------------------------------------------------------------
	movem.l d0-d2/a0-a2,-(sp)
	pea		(a0)
	move.w	#9,-(a7)
	trap	#1
	addq.w	#6,a7
	movem.l (sp)+,d0-d2/a0-a2
	rts

;--------------------------------------------------------------
SYS_SupervisorCall:
;--------------------------------------------------------------
 	pea		(a0)
	move.w 	#38,-(sp)
 	trap 	#14
 	addq.l 	#6,sp		
	rts


;--------------------------------------------------------------
TTRAM_GetInstalled:
; returns:
;	d0: size
;	d1: ram top
;	d2: ram bottom
;--------------------------------------------------------------
	cmp.l 	#$1357bd13,$5a8.w		; Ask bios for fastram magic
	bne		.err
	move.l	#$01000000,d2			; TT-RAM start
	move.l	$5a4.w,d1				; Ask bios for fastram top
	cmp.l	d2,d1					; Verify it is in TT ram range
	ble		.err
	move.l	d1,d0
	sub.l	d2,d0
	rts		
.err:
	moveq.l	#0,d0
	moveq.l	#0,d1
	moveq.l	#0,d2
	rts

