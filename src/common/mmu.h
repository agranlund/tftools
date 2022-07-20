#ifndef _MMU030_H_
#define _MMU030_H_

#include "sys.h"

#define MMU_FLAG_CI     0x40
#define MMU_FLAG_WP     0x00

typedef struct
{
    uint32  srp[2];
    uint32  crp[2];
    uint32  ttr0;
    uint32  ttr1;
    uint32  tc;
} MMURegs;

extern void mmuFlush();
extern void mmuGet(MMURegs* regs);
extern void mmuSet(MMURegs* regs);

extern void mmuDisable();
extern void mmuEnable();

extern bool mmuCreateDefault();
extern bool mmuCreate(uint32* root, uint16 pagesize);

extern void mmuMap(uint32 log, uint32 phys, uint32 size, uint32 flag);

extern uint32 mmuGetPageSize();

#endif //_MMU030_H

