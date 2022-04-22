;--------------------------------------------------------------------------
; MAPROM.S
;
;	Fastram utility for 68030 + TT-RAM accelerators.
;
;	- Installs TT-Ram to TOS when necessary
;	- Sets up MMU to default TT/Falcon config plus:
;		- Mapping ROM to TT-Ram
;		- Mapping low 4Kb/32Kb ST-Ram to TT-Ram
;
; This file is distributed under the GPL v2, or at your option any
; later version.  See LICENSE.TXT for details.
;
; Version history:
;
; 2.0	Relocate 4k instead of 32k on TOS206 just like
;		how it's done for all other version
;
; 1.9	Added maprom_c.prg which allows L1 cache for ST-RAM
;
; 1.8	Fixed TT-RAM detect after Atari TOS warm reset
;		Cache inhibit relocated low ST-RAM
;		Cache inhibit ST-RAM ($00000000-$003FFFFF)
;		Cache inhibit Alt-RAM ($00C00000-$00DFFFFF)
;		(usual gfxcard range)
;
; 1.7	Support 128MB TT-RAM
;
; 1.6	Bugfix. ROM area was not remapped properly in v1.5
;
; 1.5:	Limit to 64MB TT-RAM (temporary fix for TF536)
;
; 1.4:	Added support for TOS at $FC0000 (KAOS 1.4)
;		Added support for TOS without maddalt/mxalloc (KAOS 1.4)
;		Remap low ram to tt-ram (4kb or 32Kb depending on TOS)
;		Remap actual rom size instead of hardcoded 512Kb
;		MMU tables are now in tt-ram
;
; 1.3:	Minor bugfixes.
;
; 1.2:  Early exit if TOS is not at $E00000
;       Allocate new MMU table instead of assuming old one at $700
;
; 1.1:	Remap 512Kb instead of 1MB, leaving $E80000-$EFFFFF untouched
;
; 1.0:	initial release. Remaps $E00000-$EFFFFF to TT-RAM 
;
; Anders Granlund, 2020
;--------------------------------------------------------------------------
	include "LIB\SYS.S"
	include "LIB\CPU.S"
	include "LIB\MMU030.S"
	include "LIB\COOKIE.S"
	include "LIB\TTRAM.S"


;--------------------------------------------------------------
COOKIE_PMMU		EQU	$504d4d55
OPT_DEBUG		SET	0		; debug mode + symbols

FLAG_TTRAM		EQU	1
FLAG_BLITTER	EQU	2
FLAG_MMU		EQU	4
FLAG_RELO_ROM	EQU	8
FLAG_RELO_RAM	EQU	16

;--------------------------------------------------------------

	IFNE	OPT_DEBUG
	OPT	XDEBUG
	ENDC


;--------------------------------------------------------------
	section bss
;--------------------------------------------------------------
gResultFlags	ds.w	1
gFastRamSize	ds.l	1
gTosVersion		ds.w	1
gTosAddr		ds.l	1
gTosSize		ds.l	1
gCpuType		ds.w	1
gMapRamSize		ds.w	1
gRamInstalled	ds.l	1


;--------------------------------------------------------------
	section data
;--------------------------------------------------------------
	IFNE OPT_MMU
sVersion		dc.b	13,10,$1b,'p',"Maprom v2.0 active",$1b,'q',13,10,0
	ENDC

	IFEQ OPT_MMU
sVersion		dc.b	13,10,$1b,'p',"Fastram v2.0 active",$1b,'q',13,10,0
	ENDC

;--------------------------------------------------------------
	section text
;--------------------------------------------------------------




;--------------------------------------------------------------
Main
;--------------------------------------------------------------
	clr.w	gResultFlags
	lea		MainSU(pc),a0
	bsr		SYS_SupervisorCall
	tst.w	gResultFlags
	beq		.exit
	lea		sVersion(pc),a0
	bsr		SYS_Print	
	bra		SYS_QuitKeepResident
.exit	
	rts


;--------------------------------------------------------------
MainSU:
;--------------------------------------------------------------

	
	;----------------------------------------------
	; install fastram
	;----------------------------------------------
	bsr		TTRAM_GetInstalled		; tt-ram already installed?
	tst.l	d0
	beq		.fastramDetect

	; verify that we can allocate and if not redetect and install it.
	; This is necessary for when Atari TOS skips the memory test on warm reset.
	move.l	d0,d3
	move.w	#1,-(sp)			; alt-ram only
	move.l	#32,-(sp)			; 32 bytes
	move.w	#68,-(sp)			; Mxalloc
	trap	#1
	addq.l	#8,sp	
	tst.l	d0				; fail = redetect
	beq		.fastramDetect
	move.l	d0,-(sp)
	move.w	#73,-(sp)			; Mfree
	trap	#1
	addq.l	#6,sp		
	move.l	d3,d0
	bra		.fastramOK

.fastramDetect
	bsr		TTRAM_Detect			; detect tt-ram
	tst.l	d0
	beq		MainSUDone
	bsr		TTRAM_Install			; install tt-ram + frb
.fastramOK:
	move.l	d0,gRamInstalled
	or.w	#FLAG_TTRAM,gResultFlags
	
	IFEQ	OPT_MMU
	bra		MainSUDone
	ENDC

	;----------------------------------------------
	; get system config
	;----------------------------------------------

	bsr		CPU_Get
	move.w	d0,gCpuType
	cmp.w	#30,d0				; Need 68030 CPU
	bne		MainSUDone

	IFEQ	OPT_DEBUG
	move.l	#COOKIE_PMMU,d0
	bsr		GetCookie			; PMMU cookie must not already exist 
	bne		MainSUDone
	ENDC


	;----------------------------------------------
	; check rom size and start address
	; a3 = rom address
	; d3 = rom size
	;----------------------------------------------
	move.l	$4f2,a0				; a0 = _sysbase
	move.w	2(a0),d2
	move.l	#$30000,d3			; d3 = 192Kb (Tos 1.xx)
	cmp.w	#$200,d2
	bcs		.romSizeOK
	move.l	#$40000,d3			; d3 = 256Kb (Tos 2.xx)
	cmp.w	#$300,d2	
	bcs		.romSizeOK
	move.l	#$80000,d3			; d3 = 512Kb (Tos 3.xx / 4.xx)
.romSizeOK:
	move.l	8(a0),a3			; a3 = TOS start addr
	cmp.l	#$e00000,a3
	beq		.romAddrOK
	cmp.l	#$fc0000,a3
	beq		.romAddrOK
	moveq.l	#0,d3				; zero size to indicate unsupported rom
.romAddrOK:
	move.w	d2,gTosVersion
	move.l	d3,gTosSize
	move.l	a3,gTosAddr



	;----------------------------------------------
	; allocate ram for rom + mmu tables
	;----------------------------------------------
	move.l	#0,d4
	IFNE 	OPT_RELO_RAM
	move.l	#$1000,d4			; EmuTOS = 4Kb
	cmp.l	#'ETOS',$2c(a0)
	beq		.ramSizeOK
	move.l	#$1000,d4			; Default = 4Kb
	cmp.w	#$206,d2
	bne		.ramSizeOK
	move.l	#$1000,d4			; TOS2.06 = 4Kb
.ramSizeOK:
	ENDC
	move.w	d4,gMapRamSize

	IFEQ	OPT_RELO_ROM
	move.l	#0,d3
	ENDC

	move.l	#$8000,d0			; 32Kb for alignment
	add.l	#$1000,d0			;  4Kb for tables
	add.l	d3,d0				; rom size
	add.l	d4,d0				; ram size
	bsr		AllocateFastRam
	tst.l	d0					; memory allocated?
	beq		MainSUDone
	add.l 	#$7FFF,d0			; align to 32k pages
	and.l 	#$FFFF8000,d0
	move.l	d0,a4				; a4 = memory for rom + ram
	add.l	d3,d0				
	add.l	d4,d0
	move.l	d0,a6				; a6 = MMU table base address
	move.l	d0,a5				;
	add.l	#256,a5				; a5 = memory for extra tables


	;----------------------------------------------
	; prepare default mmu table at address d0
	;----------------------------------------------
	bsr		MMU030_Install			; configure default MMU table as TT/Falcon
	tst.l	d0
	beq		MainSUDone
	or.w	#FLAG_MMU,gResultFlags
	move.l	#COOKIE_PMMU,d0			; Write 'PMMU' cookie
	move.l	#0,d1
	bsr 	CK_WriteJar



	;----------------------------------------------
	; map rom to fastram
	;----------------------------------------------
	IFNE	OPT_RELO_ROM
	bsr		Relocate_Rom
	tst.w	d0
	beq		.reloRomDone
	or.w	#FLAG_RELO_ROM,gResultFlags
.reloRomDone:
	ENDC

	;----------------------------------------------
	; map lowram to fastram
	;----------------------------------------------
	IFNE OPT_RELO_RAM
	tst.w	gMapRamSize
	beq		.reloRamDone
	bsr		Relocate_Ram
	tst.w	d0
	beq		.reloRamDone
	or.w	#FLAG_RELO_RAM,gResultFlags
.reloRamDone:
	ENDC


	;----------------------------------------------
	; activate new mmu tables with 4k pagesize
	;----------------------------------------------
	move.l	#$80c04448,gMMU030_TC		; enable, 4k pages, IS=0, TIA=4, TIB=4, TIC=4, TID=8
	dc.l	$f0394000,gMMU030_TC		; pmove addr,tc	
	dc.l	$f0002400					; pflusha	
	bsr		CPU_CacheClear

MainSUDone:
	rts


;--------------------------------------------------------------
Relocate_Rom:
; input: d3.l = tos size (destroyed)
;	 a3.l = tos addr
;	 a4.l = memory for data (incremented)
;	 a5.l = memory for table (incremented)
;	 a6.l = MMU table
;
; result: d0.w
;--------------------------------------------------------------
	move.l	d3,d0
	beq		.done
	move.l	a4,d4				; d4 = dst address
	move.l	d3,d2
	swap	d2
	lsl.l	#4,d2				; d2 = num 4k pages
	lsr.l	#2,d3
	move.l	a3,-(sp)
.copy:
	move.l	(a3)+,(a4)+
	subq.l	#1,d3
	bne		.copy
	move.l	(sp)+,a3

	; clear TID table
	move.l	a5,d1				; d1 = TID table
	move.l	a3,d5
	and.l	#$f00000,d5
	or.l	#$41,d5				; d5 = original addr, PAGE, CACHE_INHIBIT
	move.l	#256,d3
.loop1:	
	move.l	d5,(a5)+
	add.l	#$1000,d5
	subq.l	#1,d3
	bne		.loop1

	; write relocation entries to TID table
	move.l	a3,d0
	and.l	#$0FFFFF,d0
	lsl.l	#6,d0
	swap	d0
	move.l	d1,a2
	add.l	d0,a2				; a2 = TID table + offset
	move.l	d4,d5
	or.l	#5,d5				; d5 = relocated addr, PAGE, WRITE_PROTECT
.loop2:
	move.l	d5,(a2)+
	add.l	#$1000,d5
	subq.l	#1,d2
	bne		.loop2

	; write TIA entry
	move.l	a3,d0
	and.l	#$F00000,d0
	swap	d0
	lsr.l	#2,d0
	add.l	#$c0,d0				; d0 = offset in TIA table
	move.l	a6,a2
	add.l	d0,a2				; a2 = TIA entry
	or.l	#2,d1				; d1 = pointer to TID table
	move.l	d1,(a2)
	moveq	#1,d0
.done:
	rts



;--------------------------------------------------------------
Relocate_Ram:
; input: a4 = memory for data (incremented)
;	 a5 = memory for table (incremented)
;	 a6 = MMU table 
;--------------------------------------------------------------
	move.l	a4,d0
	IFEQ OPT_STRAM_CI
		or.l	#$01,d0			; d0 = relocate | PAGE
		move.l	#$01,d1			; d1 = no relocate | PAGE
	ENDC
	IFNE OPT_STRAM_CI
		or.l	#$41,d0			; d0 = relocate | PAGE | CACHE_INHIBIT
		move.l	#$41,d1			; d1 = no relocate | PAGE | CACHE_INHIBIT
	ENDC
	move.l	a5,d4				; d4 = TID table

	move.w	gMapRamSize,d3
	lsr.w	#2,d3
	move.w	d3,d5
	lsr.w	#8,d5
	lsr.w	#2,d5				; d5 = num pages
	tst.w	d5
	beq		.last

	move.l	#0,a3
.copy:
	move.l	(a3)+,(a4)+
	subq.w	#1,d3
	bne		.copy

	move.l	$4c6,d3				; get pointer to _dskbuf from $4c6
	lsr.l	#8,d3
	lsr.l	#4,d3				; d3 is now the 4k page it belongs to
	move.w	#1,d2
	lsl.w	d3,d2				; set the bit corresponding to the page
	not.w	d2					; invert bitmask

	move.w	#$7FFF,d6			; d6 = page mask
	and.w	d2,d6				; ignore _dskbuf page

	move.w	d5,d3				; relocate pages
.loop2:
	btst	#0,d6				; check page mask
	beq		.skip				; don't relocate if bit is 0
	move.l	d0,(a5)+			; set page = new address
	bra		.loop3
.skip
	move.l	d1,(a5)+			; set page = original address
.loop3:
	lsr.w	#1,d6				; adjust page mask
	add.l	#$1000,d0			; step 4kb dst address
	add.l	#$1000,d1			; step 4kb src address
	subq.w	#1,d3				
	bne		.loop2

.last:
	move.w	#256,d3				; remaining non-relocate pages 
	sub.w	d5,d3
.loop4:
	move.l	d1,(a5)+
	add.l	#$1000,d1
	subq.w	#1,d3
	bne		.loop4

	or.l	#$2,d4
	move.l	d4,$c0(a6)			; write to offset 0xc0 in TIA table
	rts


;--------------------------------------------------------------
GetCookie:
; input:
;	d0.l  cookie
; returns:
;	d0.w: exists? 0 or 1
;	d1.l: value
;--------------------------------------------------------------
	move.l	$5a0,d1			; has cookies?
	beq		.fail
	move.l	d1,a0
.loop:
	tst.l	(a0)			; end of cookies?
	beq		.fail
	cmp.l	(a0),d0			; compare cookie name
	beq		.found
	addq.l	#8,a0
	bra		.loop
.found:
	move.l	4(a0),d1
	move.w	#1,d0
	rts	
.fail:
	moveq.l	#0,d1
	moveq.l	#0,d0
	rts


;--------------------------------------------------------------
AllocateFastRam:
; input: d0 = size, output: d0 = addr
;--------------------------------------------------------------
	tst.l	gRamInstalled
	bne		.xmalloc
	move.l	gTTRL_RamTop,d1			; tos version does not support
	sub.l	d0,d1				; alt-ram so we simply take
	move.l	d1,gTTRL_RamTop			; from the top of it without
	move.l	d1,d0				; going through mxalloc
	rts
.xmalloc:
	move.w	#1,-(sp)			; allocate alt-ram only
	move.l	d0,-(sp)			; size
	move.w	#68,-(sp)			; Mxalloc
	trap	#1
	addq.l	#8,sp	
	rts
