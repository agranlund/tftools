----------------------------------------------------------------------------
TFTOOLS

Atari utilities for TerribleFire TF534 accelerator card.

They will probably also work on other accelerators as long as FastRAM is
located in TT-RAM space (0x01000000) and the CPU is a 68030 with MMU.

These programs are distributed under the GPL version 2 license.
See SRC\LICENSE.TXT for details.

Parts of these programs are derived from work done by the EmuTOS team.
Parts of the these programs are using COOKIE.S by Arnd Beissner

Sourcecode compiles with Devpac 3
Anders Granlund, 2019
----------------------------------------------------------------------------



----------------------------------------------------------------------------
MAPROM.PRG
----------------------------------------------------------------------------
Copies the content of your TOS ROMs into FastRAM and configures the MMU to
allow TOS to execute from there for better performance.
If necessary, it will first initialize the system in exactly the same way as
FASTRAM.PRG - so there is no need to run both if you intend on using MAPROM

Stick in in your AUTO folder, preferably as the very first item, and you
will have a faster TOS experience and the ability for applications to
run from FastRAM, regardless if you are using EmuTOS or Atari TOS

MAPROM Paired with NVDI makes for a very snappy system!

The ROM images must be at location 0xE00000 so you need to be running
at least TOS 2.xx, or EmuTOS 256Kb or bigger.

----------------------------------------------------------------------------
BLITOFF.PRG
----------------------------------------------------------------------------
Disables the Blitter for programs outside of ST-RAM.
This fixes the issue with TOS2.06 and NVDI not rendering correctly or
crashing when being put in FastRAM.
Games and demos will still be able to use the Blitter as long as they
are running from ST-RAM (tested with "Hard'n'Heavy" + BlitB)


----------------------------------------------------------------------------
FASTRAM.PRG
----------------------------------------------------------------------------
- Detect and register TT-RAM with TOS
- Installs DMA Fastram buffer
- Configures PMMU as TT/Falcon

EmuTOS already does all this for you at startup, so this program is mainly
intended for registering FastRAM with Atari TOS.

While this will allow applications to take advantage of FastRAM, I strongly
recommend using MAPROM.PRG instead as that one does the same thing
but will also let TOS itself execute from FastRAM.



