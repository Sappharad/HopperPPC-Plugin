# HopperPPC-Plugin
A plugin for Hopper Disassembler which adds support for the IBM PowerPC. (Specifically the Gekko variant used on Gamecube and Wii)
Plugin thrown together by Paul Kratt.

The PPC disassembly code is based on PPCD by org.
Original code: https://code.google.com/p/ppcd/
The license for that is listed as "free opensource". This is too.

#To install
1. Checkout or download this repository.
2. Open the XCode Project.
3. Build the XCode Project.

That's it. Building the project installs it into the plugins directory.

This is very early / incomplete at the moment and you'll need to know where procedures are to disassemble them. The initial check-in was thrown together in 3 hours. This has only been tested on the OS X version of Hopper.

#Known issues
1. You'll need to mark all of the procedures yourself.
2. Some formatting / syntax might not be correct for Hopper.
