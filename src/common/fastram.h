#ifndef _FASTRAM_H_
#define _FASTRAM_H_

#include "sys.h"

bool InstallFastRam();
bool IsFastRamInstalled();
uint32 DetectFastRam(uint32 addr, uint32 max);

#endif //_FASTRAM_H_
