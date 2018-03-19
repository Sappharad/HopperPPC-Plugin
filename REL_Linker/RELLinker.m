//
//  RELLinker.m
//  RELLinker
//
//  Created by Jack Andersen on 18/03/2018.
//  Copyright (c) 2018 Jack Andersen. All rights reserved.
//

#import "RELLinker.h"
#import <Hopper/HPHopperServices.h>
#import <Hopper/HPDocument.h>
#import <Hopper/HPDisassembledFile.h>
#import <Hopper/HPSegment.h>
#import <Hopper/HPSection.h>
#import <Hopper/HPProcedure.h>
#import <Hopper/HPBasicBlock.h>
#import <Hopper/HPCallReference.h>
#import <Hopper/CPUContext.h>

#ifdef __APPLE__
#define YES_CONSTANT 1000
#else
#define YES_CONSTANT 1
#endif

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
static inline int16_t _bswap16(int16_t v) {
    return __builtin_bswap16(v);
}
static inline int32_t _bswap32(int32_t v) {
    return __builtin_bswap32(v);
}
#else
static inline int16_t _bswap16(int16_t v) {
    return v;
}
static inline int32_t _bswap32(int32_t v) {
    return v;
}
#endif

struct relhdr_info
{
    uint32_t module_id;          // in .rso or .rel, not in .sel
    
    // in .rso or .rel or .sel
    uint32_t prev;
    uint32_t next;
    uint32_t num_sections;
    uint32_t section_offset;    // points to section_entry*
    uint32_t name_offset;
    uint32_t name_size;
    uint32_t version;
};

struct relhdr
{
    struct relhdr_info info;
    
    // version 1
    uint32_t bss_size;
    uint32_t rel_offset;
    uint32_t import_offset;
    uint32_t import_size;         // size in bytes
    
    // Section ids containing functions
    uint8_t prolog_section;
    uint8_t epilog_section;
    uint8_t unresolved_section;
    uint8_t bss_section;
    
    uint32_t prolog_offset;
    uint32_t epilog_offset;
    uint32_t unresolved_offset;
    
    // version 2
    uint32_t align;
    uint32_t bss_align;
    
    // version 3
    uint32_t fix_size;
};

struct rel_section_entry
{
    uint32_t file_offset;
    uint32_t size;
};

struct rel_import_entry
{
    uint32_t module_id;      // module id, maps to id in relhdr_info, 0 = base application
    uint32_t offset;
};

enum PPCRelocationType
{
    R_PPC_NONE,
    R_PPC_ADDR32,
    R_PPC_ADDR24,
    R_PPC_ADDR16,
    R_PPC_ADDR16_LO,
    R_PPC_ADDR16_HI,
    R_PPC_ADDR16_HA,
    R_PPC_ADDR14,
    R_PPC_ADDR14_BRTAKEN,
    R_PPC_ADDR14_BRNTAKEN,
    R_PPC_REL24,
    R_PPC_REL14,
    R_DOLPHIN_NOP = 201,
    R_DOLPHIN_SECTION = 202,
    R_DOLPHIN_END = 203
};

struct rel_relocation_entry
{
    uint16_t advancement;
    uint8_t type;
    uint8_t section;
    uint32_t offset;
};

@implementation RELLinker {
    NSObject<HPHopperServices> *_services;
}

- (NSArray *)toolMenuDescription {
    return @[
             @{HPM_TITLE: @"Link REL Segments",
               HPM_SELECTOR: @"linkREL:"},
             ];
}

- (void)_prelinkREL:(NSObject<HPSegment>*)segment file:(NSObject<HPDisassembledFile>*)file {
    [_services.currentDocument beginToWait:@"Pre-Linking REL"];
    const void *bytes = segment.mappedData.bytes;
    
    // Initial metadata
    segment.readable = YES;
    segment.writable = YES;
    segment.executable = YES;
    const struct relhdr *header = bytes;
    uint32_t moduleId = _bswap32(header->info.module_id);
    uint32_t version = _bswap32(header->info.version);
    uint32_t bssAlign = 32;
    if (version >= 2)
        bssAlign = _bswap32(header->bss_align);
    uint32_t bssSize = _bswap32(header->bss_size);
    segment.segmentName = [NSString stringWithFormat:@"REL%u", moduleId];

    // BSS starts here
    NSUInteger bssStart = (file.lastSegment.endAddress + bssAlign - 1) / bssAlign * bssAlign;

    // Advertize REL sections to Hopper
    const struct rel_section_entry *sections = bytes + _bswap32(header->info.section_offset);
    uint32_t numSections = _bswap32(header->info.num_sections);
    for (int i = 0; i < numSections; ++i) {
        const struct rel_section_entry *section = &sections[i];
        uint32_t fileOffset = _bswap32(section->file_offset);
        uint32_t sectionSize = _bswap32(section->size);
        if (fileOffset == 0 && sectionSize == bssSize) {
            if (bssSize == 0)
                continue;
            NSObject<HPSegment> *seg = [file addSegmentAt:bssStart size:bssSize];
            seg.readable = YES;
            seg.writable = YES;
            seg.executable = NO;
            [seg setMappedData:[NSMutableData dataWithLength:bssSize]];
            seg.segmentName = [NSString stringWithFormat:@"BSS%u", moduleId];
            NSObject<HPSection> *sec = [seg addSectionAt:bssStart size:bssSize];
            sec.sectionName = [NSString stringWithFormat:@"bss%u", moduleId];
            sec.zeroFillSection = YES;
        } else if (sectionSize != 0) {
            NSObject<HPSection> *sec = [segment addSectionAt:segment.startAddress + (fileOffset & 0xfffffffe) size:sectionSize];
            if (fileOffset & 0x1) {
                sec.pureCodeSection = YES;
                sec.containsCode = YES;
                sec.sectionName = [NSString stringWithFormat:@"text%u_%u", moduleId, i];
            } else {
                sec.pureDataSection = YES;
                sec.sectionName = [NSString stringWithFormat:@"data%u_%u", moduleId, i];
            }
        }
    }
    
    [_services.currentDocument endWaiting];
}

- (void)recursiveMakeProcedures:(NSObject<HPProcedure>*)proc file:(NSObject<HPDisassembledFile>*)file {
    if (!proc)
        return;
    NSArray<HPCallReference> *callees = [proc.allCallees copy];
    for (NSObject<HPCallReference> *cref in callees) {
        if (![file hasProcedureAt:cref.to])
            [self recursiveMakeProcedures:[file makeProcedureAt:cref.to] file:file];
    }
}

- (void)_linkREL:(NSObject<HPSegment>*)segment file:(NSObject<HPDisassembledFile>*)file {
    [_services.currentDocument beginToWait:@"Linking REL"];
    NSMutableData* mutable = [segment.mappedData mutableCopy];
    void *bytes = mutable.mutableBytes;
    
    // Initial metadata
    const struct relhdr *header = bytes;
    uint32_t moduleId = _bswap32(header->info.module_id);
    uint32_t version = _bswap32(header->info.version);
    uint32_t bssAlign = 32;
    if (version >= 2)
        bssAlign = _bswap32(header->bss_align);
    uint32_t bssSize = _bswap32(header->bss_size);
    
    // Advertize REL sections to Hopper
    const struct rel_section_entry *sections = bytes + _bswap32(header->info.section_offset);
    uint32_t numSections = _bswap32(header->info.num_sections);
    NSMutableArray *textSections = [NSMutableArray arrayWithCapacity:4];
    NSMutableArray *dataSections = [NSMutableArray arrayWithCapacity:8];
    for (int i = 0; i < numSections; ++i) {
        const struct rel_section_entry *section = &sections[i];
        uint32_t fileOffset = _bswap32(section->file_offset);
        uint32_t sectionSize = _bswap32(section->size);
        if (fileOffset == 0 && sectionSize == bssSize) {
        } else if (sectionSize != 0) {
            NSObject<HPSection> *sec = [file sectionForVirtualAddress:segment.startAddress + (fileOffset & 0xfffffffe)];
            if (fileOffset & 0x1)
                [textSections addObject:sec];
            else
                [dataSections addObject:sec];
        }
    }
    
    // Enumerate imports and relocations
    const struct rel_import_entry *imports = bytes + _bswap32(header->import_offset);
    uint32_t numImports = _bswap32(header->import_size) / 8;
    for (int i = 0; i < numImports; ++i) {
        const struct rel_import_entry *import = &imports[i];
        uint32_t moduleId = _bswap32(import->module_id);
        NSObject<HPSegment> *moduleSeg = nil;
        NSObject<HPSegment> *moduleBss = nil;
        const struct rel_section_entry *moduleSections = NULL;
        if (moduleId) {
            moduleSeg = [file segmentNamed:[NSString stringWithFormat:@"REL%u", moduleId]];
            moduleBss = [file segmentNamed:[NSString stringWithFormat:@"BSS%u", moduleId]];
            if (moduleSeg) {
                const void *moduleBytes = moduleSeg.mappedData.bytes;
                const struct relhdr *moduleHeader = moduleBytes;
                moduleSections = moduleBytes + _bswap32(moduleHeader->info.section_offset);
            }
        }
        const struct rel_relocation_entry *relocation = bytes + _bswap32(import->offset);
        void *codePtr = NULL;
        for (bool done = false; !done; ++relocation) {
            uint16_t advancement = _bswap16(relocation->advancement);
            uint32_t offset = _bswap32(relocation->offset);
            if (moduleSeg) {
                const struct rel_section_entry *modSec = &moduleSections[relocation->section];
                uint32_t fileOffset = _bswap32(modSec->file_offset);
                if (!fileOffset)
                    offset += moduleBss.startAddress;
                else
                    offset += moduleSeg.startAddress + (fileOffset & 0xfffffffe);
            }
            codePtr += advancement;
            Address thisAddr = segment.startAddress + (codePtr - bytes);
            [[_services currentDocument] logInfoMessage:[NSString stringWithFormat:@"RELOC %08X %d %08X", (uint32_t)thisAddr, relocation->type, offset]];
            switch (relocation->type) {
            default:
                break;
            case R_PPC_ADDR32:
                *(uint32_t*)codePtr = _bswap32(offset);
                break;
            case R_PPC_ADDR24: {
                uint32_t inst = _bswap32(*(uint32_t*)codePtr);
                inst &= 0xFC000003;
                inst |= offset & 0x3FFFFFC;
                *(uint32_t*)codePtr = _bswap32(inst);
                break;
            }
            case R_PPC_ADDR16:
                *(uint16_t*)codePtr = _bswap16((uint16_t)offset);
                break;
            case R_PPC_ADDR16_LO:
                *(uint16_t*)codePtr = _bswap16((uint16_t)offset);
                break;
            case R_PPC_ADDR16_HI:
                *(uint16_t*)codePtr = _bswap16((uint16_t)(offset >> 16));
                break;
            case R_PPC_ADDR16_HA:
                if (offset & 0x8000)
                    *(uint16_t*)codePtr = _bswap16((uint16_t)((offset >> 16) + 1));
                else
                    *(uint16_t*)codePtr = _bswap16((uint16_t)(offset >> 16));
                break;
            case R_PPC_ADDR14: {
                uint32_t inst = _bswap32(*(uint32_t*)codePtr);
                inst &= 0xFFFF0003;
                inst |= offset & 0xFFFC;
                *(uint32_t*)codePtr = _bswap32(inst);
                break;
            }
            case R_PPC_ADDR14_BRTAKEN: {
                uint32_t inst = _bswap32(*(uint32_t*)codePtr);
                inst &= 0xFFDF0003;
                inst |= (offset & 0xFFFC) | 0x200000;
                *(uint32_t*)codePtr = _bswap32(inst);
                break;
            }
            case R_PPC_ADDR14_BRNTAKEN: {
                uint32_t inst = _bswap32(*(uint32_t*)codePtr);
                inst &= 0xFFDF0003;
                inst |= offset & 0xFFFC;
                *(uint32_t*)codePtr = _bswap32(inst);
                break;
            }
            case R_PPC_REL24: {
                uint32_t inst = _bswap32(*(uint32_t*)codePtr);
                inst &= 0xFC000003;
                inst |= ((int64_t)offset - (int64_t)thisAddr) & 0x3FFFFFC;
                *(uint32_t*)codePtr = _bswap32(inst);
                break;
            }
            case R_PPC_REL14: {
                uint32_t inst = _bswap32(*(uint32_t*)codePtr);
                inst &= 0xFFFF0003;
                inst |= ((int64_t)offset - (int64_t)thisAddr) & 0xFFFC;
                *(uint32_t*)codePtr = _bswap32(inst);
                break;
            }
            case R_DOLPHIN_SECTION: {
                const struct rel_section_entry *section = &sections[relocation->section];
                uint32_t fileOffset = _bswap32(section->file_offset);
                codePtr = bytes + (fileOffset & 0xfffffffe);
                break;
            }
            case R_DOLPHIN_END:
                done = true;
                break;
            }
        }
    }
    
    // Apply relocated data
    [segment setMappedData:mutable];
    
    // Prolog
    if (header->prolog_section) {
        NSObject<HPSection> *sec = [file sectionNamed:
            [NSString stringWithFormat:@"text%u_%u", moduleId, header->prolog_section]];
        if (sec) {
            uint32_t offset = _bswap32(header->prolog_offset);
            Address addr = sec.startAddress + offset;
            [self recursiveMakeProcedures:[file makeProcedureAt:addr] file:file];
            [file setName:[NSString stringWithFormat:@"_prolog%u", moduleId] forVirtualAddress:addr
                   reason:NCReason_Import];
        }
    }
    
    // Epilog
    if (header->epilog_section) {
        NSObject<HPSection> *sec = [file sectionNamed:
                                    [NSString stringWithFormat:@"text%u_%u", moduleId, header->epilog_section]];
        if (sec) {
            uint32_t offset = _bswap32(header->epilog_offset);
            Address addr = sec.startAddress + offset;
            [self recursiveMakeProcedures:[file makeProcedureAt:addr] file:file];
            [file setName:[NSString stringWithFormat:@"_epilog%u", moduleId] forVirtualAddress:addr
                   reason:NCReason_Import];
        }
    }
    
    // Unresolved
    if (header->unresolved_section) {
        NSObject<HPSection> *sec = [file sectionNamed:
                                    [NSString stringWithFormat:@"text%u_%u", moduleId, header->unresolved_section]];
        if (sec) {
            uint32_t offset = _bswap32(header->unresolved_offset);
            Address addr = sec.startAddress + offset;
            [self recursiveMakeProcedures:[file makeProcedureAt:addr] file:file];
            [file setName:[NSString stringWithFormat:@"_unresolved%u", moduleId] forVirtualAddress:addr
                   reason:NCReason_Import];
        }
    }
    
    // Analyze text sections
    NSObject<CPUContext> *context = [file buildCPUContext];
    for (NSObject<HPSection> *sec in textSections) {
        for (Address addr = sec.startAddress; addr < sec.endAddress;) {
            NSUInteger padding = [context detectedPaddingLengthAt:addr];
            if (padding) {
                [file setType:Type_Align atVirtualAddress:addr forLength:padding];
                addr += padding;
            }
            if (![file hasProcedureAt:addr])
                [self recursiveMakeProcedures:[file makeProcedureAt:addr] file:file];
            addr += 4;
        }
    }
    
    // Analyze data sections
    for (NSObject<HPSection> *sec in dataSections) {
        for (uint64_t offset = 0; offset < sec.fileLength; offset += 4) {
            uint32_t data = _bswap32(*(uint32_t*)(bytes + sec.fileOffset + offset));
            if (data >= 0x80000000 && data <= 0x8C000000) {
                Address addr = sec.startAddress + offset;
                [file setType:Type_Int32 atVirtualAddress:addr forLength:4];
                [file setFormat:Format_Address forArgument:0 atVirtualAddress:addr];
                [segment addReferencesToAddress:data fromAddress:addr];
            }
        }
    }
    
    [_services.currentDocument endWaiting];
}

- (void)linkREL:(id)sender {
    NSObject<HPDocument> *doc = [_services currentDocument];
    NSMutableArray<HPSegment> *linkedSegments = [NSMutableArray<HPSegment> new];
    bool found = false;
    for (NSObject<HPSegment> *seg in doc.disassembledFile.segments) {
        if ([seg.segmentName isEqualToString:@"unnamed segment"]) {
            const void *bytes = seg.mappedData.bytes;
            const struct relhdr *header = bytes;
            uint32_t module_id = _bswap32(header->info.module_id);
            if (module_id == 0 || _bswap32(header->info.prev) != 0 || _bswap32(header->info.next) != 0)
                continue;
            uint32_t version = _bswap32(header->info.version);
            if (version != 1 && version != 2 && version != 3)
                continue;
            
            uint32_t sectionInfoOff = _bswap32(header->info.section_offset);
            uint32_t importTableOff = _bswap32(header->import_offset);
            if (sectionInfoOff >= seg.mappedData.length || importTableOff >= seg.mappedData.length)
                continue;
            
            // Valid REL
            NSInteger result = [doc displayAlertWithMessageText:@"Detected REL"
                                                  defaultButton:@"Yes"
                                                alternateButton:@"No"
                                                    otherButton:nil
                                                informativeText:
                                [NSString stringWithFormat:@"Found REL data at 0x%" PRIX64 ". Link?", seg.startAddress]];
            found = true;
            if (result == YES_CONSTANT)
                [linkedSegments addObject:seg];
        }
    }

    if (!found) {
        [doc displayAlertWithMessageText:@"Unnamed REL segment not detected"
                           defaultButton:@"OK"
                         alternateButton:nil
                             otherButton:nil
                         informativeText:@"Unable to find \"unnamed segment\" containing REL data"];
        return;
    }

    for (NSObject<HPSegment> *seg in linkedSegments) {
        // First pass creates Hopper sections
        [self _prelinkREL:seg file:doc.disassembledFile];
    }
    
    for (NSObject<HPSegment> *seg in linkedSegments) {
        // Second pass resolves relocations from all candidate REL modules
        [self _linkREL:seg file:doc.disassembledFile];
    }
}

- (instancetype)initWithHopperServices:(NSObject <HPHopperServices> *)services {
    if (self = [super init]) {
        _services = services;
    }
    return self;
}

- (HopperUUID *)pluginUUID {
    return [_services UUIDWithString:@"42056020-EB6F-469F-8E78-425CC767B145"];
}

- (HopperPluginType)pluginType {
    return Plugin_Tool;
}

- (NSString *)pluginName {
    return @"RELLinker";
}

- (NSString *)pluginDescription {
    return @"REL Linker";
}

- (NSString *)pluginAuthor {
    return @"Jack Andersen";
}

- (NSString *)pluginCopyright {
    return @"©2018 - Jack Andersen";
}

- (NSString *)pluginVersion {
    return @"0.0.1";
}

@end
