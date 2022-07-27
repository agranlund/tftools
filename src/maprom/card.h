#ifndef _CARD_H_
#define _CARD_H_

#include "settings.h"

#define CAPS_ROM_L2			(1 << 0)
#define CAPS_RAM_L2			(1 << 1)
#define CAPS_ZERO_L2		(1 << 2)

struct TFCard
{
	char 	name[32];
	char 	ver[32];
	uint8	caps;
	bool	(*Setup)(struct TFCard* card, struct TFSettings*);
};

bool GetCard(struct TFCard* card, struct TFSettings* settings);


#endif // _CARD_H_

