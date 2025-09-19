Repository Contents
Compiled .sof files
Precompiled FPGA bitstreams that can be directly programmed onto the target board.

neorv32_cpu_cp_muldiv_r4booth.vhd
Contains the working Radix-4 Booth multiplication algorithm implementation.

neorv32_cpu_cp_muldiv.vhd
Provides the wrapper logic for initializing and connecting the Radix-4 Booth multiplication unit to the NEORV32 CPU core.

Example.c
A sanity check test bench written in C verifying multiplication results.

Tests all four multiplication cases (signed × signed, unsigned × unsigned, signed × unsigned, unsigned × signed).

All cases are passing successfully.

StressTestExample.c
An extended test bench designed for stress testing and performance measurement.

Achieves a measured speedup of 1.57× compared to baseline.

Top_Entity_File.vhd
The top-level FPGA entity file, including:

Pin mappings

Clock frequency definition

Integration with NEORV32 CPU core and the Radix-4 multiplier unit.

Notes
The Radix-4 Booth implementation has been successfully integrated and tested on hardware.

LED-based cycle benchmarks confirm correctness and speedup improvements.

This repository can serve both as a performance reference and as a template for further CPU co-processor enhancements.

