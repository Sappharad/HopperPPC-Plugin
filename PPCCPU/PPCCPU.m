//
//  PPCCPU.m
//  PPCCPU
//
//  Created by copy/pasting an example on 11/06/2015.
//  Copyright (c) 2015 PK and others. All rights reserved.
//

#import "PPCCPU.h"
#import "PPCCtx.h"

@implementation PPCCPU {
    NSObject<HPHopperServices> *_services;
}

- (instancetype)initWithHopperServices:(NSObject<HPHopperServices> *)services {
    if (self = [super init]) {
        _services = services;
    }
    return self;
}

- (NSObject<HPHopperServices> *)hopperServices {
    return _services;
}

- (Class)cpuContextClass {
    return [PPCCtx class];
}

- (NSObject<CPUContext> *)buildCPUContextForFile:(NSObject<HPDisassembledFile> *)file {
    return [[PPCCtx alloc] initWithCPU:self andFile:file];
}

- (HopperUUID *)pluginUUID {
    return [_services UUIDWithString:@"b9d7440a-2ad6-465b-a1e7-8696cf571a69"];
}

- (HopperPluginType)pluginType {
    return Plugin_CPU;
}

- (NSString *)pluginName {
    return @"PowerPC Gecko";
}

- (NSString *)pluginDescription {
    return @"PowerPC Gecko CPU support";
}

- (NSString *)pluginAuthor {
    return @"Paul Kratt and Jack Andersen - Based on code by org, whoever that is";
}

- (NSString *)pluginCopyright {
    return @"©2018";
}

- (NSArray *)cpuFamilies {
    return @[@"ppc32"];
}

- (NSString *)pluginVersion {
    return @"0.0.2";
}

- (NSArray *)cpuSubFamiliesForFamily:(NSString *)family {
    if ([family isEqualToString:@"ppc32"]) return @[@"gecko"];
    return nil;
}

- (int)addressSpaceWidthInBitsForCPUFamily:(NSString *)family andSubFamily:(NSString *)subFamily {
    if ([family isEqualToString:@"ppc32"] && [subFamily isEqualToString:@"gecko"]) return 32;
    return 0;
}

- (CPUEndianess)endianess {
    return CPUEndianess_Big;
}

- (NSUInteger)syntaxVariantCount {
    return 1;
}

- (NSUInteger)cpuModeCount {
    return 1;
}

- (NSArray *)syntaxVariantNames {
    return @[@"generic"];
}

- (NSArray *)cpuModeNames {
    return @[@"generic"];
}

- (NSString *)framePointerRegisterNameForFile:(NSObject<HPDisassembledFile>*)file cpuMode:(uint8_t)cpuMode {
    return nil;
}

- (NSUInteger)registerClassCount {
    return RegClass_PPC_Cnt;
}

- (NSUInteger)registerCountForClass:(RegClass)reg_class {
    switch (reg_class) {
        case RegClass_CPUState: return 1;
        case RegClass_GeneralPurposeRegister: return 32;
        case RegClass_FPRegister: return 32;
        case RegClass_PPC_Cnt: return 1;
        case RegClass_PPC_CondReg: return 8;
        default: break;
    }
    return 0;
}

- (BOOL)registerIndexIsStackPointer:(NSUInteger)reg ofClass:(RegClass)reg_class cpuMode:(uint8_t)cpuMode file:(NSObject<HPDisassembledFile> *)file {
    return reg_class == RegClass_GeneralPurposeRegister && reg == 1;
}

- (BOOL)registerIndexIsFrameBasePointer:(NSUInteger)reg ofClass:(RegClass)reg_class cpuMode:(uint8_t)cpuMode file:(NSObject<HPDisassembledFile> *)file {
    return NO;
}

- (BOOL)registerIndexIsProgramCounter:(NSUInteger)reg cpuMode:(uint8_t)cpuMode file:(NSObject<HPDisassembledFile> *)file {
    return NO;
}

- (BOOL)registerHasSideEffectForIndex:(NSUInteger)reg andClass:(RegClass)reg_class {
    return NO;
}

- (NSString *)registerIndexToString:(NSUInteger)reg ofClass:(RegClass)reg_class withBitSize:(NSUInteger)size position:(DisasmPosition)position andSyntaxIndex:(NSUInteger)syntaxIndex {
    switch (reg_class) {
        case RegClass_CPUState: return @"CCR";
        case RegClass_GeneralPurposeRegister: return [NSString stringWithFormat:@"r%lu", (unsigned long)reg];
        case RegClass_FPRegister: return [NSString stringWithFormat:@"f%lu", (unsigned long)reg];
        case RegClass_PPC_Cnt: return @"count";
        case RegClass_PPC_CondReg: return [NSString stringWithFormat:@"cr%lu", (unsigned long)reg];
        default: break;
    }
    return nil;
}

- (NSString *)cpuRegisterStateMaskToString:(uint32_t)cpuState {
    return @"";
}

- (NSUInteger)translateOperandIndex:(NSUInteger)index operandCount:(NSUInteger)count accordingToSyntax:(uint8_t)syntaxIndex {
    return index;
}

- (NSData *)nopWithSize:(NSUInteger)size andMode:(NSUInteger)cpuMode forFile:(NSObject<HPDisassembledFile> *)file {
    // Instruction size is always a multiple of 4
    if (size & 3) return nil;
    NSMutableData *nopArray = [[NSMutableData alloc] initWithCapacity:size];
    [nopArray setLength:size];
    uint16_t *ptr = (uint16_t *)[nopArray mutableBytes];
    for (NSUInteger i=0; i<size; i+=4) {
        OSWriteBigInt32(ptr, i, 0x60000000);
    }
    return [NSData dataWithData:nopArray];
}

- (BOOL)canAssembleInstructionsForCPUFamily:(NSString *)family andSubFamily:(NSString *)subFamily {
    return NO;
}

- (BOOL)canDecompileProceduresForCPUFamily:(NSString *)family andSubFamily:(NSString *)subFamily {
    return NO;
}

@end
