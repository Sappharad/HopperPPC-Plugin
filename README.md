# HopperPPC-Plugin (Deprecated)
This repository contains a plugin for Hopper Disassembler which adds support for the IBM PowerPC. (Specifically the Gekko variant used on Gamecube and Wii) That plug-in is no longer being maintained, now that Hopper officially has PPC support without the need for a plug-in. If you're still using Hopper v3, you can check out commit 15794b2f65d322ffddc1f00bdad95e78be31e2bf for the last version of the code that was built against Hopper v3. The disassembler plugin had a very basic feature set and does not integrate some hopper features like string identifcation.

# DOL Loader
The repository also contains a separate plugin called DOLLoader which loads Gamecube .DOL files. That plug-in now uses the PPC decompiler built into Hopper v4. When using the commit referenced above for Hopper v3, the old PPC plug-in in this repository will be used. The DOL loader plugin should be mostly complete, although only Gamecube DOL's are specifically tested. Both plugins have only been tested with the macOS version of Hopper.

# Acknowledgements
Both plugins originally thrown together by Paul Kratt. See commit history for other contributions.

The PPC disassembly code is based on PPCD by org.
Original code: https://code.google.com/p/ppcd/
The license for that is listed as "free opensource". This is too.

The DOL loading code is original, but the file format is very simple.

#To install
1. Checkout or download this repository.
2. Open the XCode Project.
3. Build the XCode Project.

That's it. Building the project installs it into the plugins directory.
