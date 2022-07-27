#include <stdio.h>
#include "sys.h"
#include "fastram.h"

#define APP_NAME "Fastram"

long _stksize = (4 * 1024);

int superMain(int argc, char** argv)
{
	if (getCPU() != 30) {
		DPRINT("Unsupported CPU");
		return 0;
	}

	if (IsFastRamInstalled()) {
		DPRINT("Fastram was already installed");
		return 0;
	}

	if (!InstallFastRam())
	{
		DPRINT("Failed installing fastram");
		return -1;
	}

	char buf[16];
	uint32 tt_top = *((volatile uint32*)0x5a4);
	uint32 tt_siz = (tt_top > 0x01000000) ? (tt_top - 0x01000000) : 0;
	tt_siz = (((tt_siz >> 12) + 255) & ~255L) >> 8;
	sprintf(buf, "%dMB", tt_siz);
	printBootInfo(APP_NAME, buf, true);

	StayResident(RESIDENT_MEM);
	return 0;
}
