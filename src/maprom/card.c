#include <string.h>
#include "sys.h"
#include "settings.h"
#include "card.h"
#include "cpu.h"

#define CARD_TF53X_FALLBACK	1

//------------------------------------------------------------
// Identify generic TF53x
//	Guess model based on amount of TT-RAM in the system
//------------------------------------------------------------
#if CARD_TF53X_FALLBACK
bool card_TF53x_Find(struct TFCard* card) {
	uint32 tt_top = *((volatile uint32*)0x5a4);
	uint32 tt_siz = (tt_top > 0x01000000) ? (tt_top - 0x01000000) : 0;
	tt_siz = (((tt_siz >> 12) + 255) & ~255L) >> 8;
	sprintf(card->name, tt_siz > 4 ? "TF536" : "TF534");
	return true;
}
#endif


//------------------------------------------------------------
//
// The cards we know and care about
//
//------------------------------------------------------------
extern bool card_TF536r2_Find(struct TFCard* card);
extern bool card_DFB1_Find(struct TFCard* card);

typedef bool(*CardEnum)(struct TFCard*);
static const CardEnum findFuncs[] = {
	card_TF536r2_Find,
	card_DFB1_Find,
#if CARD_TF53X_FALLBACK
	card_TF53x_Find,
#endif
};


//------------------------------------------------------------
//
// Identify card
//
//------------------------------------------------------------
bool GetCard(struct TFCard* card, struct TFSettings* settings) {
	memset(card, 0, sizeof(struct TFCard));
	if (settings->detectCard) {
		for (uint16 i=0; i<sizeof(findFuncs) / sizeof(findFuncs[0]); i++) {
			if (findFuncs[i](card)) {
				return true;
			}
		}
	}
	return false;
}
