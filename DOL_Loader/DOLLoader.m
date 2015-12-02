//
//  DOLLoader.m
//  DOLLoader
//
//  Created by Paul Kratt on 11/30/2015.
//  Copyright (c) 2015.
//

#import "DOLLoader.h"

@implementation DOLLoader {
    NSObject<HPHopperServices> *_services;
}

- (instancetype)initWithHopperServices:(NSObject<HPHopperServices> *)services {
    if (self = [super init]) {
        _services = services;
    }
    return self;
}

- (HopperUUID *)pluginUUID {
    return [_services UUIDWithString:@"b1906da2-7650-4db8-91cc-d9073b17aa47"];
}

- (HopperPluginType)pluginType {
    return Plugin_Loader;
}

- (NSString *)pluginName {
    return @"Gamecube/Wii Executable";
}

- (NSString *)pluginDescription {
    return @"Dolphin Executable (DOL) Loader";
}

- (NSString *)pluginAuthor {
    return @"Paul Kratt";
}

- (NSString *)pluginCopyright {
    return @"©2015";
}

- (NSString *)pluginVersion {
    return @"0.5.0";
}

- (CPUEndianess)endianess {
    return CPUEndianess_Big;
}

- (BOOL)canLoadDebugFiles {
    return NO;
}

// Returns an array of DetectedFileType objects.
- (NSArray *)detectedTypesForData:(NSData *)data {
    if ([data length] < 0x100) return @[];

    const void *bytes = (const void *)[data bytes];
    uint32_t t0offset = OSReadBigInt32(bytes, 0);
    uint32_t t0dest = OSReadBigInt32(bytes, 0x48);
    uint32_t entryPoint = OSReadBigInt32(bytes, 0xE0);
    
    //Gamecube RAM range is 0x80000000 to 0x8C000000.
    //The Wii has more memory than that, but for the initial release I'm targeting Gamecube specs.
    
    //Text0 does not need to be at 0x100, but it always is. We're going to use it to identify this as a DOL.
    if (t0offset == 0x100 && t0dest >= 0x80000000 && t0dest <= 0x8C000000 && entryPoint >= 0x80000000 && entryPoint <= 0x8C000000) {
        NSObject<HPDetectedFileType> *type = [_services detectedType];
        [type setFileDescription:@"Gamecube/Wii Executable"];
        [type setAddressWidth:AW_32bits];
        [type setCpuFamily:@"ibm"];
        [type setCpuSubFamily:@"ppc"];
        [type setShortDescriptionString:@"gamecube_dol"];
        return @[type];
    }

    return @[];
}

- (FileLoaderLoadingStatus)loadData:(NSData *)data usingDetectedFileType:(DetectedFileType *)fileType options:(FileLoaderOptions)options forFile:(NSObject<HPDisassembledFile> *)file usingCallback:(FileLoadingCallbackInfo)callback {
    const void *bytes = (const void *)[data bytes];
    if (OSReadBigInt32(bytes, 0) != 0x100) return DIS_BadFormat;
    
    for(int i=0; i<18; i++){
        uint32_t regionStart = OSReadBigInt32(bytes, 0+(i*4));
        uint32_t regionDest = OSReadBigInt32(bytes, 0x48+(i*4));
        uint32_t regionSize = OSReadBigInt32(bytes, 0x90+(i*4));
        
        if (regionStart > 0 && regionDest > 0x80000000 && regionSize > 0) {
            NSLog(@"Create section of %d bytes at [0x%x;]", regionSize, regionDest);
            NSObject<HPSegment> *segment = [file addSegmentAt:regionDest size:regionSize];
            NSObject<HPSection> *section = [segment addSectionAt:regionDest size:regionSize];
            
            if (i<=6) {
                segment.segmentName = [NSString stringWithFormat:@"TEXT%d",i];
                section.sectionName = [NSString stringWithFormat:@"text%d",i];
                section.pureCodeSection = YES;
            }
            else{
                segment.segmentName = [NSString stringWithFormat:@"DATA%d",i-6];
                section.sectionName = [NSString stringWithFormat:@"data%d",i-6];
            }
            
            NSString *comment = [NSString stringWithFormat:@"\n\nHunk %@\n\n", segment.segmentName];
            [file setComment:comment atVirtualAddress:regionDest reason:CCReason_Automatic];
            
            NSData *segmentData = [NSData dataWithBytes:(bytes+regionStart) length:regionSize];
            segment.mappedData = segmentData;
            segment.fileOffset = regionStart;
            segment.fileLength = regionSize;
            section.fileOffset = segment.fileOffset;
            section.fileLength = segment.fileLength;
        }
    }
    
    uint32_t bssLocation = OSReadBigInt32(bytes, 0xD8);
    uint32_t bssLength = OSReadBigInt32(bytes, 0xDC);
    if(bssLocation >= 0x80000000 && bssLocation <= 0x8C000000 && bssLength > 0){
        NSObject<HPSegment> *segment = [file addSegmentAt:bssLocation size:bssLength];
        NSObject<HPSection> *section = [segment addSectionAt:bssLocation size:bssLength];
        segment.segmentName = @"BSS";
        section.sectionName = @"bss";
    }
    
    file.cpuFamily = @"ibm";
    file.cpuSubFamily = @"ppc";
    [file setAddressSpaceWidthInBits:32];

    [file addEntryPoint:OSReadBigInt32(bytes, 0xE0)];

    return DIS_OK;
}

- (void)fixupRebasedFile:(NSObject<HPDisassembledFile> *)file withSlide:(int64_t)slide originalFileData:(NSData *)fileData {
    
}

- (FileLoaderLoadingStatus)loadDebugData:(NSData *)data forFile:(NSObject<HPDisassembledFile> *)file usingCallback:(FileLoadingCallbackInfo)callback {
    return DIS_NotSupported;
}

- (NSData *)extractFromData:(NSData *)data usingDetectedFileType:(DetectedFileType *)fileType returnAdjustOffset:(uint64_t *)adjustOffset {
    return nil;
}

@end
