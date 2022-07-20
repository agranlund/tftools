#include <string.h>
#include "../common/cpu.h"
#include "tf53x.h"

bool tf536_getInfo(TF536Inf* inf)
{
    uint8 tmp[16];
    uint8* s = (uint8*)TF536_ADDR_INF;
    uint8* d = tmp;
    for (uint16 i=0; i<16; i++) {
        *d++ = safeRead8(s); s++;
    }
    memset(inf, 0, sizeof(TF536Inf));
    if (tmp[0] != 'T' || tmp[1] != 'F' || tmp[2] != '5' || tmp[3] != '3')
        return false;

    memcpy(inf->ident, tmp, 8);
    inf->revision = tmp[6] - '0';
    inf->version = *((uint16*)&tmp[8]);
    inf->build_year= *((uint16*)&tmp[10]);
    inf->build_month = tmp[12];
    inf->build_day = tmp[13];
    inf->ramsize = (tmp[14] & 4) ? 128 : 64;
    inf->ideflag = tmp[14] & 3;
    return true;
}

uint8 tf536_getReg()
{
    return *((volatile uint8*)TF536_ADDR_REG);
}

void tf536_setReg(uint8 r)
{
    *((volatile uint8*)TF536_ADDR_REG) = r;
}

uint32 tf536_getRomShadowAddr()
{
    TF536Inf inf;
    if (!tf536_getInfo(&inf))
        return 0;

    uint32 addr = (inf.ramsize == 64) ? TF536_ROM_SHADOW_64 : TF536_ROM_SHADOW_128;
    return addr;
}

uint32 tf536_getRamShadowAddr()
{
    TF536Inf inf;
    if (!tf536_getInfo(&inf))
        return 0;

    uint32 addr = (inf.ramsize == 64) ? TF536_RAM_SHADOW_64 : TF536_RAM_SHADOW_128;
    return addr;
}

