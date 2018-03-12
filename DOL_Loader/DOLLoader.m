//
//  DOLLoader.m
//  DOLLoader
//
//  Created by Paul Kratt on 11/30/2015.
//  Copyright (c) 2015.
//

#import "DOLLoader.h"

#ifdef LINUX
#include <endian.h>

int16_t OSReadBigInt16(const void *address, uintptr_t offset) {
    return be16toh(*(int16_t *) ((uintptr_t) address + offset));
}

int32_t OSReadBigInt32(const void *address, uintptr_t offset) {
    return be32toh(*(int32_t *) ((uintptr_t) address + offset));
}

void OSWriteBigInt32(void *address, uintptr_t offset, int32_t data) {
    *(int32_t *) ((uintptr_t) address + offset) = htobe32(data);
}

#endif

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
    return @"Paul Kratt and Jack Andersen";
}

- (NSString *)pluginCopyright {
    return @"©2018";
}

- (NSString *)pluginVersion {
    return @"0.6.0";
}

- (CPUEndianess)endianess {
    return CPUEndianess_Big;
}

- (BOOL)canLoadDebugFiles {
    return YES;
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
        [type setCpuFamily:@"ppc32"];
        [type setCpuSubFamily:@"gecko"];
        [type setShortDescriptionString:@"gamecube_dol"];
        return @[type];
    }

    return @[];
}

struct SectionRange
{
    uint32_t start;
    uint32_t length;
    uint32_t idx;
};

static int SectionSort(const void* e1, const void* e2)
{
    return ((const struct SectionRange*)e1)->start - ((const struct SectionRange*)e2)->start;
}

static const struct SectionRange* FindSectionRange(const struct SectionRange* ranges, uint32_t idx)
{
    for(int i=0; i<19; i++){
        if (ranges[i].idx == idx)
            return &ranges[i];
    }
    return NULL;
}

- (FileLoaderLoadingStatus)loadData:(NSData *)data usingDetectedFileType:(NSObject<HPDetectedFileType> *)fileType options:(FileLoaderOptions)options forFile:(NSObject<HPDisassembledFile> *)file usingCallback:(FileLoadingCallbackInfo)callback {
    const void *bytes = (const void *)[data bytes];
    if (OSReadBigInt32(bytes, 0) != 0x100) return DIS_BadFormat;
    
    /* Sort section ranges by memory offset and clamp lengths to avoid overlap */
    struct SectionRange sections[19];
    for(int i=0; i<18; i++){
        sections[i].start = OSReadBigInt32(bytes, 0x48+(i*4));
        sections[i].length = OSReadBigInt32(bytes, 0x90+(i*4));
        if (!sections[i].start) {
            sections[i].start = 0xffffffff;
            sections[i].length = 0xffffffff;
        }
        sections[i].idx = i;
    }
    uint32_t bssLocation = OSReadBigInt32(bytes, 0xD8);
    uint32_t bssLength = OSReadBigInt32(bytes, 0xDC);
    sections[18].start = bssLocation;
    sections[18].length = bssLength;
    if (!sections[18].start) {
        sections[18].start = 0xffffffff;
        sections[18].length = 0xffffffff;
    }
    sections[18].idx = 18;
    qsort(sections, 19, sizeof(struct SectionRange), SectionSort);
    int secCount = 0;
    for (int i=0; i<18; i++){
        if (sections[i].start == 0xffffffff)
            break;
        if (sections[i].start + sections[i].length > sections[i+1].start)
            sections[i].length = sections[i+1].start - sections[i].start;
        ++secCount;
    }
    
    /* Create sections */
    int lastData = 0;
    int lastData2 = 0;
    for(int i=0; i<18; i++){
        const struct SectionRange* range = FindSectionRange(sections, i);
        uint32_t regionStart = OSReadBigInt32(bytes, 0+(i*4));
        uint32_t regionDest = range->start;
        uint32_t regionSize = range->length;
        
        if (regionStart > 0 && regionDest > 0x80000000 && regionSize > 0) {
            NSObject<HPSegment> *segment = [file addSegmentAt:regionDest size:regionSize];
            NSObject<HPSection> *section = [segment addSectionAt:regionDest size:regionSize];
            
            if (i<=6) {
                section.pureCodeSection = YES;
                section.containsCode = YES;
                segment.readable = YES;
                segment.writable = NO;
                segment.executable = YES;
                if (secCount == 11) {
                    if (i == 0) {
                        segment.segmentName = @"INIT";
                        section.sectionName = @"init";
                    } else if (i == 1) {
                        segment.segmentName = @"TEXT";
                        section.sectionName = @"text";
                    } else {
                        segment.segmentName = [NSString stringWithFormat:@"TEXT%d",i];
                        section.sectionName = [NSString stringWithFormat:@"text%d",i];
                    }
                } else {
                    segment.segmentName = [NSString stringWithFormat:@"TEXT%d",i];
                    section.sectionName = [NSString stringWithFormat:@"text%d",i];
                }
            }
            else{
                section.pureDataSection = YES;
                segment.readable = YES;
                segment.writable = NO;
                segment.executable = NO;
                if (secCount == 11) {
                    if (i == 7) {
                        segment.segmentName = @"EXTAB";
                        section.sectionName = @"extab";
                    } else if (i == 8) {
                        segment.segmentName = @"EXTABINDEX";
                        section.sectionName = @"extabindex";
                    } else if (i == 9) {
                        segment.segmentName = @"CTORS";
                        section.sectionName = @"ctors";
                    } else if (i == 10) {
                        segment.segmentName = @"DTORS";
                        section.sectionName = @"dtors";
                    } else if (i == 11) {
                        segment.segmentName = @"RODATA";
                        section.sectionName = @"rodata";
                    } else if (i == 12) {
                        segment.segmentName = @"DATA";
                        section.sectionName = @"data";
                        segment.writable = YES;
                    } else if (i == 13) {
                        segment.segmentName = @"SDATA";
                        section.sectionName = @"sdata";
                        segment.writable = YES;
                    } else if (i == 14) {
                        segment.segmentName = @"SDATA2";
                        section.sectionName = @"sdata2";
                    } else {
                        segment.segmentName = [NSString stringWithFormat:@"DATA%d",i-6];
                        section.sectionName = [NSString stringWithFormat:@"data%d",i-6];
                    }
                } else {
                    segment.segmentName = [NSString stringWithFormat:@"DATA%d",i-6];
                    section.sectionName = [NSString stringWithFormat:@"data%d",i-6];
                }
                lastData2 = lastData;
                lastData = i;
            }
            NSLog(@"Create section %@ of %d bytes at [0x%x;] from 0x%x",
                  section.sectionName, regionSize, regionDest, regionStart);

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
    
    /* Create SBSS section */
    const struct SectionRange* range = FindSectionRange(sections, 18);
    bssLocation = range->start;
    bssLength = range->length;
    if(bssLocation >= 0x80000000 && bssLocation <= 0x8C000000 && bssLength > 0){
        NSObject<HPSegment> *segment = [file addSegmentAt:bssLocation size:bssLength];
        NSObject<HPSection> *section = [segment addSectionAt:bssLocation size:bssLength];
        segment.segmentName = @"BSS";
        section.sectionName = @"bss";
        section.pureDataSection = YES;
        section.zeroFillSection = YES;
        segment.readable = YES;
        segment.writable = YES;
        segment.executable = NO;
        NSLog(@"Create section %@ of %d bytes at [0x%x;]",
              section.sectionName, bssLength, bssLocation);
    }
    
    /* Detect hidden SBSS section */
    if (lastData && lastData2) {
        const struct SectionRange* range1 = FindSectionRange(sections, lastData2);
        const struct SectionRange* range2 = FindSectionRange(sections, lastData);
        /* Gap between contiguous small data sections */
        if (range2 - range1 == 1 && range1->start + range1->length < range2->start) {
            uint32_t sbssLocation = range1->start + range1->length;
            uint32_t sbssLength = range2->start - sbssLocation;
            NSObject<HPSegment> *segment = [file addSegmentAt:sbssLocation size:sbssLength];
            NSObject<HPSection> *section = [segment addSectionAt:sbssLocation size:sbssLength];
            segment.segmentName = @"SBSS";
            section.sectionName = @"sbss";
            section.pureDataSection = YES;
            section.zeroFillSection = YES;
            segment.readable = YES;
            segment.writable = YES;
            segment.executable = NO;
            NSLog(@"Create section %@ of %d bytes at [0x%x;]",
                  section.sectionName, bssLength, bssLocation);
        }
    }
    
    file.cpuFamily = @"ppc32";
    file.cpuSubFamily = @"gecko";
    [file setAddressSpaceWidthInBits:32];

    uint32_t entryPoint = OSReadBigInt32(bytes, 0xE0);
    [file addEntryPoint:entryPoint];

    return DIS_OK;
}

- (void)fixupRebasedFile:(NSObject<HPDisassembledFile> *)file withSlide:(int64_t)slide originalFileData:(NSData *)fileData {
    
}

- (FileLoaderLoadingStatus)loadDebugData:(NSData *)data forFile:(NSObject<HPDisassembledFile> *)file usingCallback:(FileLoadingCallbackInfo)callback {
    return DIS_NotSupported;
}

- (NSData *)extractFromData:(NSData *)data usingDetectedFileType:(NSObject<HPDetectedFileType> *)fileType returnAdjustOffset:(uint64_t *)adjustOffset {
    return nil;
}

@end
