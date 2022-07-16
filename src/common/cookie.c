#include "mint/osbind.h"
#include <string.h>
#include "cookie.h"

uint32* cookieGetJar()
{
	return (uint32*) *((volatile uint32*)0x5a0);
}

void cookieSetJar(uint32* jar)
{
	*((volatile uint32*)0x5a0) = (uint32)jar;
}

uint32* cookieGetPtr(uint32 name)
{
	uint32* jar = cookieGetJar();
	if (jar == 0)
		return 0;
	while(*jar != 0)
	{
		if (*jar == name)
			return jar;
		jar += 2;
	}
	return (name == 0) ? jar : 0;
}


bool cookieGet(uint32 name, uint32* value)
{
	uint32* cookie = cookieGetPtr(name);
	if (cookie)
	{
		if (value)
			*value = *(cookie + 1);
		return true;
	}
	return false;
}

bool cookieSet(uint32 name, uint32 value)
{
	uint32* cookie = cookieGetPtr(name);
	if (cookie)
	{
		*(cookie + 1) = value;
		return true;
	}

	uint32 used = 0;
	uint32 size = 0;
	uint32* firstCookie = cookieGetJar();
	uint32* lastCookie = cookieGetPtr(0);

	if (firstCookie != lastCookie)
	{
		used = (1 + ((uint32)lastCookie - (uint32)firstCookie)) >> 3;
		size = lastCookie[1];
	}

	if ((size - used) < 1)
	{
		uint32 newsize = size + 8;
		uint32* newjar = (uint32*) Malloc((newsize << 3));
		if (!newjar) {
			return false;
		}
		memset((void*)newjar, 0, (newsize << 3));
		if (used > 0) {
			memcpy(newjar, (void*)firstCookie, (used << 3));
		}
		cookieSetJar(newjar);
		firstCookie = newjar;
		lastCookie = cookieGetPtr(0);
		size = newsize;
	}

	if (lastCookie)
	{
		lastCookie[0] = name;
		lastCookie[1] = value;
		lastCookie[2] = 0;
		lastCookie[3] = size;
		return true;
	}
	
	return false;
}

