#ifndef _SYS_H_
#define _SYS_H_

#include <stdio.h>

#define true			1
#define false			0

typedef signed short	bool;
typedef unsigned int	uint32;
typedef signed int		int32;
typedef unsigned short	uint16;
typedef signed short	int16;
typedef unsigned char	uint8;
typedef signed char		int8;

#define RESIDENT_NONE	0
#define RESIDENT_PGM	1
#define RESIDENT_MEM	2
#define RESIDENT_ALL	(RESIDENT_PGM | RESIDENT_MEM)

inline uint16 getCPU() {
    extern uint16 _CPU;
	return _CPU;
}

void StayResident(uint16 type);

extern void dbg_print(const char* file, int line, const char* fmt, ...);
#define DLOG(...)   printf(__VA_ARGS__ "\n\r")
#define DFATAL(...)	dbg_print(__FILE__, __LINE__, __VA_ARGS__)
#ifdef DEBUG
#define DPRINT(...)	dbg_print(__FILE__, __LINE__, __VA_ARGS__)
#else
#define DPRINT(...)
#endif

#endif // _SYS_H_
