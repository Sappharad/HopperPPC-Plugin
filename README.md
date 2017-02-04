# DOL Loader
This repository contains a plugin for Hopper Disassembler called DOLLoader which loads Gamecube and Wii .DOL files. That plugin uses the PPC decompiler built into Hopper v4. When using the commit referenced below for Hopper v3, the old PPC plugin in this repository will be used instead. The DOL loader plugin should be mostly complete, although only Gamecube .DOL files have been specifically tested. Both plugins have only been tested with the macOS version of Hopper.

# HopperPPC-Plugin (Deprecated)
The repository also contains a plugin which adds support for the IBM PowerPC. (Specifically the Gekko variant used on Gamecube and Wii) That plug-in is no longer being maintained, now that Hopper officially has PPC support without the need for a plugin. If you're still using Hopper v3, you can pull commit 15794b2f65d322ffddc1f00bdad95e78be31e2bf for the last version of the code that was built against Hopper SDK v3. The disassembler plugin had a very basic feature set and does not integrate some hopper features like string identifcation.

# Acknowledgements
Both plugins originally thrown together by Paul Kratt. See commit history for other contributions.

The PPC disassembly code is based on PPCD by org.
Original code: https://code.google.com/p/ppcd/
The license for that is listed as "free opensource". This is too.

The DOL loading code is original, but the file format is very simple.

# To install
1. Checkout or download this repository into a subfolder of your Hopper SDK download. The SDK include files are referenced in the parent directory relative to the project folder.
2. Open the XCode Project.
3. Build the XCode Project.

That's it. Building the project will install it into the plugins directory.
