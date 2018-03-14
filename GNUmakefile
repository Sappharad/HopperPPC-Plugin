include $(GNUSTEP_MAKEFILES)/common.make

COMMON_OBJC_FLAGS = -I../include -DLINUX -Wno-format -fblocks -fobjc-nonfragile-abi -fobjc-arc

BUNDLE_NAME = PPCCPU DOL_Loader

PPCCPU_OBJC_FILES = PPCCPU/PPCCPU.m PPCCPU/PPCCtx.m PPCCPU/ppcd/ppcd.m
PPCCPU_OBJCFLAGS=$(COMMON_OBJC_FLAGS)

DOL_Loader_OBJC_FILES = DOL_Loader/DOLLoader.m
DOL_Loader_OBJCFLAGS=$(COMMON_OBJC_FLAGS)

include $(GNUSTEP_MAKEFILES)/bundle.make

