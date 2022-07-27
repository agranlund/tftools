#include <stdio.h>
#include <string.h>
#include "mint/mintbind.h"
#include "mint/sysvars.h"
#include "mint/osbind.h"
#include "tf53x.h"
#include "cpu.h"
#include "fastram.h"
#include "cookie.h"
#include "settings.h"
#include "card.h"
#include "mmu.h"


//------------------------------------------------------------
//
// defines
//
//------------------------------------------------------------
long _stksize = (4 * 1024);


//------------------------------------------------------------
//
// cookie
//
//------------------------------------------------------------
struct TFCookie
{
	uint32 ident;		// same as cookie name
	uint32 version;		// program version
};

struct TFCookie globalCookie;

void InstallCookie()
{
	memset(&globalCookie, 0, sizeof(struct TFCookie));
	globalCookie.ident = APP_IDENT;
	globalCookie.version = 0;
	cookieSet(APP_IDENT, (uint32) &globalCookie);
}


//------------------------------------------------------------
//
// utils
//
//------------------------------------------------------------
void GetRomInfo(uint16* version, uint32* addr, uint32* size)
{
	OSHEADER* oshdr = (OSHEADER*) *((uint32*)0x000004F2);
	uint32 romSrc = (uint32)oshdr->os_beg;
	uint16 romVer = oshdr->os_version;
	uint32 romSiz = 512 * 1024;
	if (romVer < 0x0200)		{ romSiz = 192 * 1024;	}
	else if (romVer < 0x0300)	{ romSiz = 256 * 1024;	}
	if (version)				{ *version = romVer; 	}
	if (addr)					{ *addr = romSrc;		}
	if (size)					{ *size = romSiz;		}
}

void mmuMap(uint32 log, uint32 phys, uint32 size, uint8 flag) {
	// todo: make generic and move to mmu.c
	const uint32 pageSize = mmuGetPageSize();
	const uint32 tidSize = (1024 * 1024);
	const uint32 pagesPerTid = tidSize / pageSize;

	DPRINT("mmuMap %08x -> %08x, %08x, %02x (ps:%d)", log, phys, size, flag, pageSize);
	const uint32 end = log + size;
	while (log < end)
	{
		uint32 *tia, *tib, *tic, *tid;
		mmuGetEntry(log, &tia, &tib, &tic, &tid);

		const uint32 offs = log & (tidSize - 1);
		uint32 firstTidEntry = offs / pageSize;
		uint32 lastTidEntry = (offs + size - 1) / pageSize;
		const uint32 numPages = 1 + lastTidEntry - firstTidEntry;

		DPRINT(" offs:%08x first:%d last:%d pages:%d", offs, firstTidEntry, lastTidEntry, numPages);

		const bool haveTid = (tid != 0);
		const bool needTid = (numPages < pagesPerTid) || (offs != 0);

		if (needTid || haveTid) {
			if (!haveTid) {
				// todo:
				// this shouldn't happen, but in a generic solution this should
				// allocte the tid and update the tic...
				// tid = allocate it etc..
				DPRINT(" todo: create TID for %08x", log);
			}
			if (!tid) {
				// todo: fatal error
				DPRINT(" todo: fatal");
				log = end;
			} else {
				if (lastTidEntry >= pagesPerTid)
					lastTidEntry = pagesPerTid - 1;

				DPRINT(" update TID %08x (l:%08x p:%08x s:%08x f:%02x", tid, log, phys, size, flag);
				DPRINT(" first = %d, last = %d", firstTidEntry, lastTidEntry);

				while (firstTidEntry <= lastTidEntry)
				{
					*tid++ = (phys & 0xFFFFFF00) | MMU_FLAG_PAGE | flag;
					log += pageSize;
					phys += pageSize;
					size -= pageSize;
					firstTidEntry++;
				}
			}
		} else {
			DPRINT(" update TIC %08x (l:%08x p:%08x s:%08x f:%02x)", tic, log, phys, size, flag);
			// we don't need a tid, and there isn't one either, so just update tic
			*tic = (phys & 0xFFFFFF00) | MMU_FLAG_PAGE | flag;
			log += tidSize;
			phys += tidSize;
			size -= tidSize;

		}
	}
}


//------------------------------------------------------------
//
// main program
//
//------------------------------------------------------------
int superMain(int argc, char** argv)
{
	// todo: check if already loaded?

	// 68030 only
	if (getCPU() != 30) {
		DPRINT("Unsupported CPU");
		return 0;
	}

	// Install fastram
	if (!IsFastRamInstalled())
	{
		// In addition to installing fastram this also:
		// - creates FRB in ST-RAM and installs the cookie for it
		// - creates a standard Atari MMU table at default location 0x700 if needed (TOS2)
		// - creates a standard Atari MMU table in fastram if needed (TOS1)
		if (!InstallFastRam()) {
			DPRINT("Failed to install fastram");
			return 0;
		}
	}

	// Get TOS info
	uint16 romVer = 0x206;
	uint32 romSrc = 0xE00000;
	uint32 romSiz = 256 * 1024;
	GetRomInfo(&romVer, &romSrc, &romSiz);

	// Load settings
	struct TFSettings settings;
	GetSettings(&settings);

	// Identify card	
	struct TFCard card;
	GetCard(&card, &settings);

	DPRINT("card:      %s", *card.name ? card.name : "unknown");
	DPRINT(" version:  %s", *card.ver ? card.ver : "unknown");
	DPRINT(" caps:     %08x", card.caps);

	// Print on-screen info
	printBootInfo(APP_NAME" ", card.name, true);

	// Check if mmu is available
	if (settings.enableMMU) {
		uint32 cookie = 0;
		if (cookieGet('PMMU', &cookie)) {
			DLOG("Warning: MMU already in use");
			settings.enableMMU = false;
		}
	}

	// Now set up the MMU unless already in use or disabled from settings
	if (settings.enableMMU)
	{
		// are we mapping anything into fastram?
		uint32 mmuMapZero = settings.enableZeroL2 && !(card.caps & CAPS_ZERO_L2) ? 1024 : 0;
		bool mmuMapRom = settings.enableRomL2 && !(card.caps & CAPS_ROM_L2);

		// sanity check rom info
		if (mmuMapRom) {
			if (romSrc == 0x00E00000) {
				if (romSiz > (1024 * 1024))
					mmuMapRom = false;
			} else if (romSrc == 0x00FC0000) {
				if (romSiz > (192 * 1024))
					mmuMapRom = false;
			} else {
				mmuMapRom = false;
			}
		}

		// figure out what pagesize and tid tables we are going to need
		uint16 tidMask = 0;
		uint32 pageSize = 0;

		#define PAGEREQ_TIC(siz) { \
			if ((pageSize == 0) || (pageSize > (siz))) \
				pageSize = (siz); \
		}	

		#define PAGEREQ_TID(num, siz) { \
			if ((pageSize == 0) || (pageSize > (siz))) \
				pageSize = (siz); \
			tidMask |= (1 << (num)); \
		}
		
		if (settings.fixDma) {						// dma compatible = TID0, 32k
			PAGEREQ_TID(0x0, 32*1024);
		}
		if (settings.fixStga) {						// stga compatible = TIC
			PAGEREQ_TIC(1024*1024);
		}
		if (mmuMapRom || !settings.enableRomL1) {
			if (romSrc == 0xE00000) {
				PAGEREQ_TIC(1024*1024);				// maprom TOS2+ = TIC
			} else {
				PAGEREQ_TID(0xF, 32*1024);			// maprom TOS1  = TIDF, 32k
			}
		}
		if (mmuMapZero) {
			PAGEREQ_TID(0x0, mmuMapZero);			// mapzero = TID0, 2k
		}
		if (!settings.enableRamL1) {
			PAGEREQ_TIC(1024*1024);					// ram ci = TIC
		}


		// Configure the MMU, if we need it
		if (pageSize)
		{
			// todo: maybe keep the existing tia+tib+tic when it makes sense.
			//       we're only talking 256 bytes, but still.
			bool keepExistingTable = false;
			bool copyInDefaultLocation = true && !keepExistingTable && (romVer >= 0x200);

			// count number of new TIDs
			uint16 numTids = 0;
			for (uint16 i=0, m=tidMask; i<16; i++, m >>= 1) {
				numTids += (m & 1);
			}
			// validate pagesize
			if (pageSize > (32 * 1024)) {
				pageSize = 32 * 1024;
			}

			// pre-allocate all the needed memory
			const uint32 pageSizeKb = (pageSize >> 10);							// pagesize / 1024
			const uint32 numEntriesPerTid = (1024 / pageSizeKb);				// number of entries per tid table
			const uint32 memSizePerTid = numEntriesPerTid * 4;					// memory needed per tid with 4 bytes per entry
			const uint32 memSizeTid = numTids * memSizePerTid;					// total memory needed for all new tid tables
			const uint32 memSizeTix = keepExistingTable ? 0 : (4 * (16 * 4));	// 4 tables, 16 entries, 4 byte per entry (tia, tib1, tib2, tic)
			const uint32 memSizeZero = mmuMapZero;
			const uint32 memSizeRom  = mmuMapRom ? romSiz : 0;
			const uint32 memSizeTotal = memSizeRom + memSizeZero + memSizeRom + memSizeTid + memSizeTix;
			const uint32 memBase = (uint32) AllocAligned(memSizeTotal, pageSize, 3);

			// set up offsets
			uint32 mem = memBase;
			const uint32 memRom = memSizeRom ? mem : 0; mem += memSizeRom;
			const uint32 memZero = memSizeZero ? mem : 0; mem += memSizeZero;
			const uint32 memTid = mem; mem += memSizeTid;
			const uint32 memTix = memSizeTix ? mem : 0;
			DPRINT("base %08x zero %08x rom %08x tid %08x tix %08x", memBase, memZero, memRom, memTid, memTix);
			DPRINT("size          zero %08x rom %08x tid %08x tix %08x", memSizeZero, memSizeRom / 1024, memSizeTid, memSizeTix);


			// create new mmu root
			mmuDisable();
			if (memTix) {
				DPRINT("Creating new mmu root at %08x", memTix);
				mmuCreate((uint32*)memTix, pageSize);
				mmuDisable();
			}

			// setup tic + default tid configs
			// todo: should probably be part of mmu.c
			DPRINT("Setting up TIC + TIDs");
			uint32 *mtptr = (uint32*)memTid;
			uint32 *tia,*tib,*tic,*tid;
			mmuGetEntry(0x00000000, &tia, &tib, &tic, &tid);
			DPRINT("tia:%08x, tib:%08x, tic:%08x, tid:%08x", (uint32)tia, (uint32)tib, (uint32)tic, (uint32)tid);
			for (uint16 i=0, m=tidMask; i<16; i++, m >>= 1)
			{
				if (m & 1)
				{
					DPRINT("Setting up tic: %02x -> %08x", i, (uint32)mtptr);
					// make tic point to the new tid table
					tic[i] = ((uint32)mtptr) | MMU_FLAG_TABLE;

					// setup default tid table with no address translation
					uint32 addr = i * (1024 * 1024);
					for (uint16 j=0; j<numEntriesPerTid; j++)
					{
						if ((addr & 0x00F00000) == 0x00F00000)
							*mtptr++ = addr | MMU_FLAG_PAGE | MMU_FLAG_CI;
						else
							*mtptr++ = addr | MMU_FLAG_PAGE;
						addr += pageSize;
					}
				}
			}
			DPRINT("basic mmu setup done. now map stuff..");

			// ram ci
			if (!settings.enableRamL1) {
				mmuMap(0x00000000, 0x00000000, (4 * 1024 * 1024), MMU_FLAG_CI);
			}
			// dma ci
			if (settings.fixDma) {
				mmuMap(0x00000000, 0x00000000, (32 * 1024), MMU_FLAG_CI);
			}
			// stga ci
			if (settings.fixStga) {
				mmuMap(0x00C00000, 0x00C00000, (2 * 1024 * 1024), MMU_FLAG_CI);
			}
			// map zero page
			if (memZero) {
				mmuMap(0x00000000, memZero, memSizeZero, 0);
			}
			// map and/or cache inhibit rom
			if (memRom || !settings.enableRomL1) {
				uint8 flag = MMU_FLAG_WP;
				if (!settings.enableRomL1)
					flag |= MMU_FLAG_CI;
				uint32 mapdest = memRom ? memRom : romSrc;
				uint32 mapsize = (romSrc == 0x00E00000) ? (1024 * 1024) : (192 * 1024);
				mmuMap(romSrc, mapdest, mapsize, flag);
			}

			DPRINT("mmu setup complete");

			// prevent others from reprogramming the mmu
			cookieSet('PMMU', (uint32)tia);

			// copy standard parts of the mmu table to default location 0x700 in case some software just assumes it's there.
			if (copyInDefaultLocation) {
				memcpy((void*)0x700, (void*)tia, 0x100);
			}

			// copy rom
			if (memRom) {
				DPRINT("copy rom -> fastram");
				memcpy((void*)memRom, (void*)romSrc, romSiz);
			}

			// copy zero. do this last since it may contain parts of the mmu table itself
			if (memZero) {
				DPRINT("copy zero -> fastram");
				memcpy((void*)memZero, (void*)0, memSizeZero);
			}

			// activate and brace for impact...
			DPRINT("activating mmu");
			flushCache030();
			mmuEnable();
		}
	}

	// Card specific setup
	if (card.Setup) {
		DPRINT("Card specific setup");
		card.Setup(&card, &settings);
		flushCache030();
	}

	// We can't properly fix DMA issues without using the MMU.
	// The best we can do to help is disabling caches.
	if (settings.fixDma && !settings.enableMMU) {
		disableCache030();
	}

	// cookies!
	DPRINT("Installing cookie");
	InstallCookie();

	// and stay alive
	StayResident(RESIDENT_ALL);
	DPRINT("All done!");

	return 0;
}
