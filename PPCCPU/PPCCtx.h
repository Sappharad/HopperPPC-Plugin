//
//  PPCCtx.h
//  PPCCPU
//
//  Created by copy/pasting an example on 11/06/2015.
//  Copyright (c) 2015 PK and others. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Hopper/Hopper.h>

@class PPCCPU;

@interface PPCCtx : NSObject<CPUContext>

- (instancetype)initWithCPU:(PPCCPU *)cpu andFile:(NSObject<HPDisassembledFile> *)file;

@end
