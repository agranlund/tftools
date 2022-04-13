VASM=vasmm68k_mot

all: maprom fastram blitfix

clean:
	rm -f *.o fastram.prg maprom.prg blitfix.prg

maprom:
	$(VASM) -Ftos -devpac -tos-flags=0 -monst MAPROM.S -o maprom.prg

fastram:
	$(VASM) -DOPT_ONLY_RAM=1 -Ftos -devpac -tos-flags=0 MAPROM.S -o fastram.prg

blitfix:
	$(VASM) -Ftos -devpac -tos-flags=0 BLITFIX.S -o blitfix.prg