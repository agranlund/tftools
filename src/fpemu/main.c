#include <stdio.h>
#include <mint/cookie.h>
#include "sys.h"
#include "cookie.h"
#include "cpu.h"

extern int fpe_install();
static uint32 maskedVbr[256];
static uint16 maskedJumptable[256*4];


void maskVectors()
{
	// no interrupts here...
	uint16 sr = disableInterrupts();

	// get old vbr
	uint32* oldVectors = getVBR();
	uint32 vbr = (uint32) oldVectors;

	// virtualise the VBR
	if (vbr < 0x10000) {
		for(uint16 i=0,j=0; i<256; i++)
		{
			maskedVbr[i] = (uint32) &maskedJumptable[j];
			maskedJumptable[j++] = 0x2F38;			// move.l <addr>.w,-(sp)
			maskedJumptable[j++] = vbr;				// addr
			maskedJumptable[j++] = 0x4E75;			// rts
			vbr += 4;
		}
	} else {
		for(uint16 i=0,j=0; i<256; i++)
		{
			maskedVbr[i] = (uint32) &maskedJumptable[j];
			maskedJumptable[j++] = 0x2F39;   		// move.l <addr>.l,-(sp)
			maskedJumptable[j++] = (vbr >> 16);		// hi addr
			maskedJumptable[j++] = (vbr & 0xFFFF);  // lo addr
			maskedJumptable[j++] = 0x4E75;   		// rts
			vbr += 4;
		}
	}

	// lineF
	maskedVbr[11] = oldVectors[11];

	// flush caches
	flushCache();

	// replace vbr
	setVBR((uint32*)maskedVbr);

	// flush caches
	flushCache();

	// restore interrupts
	setSR(sr);
}


int superMain(int argc, char** argv)
{

	uint32 cpu = 0;
	uint32 fpu = 0;
	cookieGet('_CPU', (uint32*)&cpu);
	cookieGet('_FPU', (uint32*)&fpu);

#ifdef DEBUG
	printf("cpu: %08x\n\r", cpu);
	printf("fpu: %08x\n\r", fpu);
#endif

	if (fpu != 0) {
		DPRINT("Fpemu was not installed (FPU exists)\n\r");
		return 0;
	}

	if (cpu >= 40) {
		DPRINT("Fpemu was not installed (680%02d)\n\r", cpu);
		return 0;
	}

	if (!fpe_install())
	{
		DPRINT("Fpemu was not installed\n\r");
		return 0;
	}

	// show message
	DLOG(VER);

	// take control of the vectors
	if (1 && (cpu >= 10)) {
		maskVectors();
	}

	// install cookie and stay resident
	cookieSet('_FPU', 0x00040000);
	StayResident(RESIDENT_ALL);
	return 0;
}

