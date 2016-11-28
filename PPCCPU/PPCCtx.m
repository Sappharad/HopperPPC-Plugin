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
#import "CommonDefs.h"
#import "ppcd/ppcd.h"

@implementation PPCCtx {
    PPCCPU *_cpu;
    NSObject<HPDisassembledFile> *_file;
}

- (instancetype)initWithCPU:(PPCCPU *)cpu andFile:(NSObject<HPDisassembledFile> *)file {
    if (self = [super init]) {
        _cpu = cpu;
        _file = file;
    }
    return self;
}

- (NSObject<CPUDefinition> *)cpuDefinition {
    return _cpu;
}

- (void)initDisasmStructure:(DisasmStruct *)disasm withSyntaxIndex:(NSUInteger)syntaxIndex {
    bzero(disasm, sizeof(DisasmStruct));
}

// Analysis

- (BOOL)displacementIsAnArgument:(int64_t)displacement forProcedure:(NSObject<HPProcedure> *)procedure {
    return NO;
}

- (NSUInteger)stackArgumentSlotForDisplacement:(int64_t)displacement inProcedure:(NSObject<HPProcedure> *)procedure {
    return -1;
}

- (int64_t)displacementForStackSlotIndex:(NSUInteger)slot inProcedure:(NSObject<HPProcedure> *)procedure {
    return 0;
}

- (Address)adjustCodeAddress:(Address)address {
    // Instructions are always aligned to a multiple of 2.
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
    return NO;
    // procedures usually begins with a "movem.l xxx, -(a7)" or "link" instruction
    /*uint32_t word = [_file readUInt32AtVirtualAddress:address];
    return (word == 0x48e7) || ((word & 0xFFF8) == 0x4e50);*/
}

- (NSUInteger)detectedPaddingLengthAt:(Address)address {
    NSUInteger len = 0;
    while ([_file readUInt16AtVirtualAddress:address] == 0) {
        address += 2;
        len += 2;
    }
    
    return len;
}

- (void)analysisBeginsAt:(Address)entryPoint {

}

- (void)analysisEnded {

}

- (void)procedureAnalysisBeginsForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {

}

- (void)procedureAnalysisOfPrologForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {

}

- (void)procedureAnalysisOfEpilogForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {
    
}

- (void)procedureAnalysisEndedForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {

}

- (void)procedureAnalysisContinuesOnBasicBlock:(NSObject<HPBasicBlock> *)basicBlock {

}

- (Address)getThunkDestinationForInstructionAt:(Address)address {
    return BAD_ADDRESS;
}

- (void)resetDisassembler {

}

- (uint8_t)estimateCPUModeAtVirtualAddress:(Address)address {
    return 0;
}

-(uint32_t)extractTextToNumber:(char*)opperand{
    uint32_t retval = 0;
    NSString* text = [NSString stringWithCString:opperand encoding:NSASCIIStringEncoding];
    if([text hasPrefix:@"0x"]){
        //This is Hex
        NSCharacterSet* cs = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
        NSString* hexa = [[text componentsSeparatedByCharactersInSet:[cs invertedSet]] componentsJoinedByString:@""];
        NSScanner* scanny = [NSScanner scannerWithString:hexa];
        [scanny scanHexInt:&retval];
    }
    else{
        //Just pull all of the numbers we can find and shove
        NSString* numbers = [[text componentsSeparatedByCharactersInSet:
                              [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                             componentsJoinedByString:@""];
        retval = [numbers intValue];
    }
    return retval;
}

- (uint32_t)readLongAt:(uint32_t)address {
    return [_file readUInt32AtVirtualAddress:address];
}

- (int)disassembleSingleInstruction:(DisasmStruct *)disasm usingProcessorMode:(NSUInteger)mode {
    PPCD_CB d;
    d.pc = disasm->virtualAddr;
    d.instr = [self readLongAt:(uint32_t)disasm->virtualAddr];
    PPCDisasm(&d);
    
    //printf ("%08X  %08X  %-12s%-30s\n", pc, instr, disa.mnemonic, disa.operands);
    
    if ((d.iclass & PPC_DISA_ILLEGAL) == PPC_DISA_ILLEGAL) return DISASM_UNKNOWN_OPCODE;

    disasm->instruction.branchType = DISASM_BRANCH_NONE;
    disasm->instruction.addressValue = 0;
    for (int i=0; i<DISASM_MAX_OPERANDS; i++) disasm->operand[i].type = DISASM_OPERAND_NO_OPERAND;

    // Quick and dirty split of the instruction
    char *ptr = d.mnemonic;
    char *instrPtr = disasm->instruction.mnemonic;
    while (*ptr && *ptr != ' ') *instrPtr++ = tolower(*ptr++);
    *instrPtr = 0;
    while (*ptr == ' ') ptr++;
    ptr = d.operands;

    /*int operandIndex = 0;
    char *operand = disasm->operand[operandIndex].mnemonic;
    int p_level = 0;
    while (*ptr) {
        if (*ptr == ',' && p_level == 0) {
            *operand = 0;
            operand = disasm->operand[++operandIndex].mnemonic;
            ptr++;
            while (*ptr == ' ') ptr++;
        }
        else {
            if (*ptr == '(') p_level++;
            if (*ptr == ')') p_level--;
            *operand++ = tolower(*ptr++);
        }
    }
    *operand = 0;*/

    // In this early version, only branch instructions are analyzed in order to correctly
    // construct basic blocks of procedures.
    //
    // This is the strict minimum!
    //
    // You should also fill the "operand" description for every other instruction to take
    // advantage of the various analysis of Hopper.

    if (d.iclass & PPC_DISA_BRANCH) {
        if (strncmp(disasm->instruction.mnemonic, "bl", 2) == 0) {
            disasm->instruction.branchType = DISASM_BRANCH_CALL;
            disasm->instruction.addressValue = [self extractTextToNumber:d.operands];
            disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
            disasm->operand[0].immediateValue = disasm->instruction.addressValue;
        }
        else {
            if (disasm->instruction.mnemonic[0] == 'b' && disasm->instruction.mnemonic[1]==0) {
                disasm->instruction.branchType = DISASM_BRANCH_JMP;
            }
            if (strncmp(disasm->instruction.mnemonic, "bhi", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JA;
            }
            if (strncmp(disasm->instruction.mnemonic, "bls", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JB;
            }
            if (strncmp(disasm->instruction.mnemonic, "bcc", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JNC;
            }
            if (strncmp(disasm->instruction.mnemonic, "bcs", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JC;
            }
            if (strncmp(disasm->instruction.mnemonic, "bne", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JNE;
            }
            if (strncmp(disasm->instruction.mnemonic, "beq", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JE;
            }
            if (strncmp(disasm->instruction.mnemonic, "bvc", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JNO;
            }
            if (strncmp(disasm->instruction.mnemonic, "bvs", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JO;
            }
            if (strncmp(disasm->instruction.mnemonic, "bpl", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JA;
            }
            if (strncmp(disasm->instruction.mnemonic, "bmi", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JB;
            }
            if (strncmp(disasm->instruction.mnemonic, "bge", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JNL;
            }
            if (strncmp(disasm->instruction.mnemonic, "blt", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JL;
            }
            if (strncmp(disasm->instruction.mnemonic, "bgt", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JG;
            }
            if (strncmp(disasm->instruction.mnemonic, "ble", 3) == 0) {
                disasm->instruction.branchType = DISASM_BRANCH_JNG;
            }
            disasm->instruction.addressValue = [self extractTextToNumber:d.operands];
            disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
            disasm->operand[0].immediateValue = disasm->instruction.addressValue;
        }
    }

    if (strncmp(disasm->instruction.mnemonic, "blr", 3) == 0) {
        disasm->instruction.branchType = DISASM_BRANCH_RET;
    }

    return 4; //All instructions are 4 bytes
}

- (BOOL)instructionHaltsExecutionFlow:(DisasmStruct *)disasm {
    return NO;
}

- (void)performBranchesAnalysis:(DisasmStruct *)disasm computingNextAddress:(Address *)next andBranches:(NSMutableArray *)branches forProcedure:(NSObject<HPProcedure> *)procedure basicBlock:(NSObject<HPBasicBlock> *)basicBlock ofSegment:(NSObject<HPSegment> *)segment calledAddresses:(NSMutableArray *)calledAddresses callsites:(NSMutableArray *)callSitesAddresses {

}

- (void)performInstructionSpecificAnalysis:(DisasmStruct *)disasm forProcedure:(NSObject<HPProcedure> *)procedure inSegment:(NSObject<HPSegment> *)segment {

}

- (void)performProcedureAnalysis:(NSObject<HPProcedure> *)procedure basicBlock:(NSObject<HPBasicBlock> *)basicBlock disasm:(DisasmStruct *)disasm {

}

- (void)updateProcedureAnalysis:(DisasmStruct *)disasm {

}

// Printing

- (NSString *)defaultFormattedVariableNameForDisplacement:(int64_t)displacement inProcedure:(NSObject<HPProcedure> *)procedure {
    return [NSString stringWithFormat:@"var%lld", displacement];
}

/*- (void)buildInstructionString:(DisasmStruct *)disasm forSegment:(NSObject<HPSegment> *)segment populatingInfo:(NSObject<HPFormattedInstructionInfo> *)formattedInstructionInfo {
    const char *spaces = "                ";
    strcpy(disasm->completeInstructionString, disasm->instruction.mnemonic);
    strcat(disasm->completeInstructionString, spaces + strlen(disasm->instruction.mnemonic));
    for (int i=0; i<DISASM_MAX_OPERANDS; i++) {
        if (disasm->operand[i].mnemonic[0] == 0) break;
        if (i) strcat(disasm->completeInstructionString, ", ");
        strcat(disasm->completeInstructionString, disasm->operand[i].mnemonic);
    }
}*/

- (NSObject<HPASMLine> *)buildMnemonicString:(DisasmStruct *)disasm inFile:(NSObject<HPDisassembledFile> *)file {
    NSObject<HPHopperServices> *services = _cpu.hopperServices;
    NSObject<HPASMLine> *line = [services blankASMLine];
    [line appendMnemonic:@(disasm->instruction.mnemonic)];
    return line;
}

- (NSObject<HPASMLine> *)buildOperandString:(DisasmStruct *)disasm forOperandIndex:(NSUInteger)operandIndex inFile:(NSObject<HPDisassembledFile> *)file raw:(BOOL)raw {
    if (operandIndex >= DISASM_MAX_OPERANDS) return nil;
    DisasmOperand *operand = disasm->operand + operandIndex;
    if (operand->type == DISASM_OPERAND_NO_OPERAND) return nil;
   
    NSObject<HPHopperServices> *services = _cpu.hopperServices;
    NSObject<HPASMLine> *line = [services blankASMLine];
    
    if (operand->type & DISASM_OPERAND_CONSTANT_TYPE) {
        [line appendRawString:@"#"];
        [line appendHexadecimalNumber:operand->immediateValue];
    }
    
    [line setIsOperand:operandIndex startingAtIndex:0];
    
    return line;
}

- (NSObject<HPASMLine> *)buildCompleteOperandString:(DisasmStruct *)disasm inFile:(NSObject<HPDisassembledFile> *)file raw:(BOOL)raw {
    NSObject<HPHopperServices> *services = _cpu.hopperServices;
    
    NSObject<HPASMLine> *line = [services blankASMLine];
    
    for (int op_index=0; op_index<=DISASM_MAX_OPERANDS; op_index++) {
        NSObject<HPASMLine> *part = [self buildOperandString:disasm forOperandIndex:op_index inFile:file raw:raw];
        if (part == nil) break;
        if (op_index) [line appendRawString:@", "];
        [line append:part];
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

- (BOOL)instructionMayBeASwitchStatement:(DisasmStruct *)disasmStruct {
    return NO;
}

@end
