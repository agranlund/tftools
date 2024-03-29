#include <string.h>
#include "sys.h"
#include "settings.h"


bool LoadSettings(struct TFSettings* settings);
bool SaveSettings(struct TFSettings* settings);


void GetSettings(struct TFSettings* settings)
{
	// set defaults
	memset(settings, 0, sizeof(struct TFSettings));
	settings->enableMMU = true;							// use the mmu
	settings->detectCard = true;						// detect accelerator card
	settings->fixDma = CFG_FIXDMA_FULL;					// cache inhibit first 32k
	settings->fixStga = true;							// cache inhibit C00000+D00000
	settings->enableRamL1 = true;						// don't cache inhibit ram area
	settings->enableRomL1 = true;						// don't cache inhibit rom area
	settings->enableRamL2 = true;						// no ram L2
	settings->enableRomL2 = true;						// map rom  -> fastram
	settings->enableZeroL2 = true;						// map zero -> fastram

	// load settings
	bool loaded = LoadSettings(settings);

	// todo: bring up a menu if some key is held down?
	bool changed = !loaded;

	// save settings if changed
	if (changed) {
		SaveSettings(settings);
	}
}

void GetSettingsFilename(char* out) {
	/*
	bool isAutoFolder = false;
	Dgetpath(out, 0);
	DPRINT("path = [%s]", out);
	if (isAutoFolder) {
		sprintf(out, "%c:\\auto\\tf536.inf", 'a' + (*((volatile uint16*)0x446L) & 0xFF));
	} else {
	*/
		strcpy(out, APP_NAME".inf");
	//}
}


bool LoadSettings(struct TFSettings* settings) {
	char fname[24];
	GetSettingsFilename(fname);
	int32 fr = Fopen(fname, 0);
	if (fr < 0)
		return false;

	int16 fh = (int16) (fr & 0xFFFF);
	int32 size = Fseek(0, fh, 2);
	Fseek(0, fh, 0);
	if (size < 1) {
		Fclose(fh);
		return false;
	}

	char* buf = Malloc(size + 2);
	memset((void*)buf, 0, size + 2);
	Fread(fh, size, (void*)buf);
	Fclose(fh);

	DPRINT("Parsing %s", fname);

	// first pass cleanup
	for (uint16 i=0; i<size; i++) {
		if (buf[i] == '\r')
			buf[i] = '\n';
		else if ((buf[i] >= 'A') && (buf[i] <= 'Z'))
			buf[i] = buf[i] - 'A' + 'a';
		else if (!((buf[i] >= 'a' && buf[i] <= 'z') || (buf[i] >= '0' && buf[i] <= '9') || (buf[i] == '#')))
			buf[i] = 0;
	}
	// get rid of comments
	for (uint16 i=0; i<size; i++) {
		if (buf[i] == '#') {
			while (i<size && (buf[i] != '\n')) {
				buf[i] = 0; i++;
			}
		}
	}
	// second pass cleanup
	for (uint16 i=0; i<size; i++) {
		if (buf[i] == '#' || buf[i] == '\n')
			buf[i] = 0;
	}

	// now parse
	uint16 i = 0;
	while (i < size) {
		// skip whitespace
		while (i < size && buf[i] == 0) {
			i++;
		}
		// key
		char* s1 = &buf[i];
		while (i < size && buf[i] != 0)
			i++;
		// skip whitespace
		while(i < size && buf[i] == 0) {
			i++;
		}
		// value
		char* s2 = &buf[i];
		while (i < size && buf[i] != 0)
			i++;
		// parse it
		if ((*s1 != 0) && (*s1 != '#') && (*s2 != 0) && (*s2 != '#')) {
			int32 ival = atoi(s2);
			DPRINT("key = [%s] value = [%s] [%d]", s1, s2, ival);

			#define GETBOOL(key, var)		if (strcmp(s1, key) == 0) { var = (ival == 0) ? 0 : 1; }
			#define GETINT(key, var)		if (strcmp(s1, key) == 0) { var = ival; }

			GETBOOL("pmmu", 	settings->enableMMU);
			GETBOOL("detect",	settings->detectCard);
			GETBOOL("raml1", 	settings->enableRamL1);
			GETBOOL("roml1", 	settings->enableRomL1);
			GETBOOL("raml2", 	settings->enableRamL2);
			GETBOOL("roml2", 	settings->enableRomL2);
			GETINT ("fixdma", 	settings->fixDma);
			GETBOOL("fixstga", 	settings->fixStga);
		}
	}

	Mfree(buf);
	DPRINT("Settings loaded");
	return true;
}


bool SaveSettings(struct TFSettings* settings) {
	static const char* sep = "-----------------------------------------------------------";

	char buf[80];
	GetSettingsFilename(buf);
	int32 fr = Fcreate(buf, 0);
	if (fr < 0)
		return false;

	DPRINT("Saving %s", buf);
	int16 fh = (int16) (fr & 0xFFFF);

	#define WRITELINE(...)			{ sprintf(buf, __VA_ARGS__); Fwrite(fh, strlen(buf), buf); Fwrite(fh, 2, "\r\n"); }
	#define WRITEINT(key, var)		{ sprintf(buf, "%s %d\r\n", key, var); Fwrite(fh, strlen(buf), buf); }
	#define WRITEBOOL 				WRITEINT

	WRITELINE("# This file is autogenerated")
	WRITELINE(" ");
	WRITELINE(sep);
	WRITELINE("# Enable usage of PMMU.")
	WRITELINE("#  Some features depend on it but disabling it will");
	WRITELINE("# allow MiNT to run with memory protection");
	WRITELINE(sep);
	WRITEBOOL("PMMU       :", settings->enableMMU);
	WRITELINE(" ");

	WRITELINE(sep);
	WRITELINE("# Detect accelerator for card specific features.");
	WRITELINE(sep);
	WRITEBOOL("detect     :", settings->detectCard);
	WRITELINE(" ");

	WRITELINE(sep);
	WRITELINE("# L1 cache. Disabling requires MMU");
	WRITELINE(sep);
	WRITEBOOL("ramL1      :", settings->enableRamL1);
	WRITEBOOL("romL1      :", settings->enableRomL1);
	WRITELINE(" ");

	WRITELINE(sep);
	WRITELINE("# L2 cache for ST-RAM. Requires support from card");
	WRITELINE(sep);
	WRITEBOOL("ramL2      :", settings->enableRamL2);
	WRITELINE(" ");

	WRITELINE(sep);
	WRITELINE("# L2 cache for Zeropage. May use MMU depending on card");
	WRITELINE(sep);
	WRITEBOOL("zeroL2     :", settings->enableZeroL2);
	WRITELINE(" ");

	WRITELINE(sep);
	WRITELINE("# L2 cache for ROM. May use MMU depending on card");
	WRITELINE(sep);
	WRITEBOOL("romL2      :", settings->enableRomL2);
	WRITELINE(" ");

	WRITELINE(sep);
	WRITELINE("# STGA fix. Uses MMU to cache inhibit $C00000-$DFFFFF");
	WRITELINE(sep);
	WRITEBOOL("fixSTGA    :", settings->fixStga);
	WRITELINE(" ");

	WRITELINE(sep);
	WRITELINE("# DMA fixes.");
	WRITELINE("#  0 = off");
	WRITELINE("#  1 = standard (cache inhibit $0000-$7FFF)");
	WRITELINE("#  2 = full (additional L2 cache fixes)");
	WRITELINE(sep);
	WRITEINT ("fixDMA     :", settings->fixDma);
	WRITELINE(" ");

	Fclose(fh);
	DPRINT("Settings saved");
	return true;
}

