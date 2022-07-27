#ifndef _TF53X_H_
#define _TF53X_H_

#include "sys.h"

#define TF536_ADDR_REG          0x00FFFD10
#define TF536_ADDR_INF          0x00FFFD00
#define TF536_ROM_SHADOW_64     0x04B00000
#define TF536_REG_SHADOW_64     0x04BF0000
#define TF536_RAM_SHADOW_64     0x04C00000
#define TF536_ROM_SHADOW_128    0x08B00000
#define TF536_REG_SHADOW_128    0x08BF0000
#define TF536_RAM_SHADOW_128    0x08C00000

#define TF536_BIT_ROM_L1        0
#define TF536_BIT_ROM_L2        1
#define TF536_BIT_RAM_L1        2
#define TF536_BIT_RAM_L2        3
#define TF536_BIT_RAM_SIZE      4

#define TF536_MASK_ROM_L1       ( 1 << TF536_BIT_ROM_L1)
#define TF536_MASK_ROM_L2       ( 1 << TF536_BIT_ROM_L2)
#define TF536_MASK_RAM_L1       ( 1 << TF536_BIT_RAM_L1)
#define TF536_MASK_RAM_L2       ( 1 << TF536_BIT_RAM_L2)
#define TF536_MASK_RAM_SIZE     (15 << TF536_BIT_RAM_SIZE)

typedef struct
{
    char        ident[8];
    uint8       revision;
    uint16      version;
    uint16      build_year;
    uint8       build_month;
    uint8       build_day;
    uint8       ramsize;
    uint8       ideflag;
} TF536Inf;

bool tf536_getInfo(TF536Inf* inf);
uint32 tf536_getRomShadowAddr();
uint32 tf536_getRamShadowAddr();
uint32 tf536_getRegShadowAddr();

uint8 tf536_getReg();
void  tf536_setReg(uint8 reg);


#endif //_TF53X_H_

