#include <stdio.h>
#include "mint/osbind.h"
#include "string.h"

#include "sys.h"
#include "cpu.h"
#include "vbr.h"

struct VBRProxy* vbrGetProxy(uint32 ident)
{
	uint32 vbr = (uint32) getVBR();
	while (vbr > sizeof(struct VBRProxy))
	{
		struct VBRProxy* p = (struct VBRProxy*) (vbr - sizeof(struct VBRProxy));
		if (p->magic != VBRX_MAGIC)
			return 0;
		if (p->ident == ident)
			return p;
		vbr = (uint32)p->old;
	}
	return 0;
}

struct VBRProxy* vbrCreateProxy(uint32 ident)
{
	// allocate memory
	const uint32 size_header = sizeof(struct VBRProxy);
	const uint32 size_vbr = 256 * 4 * 1;
	const uint32 size_proxy = 256 * 2 * 4;
	uint32 size = size_header + size_vbr + size_proxy;	// header + vbr + proxy
	uint32 base = (uint32) AllocAligned(size, 4, 3);
	if (base == 0)
		return 0;

	// build header
	memset((void*)base, 0, size);
	struct VBRProxy* p = (struct VBRProxy*) base;
	p->vbr = (uint32*) (base + size_header);
	p->proxy = (uint16*) (base + size_header + size_vbr);
	p->magic = VBRX_MAGIC;
	p->ident = ident;
	p->old = (uint32*) getVBR();

	// build vbr + proxy table
	uint32 oldVec = (uint32) p->old;
	if (oldVec < 0x10000) {
		for(uint16 i=0,j=0; i<256; i++)
		{
			p->vbr[i] = (uint32) &p->proxy[j];
			p->proxy[j++] = 0x2F38;			// move.l <addr>.w,-(sp)
			p->proxy[j++] = oldVec;			// addr
			p->proxy[j++] = 0x4E75;			// rts
			p->proxy[j++] = 0x4E75;			// rts
			oldVec += 4;
		}
	} else {
		for(uint16 i=0,j=0; i<256; i++)
		{
			p->vbr[i] = (uint32) &p->proxy[j];
			p->proxy[j++] = 0x2F39;  	 		// move.l <addr>.l,-(sp)
			p->proxy[j++] = (oldVec >> 16);		// hi addr
			p->proxy[j++] = (oldVec & 0xFFFF);  // lo addr
			p->proxy[j++] = 0x4E75;   			// rts
			oldVec += 4;
		}
	}

	// install proxy and stay resident
	uint16 sr = disableInterrupts();
	flushCache();
	setVBR(p->vbr);
	flushCache();
	setSR(sr);
	StayResident(RESIDENT_MEM);
	return p;
}

struct VBRProxy* vbrGetOrCreateProxy(uint32 ident)
{
	struct VBRProxy* p = vbrGetProxy(ident);
	if (p == 0) {
		return vbrCreateProxy(ident);
	}
	return p;
}
