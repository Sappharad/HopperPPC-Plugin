//
//  PPCCPU.h
//  PPCCPU
//
//  Created by copy/pasting an example on 11/06/2015.
//  Copyright (c) 2015 PK and others. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Hopper/Hopper.h>

typedef NS_ENUM(NSUInteger, PPCRegClass) {
    RegClass_AddressRegister = RegClass_FirstUserClass,
    RegClass_FPRegister,
    RegClass_PPC_Cnt
};

typedef NS_ENUM(NSUInteger, PPCIncrement) {
    INCR_NoIncrement,
    INCR_Postincrement,
    INCR_Predecrement
};

@interface PPCCPU : NSObject<CPUDefinition>

- (NSObject<HPHopperServices> *)hopperServices;

@end
