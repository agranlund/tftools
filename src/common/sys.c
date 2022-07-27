#include <stdio.h>
#include <string.h>
#include "mint/mintbind.h"
#include "mint/sysvars.h"
#include "mint/osbind.h"
#include "sys.h"
#include "cookie.h"

extern unsigned long _PgmSize;
static bool _StayResident = RESIDENT_NONE;
uint32 _CPUCOOKIE = 0;
uint16 _CPU = 0;
uint16 _TOS = 0;

#define XBRA_MAGIC 0x58425241

void sys_print(const char* fmt, ...)
{
	va_list va;
	va_start(va, fmt);
	vprintf(fmt, va);
	va_end(va);
	printf("\n\r");
}

void dbg_print(const char* file, int line, const char* fmt, ...)
{
	printf("%s:%d : ", file, line);
	va_list va;
	va_start(va, fmt);
	vprintf(fmt, va);
	va_end(va);
	printf("\n\r");
}

void StayResident(uint16 flag) {
	switch (flag)
	{
		case RESIDENT_NONE:
			_StayResident = RESIDENT_NONE;
			break;
		default:
			_StayResident |= flag;
			break;
	}
}

void printBootInfo(char* left, char* right, bool stamp)
{
	int16 len = 39;
	int16 l1 = left ? strlen(left) : 0;
	int16 l2 = stamp ? (3 + strlen(__DATE__)) : 0;
	int16 l3 = right ? strlen(right) : 0;
	int16 pad = len - l1 - l2 - l3 - 2;

	Cconws("\r\n\x1Bp");
	for (uint16 i=0; i<len; i++) {
		Cconws(" ");
	}
	Cconws("\r ");
	if (left) {
		Cconws(left);
	}
	if (stamp) {
		Cconws(" : ");
		Cconws(__DATE__);
	}
	for (uint16 i=0; i<pad; i++) {
		Cconws(" ");
	}
	if (right) {
		Cconws(right);
	}
	Cconws("\x1Bq\r\n");	
}


void* AllocAligned(uint32 size, uint16 alignment, uint8 flag)
{
	if (size == 0)
		return 0;
	if (alignment < 4)
		alignment = 4;
	if (size < 4)
		size = 4;

	uint32 mask = alignment - 1;
	size = ((size + mask) & ~mask);
	uint32 mem = 0;
#if 1
	if (flag == 0) {
		mem = (uint32) malloc(size + alignment);
	} else
#endif
	{
		mem = (uint32) Mxalloc(size + alignment, flag);

		// special case fallback when Mxalloc doesn't exist
		if ((int32)mem == -32) {
			mem = 0;
			if (*((volatile uint32*)0x5a8) == 0x1357bd13) {	// check fastram magic
				uint32 top = *((volatile uint32*)0x5a4);	// get fastram top
				if (top >= 0x00400000) {					// seems valid?
					top -= size;							// "allocate" from top
					top &= ~mask;							// align
					top -= 4;								// take 4 more bytes for header
					*((volatile uint32*)0x5a4) = top;		// update fastram top
					uint32* base = (uint32*) (top + 4);		// returned memory is top+4
					memset((void*)base, 0, size);			// clear memory to 0
					*(base-1) = 0;							// header is 0 to indicate this memory can never be released
					return (void*)base;
				}
			}
		}
	}
	if (mem == 0) {
		return 0;
	}
	uint32* base = (uint32*) ((mem + alignment) & ~mask);
	*(base-1) = mem;
	memset((void*)base, 0, size);
	return (void*)base;
}

void FreeAligned(void* ptr)
{
	if (ptr) {
		uint32 p = (uint32)ptr;
		uint32* base = (uint32*)(p - 4);
		uint32 mem = *base;
		if (mem != 0) {
			Mfree((void*)mem);
		}
	}
}

int32 xbraSet(int16 number, uint32 id, uint32 addr)
{
	uint32* xbra = (uint32*) (addr - 12);
	*xbra++ = XBRA_MAGIC;
	*xbra++ = id;
	uint32 old = Setexc(number, addr);
	*xbra++ = old;
	return old;
}

uint32 xbraFind(int16 number, uint32 id)
{
	uint32* addr = (uint32*) *((volatile uint32*)(number << 2));
	while ((uint32)addr > 12)
	{
		if (*(addr - 3) != XBRA_MAGIC)
			return 0;
		if (*(addr - 2) == id)
			return (uint32) addr;
		addr = (uint32*) *(addr - 1);
	}
	return 0;
}

void xbraRemove(int16 number, uint32 id)
{
	uint32* prevaddr = 0;
	uint32* addr = (uint32*) *((volatile uint32*)(number << 2));
	while ((uint32)addr > 12)
	{
		if (*(addr - 3) != XBRA_MAGIC)
			return;

		uint32 xbra_id = *(addr - 2);
		uint32 xbra_old = *(addr - 1);

		if (xbra_id == id) {
			if (prevaddr) {
				*(prevaddr - 1) = xbra_old;
			}
			return;
		}

		prevaddr = addr;
		addr = (uint32*) xbra_old;
	}
}


extern int superMain(int argc, char** argv);

int superTrampoline() {
	// get tos version
	OSHEADER* oshdr = (OSHEADER*) *((uint32*)0x000004F2);
	_TOS = oshdr->os_version;

	// then cookies
	cookieGet('_CPU', &_CPUCOOKIE);
	_CPU = (uint16) _CPUCOOKIE;

	// then go!
	extern unsigned int __libc_argc;
	extern char** __libc_argv;
	return superMain(__libc_argc, __libc_argv);
}

int main() {

	_StayResident = false;
	DPRINT("Entering superMain");
	int result = Supexec(superTrampoline);
	DPRINT("superMain finished with %d", result);
	if (_StayResident != RESIDENT_NONE) {
		#if DEBUG
		uint32 size = (_StayResident & RESIDENT_PGM) ? _PgmSize : 0;
		DPRINT("staying resident: %d Kb + Mallocs", size / 1024);
		#endif
		Ptermres(_PgmSize, result);
	}
	return result;
}

void __main() {
}

