----------------------------------------------------------------------------
TFTOOLS

Atari utilities for TerribleFire TF534/TF536 accelerator cards.

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
Maps TOS ROMs into FastRAM.
Maps System vectors + supervisor stack to FastRAM ($0000-$0FFF)
Maps some TOS system variables to FastRAM ($2000-$7FFF, TOS 2.06 only)

Supports TOS Roms at 0xE00000 and 0xFC0000
Tested with EmuTOS 0.9.12, Atari TOS 2.06 and KAOS TOS 1.04

Stick in in your AUTO folder, preferably as the very first item, and you
will have a faster TOS experience and the ability for applications to
run from FastRAM, regardless if you are using EmuTOS or TOS 2.06

----------------------------------------------------------------------------
FASTRAM.PRG
----------------------------------------------------------------------------
Detects and registers Fastram with the OS.
Creates the DMA Fastram buffer and cookie.
This one is useful as an alternative to maprom.prg if you only want to
enable fastram without any of the extras that maprom provides.


----------------------------------------------------------------------------
BLITFIX.PRG
----------------------------------------------------------------------------
Fixes Blitter issues for machines that has TT-RAM, while still allowing
programs and TOS to use the blitter.
The program does nothing unless TT-RAM is available, the CPU is 32bit,
and a blitter is actually installed - so it's safe to leave the program
in the AUTO folder even if you toggle off the accelerator,
remove the blitter, etc.

This program should run after MAPROM.PRG.


* Mainly for TOS 2.06/3.06 & EmuTOS. Limited use for other versions.


NVDI / WARP9:
  - These programs are tricked into thinking that the blitter is not
    present, thus preventing them from crashing.

Atari TOS 2.06 / 3.06:
  - VDI/LineA blitter routines are patched to be able to fall back
    to software routines when addresses are outside of blitter range.

EmuTOS:
  - Allows programs running in ST-RAM to know the real status
    of the blitter.
    (EmuTOS will by default hide the blitter if TT-RAM is present)

  - If you have a custom build of EmuTOS which is not lying about
    the blitter, then this program does nothing.


Other TOS versions:
  - TOS is made to believe the blitter is not present
  - Only programs running in ST-RAM will be told that blitter is present

