The current folder contains the following files:
a. compiled .sof files
b. neorv32_cpu_cp_muldiv_r4booth.vhd contains the working radix4 algorithm
c. neorv32_cpu_cp_muldiv.vhd contains the wrapper for initilizing the algorithm
d. Example.c is the sanity check test bench which verifies the result. (all 4 cases are passing)
e. StressTestExample.c is a better test bench with good speedup. (1.57)
f. Top_Entity_File.vhd is the top level entity file that describes the pin config, clock freq etc.