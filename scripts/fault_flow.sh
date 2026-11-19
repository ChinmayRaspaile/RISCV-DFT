#!/usr/bin/env bash
# Phases 2-3: scan insertion + stuck-at ATPG with AUCOHL/Fault.
# !! These CLI invocations are written from memory of Fault's docs and were NOT executed in the environment
# !! where this project was authored. Fault's flags change between releases: run `fault --help` and
# !! `fault <subcommand> --help` and adjust. Docs: https://github.com/AUCOHL/Fault
set -euo pipefail
LIB=${LIB:?set LIB=path/to/sky130_fd_sc_hd__tt_025C_1v80.lib}
CELLS=${CELLS:?set CELLS=path/to/sky130_fd_sc_hd.v (verilog cell models)}
TOP=picorv32
NCHAINS=${NCHAINS:-1}
mkdir -p results/fault

# 1. synthesize (Fault wraps Yosys)
fault synth -t $TOP -l $LIB -o results/fault/${TOP}.netlist.v third_party/picorv32/picorv32.v

# 2. insert scan chain(s)  (clock/reset names for picorv32: clk / resetn(active low))
fault chain --clock clk --reset resetn --activeLow -l $LIB -c $CELLS \
      -o results/fault/${TOP}.chained.v results/fault/${TOP}.netlist.v

# 3. ATPG (stuck-at), target 95% coverage
fault atpg -c $CELLS --clock clk --reset resetn --activeLow \
      -o results/fault/${TOP}.tv.json -m 95 results/fault/${TOP}.chained.v

# 4. assemble a self-checking testbench with the vectors, then simulate (Phase 3)
fault asm -o results/fault/tb.v results/fault/${TOP}.tv.json results/fault/${TOP}.chained.v
iverilog -g2012 -o results/fault/tb.vvp results/fault/tb.v results/fault/${TOP}.chained.v $CELLS
vvp results/fault/tb.vvp | tail
