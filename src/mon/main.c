#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "sys.h"
#include "cpu.h"

void info()
{
	printf(VER "\n\r");
	printf("Usage: mon <cmd> {options}\n\r");
	printf("  pb <addr> {value}           : peek or poke byte\n\r");
	printf("  pw <addr> {value}           : peek or poke word\n\r");
	printf("  pl <addr> {value}           : peek or poke dword\n\r");
	printf("  d  <addr> {len}             : dump memory to screen\n\r");
	printf("  l  <addr> <filename>        : load memory from file\n\r");
	printf("  s  <addr> <len> <filename>  : save memory to file\n\r");
	printf("  x  <addr> <len> {value}     : set memory\n\r");
	printf("  c  <dst> <src> <len>        : copy memory\n\r");
	printf("  e  <addr>                   : execute from memory\n\r");
	printf("  r  <reg> {value}            : get or set register\n\r");
}

uint32 stringToHex(const char* s)
{
	uint32 val = 0;
	uint16 len = strlen(s);
	for (uint16 i=0; i<len; i++)
	{
		uint8 v = *s++;
		uint8 b = 0;
		if (v >= '0' && v <= '9')
			b = v - '0';
		else if (v >= 'a' && v <= 'f')
			b = 0xA + (v - 'a');
		else if (v >= 'A' && v <= 'F')
			b = 0xA + (v - 'A');
		val <<= 4;
		val |= b;
	}
	return val;
}

uint32 stringToDec(const char* s)
{
	return (uint32)atoi(s);
}

int superMain(int argc, char** argv)
{
	if (argc < 3) {
		info();
		return 0;
	}

	char* opt = argv[1];
	char opt0 = tolower(opt[0]);
	char opt1 = tolower(opt[1]);

	if (opt0 == 'p') // peek or poke
	{
		uint16 size = 1;
		if (opt1 == 'w')
			size = 2;
		else if (opt1 == 'l')
			size = 4;

		uint32 addr = stringToHex(argv[2]);
		if (argc < 4)
		{
			// peek
			switch (size)
			{
				case 1:
					printf("%02x\n\r", *((volatile uint8*)addr));
					break;
				case 2:
					printf("%04x\n\r", *((volatile uint16*)addr));
					break;
				case 4:
					printf("%08x\n\r", *((volatile uint32*)addr));
					break;
			}
		}
		else
		{
			// poke
			uint32 val = stringToHex(argv[3]);
			switch (size)
			{
				case 1:
					*((volatile uint8*)addr) = (uint8) val;
					break;
				case 2:
					*((volatile uint16*)addr) = (uint16) val;
					break;
				case 4:
					*((volatile uint32*)addr) = (uint32) val;
					break;
			}
		}
		return 0;
	}

	// dump / save
	else if (opt0== 'd' || opt0 == 's')
	{
		int len = (argc > 3) ? stringToDec(argv[3]) : 16;
		if (len > 0)
		{
			uint32 addr = stringToHex(argv[2]);
			if (argc > 4)
			{
				// to file
				const char* fname = argv[4];
				FILE* f = fopen(fname, "wb");
				int written = 0;
				if (f)
				{
					written = fwrite((const void*)addr, 1, len, f);
					fclose(f);
				}
				if (written != len)
				{
					printf(" Failed to write %s from %08x\n\r", fname, addr);
					return -1;
				}
				printf(" Saved %d bytes from %08x to %s\n\r", written, addr, fname);
				return 0;
			}
			else
			{
				while (len > 0)
				{
					uint16 count = (len >= 16) ? 16 : len;
					printf("%08x:", addr);
					for (uint16 i=0; i<count; i++)
					{
						printf(" %02x", *((volatile uint8*)addr));
						addr++;
						len--;
					}
					printf("\n\r");
				}
				return 0;
			}
		}
	}

	// load
	else if (opt0 == 'l')
	{
		if (argc > 3)
		{
			int len = 0;
			int loaded = 0;
			uint32 addr = stringToHex(argv[2]);
			char* fname = argv[3];
			FILE* f = fopen(fname, "rb");
			if (f)
			{
				fseek(f, 0, SEEK_END);
				len = ftell(f);
				if (len > 0)
				{
					fseek(f, 0, SEEK_SET);
					loaded = fread((void*)addr, 1, len, f);
				}
				fclose(f);
			}
			if ((len <= 0) || (len != loaded))
			{
				printf(" Failed to load %s to %08x\n\r", fname, addr);
				return -1;
			}
			printf(" Loaded %d bytes into %08x from %s\n\r", len, addr, fname);
			return 0;
		}
	}

	// set memory
	else if (opt0 == 'x')
	{
		if (argc > 3)
		{
			uint32 addr = stringToHex(argv[2]);
			int len = stringToDec(argv[3]);
			uint8 val = (argc > 4) ? stringToHex(argv[4]) : 0;
			memset((void*)addr, val, len);
			return 0;
		}
	}

	// copy memory
	else if (opt0 == 'c')
	{
		if (argc > 4)
		{
			uint32 dst = stringToHex(argv[2]);
			uint32 src = stringToHex(argv[3]);
			int len = stringToDec(argv[4]);
			memcpy((void*)dst, (void*)src, len);
			return 0;
		}
	}

	// exec
	else if (opt0 == 'e')
	{
		uint32 addr = stringToHex(argv[2]);
		void(*func)(void) = (void*)addr;
		func();
	}

	// register
	else if (opt0 == 'r')
	{
		printf(" SR        %04x\n\r", getSR());
		printf(" CACR  %08x\n\r", getCACR());
		// todo: sp/usp
		// todo: mmu
		// todo: d0-d7/a0-a7
	}

	info();
	return 0;
}
