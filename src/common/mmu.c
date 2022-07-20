#include "mint/osbind.h"
#include "mmu.h"
#include "cpu.h"
#include "sys.h"

static const uint32 MMU_TABLE  = 0x02;
static const uint32 MMU_PAGE   = 0x01;
static const uint32 MMU_CI     = 0x40;


void mmuFlush()
{
	__asm__ volatile (			\
		"\n nop"				\
		"\n pflusha"			\
		"\n nop"				\
		: : : "cc", "memory" 	\
	);
}

void mmuGet(MMURegs* regs)
{
	uint16 sr = disableInterrupts();
	__asm__ volatile (				\
		"\n	pmove	srp,0(%0)"		\
		"\n pmove	crp,8(%0)"		\
		"\n	pmove	tt0,16(%0)"		\
		"\n pmove	tt1,20(%0)"		\
		"\n pmove	tc,24(%0)"		\
		: : "a"(regs)				\
		: "cc", "memory"			\
	);
	restoreInterrupts(sr);
}

void mmuSet(MMURegs* regs)
{
	uint16 sr = disableInterrupts();
	mmuDisable();

	// only set SRP register if the SRE bit is enable in TC
	if (regs->tc & (1 << 25)) {
		__asm__ volatile (			\
			"\n pmove	0(%0),srp"	\
		: : "a"(regs)				\
		: "cc", "memory" 			\
		);
	}

	// set all other registers, ending with TC
	__asm__ volatile (			\
		"\n pmove	8(%0),crp"	\
		"\n pmove	16(%0),tt0"	\
		"\n pmove	20(%0),tt1"	\
		"\n pmove	24(%0),tc"	\
		: : "a"(regs)			\
		: "cc", "memory" 		\
	);

	mmuFlush();
	restoreInterrupts(sr);
}

void mmuDisable()
{
	mmuFlush();
	__asm__ volatile (					\
		"\n subq.l	#4,sp"				\
		"\n	pmove	tc,(sp)"			\
		"\n move.l	(sp),d0"			\
		"\n and.l	#0x7FFFFFFF,d0"		\
		"\n move.l	d0,(sp)"			\
		"\n	pmove	(sp),tc"			\
		"\n addq.l	#4,sp"				\
		: : : "d0", "cc", "memory"		\
	);
}

void mmuEnable()
{
	__asm__ volatile (					\
		"\n subq.l	#4,sp"				\
		"\n	pmove	tc,(sp)"			\
		"\n move.l	(sp),d0"			\
		"\n or.l	#0x80000000,d0"		\
		"\n move.l	d0,(sp)"			\
		"\n	pmove	(sp),tc"			\
		"\n addq.l	#4,sp\n"			\
		: : : "d0", "cc", "memory"		\
	);
	mmuFlush();
}

bool mmuCreateDefault() 
{
	MMURegs r;
	mmuGet(&r);
	if (r.tc & 0x80000000) {		// 0x80F04445
		DPRINT("MMU table already active");
		return true;
	}

	DPRINT("Creating default MMU table");
	mmuDisable();
	return mmuCreate((uint32*)0x700, (32*1024));
}

bool mmuCreate(uint32* root, uint16 pagesize)
{
	DPRINT("Creating MMU with pagesize %d", pagesize);
	uint32 tid_bits = 5;
	switch(pagesize)
	{
		case 32768:	tid_bits = 5;	break;
		case 16384:	tid_bits = 6;	break;
		case 8192:	tid_bits = 7;	break;
		case 4096:	tid_bits = 8;	break;
		case 2048:	tid_bits = 9;	break;
		case 1024:	tid_bits = 10;	break;
		case 512:	tid_bits = 11;	break;
		case 256:	tid_bits = 12;	break;
	}
	const uint32 tic_bits = 4;
	const uint32 tib_bits = 4;
	const uint32 tia_bits = 4;
	const uint32 is_bits  = 0;
	const uint32 ps_bits = 32 - is_bits - tia_bits - tib_bits - tic_bits - tid_bits;

	const uint32 tia_count = 1;
	const uint32 tib_count = 2;
	const uint32 tic_count = 1;
	const uint32 tid_count = 0;

	const uint32 size =
		((1 << tia_bits) * tia_count) +
		((1 << tib_bits) * tib_count) +
		((1 << tic_bits) * tic_count) +
		((1 << tid_bits) * tid_count);

	if (root == 0)
	{
		uint32 m = (Mxalloc(256 + size, 3) + 255) & 0xFFFFFF00;
		if (m == 0) {
			DPRINT(" Failed alloc %d bytes", 256 + size);
			return false;
		}
		root = (uint32*) m;
	}

	uint32* tia = root;
	uint32* tib0 = &root[16];
	uint32* tib1 = &root[32];
	uint32* tic = &root[48];
	//uint32* tid = &root[64];

	tia[ 0] = MMU_TABLE | (uint32)tib0;
	tia[ 1] = 0x10000000 | MMU_PAGE;
	tia[ 2] = 0x20000000 | MMU_PAGE;
	tia[ 3] = 0x30000000 | MMU_PAGE;
	tia[ 4] = 0x40000000 | MMU_PAGE;
	tia[ 5] = 0x50000000 | MMU_PAGE;
	tia[ 6] = 0x60000000 | MMU_PAGE;
	tia[ 7] = 0x70000000 | MMU_PAGE;
	tia[ 8] = 0x80000000 | MMU_PAGE | MMU_CI;
	tia[ 9] = 0x90000000 | MMU_PAGE | MMU_CI;
	tia[10] = 0xA0000000 | MMU_PAGE | MMU_CI;
	tia[11] = 0xB0000000 | MMU_PAGE | MMU_CI;
	tia[12] = 0xC0000000 | MMU_PAGE | MMU_CI;
	tia[13] = 0xD0000000 | MMU_PAGE | MMU_CI;
	tia[14] = 0xE0000000 | MMU_PAGE | MMU_CI;
	tia[15] = MMU_TABLE | (uint32)tib1;

	tib0[ 0] = MMU_TABLE | (uint32)tic;
	tib0[ 1] = 0x01000000 | MMU_PAGE;
	tib0[ 2] = 0x02000000 | MMU_PAGE;
	tib0[ 3] = 0x03000000 | MMU_PAGE;
	tib0[ 4] = 0x04000000 | MMU_PAGE;
	tib0[ 5] = 0x05000000 | MMU_PAGE;
	tib0[ 6] = 0x06000000 | MMU_PAGE;
	tib0[ 7] = 0x07000000 | MMU_PAGE;
	tib0[ 8] = 0x08000000 | MMU_PAGE;
	tib0[ 9] = 0x09000000 | MMU_PAGE;
	tib0[10] = 0x0A000000 | MMU_PAGE;
	tib0[11] = 0x0B000000 | MMU_PAGE;
	tib0[12] = 0x0C000000 | MMU_PAGE;
	tib0[13] = 0x0D000000 | MMU_PAGE;
	tib0[14] = 0x0E000000 | MMU_PAGE;
	tib0[15] = 0x0F000000 | MMU_PAGE;

	tib1[ 0] = 0xF0000000 | MMU_PAGE | MMU_CI;
	tib1[ 1] = 0xF1000000 | MMU_PAGE | MMU_CI;
	tib1[ 2] = 0xF2000000 | MMU_PAGE | MMU_CI;
	tib1[ 3] = 0xF3000000 | MMU_PAGE | MMU_CI;
	tib1[ 4] = 0xF4000000 | MMU_PAGE | MMU_CI;
	tib1[ 5] = 0xF5000000 | MMU_PAGE | MMU_CI;
	tib1[ 6] = 0xF6000000 | MMU_PAGE | MMU_CI;
	tib1[ 7] = 0xF7000000 | MMU_PAGE | MMU_CI;
	tib1[ 8] = 0xF8000000 | MMU_PAGE | MMU_CI;
	tib1[ 9] = 0xF9000000 | MMU_PAGE | MMU_CI;
	tib1[10] = 0xFA000000 | MMU_PAGE | MMU_CI;
	tib1[11] = 0xFB000000 | MMU_PAGE | MMU_CI;
	tib1[12] = 0xFC000000 | MMU_PAGE | MMU_CI;
	tib1[13] = 0xFD000000 | MMU_PAGE | MMU_CI;
	tib1[14] = 0xFE000000 | MMU_PAGE | MMU_CI;
	tib1[15] = MMU_TABLE | (uint32)tic;

	tic[ 0] = 0x00000000 | MMU_PAGE;
	tic[ 1] = 0x00100000 | MMU_PAGE;
	tic[ 2] = 0x00200000 | MMU_PAGE;
	tic[ 3] = 0x00300000 | MMU_PAGE;
	tic[ 4] = 0x00400000 | MMU_PAGE;
	tic[ 5] = 0x00500000 | MMU_PAGE;
	tic[ 6] = 0x00600000 | MMU_PAGE;
	tic[ 7] = 0x00700000 | MMU_PAGE;
	tic[ 8] = 0x00800000 | MMU_PAGE;
	tic[ 9] = 0x00900000 | MMU_PAGE;
	tic[10] = 0x00A00000 | MMU_PAGE;
	tic[11] = 0x00B00000 | MMU_PAGE;
	tic[12] = 0x00C00000 | MMU_PAGE;
	tic[13] = 0x00D00000 | MMU_PAGE;
	tic[14] = 0x00E00000 | MMU_PAGE;
	tic[15] = 0x00F00000 | MMU_PAGE | MMU_CI;

	MMURegs r;
	r.ttr0 = 0x017E8107;	// 0x01000000-0x7FFFFFFF
	r.ttr1 = 0x807E8507;	// 0x08000000-0xFEFFFFFF CI
	r.srp[0] = 0;
	r.srp[1] = 0;
	r.crp[0] = 0x80000002;
	r.crp[1] = (uint32)tia;
	r.tc =	(ps_bits  << 20) |
			(is_bits  << 16) |
			(tia_bits << 12) |
			(tib_bits <<  8) |
			(tic_bits <<  4) |
			(tid_bits <<  0) |
			0x80000000;

	DPRINT(" tc   = %08x", r.tc);
	DPRINT(" crp  = %08x %08x", r.crp[0], r.crp[1]);
	DPRINT(" srp  = %08x %08x", r.srp[0], r.srp[1]);
	DPRINT(" ttr  = %08x %08x", r.ttr0, r.ttr1);
	mmuSet(&r);
	DPRINT(" Done");
	return true;
}

uint32 mmuGetPageSize()
{
	MMURegs r; mmuGet(&r);
	uint32 tid_bits = (r.tc & 0xF);
	switch(tid_bits)
	{
		case  5: return 32768; break;
		case  6: return 16384; break;
		case  7: return  8192; break;
		case  8: return  4096; break;
		case  9: return  2048; break;
		case 10: return  1024; break;
		case 11: return   512; break;
		case 12: return   256; break;
		default: return     0; break;
	}
}


void mmuMap(uint32 log, uint32 phys, uint32 size, uint32 flag)
{

}


bool mmuGetEntry(uint32 addr, uint32* tia, uint32* tib, uint32* tic, uint32* tid)
{
	*tia = 0;
	*tib = 0;
	*tic = 0;
	*tid = 0;

	MMURegs r;
	mmuGet(&r);

	// tia
	uint32 a = addr;
	uint32* root = (uint32*) r.crp[1];
	uint32 bits = (r.tc >> 12) & 0xF;
	uint32 len  = (1 << bits);
	uint32 idx  = a / len;
	*tia = root[idx];
	if (*tia & MMU_PAGE)
		return true;

	// tib
	root = (uint32*) (0xFFFFFF00 & *tia);
	a = a - (idx * len);
	bits = (r.tc >> 8) & 0xF;
	len  = (1 << bits);
	idx  = a / len;
	*tib = root[idx];
	if (*tib & MMU_PAGE)
		return true;

	// tic
	root = (uint32*) (0xFFFFFF00 & *tib);
	a = a - (idx * len);
	bits = (r.tc >> 4) & 0xF;
	len  = (1 << bits);
	idx  = a / len;
	*tic = root[idx];
	if (*tib & MMU_PAGE)
		return true;

	// tid
	root = (uint32*) (0xFFFFFF00 & *tic);
	a = a - (idx * len);
	bits = (r.tc >> 0) & 0xF;
	len  = (1 << bits);
	idx  = a / len;
	*tid = root[idx];
	return true;
}

