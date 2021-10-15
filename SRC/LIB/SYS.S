;--------------------------------------------------------------
; SYS.S
;
;	crt0 and misc system related stuff
;
;	SYS_Quit
;	SYS_QuitKeepResident
;	SYS_Print
;	SYS_PrintLong
;	SYS_Waitkey
;	SYS_SupervisorCall
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
gSys_StackTop	ds.l 256	; 1024 byte stack
gSYS_Stack	ds.l 2
gSYS_TsrSize	ds.l 1		; program size for TSR


;--------------------------------------------------------------
section text
;--------------------------------------------------------------


;--------------------------------------------------------------
_entrypoint
;--------------------------------------------------------------
  	move.l	4(sp),a0		; a0 = basepage
  	lea	gSYS_Stack(pc),sp	; initalize stack
      	move.l	#100,d0			; basepage size
	add.l	#$1000,d0		; 
  	add.l	$c(a0),d0		; text size
  	add.l	$14(a0),d0		; data size
  	add.l	$1c(a0),d0		; bss size
	lea	gSYS_TsrSize(pc),a1
	move.l	d0,(a1)
  	
	move.l	d0,-(sp)		; Mshrink()
	move.l	a0,-(sp)
	clr.w	-(sp)
	move.w	#$4a,-(sp)
	trap	#1
	add.l	#12,sp
 
  	bsr	Main			; Main()
 


;--------------------------------------------------------------
SYS_Quit:
;--------------------------------------------------------------
	move.w	#0,-(sp)		; Pterm(0)
	move.w	#76,-(sp) 
	trap	#1
	addq.l	#4,sp

;--------------------------------------------------------------
SYS_QuitKeepResident:
;--------------------------------------------------------------
	move.w	#0,-(sp)		; Ptermres()
	lea	gSYS_TsrSize(pc),a0
	move.l	(a0),-(sp)
	move.w	#49,-(sp)
	trap	#1
	addq.l	#8,sp

;--------------------------------------------------------------
SYS_QuitKeepResidentMallocOnly:
;--------------------------------------------------------------
	move.w	#0,-(sp)		; Ptermres()
	move.l	#$100,-(sp)
	move.w	#49,-(sp)
	trap	#1
	addq.l	#8,sp

;--------------------------------------------------------------
SYS_Print:
;	a0 = string data
;--------------------------------------------------------------
	movem.l d0-d2/a0-a2,-(sp)
	pea	(a0)			; CConws()
	move.w	#9,-(a7)
	trap	#1
	addq.w	#6,a7
	movem.l (sp)+,d0-d2/a0-a2
	rts

;--------------------------------------------------------------
SYS_PrintLong:
; d0 = value
;--------------------------------------------------------------
	movem.l d1-d3/a0-a2,-(sp)
	move.l  #131129,d1
	moveq   #1,d2
.next:	pea     .loop(pc)
	movem.l d1-d3/a0-a2,-(sp)
	move.l  d2,d3
	add.l   d3,d3
	add.l   d3,d3
	add.l   d3,d2
	bcs.s   .fix
	add.l   d2,d2
	cmp.l   d2,d0
	bcc.s   .next
	sub.l   d2,d0
	movem.l (sp)+,d1-d3/a0-a2
	rts
.fix	lea     28(sp),sp
	subq.b  #5,d1
	sub.l   d3,d2
	sub.l   d3,d0
	sub.l   d2,d0
.loop	add.l   d2,d0
	dbcs    d1,.loop
	sub.l   d2,d0
	move.l  d0,-(sp)
	move.l  d1,-(sp)
	trap    #1
	addq.l  #4,sp
	movem.l (sp)+,d0-d3/a0-a2
	rts

;--------------------------------------------------------------
SYS_Waitkey:
;--------------------------------------------------------------
	movem.l d0-d2/a0-a2,-(sp)
	move.w #1,-(sp)			; Cconin()
	trap #1
	addq.l #2,sp	
	movem.l (sp)+,d0-d2/a0-a2
	rts

;--------------------------------------------------------------
SYS_SupervisorCall:
;--------------------------------------------------------------
 	pea	(a0)
	move.w 	#38,-(sp)
 	trap 	#14
 	addq.l 	#6,sp		
	rts



