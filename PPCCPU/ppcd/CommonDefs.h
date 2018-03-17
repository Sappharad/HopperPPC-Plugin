#pragma once

#ifdef  WIN32
#define WINDOWS
#endif

/*
 * General Data Types.
*/

#include <stdint.h>

typedef int8_t         s8;
typedef int16_t        s16;
typedef int32_t        s32;
typedef uint8_t        u8;
typedef uint16_t       u16;
typedef uint32_t       u32;
typedef float          f32;
typedef double         f64;

typedef uint64_t       u64;
typedef int64_t        s64;

#include <Hopper/CommonTypes.h>

HP_BEGIN_DECL_ENUM(NSUInteger, PPCRegClass) {
    RegClass_FPRegister = RegClass_FirstUserClass,
    RegClass_PPC_Cnt,
    RegClass_PPC_CondReg,
    RegClass_SPRegister,
    RegClass_TBRegister
}
HP_END_DECL_ENUM(PPCRegClass);

HP_BEGIN_DECL_ENUM(NSUInteger, PPCIncrement) {
    INCR_NoIncrement,
    INCR_Postincrement,
    INCR_Predecrement
}
HP_END_DECL_ENUM(PPCIncrement);

// Hopper user instruction flags
#define DISASM_PPC_INST_NONE 0x0
#define DISASM_PPC_INST_BRANCH_SET_LINK_REGISTER 0x1
#define DISASM_PPC_INST_BRANCH_TO_LINK_REGISTER 0x2
#define DISASM_PPC_INST_BRANCH_TO_COUNT_REGISTER 0x4
#define DISASM_PPC_INST_LOAD_STORE 0x8
#define DISASM_PPC_INST_INDEXED_LOAD_STORE 0x10
#define DISASM_PPC_INST_ADDI 0x20
#define DISASM_PPC_INST_SUBI 0x40

// Hopper user operand flags
#define DISASM_PPC_OPER_NONE 0x0
#define DISASM_PPC_OPER_IMM_HEX 0x1
#define DISASM_PPC_OPER_LIS_ADDI 0x2
#define DISASM_PPC_OPER_RLWIMI 0x4
#define DISASM_PPC_OPER_MULHW 0x8

static inline u32 MASK32VAL(u32 b, u32 e)
{
    u32 mask = ((u32)0xffffffff >> (b)) ^ (((e) >= 31) ? 0 : ((u32)0xffffffff) >> ((e) + 1));
    return ((b) > (e)) ? (~mask) : (mask);
}

static inline u64 MASK64VAL(u32 b, u32 e)
{
    u64 mask = ((u64)0xffffffffffffffff >> (b)) ^ (((e) >= 63) ? 0 : ((u64)0xffffffffffffffff) >> ((e) + 1));
    return ((b) > (e)) ? (~mask) : (mask);
}

#define FASTCALL    __fastcall
#define INLINE      __inline
