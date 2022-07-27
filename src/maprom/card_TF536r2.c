#include <string.h>
#include "sys.h"
#include "settings.h"
#include "card.h"
#include "cpu.h"
#include "tf53x.h"

#define VBR_MAGIC   0x56425250          /* VBRP */
#define XBRA_IDENT  0x54353336          /* T536 */

extern void GetRomInfo(uint16* version, uint32* addr, uint32* size);
extern void vecDmaIrq_TF536r2_64();
extern void vecDmaIrq_TF536r2_128();


// called after generic mmu setup
bool card_TF536r2_Setup(struct TFCard* card, struct TFSettings* settings) {
	// disable everything
	uint8 reg = 0xF;
	tf536_setReg(reg);

	//----------------------------------------
	// L1 cache
	//----------------------------------------
	if (settings->enableRomL1) {
		DPRINT("TF536: Enable ROM L1");
		reg &= ~TF536_MASK_ROM_L1;
	}

	if (settings->enableRamL1) {
		DPRINT("TF536: Enable RAM L1");
		reg &= ~TF536_MASK_RAM_L1;
	}

	//----------------------------------------
	// L2 cache, ROM
	//----------------------------------------
	if (settings->enableRomL2 && (card->caps & CAPS_ROM_L2)) {
		DPRINT("TF536: Enable ROM L2");
		uint16 ver = 0; uint32 src = 0; uint32 siz = 0;
		GetRomInfo(&ver, &src, &siz);
		memcpy((void*)tf536_getRomShadowAddr(), (void*)src, siz);
		reg &= ~TF536_MASK_ROM_L2;
	}

	//----------------------------------------
	// L2 cache, RAM
	//----------------------------------------
	if (settings->enableRamL2 && (card->caps & CAPS_RAM_L2)) {
		DPRINT("TF536: Enable RAM L2");
		// get size of st-ram rounded to nearest 512kb
		uint32 size = *((volatile uint32*)0x436) >> 10;
		size = (size + 511) & ~511L;
		// make register value
		size = size >> 9;
		if (size > 8)
			size = 8;
		reg |= (size << TF536_BIT_RAM_SIZE);
		reg &= ~TF536_MASK_RAM_L2;

		// dma fix
		if (settings->fixDma >= CFG_FIXDMA_FULL) {

			TF536Inf tf;
			tf536_getInfo(&tf);

			DPRINT("TF536: Enable RAM L2 dma fix");
			uint16 sr = disableInterrupts();

			// reset dma address in register shadow
			uint32 regShadow = tf536_getRegShadowAddr();
			*((volatile uint8*)(regShadow | 0x8609)) = 0xFF;
			*((volatile uint8*)(regShadow | 0x860B)) = 0xFF;
			*((volatile uint8*)(regShadow | 0x860D)) = 0xFF;

			// install interrupt handler
		    uint16 idx = (0x11C / 4);
			if (tf.ramsize == 64) {
		    	xbraSet(idx, XBRA_IDENT, (uint32)vecDmaIrq_TF536r2_64);
			} else {
		    	xbraSet(idx, XBRA_IDENT, (uint32)vecDmaIrq_TF536r2_128);
			}
		    flushCache();

			// enable fdc/hdd interrupts
			uint8 mask = (1 << 7);
			*((volatile uint8*)0xFFFA0D) &= ~mask;		// pending
			*((volatile uint8*)0xFFFA11) &= ~mask;		// in service
			*((volatile uint8*)0xFFFA15) |= mask;		// mask
			*((volatile uint8*)0xFFFA09) |= mask;		// enable
		    setSR(sr);
		}

	}
	else if (settings->enableZeroL2 && (card->caps & CAPS_ZERO_L2)) {
		DPRINT("TF536: Enable Zero L2");
		reg &= ~TF536_MASK_RAM_L2;
	}

	// apply settings
	tf536_setReg(reg);
	return true;
}


// called at beginning to find + configure card caps
bool card_TF536r2_Find(struct TFCard* card) {
	TF536Inf tf;
	tf536_getInfo(&tf);
	if (tf.revision != 2)
		return false;

	sprintf(card->name, "%s", tf.ident);
	sprintf(card->ver, "%04d-%02d-%02d", tf.build_year, tf.build_month, tf.build_day);

	uint32 fw = (tf.build_year * 10000) + (tf.build_month * 100) + tf.build_day;
	if (fw >= 20220726)
	{
		if (tf536_getRamShadowAddr()) {
			card->caps |= (CAPS_RAM_L2 | CAPS_ZERO_L2);
		}
		if (tf536_getRomShadowAddr()) {
			uint32 romSize = 0; uint32 romAddr = 0;
			GetRomInfo(0, &romAddr, &romSize);
			if ((romAddr == 0xE00000) && romSize <= (512 * 1024))
				card->caps |= CAPS_ROM_L2;
		}
	}
	card->Setup = card_TF536r2_Setup;
	return true;
}

