#ifndef _SETTINGS_H_
#define _SETTINGS_H_

#define APP_NAME				"Maprom"
#define APP_IDENT				'MROM'


#define CFG_FIXDMA_NONE		0
#define CFG_FIXDMA_NORMAL	1
#define CFG_FIXDMA_FULL		2

struct TFSettings
{
	bool	enableMMU;
	bool	detectCard;
	bool	enableRamL1;
	bool	enableRomL1;
	bool	enableRamL2;
	bool	enableRomL2;
	bool	enableZeroL2;

	uint8	fixDma;
	bool	fixStga;
};


void GetSettings(struct TFSettings* settings);


#endif // _SETTINGS_H_

