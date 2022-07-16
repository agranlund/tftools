#Makefile
VASM=../ext/vasm/vasmm68k_mot
OUT_DIR=../..
TARGETS=$(OUT_DIR)/blitfix.prg $(OUT_DIR)/blitfix.txt
FLAGS=-Ftos -devpac -tos-flags=0 -monst

all: $(TARGETS)

clean:
	rm -f *.o $(TARGETS)

$(OUT_DIR)/blitfix.prg: $(VASM) blitfix.s cookie.s
	$(VASM) $(FLAGS) BLITFIX.S -o $@

$(OUT_DIR)/blitfix.txt: blitfix.txt
	cp $< $@

$(VASM):
	cd ../ext/vasm && make CPU=m68k SYNTAX=mot
