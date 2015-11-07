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
    return @"IBM PPC";
}

- (NSString *)pluginDescription {
    return @"PowerPC CPU support";
}

- (NSString *)pluginAuthor {
    return @"Paul Kratt - Based on code by org, whoever that is";
}

- (NSString *)pluginCopyright {
    return @"©2015";
}

- (NSArray *)cpuFamilies {
    return @[@"ibm"];
}

- (NSString *)pluginVersion {
    return @"0.0.1";
}

- (NSArray *)cpuSubFamiliesForFamily:(NSString *)family {
    if ([family isEqualToString:@"ibm"]) return @[@"ppc"];
    return nil;
}

- (int)addressSpaceWidthInBitsForCPUFamily:(NSString *)family andSubFamily:(NSString *)subFamily {
    if ([family isEqualToString:@"ibm"] && [subFamily isEqualToString:@"ppc"]) return 32;
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

- (NSString *)framePointerRegisterNameForFile:(NSObject<HPDisassembledFile> *)file {
    return nil;
}

- (NSUInteger)registerClassCount {
    return RegClass_PPC_Cnt;
}

- (NSUInteger)registerCountForClass:(RegClass)reg_class {
    switch (reg_class) {
        case RegClass_CPUState: return 1;
        case RegClass_PseudoRegisterSTACK: return 32;
        case RegClass_GeneralPurposeRegister: return 32;
        case RegClass_AddressRegister: return 8;
        default: break;
    }
    return 0;
}

- (BOOL)registerIndexIsStackPointer:(uint32_t)reg ofClass:(RegClass)reg_class {
    return reg_class == RegClass_AddressRegister && reg == 1;
}

- (BOOL)registerIndexIsFrameBasePointer:(uint32_t)reg ofClass:(RegClass)reg_class {
    return NO;
}

- (BOOL)registerIndexIsProgramCounter:(uint32_t)reg {
    return NO;
}

- (NSString *)registerIndexToString:(int)reg ofClass:(RegClass)reg_class withBitSize:(int)size andPosition:(DisasmPosition)position {
    switch (reg_class) {
        case RegClass_CPUState: return @"CCR";
        case RegClass_PseudoRegisterSTACK: return [NSString stringWithFormat:@"STK%d", reg];
        case RegClass_GeneralPurposeRegister: return [NSString stringWithFormat:@"d%d", reg];
        case RegClass_AddressRegister: return [NSString stringWithFormat:@"a%d", reg];
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

- (NSAttributedString *)colorizeInstructionString:(NSAttributedString *)string {
    NSMutableAttributedString *colorized = [string mutableCopy];
    [_services colorizeASMString:colorized
               operatorPredicate:^BOOL(unichar c) {
                   return (c == '#' || c == '$');
               }
           languageWordPredicate:^BOOL(NSString *s) {
               return [s isEqualToString:@"r0"] || [s isEqualToString:@"r1"] || [s isEqualToString:@"r2"] || [s isEqualToString:@"r3"]
               || [s isEqualToString:@"r4"] || [s isEqualToString:@"r5"] || [s isEqualToString:@"r6"] || [s isEqualToString:@"r7"]
               || [s isEqualToString:@"r8"] || [s isEqualToString:@"r9"] || [s isEqualToString:@"r10"] || [s isEqualToString:@"r11"]
               || [s isEqualToString:@"r12"] || [s isEqualToString:@"r13"] || [s isEqualToString:@"r14"] || [s isEqualToString:@"r15"]
               || [s isEqualToString:@"r16"] || [s isEqualToString:@"r17"] || [s isEqualToString:@"r18"] || [s isEqualToString:@"r19"]
               || [s isEqualToString:@"r20"] || [s isEqualToString:@"r21"] || [s isEqualToString:@"r22"] || [s isEqualToString:@"r23"]
               || [s isEqualToString:@"r24"] || [s isEqualToString:@"r25"] || [s isEqualToString:@"r26"] || [s isEqualToString:@"r27"]
               || [s isEqualToString:@"r28"] || [s isEqualToString:@"r29"] || [s isEqualToString:@"r30"] || [s isEqualToString:@"r31"]
               || [s isEqualToString:@"fr0"] || [s isEqualToString:@"fr1"] || [s isEqualToString:@"fr2"] || [s isEqualToString:@"fr3"]
               || [s isEqualToString:@"fr4"] || [s isEqualToString:@"fr5"] || [s isEqualToString:@"fr6"] || [s isEqualToString:@"fr7"]
               || [s isEqualToString:@"fr8"] || [s isEqualToString:@"fr9"] || [s isEqualToString:@"fr10"] || [s isEqualToString:@"fr11"]
               || [s isEqualToString:@"fr12"] || [s isEqualToString:@"fr13"] || [s isEqualToString:@"fr14"] || [s isEqualToString:@"fr15"]
               || [s isEqualToString:@"fr16"] || [s isEqualToString:@"fr17"] || [s isEqualToString:@"fr18"] || [s isEqualToString:@"fr19"]
               || [s isEqualToString:@"fr20"] || [s isEqualToString:@"fr21"] || [s isEqualToString:@"fr22"] || [s isEqualToString:@"fr23"]
               || [s isEqualToString:@"fr24"] || [s isEqualToString:@"fr25"] || [s isEqualToString:@"fr26"] || [s isEqualToString:@"fr27"]
               || [s isEqualToString:@"fr28"] || [s isEqualToString:@"fr29"] || [s isEqualToString:@"fr30"] || [s isEqualToString:@"fr31"];
           }
        subLanguageWordPredicate:^BOOL(NSString *s) {
            return NO;
        }];
    return colorized;
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
