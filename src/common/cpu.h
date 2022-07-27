#ifndef _CPU_H_
#define _CPU_H_

#include "sys.h"

uint16 disableInterrupts();
void restoreInterrupts(uint16 oldsr);
uint8 safeRead8(void* addr);
int32 testRead16(void* addr);

extern uint16 getSR();
extern void setSR(uint16);
extern uint16 getCACR();
extern uint16 setCACR(uint16);
extern uint32* getVBR();
extern void setVBR(uint32*);
extern void flushCache000();
extern void flushCache020();
extern void flushCache040();
extern void jump(uint32);

extern void disableCache020();
#define disableCache030	disableCache020

#define flushCache010	flushCache000
#define flushCache030   flushCache020
#define flushCache060   flushCache040

inline void flushCache() {
	uint16 cpu = getCPU();
	if (cpu >= 40) {
		flushCache040();
	} else if (cpu >= 20) {
		flushCache020();
	}
}


// Four-Word
typedef struct
{
	uint16 sr;				// 0x00
	uint32 pc;				// 0x02
	uint16 format : 4;		// 0x06
	uint16 offset : 12;		// 0x06
} TStackFrame0;

// Four-Word throwaway
typedef struct
{
	uint16 sr;				// 0x00
	uint32 pc;				// 0x02
	uint16 format : 4;		// 0x06
	uint16 offset : 12;		// 0x06
} TStackFrame1;

// Six-word
typedef struct
{
	uint16 sr;				// 0x00
	uint32 pc;				// 0x02
	uint16 format : 4;		// 0x06
	uint16 offset : 12;		// 0x06
	uint32 addr;			// 0x08
} TStackFrame2;

// 68040 Floating point post-instruction
typedef struct
{
	uint16 sr;				// 0x00
	uint32 pc;				// 0x02
	uint16 format : 4;		// 0x06
	uint16 offset : 12;		// 0x06
	uint32 addr;				// 0x08
} TStackFrame3;

// 68040 Floating point unimplemented
typedef struct
{
	uint16 sr;				// 0x00
	uint32 pc;				// 0x02
	uint16 format : 4;		// 0x06
	uint16 offset : 12;		// 0x06
	uint32 ea;				// 0x08 - effective address
	uint32 fault_pc;		// 0x0C - pc of faulted instruction
} TStackFrame4;

// 68040 Access error
typedef struct
{
	uint16 sr;				// 0x00
	uint32 pc;				// 0x02
	uint16 format : 4;		// 0x06
	uint16 offset : 12;		// 0x06
	uint32 ea;				// 0x08
	uint16 ssw;				// 0x0C
	uint16 wb3s;			// 0x0E
	uint16 wb2s;			// 0x10
	uint16 wb1s;			// 0x12
	uint32 fa;				// 0x14
	uint32 wb3a;			// 0x18
	uint32 wb3d;			// 0x1C
	uint32 wb2a;			// 0x20
	uint32 wb2d;			// 0x24
	uint32 wb1a;			// 0x28
	uint32 wb1d;			// 0x2C (wb1d or pd0)
	uint32 pd1;				// 0x30
	uint32 pd2;				// 0x34
	uint32 pd3;				// 0x38
} TStackFrame7;

// 68010 bus and address error
typedef struct
{
	uint16 sr;				// 0x00
	uint16 pc_hi;			// 0x02
	uint16 pc_lo;			// 0x04
	uint16 format : 4;		// 0x06
	uint16 offset : 12;		// 0x06
	uint16 ssw;				// 0x08
	uint16 fa_hi;			// 0x0A
	uint16 fa_lo;			// 0x0C
	uint16 reserved0;		// 0x0E
	uint16 data_out;		// 0x10
	uint16 reserved1;		// 0x12
	uint16 data_in;			// 0x14
	uint16 reserved2;		// 0x16
	uint16 instr_out;		// 0x18
	uint16 internal[16];		
} TStackFrame8;

// 68020+68030 coprocessor mid instruction
typedef struct
{
	uint16 sr;				// 0x00
	uint32 pc;				// 0x02
	uint16 format : 4;		// 0x06
	uint16 offset : 12;		// 0x06
	uint32 addr;			// 0x08
	uint16 internal[4];		// 0x0C
} TStackFrame9;

// 68020+68030 short bus cycle
typedef struct
{
	uint16 sr;				// 0x00
	uint32 pc;				// 0x02
	uint16 format : 4;		// 0x06
	uint16 offset : 12;		// 0x06
	uint16 internal0;		// 0x08
	uint16 ssw;				// 0x0A
	uint16 stageC;			// 0x0C
	uint16 stageB;			// 0x0E
	uint32 fault_addr;		// 0x10
	uint16 internal1[2];	// 0x14
	uint32 data_out;		// 0x18
	uint16 internal2[2];	// 0x1C
} TStackFrameA;

// 68020+68030 long bus cycle
typedef struct
{
	uint16 sr;				// 0x00
	uint32 pc;				// 0x02
	uint16 format : 4;		// 0x06
	uint16 offset : 12;		// 0x06
	uint16 internal0;		// 0x08
	uint16 ssw;				// 0x0A
	uint16 stageC;			// 0x0C
	uint16 stageB;			// 0x0E
	uint32 fault_addr;		// 0x10
	uint16 internal1[2];	// 0x14
	uint32 data_out;		// 0x18
	uint16 internal2[4];	// 0x1C
	uint32 stageB_addr;		// 0x24
	uint16 internal3[2];	// 0x28
	uint32 data_in;			// 0x2C
	uint16 internal4[3];	// 0x30
	uint16 version : 4;		// 0x38
	uint16 internal5 : 12;	// 0x38
	uint16 internal6[17];	// 0x3A
} TStackFrameB;

// CPU32 frames
typedef struct
{
	uint16 sr;				// 0x00
	uint16 return_pc_hi;	// 0x02
	uint16 return_pc_lo;	// 0x04
	uint16 format : 4;		// 0x06
	uint16 offset : 12;		// 0x06
	uint16 fault_addr_hi;	// 0x08
	uint16 fault_addR_lo;	// 0x0A
	uint16 dbuf_hi;			// 0x0C
	uint16 dbuf_lo;			// 0x0E
	uint16 pc_hi;			// 0x10
	uint16 pc_lo;			// 0x12
	uint16 itc;				// 0x14
	uint16 ssw;				// 0x16
} TStackFrameC;


// 68000 group 1 & 2*/
typedef struct
{
	uint16 sr;				// 0x00
	uint16 pc_hi;			// 0x02
	uint16 pc_lo;			// 0x04
} TStackFrame_68000_Group1_2;

// 68000 bus and address error
typedef struct
{
	uint16 internal : 11;	// 0x00
	uint16 rw : 1;			// 0x00
	uint16 in : 1;			// 0x00
	uint16 fc : 3;			// 0x00
	uint16 addr_hi;			// 0x02
	uint16 addr_lo;			// 0x04
	uint16 ir;				// 0x06
	uint16 sr;				// 0x08
	uint16 pc_hi;			// 0x0A
	uint16 pc_lo;			// 0x0C
} TStackFrame_68000_BusAddr;


#endif //_CPU_H_
