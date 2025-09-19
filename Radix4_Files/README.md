# Project Overview

This repository contains the implementation and testing of a **Radix-4 Booth multiplication algorithm** integrated into the NEORV32 architecture, alongside example test benches and FPGA top-level configuration.

---

## Repository Contents

| File Name                         | Description                                                                                           |
|----------------------------------|-----------------------------------------------------------------------------------------------------|
| Compiled .sof files              | Precompiled FPGA bitstreams ready for programming the target board.                                 |
| neorv32_cpu_cp_muldiv_r4booth.vhd | Working Radix-4 Booth multiplication algorithm implementation.                                      |
| neorv32_cpu_cp_muldiv.vhd        | Wrapper file for initializing and connecting the Radix-4 Booth multiplier to the NEORV32 CPU core. |
| Example.c                       | Sanity check test bench to verify multiplication correctness in all 4 cases. All tests pass.       |
| StressTestExample.c             | More comprehensive test bench with stress tests and performance measurement. Achieves 1.57× speedup. |
| Top_Entity_File.vhd              | Top-level FPGA entity, including pin configuration, clock frequency, and integration details.      |

---

## Additional Information

- The design has been validated both in simulation and on hardware with cycle benchmark results confirming correctness and speed improvement.

- This project serves as a reference for integrating efficient multiplication algorithms into RISC-V compatible cores.


