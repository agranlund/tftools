#include <stdio.h>
#include <string.h>
#include "mint/mintbind.h"
#include "mint/sysvars.h"
#include "mint/osbind.h"
#include "tf53x.h"

int superMain(int argc, char** argv)
{
	TF536Inf tf;
	tf536_getInfo(&tf);
	if (tf.revision != 2)
		return 0;

	uint8 reg = tf536_getReg();
	uint8 size = ((reg & TF536_MASK_RAM_SIZE) >> TF536_BIT_RAM_SIZE);
	uint8 en = ((reg & TF536_MASK_RAM_L2) >> TF536_BIT_RAM_L2);
	bool wasEnabled = ((en == 0) && (size != 0));

	if (!wasEnabled)
	{
		uint32 memtop = *((volatile uint32*)0x436);
		uint8 size = 1; // 512Kb
		if (memtop >= (512 * 7 * 1024))			size = 8;	// 4.0 MB
		else if (memtop >= (512 * 6 * 1024))	size = 7;	// 3.5 MB
		else if (memtop >= (512 * 5 * 1024))	size = 6;	// 3.0 MB
		else if (memtop >= (512 * 4 * 1024))	size = 5;	// 2.5 MB
		else if (memtop >= (512 * 3 * 1024))	size = 4;	// 2.0 MB
		else if (memtop >= (512 * 2 * 1024))	size = 3;	// 1.5 MB
		else if (memtop >= (512 * 1 * 1024))	size = 2;	// 1.0 MB
		reg |= (size << TF536_BIT_RAM_SIZE);
		reg &= ~TF536_MASK_RAM_L2;
		// todo: perform full refresh of the shadow memory?
	}
	else
	{
		reg &= ~TF536_MASK_RAM_SIZE;	// keep enabled for first 2kb
	}

	DLOG("%s L2 cache %s", tf.ident, wasEnabled ? "disabled" : "enabled");
	tf536_setReg(reg);
	return 0;
}
