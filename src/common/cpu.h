#ifndef _CPU_H_
#define _CPU_H_

#include "sys.h"

uint16 disableInterrupts();
void restoreInterrupts(uint16 oldsr);
uint8 safeRead8(void* addr);

extern uint16 getSR();
extern void setSR(uint16);
extern uint16 getCACR();
extern uint16 setCACR(uint16);
extern uint32* getVBR();
extern void setVBR(uint32*);
extern void flushCache000();
extern void flushCache020();
extern void flushCache040();
extern void jump(uint32);

#define flushCache010	flushCache000
#define flushCache030   flushCache020
#define flushCache060   flushCache040

inline void flushCache() {
	uint16 cpu = getCPU();
	if (cpu >= 40) {
		flushCache040();
	} else if (cpu >= 20) {
		flushCache020();
	}
}

#endif //_CPU_H_
