#include <stdio.h>
#include <string.h>
#include "mint/mintbind.h"
#include "mint/sysvars.h"
#include "mint/osbind.h"
#include "tf53x.h"
#include "cpu.h"
//#include "mmu.h"
#include "fastram.h"
//#include "cookie.h"


int superMain(int argc, char** argv)
{
	// 68030 only
	if (getCPU() != 30) {
		return 0;
	}

	TF536Inf tf;
	uint8 tfreg = 0xFF;
	//uint32 ver = 0;

	bool isTF536r2 = false;
	bool doMapRom = true;
	bool doMapRam = true;

	// Get info
	tf536_getInfo(&tf);
	if (tf.revision == 2)
		isTF536r2 = true;

	if (isTF536r2)
	{
		DLOG("\n\r%s %dMB (fw:%04d%02d%02d)", tf.ident, tf.ramsize, tf.build_year, tf.build_month, tf.build_day);
		//ver = ((tf.build_year*10000) + (tf.build_month*100) + tf.build_day);
		tfreg =	0 << TF536_BIT_ROM_L1 	|		// romL1 : enable
				1 << TF536_BIT_ROM_L2	|		// romL2 : disable
				0 << TF536_BIT_RAM_L1	|		// ramL1 : enable
				1 << TF536_BIT_RAM_L2	|		// ramL2 : disable
				0 << TF536_BIT_RAM_SIZE;		// ramL2 size = 2048 bytes
	}
	else
	{
		// unknown or no accelerator.
		// we can still use the PMMU a'la maprom though
	}


	// -------------------------------------
	// Install Fastram
	// -------------------------------------
	if (!IsFastRamInstalled())
	{
		// This also creates a standard Atari MMU table at 0x700 and _FRB with cookie
		if (!InstallFastRam()) {
			DPRINT("Failed to install fastram");
		}
	}


	// -------------------------------------
	// ROM -> Fastram
	// -------------------------------------
	if (doMapRom)
	{
		OSHEADER* oshdr = (OSHEADER*) *((uint32*)0x000004F2);
		uint32 romSrc = (uint32)oshdr->os_beg;
		uint16 romVer = oshdr->os_version;
		uint32 romSiz = 512 * 1024;
		if (romVer < 0x0200)
			romSiz = 192 * 1024;
		else if (romVer < 0x0300)
			romSiz = 256 * 1024;
		uint32 romDst = isTF536r2 ? tf536_getRomShadowAddr() : 0;

		DPRINT("rom dst:%08x src:%08x siz%d", romDst, romSrc, romSiz / 1024);
		if ((romDst != 0) && (romSrc == 0xE00000))
		{
			memcpy((void*)romDst, (void*)romSrc, romSiz);
			tfreg &= ~TF536_MASK_ROM_L2;	// rom L2 enable
		}
		else
		{
			// todo: MMU version
		}
	}

	// -------------------------------------
	// RAM -> Fastram
	// -------------------------------------
	if (doMapRam)
	{
		if (isTF536r2)
		{
			tfreg &= ~TF536_MASK_RAM_SIZE;		// 2048 bytes
			tfreg &= ~TF536_MASK_RAM_L2;		// ram L2 enable
		}
		else
		{
			// todo: MMU version
		}
	}

	// set tf536 control register
	if (isTF536r2) {
		DPRINT("Setting control reg: %02x\n\r", tfreg);
		tf536_setReg(tfreg);
	}
	
	DPRINT("done");
	return 0;
}
