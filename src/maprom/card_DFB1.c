#include <string.h>
#include "sys.h"
#include "settings.h"
#include "card.h"
#include "cpu.h"


// called after generic mmu setup
bool card_DFB1_Setup(struct TFCard* card, struct TFSettings* settings) {
	return true;
}

// called at beginning to find + configure card caps
bool card_DFB1_Find(struct TFCard* card) {
	if (!testRead16((void*)0x00F20000))
		return false;

	sprintf(card->name, "DFB1");
	card->Setup = card_DFB1_Setup;
	return true;
}
