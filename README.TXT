--------------------------------------
TFTOOLS

Atari utilities for TerribleFire
TF534 accelerator card.

They will probably also work on other
accelerators as long as FastRAM is
located in TT-RAM space (0x01000000)
and the CPU is a 68030 with MMU.

These programs are distributed
under the GPL version 2 license.
See SRC\LICENSE.TXT for details.

Parts of these programs are derived
from work done by the EmuTOS team.

Parts of the these programs are using
COOKIE.S by Arnd Beissner

Sourcecode compiles with Devpac 3
Anders Granlund, 2019
--------------------------------------



--------------------------------------
MAPROM.PRG
--------------------------------------
Copies the content of TOS ROMs into
FastRAM for better TOS performance.
When necessary, it will initialize
the system in exactly the same way as
FASTRAM.PRG so you are not required
to use that one before running this.


--------------------------------------
FASTRAM.PRG
--------------------------------------
- Detect and register TT-RAM with TOS
- Installs DMA Fastram buffer
- Configures PMMU as TT/Falcon

EmuTOS already does all this for you
at startup, so this program is mainly
for when running Atari TOS.
There is however no harm in running
it even when TT-RAM was already
installed - it will simply do nothing
in that case.

While this will allow applications to
take advantage of FastRAM, I strongly
recommend using MAPROM.PRG instead
in order to also allow TOS itself
to run from FastRAM.

This program is provided in case MAPROM
is causing compatability issues with
certain OS versions, or if you are
running an OS that is already loading
itself into RAM.

