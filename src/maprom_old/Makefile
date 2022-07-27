#Makefile
OUT_DIR=../..
VASM=../ext/vasm/vasmm68k_mot
FLAGS=-Ftos -devpac -tos-flags=0 -monst

TARGETS = \
	$(OUT_DIR)/fastram.prg \
	$(OUT_DIR)/fastram.txt \
	$(OUT_DIR)/maprom.prg \
	$(OUT_DIR)/maprom.txt \
	$(OUT_DIR)/maprom_c.prg

all: clean $(TARGETS)

clean:
	rm -f *.o $(TARGETS)

$(OUT_DIR)/fastram.prg:
	rm -f *.o
	$(VASM) $(FLAGS) -DOPT_MMU=0 -DOPT_STRAM_CI=1 -DOPT_RELO_ROM=0 -DOPT_RELO_RAM=0 MAPROM.S -o $@

$(OUT_DIR)/fastram.txt: fastram.txt
	cp $< $@

$(OUT_DIR)/maprom.prg:
	rm -f *.o
	$(VASM) $(FLAGS) -DOPT_MMU=1 -DOPT_STRAM_CI=1 -DOPT_RELO_ROM=1 -DOPT_RELO_RAM=1 MAPROM.S -o $@

$(OUT_DIR)/maprom.txt: maprom.txt
	cp $< $@

$(OUT_DIR)/maprom_c.prg:
	rm -f *.o
	$(VASM) $(FLAGS) -DOPT_MMU=1 -DOPT_STRAM_CI=0 -DOPT_RELO_ROM=1 -DOPT_RELO_RAM=1 MAPROM.S -o $@

$(VASM):
	cd ../ext/vasm && make CPU=m68k SYNTAX=mot
