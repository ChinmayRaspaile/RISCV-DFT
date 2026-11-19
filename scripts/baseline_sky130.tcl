# Phase 1 baseline. Run:  LIB=<path to sky130_fd_sc_hd__tt_025C_1v80.lib> yosys -c scripts/baseline_sky130.tcl
yosys -import
set lib $::env(LIB)
read_verilog third_party/picorv32/picorv32.v
hierarchy -top picorv32
synth -top picorv32 -flatten
dfflibmap -liberty $lib
abc -liberty $lib -D 10000        ;# 10 ns target
opt_clean -purge
tee -o results/baseline_stat.txt stat -liberty $lib
write_verilog -noattr -noexpr results/picorv32_baseline.v
