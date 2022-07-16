/*
 * Copyright (c) 2022 Anders Granlund
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


#include "fpe_atari.h"
#include <mint/cookie.h>
#include <mint/sysvars.h>>
#include <stdio.h>
#include "fpu_emulate.h"

//#define DEBUG_FPE

// from fpu_subr.c
extern int (*bfffo)(uint32_t);
extern int bfffo_68000(uint32_t);
extern int bfffo_68020(uint32_t);

// from fpe_atar_asm.S
extern void fpe_vec_sf();
extern void fpe_vec_sf_tos1();
extern void fpe_vec_sf_tos1r();
extern void fpe_vec_lf();
extern void fpe_vec_lf_tos1();
extern void fpe_vec_lf_tos1r();
extern uint32_t tos1bot;
extern uint32_t tos1top;

int fpe_install()
{
	// sanity check
	long cpu = 0;
	long fpu = 0;
	Getcookie('_CPU', &cpu);
	Getcookie('_FPU', &fpu);
	if (fpu != 0) {
		#ifdef DEBUG_FPE
		printf("FPE not installed. FPU exist\n\r");
		#endif
		return 0;
	}

	// get tos version
	uint16_t tos = 0x0206;
	OSHEADER* oshdr = (OSHEADER*) *((uint32_t*)0x4F2);
	if (oshdr) {
		tos = oshdr->os_version;
	}

	#ifdef DEBUG_FPE
	printf("CPU: %08x\n\r", cpu);
	printf("TOS: %04x\n\r", tos);
	#endif

	// pick cpu & tos specific line-f handler
	uint32_t vec = *((uint32_t*)0x2C);

	if (tos >= 0x0200) {
		vec = (uint32_t) ((cpu == 0) ? fpe_vec_sf : fpe_vec_lf);
	} else {
		tos1bot = (uint32_t) oshdr->os_beg;
		tos1top = tos1bot + (192 * 1024);

		#ifdef DEBUG_FPE
		printf("TOS1BOT: %08x\n\r", tos1bot);
		printf("TOS1TOP: %08x\n\r", tos1top);
		#endif

		if (tos1bot == 0x00FC0000) {
			vec = (uint32_t) ((cpu == 0) ? fpe_vec_sf_tos1 : fpe_vec_lf_tos1);
		} else {
			vec = (uint32_t) ((cpu == 0) ? fpe_vec_sf_tos1r : fpe_vec_lf_tos1r);
		}
	}

	// 68020+ optimized functions
	if (cpu >= 20) {
		bfffo = &bfffo_68020;
	}

	// install vector with xbra protocol
	uint32_t* xbra = (uint32_t*) (vec - 12);
	*xbra++ = 'XBRA';
	*xbra++ = 'FPE0';
	*xbra++ = (uint32_t) Setexc(11, vec);
	return 1;
}

void panic(const char* str) {
	// todo
#ifdef DIAGNOSTIC	
	printf("FPE PANIC [%s]!\n\r", str);
#endif
}

int fpe_abort(struct frame *frame, int signo, int code)
{
	// todo
#ifdef DIAGNOSTIC	
	printf("FPE ABORT! pc = %08x\n\r", frame->f_pc);
#endif
	return signo;
}


