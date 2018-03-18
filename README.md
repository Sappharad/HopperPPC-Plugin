# DOL Loader
This repository contains a plugin for Hopper Disassembler called DOLLoader which loads Gamecube and Wii .DOL files. The plugin *does not* use Hopper's built-in PPC disassembler due to unsupported Gecko instructions. Instead, this repository also contains a full PPC plugin replacement to add Gecko functionality and some environmental awareness of the GameCube/Wii. Both plugins have been successfully tested on macOS and Linux.

![metroid prime switch statement](https://jackoalan.github.io/HopperPPC-Plugin/MetroidPrimeSwitchStatement.png "A switch statement from Metroid Prime")

# PPCCPU Plugin
The repository also contains a plugin which adds support for the Gecko variant of the IBM PowerPC 750. This CPU reports itself as `ppc32/gecko` and will only work with 32-bit PPC binaries. In addition to supporting Gecko instructions, linker-defined symbols left for the CodeWarrior C runtime are automatically discovered and used to aid in resolving SDA memory accesses via `r13` and `r2`. Sections are named according to the GameCube's common linker configuration (init, extab, text, data, rodata, sdata, sdata2, etc). The PPC plugin also performs inline stack variable printing for load/store/addi instructions relative to `r1`.

# REL Linker
The repository also contains a tool which links REL files appended to the DOL within Hopper. To use this, open one or more REL files (shipped with the DOL) using File > Load Additional Binary. You have the option to specify where in virtual memory the REL gets mapped. Hopper's default value is typically fine; but make sure it's 32-byte aligned. The other options may be left at their defaults. Next, run the linker from Tool Plugins > Link REL Segments. When this completes, you may browse the new sections using Navigate > Show Section List...

# Acknowledgements
Both plugins originally thrown together by Paul Kratt.

Forked by Jack Andersen and fleshed out with the following:
- Support for Hopper 4.3+
- Directly integrated PPCD (no second-stage parsing of instructions)
- Proper syntax-colored operands
- Instruction simplifications for `rlwinm` (slwi, clrlwi, extlwi, etc)
- Automatic comments rendering `rlwinm` as a C expression
- Automatic comments for division by constant
- Inline stack variables
- Jump table parsing and case label generation
- Section names and permissions based on the GameCube's CodeWarrior toolchain
- REL Linking
- Linux makefile

See commit history for other contributions.

The PPC disassembly code is based on PPCD by org.
Original code: https://code.google.com/p/ppcd/
The license for that is listed as "free opensource". This is too.

The DOL loading code is original, but the file format is very simple.

# macOS install
1. Checkout or download this repository into a subfolder of your Hopper SDK download so the XCode project can find the includes.
2. Open the XCode Project.
3. Build the XCode Project.
4. That's it. Building the project will install it into the plugins directory.

# Linux install
1. Checkout or download this repository into a subfolder of your Hopper SDK download.
2. Follow the instructions in "SDK Documentation.pdf" to get a GNUstep build environment established for your user.
3. Setup the GNUstep build environment for your shell by running `. "gnustep-Linux-<arch>/share/GNUstep/Makefiles/GNUstep.sh"`
4. `cd` into the HopperPPC-Plugin directory and run `make`
5. Create symlinks for Hopper to discover the bundles:
```sh
mkdir -p ~/GNUstep/Library/ApplicationSupport/Hopper/PlugIns/v4/{CPUs,Loaders,Tools}
ln -s $(pwd)/PPCCPU.bundle ~/GNUstep/Library/ApplicationSupport/Hopper/PlugIns/v4/CPUs/PPCCPU.hopperCPU
ln -s $(pwd)/DOL_Loader.bundle ~/GNUstep/Library/ApplicationSupport/Hopper/PlugIns/v4/Loaders/DOL_Loader.hopperLoader
ln -s $(pwd)/REL_Linker.bundle ~/GNUstep/Library/ApplicationSupport/Hopper/PlugIns/v4/Tools/REL_Linker.hopperTool
```
