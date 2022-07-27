#include <stdio.h>
#include <mint/cookie.h>
#include "sys.h"
#include "cookie.h"
#include "cpu.h"
#include "vbr.h"

extern int fpe_install();

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
		struct VBRProxy* vbrx = vbrGetOrCreateProxy(VBRX_IDENT);
		if (vbrx) {
			uint16 sr = disableInterrupts();
			vbrx->vbr[11] = vbrx->old[11];
			flushCache();
			setSR(sr);
		}
	}

	// install cookie and stay resident
	cookieSet('_FPU', 0x00040000);
	StayResident(RESIDENT_ALL);
	return 0;
}
