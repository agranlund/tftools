#include <stdio.h>
#include "mint/osbind.h"
#include "sys.h"
#include "cookie.h"

extern unsigned long _PgmSize;
static bool _StayResident = RESIDENT_NONE;
uint32 _CPUCOOKIE = 0;
uint16 _CPU = 0;

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

extern int superMain(int argc, char** argv);

int superTrampoline() {
	// cookie first
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

