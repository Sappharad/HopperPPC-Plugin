//
//  PPCCPU.h
//  PPCCPU
//
//  Created by copy/pasting an example on 11/06/2015.
//  Copyright (c) 2015 PK and others. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Hopper/Hopper.h>
#import "ppcd/CommonDefs.h"

@interface PPCCPU : NSObject<CPUDefinition>

- (NSObject<HPHopperServices> *)hopperServices;

@end
