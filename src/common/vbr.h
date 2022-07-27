#ifndef _VBR_H_
#define _VBR_H_

#include "sys.h"

#define VBRX_MAGIC  'XVBR'
#define VBRX_IDENT  'XVBR'

struct VBRProxy     // 32 bytes
{
    uint32* vbr;
    uint16* proxy;
    uint32  reserved[3];
    uint32  magic;          // "XVBR"
    uint32  ident;          // user specific
    uint32* old;
};

extern struct VBRProxy* vbrGetProxy(uint32 ident);
extern struct VBRProxy* vbrCreateProxy(uint32 ident);
extern struct VBRProxy* vbrGetOrCreateProxy(uint32 ident);

#endif // _VBR_H_
