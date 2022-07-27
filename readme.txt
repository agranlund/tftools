Various Atari utilities.
While they were primarily made for use with TF53x accelerators
they are not exclusive for them and may work fine in other setups


maprom.prg    Maps things to fastram.
fastram.prg   Register fastram with operating system
blitfix.prg   Fixes for machines with blitter + fastram
fpemu.prg     68881 FPU emulator
mon.prg       Simple monitor tool

See individual readme files for more details.


As early as possible in the AUTO folder:
  fastram.prg     (If using Atari TOS2.x or earlier)
  maprom.prg 
  blitfix.prg     (If you have a blitter)

fastram.prg and blitfix.prg are optional but maprom.prg is
pretty much mandatory for setting up the system to work
well with the accelerator.

Visit Exxos forum for help:
https://www.exxosforum.co.uk/forum/index.php

