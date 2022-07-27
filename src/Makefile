DIRS =
#DIRS += maprom_old
DIRS += maprom
DIRS += fastram
DIRS += blitfix
DIRS += fpemu
DIRS += mon
BUILDDIRS = $(DIRS:%=build-%)
CLEANDIRS = $(DIRS:%=clean-%)

NATIVE_GCC = gcc
NATIVE_EXT =


all: $(BUILDDIRS)
$(DIRS): $(BUILDDIRS)
$(BUILDDIRS):
	make -C $(@:build-%=%)

clean: $(CLEANDIRS)
$(CLEANDIRS): 
	make -C $(@:clean-%=%) clean

distclean: clean
	rm -f ext/stripx/stripx
	cd ext/vasm && make CPU=m68k SYNTAX=mot clean
	cd ext/libcmini && make clean
#	cd ext/gemlib && make clean

.PHONY: $(BUILDDIRS)
.PHONY: $(CLEANDIRS) 
.PHONY: all clean distclean


