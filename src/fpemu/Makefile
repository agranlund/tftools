
NAME = Fpemu
BIN = fpemu.prg
DOC = fpemu.txt

SRC = 	main.c \
		fpe/fpe_atari_asm.S \
		fpe/fpe_atari.c \
		fpe/fpu_68020.c \
		fpe/fpu_add.c \
		fpe/fpu_calcea.c \
		fpe/fpu_cordic.c \
		fpe/fpu_div.c \
		fpe/fpu_emulate.c \
		fpe/fpu_exp.c \
		fpe/fpu_explode.c \
		fpe/fpu_fmovecr.c \
		fpe/fpu_fscale.c \
		fpe/fpu_fstore.c \
		fpe/fpu_getexp.c \
		fpe/fpu_hyperb.c \
		fpe/fpu_implode.c \
		fpe/fpu_int.c \
		fpe/fpu_log.c \
		fpe/fpu_mul.c \
		fpe/fpu_rem.c \
		fpe/fpu_sqrt.c \
		fpe/fpu_subr.c \
		fpe/fpu_trig.c \


DISASM =

OPT = -O2
DEFS += -m68000
DEFS += -Ifpe -I./fpe/include/

include ../common/Makefile.common

$(OBJ_DIR)/fpu_68020.o : fpe/fpu_68020.c
	$(CC) $(INCLUDE) $(CPUFLAGS) $(CXXFLAGS) -m68020-60 -c $< -o $@
