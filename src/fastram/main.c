#include <stdio.h>
#include "sys.h"
#include "fastram.h"

#define APP_NAME		"Fastram"

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
	sprintf(buf, "%d MB", tt_siz);

	int16 len = 40;
	int16 l1 = strlen(APP_NAME);
	int16 l2 = strlen(__DATE__);
	int16 l3 = strlen(buf);
	int16 pad = len - l1 - 3 - l2 - l3 - 2;

	Cconws("\r\n\x1Bp");
	for (uint16 i=0; i<len; i++) {
		Cconws(" ");
	}
	Cconws("\r ");
	Cconws(APP_NAME);
	Cconws(" : ");
	Cconws(__DATE__);
	for (uint16 i=0; i<pad; i++) {
		Cconws(" ");
	}
	Cconws(buf);
	Cconws("\x1Bq\r\n");

	StayResident(RESIDENT_MEM);
	return 0;
}
