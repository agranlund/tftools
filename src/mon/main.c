#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <mint/sysvars.h>
#include "sys.h"
#include "cpu.h"
#include "mmu.h"
#include "cookie.h"

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
	printf("  r  {reg} {value}            : get or set register(s)\n\r");
	printf("  k  {id} {value}             : get or set cookie(s)\n\r");
	printf("  i                           : system info\n\r");
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
	char* opt = argv[1];
	char opt0 = tolower(opt[0]);
	char opt1 = tolower(opt[1]);

	if (opt0 == 'p') // peek or poke
	{
		if (argc > 2)
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
	}

	// dump / save
	else if (opt0== 'd' || opt0 == 's')
	{
		if (argc > 2)
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
		if (argc > 2)
		{
			uint32 addr = stringToHex(argv[2]);
			void(*func)(void) = (void*)addr;
			func();
		}
	}

	// register
	else if (opt0 == 'r')
	{
		bool show = true;
		if (argc > 3)
		{
			char* reg = argv[2];
			uint32 val0 = argc > 3 ? stringToHex(argv[3]) : 0;
			uint32 val1 = argc > 4 ? stringToHex(argv[4]) : 0;
			if (strcmp(reg, "cacr") == 0) {
				setCACR(val0);
			}
			if (strcmp(reg, "sr") == 0) {
				setSR(val0);
			}
			if (strcmp(reg, "vbr") == 0) {
				setVBR(val0);
			}
			if (getCPU() >= 20 && getCPU() <= 30) {
				MMURegs mmu; mmuGet(&mmu);
				if (strcmp(reg, "tc") == 0) {
					mmu.tc = val0;
					mmuSet(&mmu);
				}
				else if (argc > 4) {
					if (strcmp(reg, "ttr") == 0) {
						mmu.ttr0 = val0;
						mmu.ttr1 = val1;
						mmuSet(&mmu);
					}
					else if (strcmp(reg, "crp") == 0) {
						mmu.crp[0] = val0;
						mmu.crp[1] = val1;
						mmuSet(&mmu);
					}
					else if (strcmp(reg, "srp") == 0) {
						mmu.srp[0] = val0;
						mmu.srp[1] = val1;
						mmuSet(&mmu);
					}
				}
			}
		}

		if (show) {
			uint16 cpu = getCPU();
			printf(" SR          %04x\n\r", getSR());
			printf(" CACR        %08x\n\r", getCACR());
			printf(" VBR         %08x\n\r", getCPU() > 0 ? (uint32)getVBR() : 0);
			if ((cpu >= 20) & (cpu <= 30)) {
				MMURegs mmu;
				mmuGet(&mmu);
				printf(" TC          %08x\n\r", mmu.tc);
				printf(" CRP         %08x %08x\n\r", mmu.crp[0], mmu.crp[1]);
				printf(" SRP         %08x %08x\n\r", mmu.srp[0], mmu.srp[1]);
				printf(" TTR         %08x %08x\n\r", mmu.ttr0, mmu.ttr1);
			}
		}
		return 0;
	}

	// info
	else if (opt0 == 'i')
	{
		uint32 cmint = 0;
		uint32 cmagic = 0;
		uint32 cfrb = 0;
		uint32 emutos = 0;
		cookieGet('_FRB', &cfrb);
		cookieGet('MagX', &cmagic);
		cookieGet('MiNT', &cmint);

		int32 freeST = Mxalloc(-1, 0);
		int32 freeTT = Mxalloc(-1, 1);
		if (freeST < 0) freeST = 0;
		if (freeTT < 0) freeTT = 0;

		OSHEADER* hdr = (OSHEADER*) *((volatile uint32*)0x4f2);
		if (*(((uint32*)hdr->os_beg)+(0x2c/4)) == 'ETOS') {
			emutos = 1;
		}

		printf(" CPU         680%02d\n\r", getCPU());
		printf(" TOS         %d.%02d", getTOS() >> 8, getTOS() & 0xFF);
		if (cmint) {
			printf(" (MiNT %d.%02d)\n\r", cmint>>16, (cmint & 0xFFFF));
		} else if (cmagic) {
			printf(" (Magic)\n\r");
		} else if (emutos) {
			printf(" (EmuTOS)\n\r");
		} else {
			printf("\n\r", getTOS());
		}
		printf(" STFree      %dKb\n\r", freeST / 1024);
		printf(" TTFree      %dKb\n\r", freeTT / 1024);

		printf(" SysBase     %08x\n\r", (uint32) hdr);
		printf(" OSBegin     %08x\n\r", (uint32) hdr->os_beg);
		printf(" OSVer       %04x\n\r", (uint16) hdr->os_version);
		printf(" RamPtrs     %08x %08x %08x %08x\n\r",
			*((volatile uint32*)0x432),		// membtm
			*((volatile uint32*)0x436),		// memtop
			*((volatile uint32*)0x42e),		// phystop
			*((volatile uint32*)0x5a8) == 0x1357bd13 ? *((volatile uint32*)0x5a4) : 0);	// ramtop (if valid)
		printf(" DskBuf      %08x\n\r", *((volatile uint32*)0x4c6));
		printf(" FRB         %08x\n\r", cfrb);
		return 0;
	}

	// cookies
	else if (opt0 == 'k')
	{
		bool showall = true;

		if (argc > 2) {
			char* name = argv[2];
			uint32 n = (name[0] << 24) | (name[1] << 16) | (name[2] << 8) | (name[3] << 0);
			uint32 v = 0;
			if (argc == 4) {
				v = stringToHex(argv[3]);
				cookieSet(n, v);
			}
			v = 0;
			if (cookieGet(n, &v)) {
				printf("  %c%c%c%c       %08x\n\r", name[0], name[1], name[2], name[3], v);
			}
		} else {
			uint32* jar = (uint32*) *((volatile uint32*)0x5a0);
			printf(" Jarptr      %08x\n\r", (uint32) jar);
			uint16 count = 0;
			uint16 size = 0;
			bool done = false;
			while (!done) {
				if (*jar == 0) {
					done = true;
					size = *(jar+1);
				} else {
					uint8 n0 = ((*jar) >> 24) & 0xFF;
					uint8 n1 = ((*jar) >> 16) & 0xFF;
					uint8 n2 = ((*jar) >>  8) & 0xFF;
					uint8 n3 = ((*jar) >>  0) & 0xFF;
					uint32 val = *(jar+1);
					printf("  %c%c%c%c       %08x\n\r", n0, n1, n2, n3, val);
					jar += 2;
					count++;
				}
			}
			printf("Cookies      %d/%d\n\r", count, size);
		}
		return 0;
	}

	info();
	return 0;
}
