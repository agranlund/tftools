#include <stdio.h>
#include "mint/osbind.h"
#include "sys.h"
#include "cpu.h"
#include "mmu.h"
#include "cookie.h"
#include "fastram.h"

#define ALTRAM_TT_ADDR		0x01000000
#define ALTRAM_TT_MAGIC		0x1357bd13

#define ALTRAM_FRB_COOKIE	'_FRB'
#define ALTRAM_FRB_SIZE		(64 * 1024)

bool IsFastRamInstalled()
{
	uint32 magic = *((volatile uint32*)0x5a8);
	DPRINT("magic = %08x", magic);
	if (magic != ALTRAM_TT_MAGIC)
		return false;

	uint32 memtop = *((volatile uint32*)0x5a4);
	DPRINT("memtop = %08x", memtop);
	if (memtop <= ALTRAM_TT_ADDR)
		return false;

	return true;
}

static bool TestRamAddress(uint32* addr)
{
	// old tf536 firmware does not trigger buserror so test read/write too
	uint16 result = 0;
	__asm__ volatile (					\
		"\n move.l	#0,%0"				\
		"\n	move.l	%1,a2"				\
		"\n	move.l	0x8,a3\t"			\
		"\n	move.l	sp,a4\t"			\
		"\n	move.l	#.altrerr,0x8"		\
		"\n	move.l	(a2),d4"			\
		"\n	add.l	#1234,d4"			\
		"\n	move.l	d4,(a2)"			\
		"\n	cmp.l	(a2),d4"			\
		"\n	bne		.altrdone"			\
		"\n move.w	#1,%0"				\
		"\n bra		.altrdone"			\
		"\n.altrerr:"					\
		"\n	move.l	a4,sp"				\
		"\n.altrdone:"					\
		"\n	move.l	a3,0x8"				\
		: "=d"(result) : "a"(addr) : "a2", "a3", "a4", "d4", "cc", "memory" \
	);
	return (result == 0) ? false : true;
}

uint32 DetectRam(uint32 addr, uint32 max)
{
	uint16 sr = disableInterrupts();
	uint32 cacr = setCACR(0);
	uint32 size = 0;
	const uint32 step = (512 * 1024);
	const uint32* end = (uint32*) (addr + (max * (1024 * 1024)));
	uint32* ptr = (uint32*) (addr + (step - 4));

	DPRINT("Detect start %08x end %08x", ptr, end);
	while (ptr < end)
	{
		bool result = TestRamAddress(ptr);
		DPRINT("Test %08x = %d", (uint32)ptr, result);
		if (!result)
			break;
	
		size += step;
		ptr += (step >> 2);
	}
	setCACR(cacr);
	restoreInterrupts(sr);
	return size;
}

bool InstallFastRam()
{
	if (IsFastRamInstalled())
	{
		DPRINT("Already installed");
		return true;
	}

	// detect ram
	uint32 addr = ALTRAM_TT_ADDR;
	uint32 size = DetectRam(addr, 256);
	DPRINT("addr = %08x size = %dKb", addr, size / 1024);
	if (size == 0)
	{
		DPRINT("No fastram detected");
		return false;
	}

	// install standard mmu table
	MMURegs r; mmuGet(&r);
	if ((r.tc & 0x80000000) == 0)
	{
		DPRINT("Creating standard MMU config");
		mmuDisable();
		if (!mmuCreate((uint32*)0x700, 32 * 1024))
		{
			DPRINT("Failed creating MMU config");
			return -1;
		}
	} else {
		DPRINT("MMU already configured");
	}

	// install FRB
	if (!cookieGet(ALTRAM_FRB_COOKIE, 0))
	{
		DPRINT("Allocating FRB of %dKb", ALTRAM_FRB_SIZE / 1024);
		uint32 frb = (uint32) Mxalloc(ALTRAM_FRB_SIZE, 0);
		if (frb == 0)
		{
			DPRINT("Failed allocating FRB");
			return false;
		}
		DPRINT("Setting FRB cookie to %08x", frb);
		cookieSet(ALTRAM_FRB_COOKIE, frb);
		StayResident(RESIDENT_MEM);
	} else {
		DPRINT("FRB already installed");
	}

	// install fastram
	DPRINT("Maddalt");
	Maddalt(addr, size);

	// make fastram valid
	*((volatile uint32*)0x5a4) = addr + size;
	*((volatile uint32*)0x5a8) = ALTRAM_TT_MAGIC;
	DPRINT("Done");
	return true;
}
