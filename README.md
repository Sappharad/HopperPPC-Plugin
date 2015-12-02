# HopperPPC-Plugin
This repository contains a plugin for Hopper Disassembler which adds support for the IBM PowerPC. (Specifically the Gekko variant used on Gamecube and Wii)
The repository also contains a separate plugin called DOLLoader which loads Gamecube .DOL files.

Both plugins thrown together by Paul Kratt.

The PPC disassembly code is based on PPCD by org.
Original code: https://code.google.com/p/ppcd/
The license for that is listed as "free opensource". This is too.

The DOL loading code is original, but the file format is very simple.

#To install
1. Checkout or download this repository.
2. Open the XCode Project.
3. Build the XCode Project.

That's it. Building the project installs it into the plugins directory.

The disassembler plugin has a very basic feature set and does not integrate some hopper features like string identifcation yet. The DOL loader plugin should be mostly complete, although only Gamecube DOL's are specifically supported. Both plugins have only been tested with the OS X version of Hopper.

#Known issues
1. Some formatting / syntax might not be correct for Hopper.
2. Strings are not automatically identified.
