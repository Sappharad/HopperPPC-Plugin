//
//  PPCCtx.m
//  PPCCPU
//
//  Created by copy/pasting an example on 11/06/2015.
//  Copyright (c) 2015 PK and others. All rights reserved.
//

#import "PPCCtx.h"
#import "PPCCPU.h"
#import <Hopper/CommonTypes.h>
#import <Hopper/CPUDefinition.h>
#import <Hopper/HPDisassembledFile.h>
#import "ppcd/CommonDefs.h"
#import "ppcd/ppcd.h"

struct TypeSet {
    Address addr;
    u32 size;
    ArgFormat format;
};

@implementation PPCCtx {
    PPCCPU *_cpu;
    NSObject<HPDisassembledFile> *_file;
    bool _trackingLis;
    int32_t lisArr[32];
    double  mulhwArr[32];
    int32_t dividendArr[32];
    int32_t stackDisp;
    int32_t indexBaseArr[32];
    int32_t indexBaseCTR;
    int32_t lastCmplwi;
    Address foundSDA, foundSDA2;
    NSMutableDictionary* localLabels;
    
    uint64_t typesToSetCapacity;
    uint64_t typesToSetCount;
    struct TypeSet* typesToSet;
}

- (instancetype)initWithCPU:(PPCCPU *)cpu andFile:(NSObject<HPDisassembledFile> *)file {
    if (self = [super init]) {
        _cpu = cpu;
        _file = file;
        _trackingLis = false;
        for (int i = 0; i < 32; ++i) {
            lisArr[i] = ~0;
            mulhwArr[i] = 0.0;
            dividendArr[i] = ~0;
            indexBaseArr[i] = ~0;
        }
        indexBaseCTR = ~0;
        stackDisp = 0;
        lastCmplwi = 0;
        foundSDA = BAD_ADDRESS;
        foundSDA2 = BAD_ADDRESS;
        localLabels = [NSMutableDictionary new];
        
        typesToSetCapacity = 256;
        typesToSetCount = 0;
        typesToSet = malloc(sizeof(struct TypeSet) * typesToSetCapacity);
    }
    return self;
}

- (void)dealloc {
    free(typesToSet);
}

- (void)addTypeToSet:(Address)addr size:(u32)size format:(ArgFormat)format {
    if (typesToSetCount == typesToSetCapacity) {
        typesToSetCapacity *= 2;
        typesToSet = realloc(typesToSet, sizeof(struct TypeSet) * typesToSetCapacity);
    }
    struct TypeSet* storage = &typesToSet[typesToSetCount];
    storage->addr = addr;
    storage->size = size;
    storage->format = format;
    ++typesToSetCount;
}

- (NSObject<CPUDefinition> *)cpuDefinition {
    return _cpu;
}

- (void)initDisasmStructure:(DisasmStruct *)disasm withSyntaxIndex:(NSUInteger)syntaxIndex {
    bzero(disasm, sizeof(DisasmStruct));
}

// Analysis

- (Address)adjustCodeAddress:(Address)address {
    // Instructions are always aligned to a multiple of 4.
    return address & ~3;
}

- (uint8_t)cpuModeFromAddress:(Address)address {
    return 0;
}

- (BOOL)addressForcesACPUMode:(Address)address {
    return NO;
}

- (Address)nextAddressToTryIfInstructionFailedToDecodeAt:(Address)address forCPUMode:(uint8_t)mode {
    return ((address & ~3) + 4);
}

- (int)isNopAt:(Address)address {
    uint32_t word = [_file readUInt32AtVirtualAddress:address];
    return (word == 0x60000000) ? 4 : 0;
}

- (BOOL)hasProcedurePrologAt:(Address)address {
    // procedures usually begin with a "stwu r1, -X(r1)" or "blr" instruction
    uint32_t word = [_file readUInt32AtVirtualAddress:address];
    return (word & 0xffff8000) == 0x94218000 || word == 0x4e800020;
}

- (NSUInteger)detectedPaddingLengthAt:(Address)address {
    NSUInteger len = 0;
    Address endAddr = _file.lastSegment.endAddress;
    while (address < endAddr && [_file readUInt32AtVirtualAddress:address] == 0) {
        address += 4;
        len += 4;
    }
    return len;
}

- (void)analysisBeginsAt:(Address)entryPoint {
    //printf("analysisBeginsAt\n");
    NSObject<HPSection> *ctors = [_file sectionNamed:@"ctors"];
    if (ctors) {
        for (Address addr = ctors.startAddress; addr < ctors.endAddress; addr += 4) {
            [_file setType:Type_Int32 atVirtualAddress:addr forLength:4];
            [_file setFormat:Format_Address forArgument:0 atVirtualAddress:addr];
        }
    }
    NSObject<HPSection> *dtors = [_file sectionNamed:@"dtors"];
    if (dtors) {
        for (Address addr = dtors.startAddress; addr < dtors.endAddress; addr += 4) {
            [_file setType:Type_Int32 atVirtualAddress:addr forLength:4];
            [_file setFormat:Format_Address forArgument:0 atVirtualAddress:addr];
        }
    }
}

- (void)procedureAnalysisBeginsForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {
    //printf("procedureAnalysisBeginsForProcedure %p\n", procedure);
    _trackingLis = true;
}

- (void)performProcedureAnalysis:(NSObject<HPProcedure> *)procedure basicBlock:(NSObject<HPBasicBlock> *)basicBlock disasm:(DisasmStruct *)disasm {
    //printf("performProcedureAnalysis %p\n", procedure);
}

static NSString* MakeNumericComment(u32 val)
{
    for (int i = 0; i < 4; ++i) {
        u8 b = (u8)(val >> (i * 8));
        if (b < 32 || b > 126)
            return [NSString stringWithFormat:@"0x%08X", val];
    }
    u32 bigVal = __builtin_bswap32(val);
    return [NSString stringWithFormat:@"0x%08X '%.4s'", val, (char*)&bigVal];
}

static ByteType TypeForSize(u32 size)
{
    switch (size)
    {
    case 1:
    default:
        return Type_Int8;
    case 2:
        return Type_Int16;
    case 4:
        return Type_Int32;
    case 8:
        return Type_Int64;
    }
}

- (void)performInstructionSpecificAnalysis:(DisasmStruct *)disasm forProcedure:(NSObject<HPProcedure> *)procedure inSegment:(NSObject<HPSegment> *)segment {
    //printf("performInstructionSpecificAnalysis %08X %s %p\n", (u32)disasm->virtualAddr, disasm->instruction.mnemonic, procedure);
    
    // LIS/ADDI resolved address
    for (int i = 0; i < DISASM_MAX_OPERANDS; ++i) {
        DisasmOperand *operand = disasm->operand + i;
        if (operand->userData[0] & DISASM_PPC_OPER_LIS_ADDI) {
            if ([_file segmentForVirtualAddress:(u32)operand->userData[1]])
            {
                [segment addReferencesToAddress:(u32)operand->userData[1] fromAddress:disasm->virtualAddr];
            }
            else
            {
                [_file setInlineComment:MakeNumericComment((u32)operand->userData[1])
                       atVirtualAddress:disasm->virtualAddr reason:CCReason_Automatic];
            }
            
            // SDA/SDA2 symbol synthesis
            if (disasm->operand[0].type & DISASM_BUILD_REGISTER_INDEX_MASK(13) && segment == _file.firstSegment)
                foundSDA = (u32)operand->userData[1];
            else if (disasm->operand[0].type & DISASM_BUILD_REGISTER_INDEX_MASK(2) && segment == _file.firstSegment)
                foundSDA2 = (u32)operand->userData[1];
            break;
        }
    }
    
    // Handle MULHW
    if (disasm->operand[2].userData[0] & DISASM_PPC_OPER_MULHW) {
        int32_t divConstant = (int32_t)disasm->operand[2].userData[1];
        if (divConstant != ~0) {
            double factor = (double)divConstant / (double)(1LL << 32LL);
            mulhwArr[GetRegisterIndex(disasm->operand[0].type)] = factor;
            dividendArr[GetRegisterIndex(disasm->operand[0].type)] = GetRegisterIndex(disasm->operand[2].type);
            double rounded = round(1.0 / factor);
            if (fabs(rounded - 1.0 / factor) < 0.0001)
                [_file setInlineComment:[NSString stringWithFormat:@"divide by %g", rounded]
                       atVirtualAddress:disasm->virtualAddr reason:CCReason_Automatic];
        }
    } else if (!strcmp(disasm->instruction.mnemonic, "add")) {
        int32_t dividend = dividendArr[GetRegisterIndex(disasm->operand[1].type)];
        if (dividend == GetRegisterIndex(disasm->operand[2].type)) {
            double factor = mulhwArr[GetRegisterIndex(disasm->operand[1].type)];
            factor += 1.0;
            mulhwArr[GetRegisterIndex(disasm->operand[0].type)] = factor;
            dividendArr[GetRegisterIndex(disasm->operand[0].type)] = dividend;
            double rounded = round(1.0 / factor);
            if (fabs(rounded - 1.0 / factor) < 0.0001)
                [_file setInlineComment:[NSString stringWithFormat:@"divide by %g", rounded]
                       atVirtualAddress:disasm->virtualAddr reason:CCReason_Automatic];
        }
    } else if (!strcmp(disasm->instruction.mnemonic, "srawi")) {
        int32_t dividend = dividendArr[GetRegisterIndex(disasm->operand[1].type)];
        if (dividend != ~0) {
            double factor = mulhwArr[GetRegisterIndex(disasm->operand[1].type)];
            factor /= (double)(1LL << disasm->operand[2].immediateValue);
            mulhwArr[GetRegisterIndex(disasm->operand[0].type)] = factor;
            double rounded = round(1.0 / factor);
            if (fabs(rounded - 1.0 / factor) < 0.0001)
                [_file setInlineComment:[NSString stringWithFormat:@"divide by %g", rounded]
                       atVirtualAddress:disasm->virtualAddr reason:CCReason_Automatic];
        }
    }
    
    // Stack register handling
    if (disasm->instruction.userData & DISASM_PPC_INST_LOAD_STORE &&
        disasm->operand[2].type & DISASM_BUILD_REGISTER_INDEX_MASK(1)) {
        if (disasm->operand[0].type & DISASM_BUILD_REGISTER_INDEX_MASK(1) &&
            !strcmp(disasm->instruction.mnemonic, "stwu")) {
            stackDisp = (int32_t)disasm->operand[1].immediateValue;
            [procedure setVariableName:@"BPpush" forDisplacement:disasm->operand[1].immediateValue];
        } else {
            int32_t imm = (int32_t)disasm->operand[1].immediateValue + stackDisp;
            if (imm < 0) {
                [procedure setVariableName:[NSString stringWithFormat:@"var_%X", -imm] forDisplacement:disasm->operand[1].immediateValue];
            } else {
                if (imm == 4 && disasm->instruction.mnemonic[0] == 's')
                    [procedure setVariableName:@"LRpush" forDisplacement:disasm->operand[1].immediateValue];
                else if (imm == 4 && disasm->instruction.mnemonic[0] == 'l')
                    [procedure setVariableName:@"LR" forDisplacement:disasm->operand[1].immediateValue];
                else
                    [procedure setVariableName:[NSString stringWithFormat:@"arg_%X", imm] forDisplacement:disasm->operand[1].immediateValue];
            }
        }
    } else if (disasm->instruction.userData & DISASM_PPC_INST_ADDI &&
               disasm->operand[0].type & DISASM_BUILD_REGISTER_INDEX_MASK(1) &&
               disasm->operand[1].type & DISASM_BUILD_REGISTER_INDEX_MASK(1)) {
        stackDisp += (int32_t)disasm->operand[2].immediateValue;
        [procedure setVariableName:@"BPpop" forDisplacement:disasm->operand[2].immediateValue];
    }
    
    // Load/store handling
    if (disasm->instruction.userData & DISASM_PPC_INST_LOAD_STORE &&
        disasm->instruction.addressValue && disasm->operand[2].size) {
        ArgFormat format = Format_Hexadecimal;
        if (!strcmp(disasm->instruction.mnemonic, "lwz") || !strcmp(disasm->instruction.mnemonic, "stw")) {
            uint32_t data = [_file readInt32AtVirtualAddress:disasm->instruction.addressValue];
            if (data >= 0x80000000 && data <= 0x8C000000)
                format = Format_Address;
        } else if (!strncmp(disasm->instruction.mnemonic, "lf", 2) || !strncmp(disasm->instruction.mnemonic, "stf", 2))
            format = Format_Float;
        [self addTypeToSet:disasm->instruction.addressValue size:disasm->operand[2].size format:format];
    }
    
    // Indexed load/store handling
    if (disasm->instruction.userData & DISASM_PPC_INST_INDEXED_LOAD_STORE) {
        Address baseAddr = disasm->operand[2].userData[1];
        indexBaseArr[GetRegisterIndex(disasm->operand[0].type)] = (u32)baseAddr;
    }
    
    if (!strcmp(disasm->instruction.mnemonic, "mtctr")) {
        indexBaseCTR = indexBaseArr[GetRegisterIndex(disasm->operand[0].type)];
    } else if (!strcmp(disasm->instruction.mnemonic, "cmplwi")) {
        lastCmplwi = (s32)disasm->operand[1].immediateValue;
    }
}

- (void)updateProcedureAnalysis:(DisasmStruct *)disasm {
    //printf("updateProcedureAnalysis %s\n", disasm->instruction.mnemonic);
}

- (void)procedureAnalysisContinuesOnBasicBlock:(NSObject<HPBasicBlock> *)basicBlock {
    //printf("procedureAnalysisContinuesOnBasicBlock\n");
}

- (void)procedureAnalysisOfPrologForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {
    //printf("procedureAnalysisOfPrologForProcedure %p\n", procedure);
}

- (void)procedureAnalysisOfEpilogForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {
    //printf("procedureAnalysisOfEpilogForProcedure %p\n", procedure);
}

- (void)procedureAnalysisEndedForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {
    //printf("procedureAnalysisEndedForProcedure %p\n", procedure);
    _trackingLis = false;
    for (int i = 0; i < 32; ++i) {
        lisArr[i] = ~0;
        mulhwArr[i] = 0.0;
        dividendArr[i] = ~0;
        indexBaseArr[i] = ~0;
    }
    lastCmplwi = 0;
    indexBaseCTR = ~0;
    stackDisp = 0;
    
    // SDA/SDA2 symbol synthesis
    Address maxSDA = BAD_ADDRESS;
    if (foundSDA != BAD_ADDRESS && foundSDA2 != BAD_ADDRESS)
        maxSDA = MAX(foundSDA, foundSDA2);
    else if (foundSDA != BAD_ADDRESS)
        maxSDA = foundSDA;
    else if (foundSDA2 != BAD_ADDRESS)
        maxSDA = foundSDA2;
    
    if (maxSDA != BAD_ADDRESS) {
        if (![_file segmentForVirtualAddress:maxSDA]) {
            Address startAddr = _file.lastSegment.endAddress;
            NSObject<HPSegment> *seg = [_file addSegmentAt:startAddr toExcludedAddress:maxSDA + 4];
            seg.segmentName = @"SBSS2";
            seg.readable = YES;
            seg.writable = NO;
            seg.executable = NO;
            NSObject<HPSection> *sec = [seg addSectionAt:startAddr toExcludedAddress:maxSDA + 4];
            sec.sectionName = @"sbss2";
            sec.pureDataSection = YES;
            sec.zeroFillSection = YES;
        }
    }
    
    if (foundSDA != BAD_ADDRESS) {
        [_file setName:@"_SDA_BASE_" forVirtualAddress:foundSDA reason:NCReason_Import];
        [[_cpu hopperServices] logMessage:[NSString stringWithFormat:@"Found _SDA_BASE_ (r13): 0x%08X", (u32)foundSDA]];
    }
    
    if (foundSDA2 != BAD_ADDRESS) {
        [_file setName:@"_SDA2_BASE_" forVirtualAddress:foundSDA2 reason:NCReason_Import];
        [[_cpu hopperServices] logMessage:[NSString stringWithFormat:@"Found _SDA2_BASE_ (r2): 0x%08X", (u32)foundSDA2]];
    }
}

- (void)analysisEnded {
    //printf("analysisEnded\n");
    for (id addr in localLabels) {
        NSObject<HPProcedure> *procedure = [_file procedureAt:(u32)[addr unsignedIntegerValue]];
        id val = [localLabels objectForKey:addr];
        if ([procedure addressOfLocalLabel:val] == BAD_ADDRESS)
            [procedure setLocalLabel:val atAddress:(u32)[addr unsignedIntegerValue]];
        else
            [_file setComment:val atVirtualAddress:(u32)[addr unsignedIntegerValue] reason:CCReason_Automatic];
    }
    [localLabels removeAllObjects];
    
    for (uint64_t i = 0; i < typesToSetCount; ++i) {
        struct TypeSet* storage = &typesToSet[i];
        [_file setType:TypeForSize(storage->size) atVirtualAddress:(u32)storage->addr forLength:storage->size];
        [_file setFormat:storage->format forArgument:0 atVirtualAddress:(u32)storage->addr];
    }
    typesToSetCount = 0;
}

- (Address)getThunkDestinationForInstructionAt:(Address)address {
    return BAD_ADDRESS;
}

- (void)resetDisassembler {

}

- (uint8_t)estimateCPUModeAtVirtualAddress:(Address)address {
    return 0;
}

- (int)disassembleSingleInstruction:(DisasmStruct *)disasm usingProcessorMode:(NSUInteger)mode {
    DisasmStruct working;
    memcpy(&working, disasm, sizeof(working));
    working.instruction.branchType = DISASM_BRANCH_NONE;
    working.instruction.addressValue = 0;
    working.instruction.userData = 0;
    for (int i=0; i<DISASM_MAX_REG_CLASSES; i++) {
        working.implicitlyReadRegisters[i] = 0;
        working.implicitlyWrittenRegisters[i] = 0;
    }
    for (int i=0; i<DISASM_MAX_OPERANDS; i++) {
        working.operand[i].type = DISASM_OPERAND_NO_OPERAND;
        working.operand[i].accessMode = DISASM_ACCESS_NONE;
        bzero(&working.operand[i].memory, sizeof(working.operand[i].memory));
        working.operand[i].isBranchDestination = 0;
        working.operand[i].userData[0] = 0;
        working.operand[i].size = 0;
    }
    
    PPCD_CB d;
    d.pc = working.virtualAddr;
    d.instr = [_file readUInt32AtVirtualAddress:working.virtualAddr];
    d.disasm = &working;
    d.lisArr = _trackingLis ? lisArr : NULL;
    PPCDisasm(&d);
    
    /* Resolve SDA/SDA2 load/store here */
    if (working.instruction.userData & DISASM_PPC_INST_LOAD_STORE) {
        if (working.operand[2].type & DISASM_BUILD_REGISTER_INDEX_MASK(13)) {
            Address addr = [_file findVirtualAddressNamed:@"_SDA_BASE_"];
            if (addr != BAD_ADDRESS)
                working.instruction.addressValue = addr + working.operand[1].immediateValue;
        } else if (working.operand[2].type & DISASM_BUILD_REGISTER_INDEX_MASK(2)) {
            Address addr = [_file findVirtualAddressNamed:@"_SDA2_BASE_"];
            if (addr != BAD_ADDRESS)
                working.instruction.addressValue = addr + working.operand[1].immediateValue;
        }
    } else if (working.instruction.userData & DISASM_PPC_INST_ADDI) {
        if (working.operand[1].type & DISASM_BUILD_REGISTER_INDEX_MASK(13)) {
            Address addr = [_file findVirtualAddressNamed:@"_SDA_BASE_"];
            if (addr != BAD_ADDRESS)
                working.instruction.addressValue = addr + working.operand[2].immediateValue;
        } else if (working.operand[1].type & DISASM_BUILD_REGISTER_INDEX_MASK(2)) {
            Address addr = [_file findVirtualAddressNamed:@"_SDA2_BASE_"];
            if (addr != BAD_ADDRESS)
                working.instruction.addressValue = addr + working.operand[2].immediateValue;
        }
    } else if (working.instruction.userData & DISASM_PPC_INST_SUBI) {
        if (working.operand[1].type & DISASM_BUILD_REGISTER_INDEX_MASK(13)) {
            Address addr = [_file findVirtualAddressNamed:@"_SDA_BASE_"];
            if (addr != BAD_ADDRESS)
                working.instruction.addressValue = addr - working.operand[2].immediateValue;
        } else if (working.operand[1].type & DISASM_BUILD_REGISTER_INDEX_MASK(2)) {
            Address addr = [_file findVirtualAddressNamed:@"_SDA2_BASE_"];
            if (addr != BAD_ADDRESS)
                working.instruction.addressValue = addr - working.operand[2].immediateValue;
        }
    }
    
    memcpy(disasm, &working, sizeof(working));
    
#if 0
    if (_trackingLis) {
        printf ("%08X  %08X  %-12s%-30s\n", d.pc, d.instr, d.mnemonic, d.operands);
    }
#endif
    
    if ((d.iclass & PPC_DISA_ILLEGAL) == PPC_DISA_ILLEGAL) return DISASM_UNKNOWN_OPCODE;
    return 4; //All instructions are 4 bytes
}

- (BOOL)instructionHaltsExecutionFlow:(DisasmStruct *)disasm {
    return NO;
}

- (void)performBranchesAnalysis:(DisasmStruct *)disasm computingNextAddress:(Address *)next andBranches:(NSMutableArray<NSNumber *> *)branches forProcedure:(NSObject<HPProcedure> *)procedure basicBlock:(NSObject<HPBasicBlock> *)basicBlock ofSegment:(NSObject<HPSegment> *)segment calledAddresses:(NSMutableArray<NSNumber *> *)calledAddresses callsites:(NSMutableArray<NSNumber *> *)callSitesAddresses {
    //printf("performBranchesAnalysis %08X %s %p\n", (u32)disasm->virtualAddr, disasm->instruction.mnemonic, procedure);
    
    // Switch statement
    if (indexBaseCTR != ~0 && !strcmp(disasm->instruction.mnemonic, "bctr") && lastCmplwi) {
        uint32_t offset = 0;
        Address addr = [_file readUInt32AtVirtualAddress:(u32)indexBaseCTR];
        NSMutableDictionary* labelDict = [NSMutableDictionary dictionaryWithCapacity:lastCmplwi+1];
        for (int32_t i = 0; i <= lastCmplwi; ++i) {
            NSMutableArray* arr = [labelDict objectForKey:@(addr)];
            if (!arr) {
                arr = [NSMutableArray new];
                [labelDict setObject:arr forKey:@(addr)];
            }
            [arr addObject:@(offset / 4)];
            offset += 4;
            addr = [_file readUInt32AtVirtualAddress:(u32)indexBaseCTR + offset];
        }
        [_file setType:Type_Int32 atVirtualAddress:(u32)indexBaseCTR forLength:offset];
        [_file setName:[NSString stringWithFormat:@"jump table for 0x%08X", (u32)disasm->virtualAddr]
            forVirtualAddress:(u32)indexBaseCTR reason:NCReason_Automatic];
        NSUInteger maxTargetCount = 0;
        for (id addr in labelDict) {
            [branches addObject:addr];
            NSMutableArray* arr = [labelDict objectForKey:addr];
            maxTargetCount = MAX(maxTargetCount, arr.count);
        }
        NSUInteger maxDupeCount = 0;
        for (id addr in labelDict) {
            [branches addObject:addr];
            NSMutableArray* arr = [labelDict objectForKey:addr];
            if (arr.count == maxTargetCount)
                ++maxDupeCount;
        }
        for (id addr in labelDict) {
            NSMutableArray* arr = [labelDict objectForKey:addr];
            if (maxDupeCount == 1 && arr.count == maxTargetCount)
                [localLabels setObject:@"default" forKey:addr];
            else {
                NSArray* sorted = [arr sortedArrayUsingSelector:@selector(compare:)];
                NSMutableString* str = [NSMutableString stringWithString:@"case "];
                int prev = -1;
                bool inRange = false;
                for (id idx in sorted) {
                    int this = [idx intValue];
                    if (prev == -1) {
                        [str appendFormat:@"%d", this];
                    } else if (this == prev) {
                    } else if (this == prev + 1) {
                        inRange = true;
                    } else {
                        if (inRange) {
                            inRange = false;
                            [str appendFormat:@"-%d", prev];
                        }
                        [str appendFormat:@",%d", this];
                    }
                    prev = this;
                }
                if (inRange) {
                    inRange = false;
                    [str appendFormat:@"-%d", prev];
                }
                [localLabels setObject:str forKey:addr];
            }
        }
        *next = disasm->virtualAddr + 4;
        return;
    }
    
    if (disasm->instruction.branchType == DISASM_BRANCH_CALL) {
        [callSitesAddresses addObject:@(disasm->instruction.addressValue)];
        *next = disasm->virtualAddr + 4;
    } else if (disasm->instruction.branchType == DISASM_BRANCH_RET) {
        *next = BAD_ADDRESS;
    } else {
        [branches addObject:@(disasm->instruction.addressValue)];
        *next = disasm->virtualAddr + 4;
    }
    //printf("%08X NEXT %08X %d\n", disasm->virtualAddr, *next, disasm->instruction.branchType);
}

// Printing

- (NSObject<HPASMLine> *)buildMnemonicString:(DisasmStruct *)disasm inFile:(NSObject<HPDisassembledFile> *)file {
    NSObject<HPHopperServices> *services = _cpu.hopperServices;
    NSObject<HPASMLine> *line = [services blankASMLine];
    [line appendMnemonic:@(disasm->instruction.mnemonic)];
    return line;
}

static RegClass GetRegisterClass(DisasmOperandType type)
{
    for (int i = 0; i < DISASM_MAX_REG_CLASSES; ++i)
        if (type & DISASM_BUILD_REGISTER_CLS_MASK(i))
            return i;
    return -1;
}

static int GetRegisterIndex(DisasmOperandType type)
{
    for (int i = 0; i < DISASM_MAX_REG_INDEX; ++i)
        if (type & DISASM_BUILD_REGISTER_INDEX_MASK(i))
            return i;
    return -1;
}

- (NSObject<HPASMLine> *)buildOperandString:(DisasmStruct *)disasm forOperandIndex:(NSUInteger)operandIndex inFile:(NSObject<HPDisassembledFile> *)file raw:(BOOL)raw {
    if (operandIndex >= DISASM_MAX_OPERANDS) return nil;
    DisasmOperand *operand = disasm->operand + operandIndex;
    if (operand->type == DISASM_OPERAND_NO_OPERAND) return nil;
   
    // Get the format requested by the user
    ArgFormat format = [file formatForArgument:operandIndex atVirtualAddress:disasm->virtualAddr];
    
    NSObject<HPHopperServices> *services = _cpu.hopperServices;
    NSObject<HPASMLine> *line = [services blankASMLine];
    
    if (operand->type & DISASM_OPERAND_CONSTANT_TYPE) {
        // Local variable
        if ((format == Format_Default || format == Format_StackVariable)) {
            if ((operandIndex == 1 && disasm->instruction.userData & DISASM_PPC_INST_LOAD_STORE &&
                 disasm->operand[2].type & DISASM_BUILD_REGISTER_INDEX_MASK(1)) ||
                (operandIndex == 2 && disasm->instruction.userData & DISASM_PPC_INST_ADDI &&
                 disasm->operand[1].type & DISASM_BUILD_REGISTER_INDEX_MASK(1))) {
                NSObject<HPProcedure> *proc = [file procedureAt:disasm->virtualAddr];
                if (proc) {
                    NSString *variableName = [proc variableNameForDisplacement:operand->immediateValue];
                    if (variableName) {
                        [line appendVariableName:variableName withDisplacement:operand->immediateValue];
                        [line setIsOperand:operandIndex startingAtIndex:0];
                        return line;
                    }
                }
            } else if (operandIndex == 2 && disasm->instruction.userData & DISASM_PPC_INST_SUBI &&
                       disasm->operand[1].type & DISASM_BUILD_REGISTER_INDEX_MASK(1)) {
                NSObject<HPProcedure> *proc = [file procedureAt:disasm->virtualAddr];
                if (proc) {
                    NSString *variableName = [proc variableNameForDisplacement:-operand->immediateValue];
                    if (variableName) {
                        [line appendVariableName:variableName withDisplacement:-operand->immediateValue];
                        [line setIsOperand:operandIndex startingAtIndex:0];
                        return line;
                    }
                }
            }
        }
        
        if (format == Format_Default) {
            if (disasm->instruction.addressValue != 0 && !(disasm->instruction.userData & DISASM_PPC_INST_LOAD_STORE)) {
                format = Format_Address;
            }
            else if (operandIndex <= 2 &&
                     disasm->instruction.userData & (DISASM_PPC_INST_ADDI | DISASM_PPC_INST_SUBI | DISASM_PPC_INST_LOAD_STORE)) {
                format = Format_Hexadecimal | Format_Signed;
            }
            else {
                if (operand->userData[0] & DISASM_PPC_OPER_IMM_HEX || llabs(operand->immediateValue) > 255)
                    format = Format_Hexadecimal | Format_Signed;
                else
                    format = Format_Decimal | Format_Signed;
            }
        }
        [line append:[file formatNumber:operand->immediateValue
                                     at:disasm->virtualAddr usingFormat:format
                             andBitSize:32]];
    }
    else if (operand->type & DISASM_OPERAND_REGISTER_TYPE || operand->type & DISASM_OPERAND_MEMORY_TYPE) {
        RegClass regCls = GetRegisterClass(operand->type);
        int regIdx = GetRegisterIndex(operand->type);
        [line appendRegister:[_cpu registerIndexToString:regIdx
                                                 ofClass:regCls
                                             withBitSize:32
                                                position:DISASM_LOWPOSITION
                                          andSyntaxIndex:file.userRequestedSyntaxIndex]
                     ofClass:regCls
                    andIndex:regIdx];
    }
    else if (operand->type & DISASM_OPERAND_OTHER) {
        [line appendRegister:@(operand->userString + 8)];
    }
    
    [line setIsOperand:operandIndex startingAtIndex:0];
    
    return line;
}

static const char* CRNames[] =
{
    "lt",
    "gt",
    "eq",
    "so"
};

- (NSObject<HPASMLine> *)buildCompleteOperandString:(DisasmStruct *)disasm inFile:(NSObject<HPDisassembledFile> *)file raw:(BOOL)raw {
    NSObject<HPHopperServices> *services = _cpu.hopperServices;
    
    NSObject<HPASMLine> *line = [services blankASMLine];
    
    int op_index = 0;
    
    if (disasm->instruction.userData & DISASM_PPC_INST_LOAD_STORE)
    {
        NSObject<HPASMLine> *part = [self buildOperandString:disasm forOperandIndex:0 inFile:file raw:raw];
        if (part == nil) return line;
        [line append:part];
        [line appendRawString:@", "];
        
        part = [self buildOperandString:disasm forOperandIndex:1 inFile:file raw:raw];
        if (part == nil) return line;
        [line append:part];
        [line appendRawString:@"("];
        
        part = [self buildOperandString:disasm forOperandIndex:2 inFile:file raw:raw];
        if (part == nil) return line;
        [line append:part];
        [line appendRawString:@")"];
        
        op_index = 3;
    }
    
    for (; op_index<DISASM_MAX_OPERANDS; op_index++) {
        NSObject<HPASMLine> *part = [self buildOperandString:disasm forOperandIndex:op_index inFile:file raw:raw];
        if (part == nil) break;
        if (op_index) [line appendRawString:@", "];
        [line append:part];
        
        // RLWIMI comment
        DisasmOperand *operand = disasm->operand + op_index;
        if (operand->userData[0] & DISASM_PPC_OPER_RLWIMI) {
            int ra = GetRegisterIndex(disasm->operand[0].type);
            int rs = GetRegisterIndex(disasm->operand[1].type);
            int sh = (int)operand->userData[1];
            int mb = (int)operand->userData[2];
            int me = (int)operand->userData[3];
            if (sh == 0) {
                [line appendComment:[NSString stringWithFormat:@" # r%d = r%d & 0x%08X", ra, rs, MASK32VAL(mb, me)]];
            } else if (me + sh > 31) {
                // Actually a shift right
                [line appendComment:[NSString stringWithFormat:@" # r%d = (r%d >> %d) & 0x%08X", ra, rs, 32 - sh, MASK32VAL(mb, me)]];
            } else {
                [line appendComment:[NSString stringWithFormat:@" # r%d = (r%d << %d) & 0x%08X", ra, rs, sh, MASK32VAL(mb, me)]];
            }
        }
    }
    
    if (!strcmp(disasm->instruction.mnemonic, "cror")) {
        [line appendComment:[NSString stringWithFormat:@" # %s = %s | %s",
                             CRNames[GetRegisterIndex(disasm->operand[0].type) & 0x3],
                             CRNames[GetRegisterIndex(disasm->operand[1].type) & 0x3],
                             CRNames[GetRegisterIndex(disasm->operand[2].type) & 0x3]]];
    }
    
    return line;
}

// Decompiler

- (BOOL)canDecompileProcedure:(NSObject<HPProcedure> *)procedure {
    return NO;
}

- (Address)skipHeader:(NSObject<HPBasicBlock> *)basicBlock ofProcedure:(NSObject<HPProcedure> *)procedure {
    return basicBlock.from;
}

- (Address)skipFooter:(NSObject<HPBasicBlock> *)basicBlock ofProcedure:(NSObject<HPProcedure> *)procedure {
    return basicBlock.to;
}

- (ASTNode *)rawDecodeArgumentIndex:(int)argIndex
                           ofDisasm:(DisasmStruct *)disasm
                  ignoringWriteMode:(BOOL)ignoreWrite
                    usingDecompiler:(Decompiler *)decompiler {
    return nil;
}

- (ASTNode *)decompileInstructionAtAddress:(Address)a
                                    disasm:(DisasmStruct *)d
                                 addNode_p:(BOOL *)addNode_p
                           usingDecompiler:(Decompiler *)decompiler {
    return nil;
}

// Assembler

- (NSData *)assembleRawInstruction:(NSString *)instr atAddress:(Address)addr forFile:(NSObject<HPDisassembledFile> *)file withCPUMode:(uint8_t)cpuMode usingSyntaxVariant:(NSUInteger)syntax error:(NSError **)error {
    return nil;
}

- (BOOL)instructionCanBeUsedToExtractDirectMemoryReferences:(DisasmStruct *)disasmStruct {
    return YES;
}

- (BOOL)instructionOnlyLoadsAddress:(DisasmStruct *)disasmStruct {
    return NO;
}

- (BOOL)instructionMayBeASwitchStatement:(DisasmStruct *)disasmStruct {
    return !strcmp(disasmStruct->instruction.mnemonic, "bctr");
}

@end
