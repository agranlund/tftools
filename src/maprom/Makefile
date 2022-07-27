NAME = MAPROM

BIN = maprom.prg
DOC = maprom.txt

SRC = 	../common/tf53x.c \
		../common/fastram.c \
		../common/mmu.c \
		main.c \
		settings.c \
		card.c \
		card_TF536r2.c \
		card_TF536r2asm.S \
		card_DFB1.c

#DEFS += -DDEBUG

include ../common/Makefile.common

$(OBJ_DIR)/api_funcs.o : api_funcs.c
	$(CC) $(INCLUDE) $(CPUFLAGS) $(CXXFLAGS) -mpcrel -c $< -o $@

