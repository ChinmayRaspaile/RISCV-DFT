# DFT on a RISC-V Core with Open-Source EDA

Scan + ATPG (Fault), JTAG 1149.1, MBIST (March C-), LBIST (LFSR/MISR), STA and sky130 physical design.

## Status of each part (be honest about this on your resume/README)
| Part | Files | Status |
|---|---|---|
| MBIST March C- + fault-injecting SRAM | `rtl/mbist_ctrl.v`, `sram_model.v`, `mem_bist_wrap.v`, `tb/tb_mbist.v` | Simulated with Icarus 12: golden passes, SA0/SA1/TF/CFin all detected |
| JTAG TAP (IDCODE, BYPASS, SAMPLE/PRELOAD, EXTEST, MBIST instr.) | `rtl/jtag_tap.v`, `tb/tb_tap.v` | Simulated, all checks pass |
| LBIST + fault grading | `rtl/lfsr32.v`, `misr16.v`, `cut_adder.v`, `lbist_top.v`, `tb/tb_lbist.v` | Simulated; 64 stuck-at faults graded vs pattern count |
| JTAG-controlled MBIST (CDC synced) | `rtl/dft_top.v`, `tb/tb_dft_top.v` | Simulated (good + faulty RAM) |
| Generic Yosys synthesis | `scripts/synth_*.ys` | Run with Yosys 0.33 |
| Baseline sky130 synthesis, Fault scan/ATPG, OpenLane, OpenSTA | `baseline_sky130.tcl`, `fault_flow.sh`, `openlane_config.json`, `sta_scan.tcl` | **Templates, not executed.** Flags/paths may need adjusting to your tool versions |

## Step 0: Install
```bash
sudo apt install iverilog yosys gtkwave git make python3-pip
pip install cocotb                      # optional, for cocotb tests
# Physical design: OpenLane 2 (pip install openlane) or Docker; includes OpenROAD, OpenSTA, KLayout, Magic, sky130 PDK
# Fault: follow https://github.com/AUCOHL/Fault (Nix or Docker install)
```

## Step 1: Run everything that works out of the box
```bash
make test      # MBIST, TAP, LBIST, JTAG->MBIST system test
make synth     # generic Yosys synthesis + cell counts
gtkwave results/tap.vcd   # inspect waveforms (also mbist.vcd, dft_top.vcd)
```
Expected: `MBIST TEST PASSED`, `TAP TEST PASSED`, LBIST coverage table, `DFT_TOP TEST PASSED` for both MEM_FAULT=0 and 2.

## Step 2: Baseline (Phase 1)
```bash
make picorv32                                   # clones PicoRV32 into third_party/
LIB=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib \
  yosys -c scripts/baseline_sky130.tcl
cat results/baseline_stat.txt                   # area, cell count, flop count  = "before DFT"
```

## Step 3: Scan insertion + ATPG (Phases 2-3)
```bash
export LIB=...sky130_fd_sc_hd__tt_025C_1v80.lib
export CELLS=...sky130_fd_sc_hd.v               # verilog models of the std cells
NCHAINS=1 ./scripts/fault_flow.sh               # edit script flags per `fault --help`
```
Record per run: number of scan chains and length, stuck-at coverage, pattern count, and which faults were untestable and why.
Repeat with 4 and 8 chains and tabulate test time ≈ patterns × (longest chain + capture).
Alternative: OpenROAD's DFT commands (`set_dft_config`, `scan_replace`, `insert_dft`) on a netlist mapped to `sdfxtp` scan flops. Check the OpenROAD docs for your version.

Note: with `make synth`, the 64x8 RAM flattens into ~520 flops because there is no memory macro in a generic flow. In the real flow use an OpenRAM/sky130 macro or keep the RAM as a black box and test it **only** with MBIST. That separation is exactly the point of MBIST.

## Step 4: Verify and extend the RTL DFT blocks
- Change fault params in `tb/tb_mbist.v` (address/bit) and confirm detection; try a fault March C- misses (e.g. a linked coupling fault) and discuss March C+/March SS.
- Port tests to cocotb for the resume ("verified with cocotb").
- LBIST: add `make`-driven plots of `results/lbist_coverage.csv`; add an X-source and show the MISR is corrupted, then add X-masking.

## Step 5: Physical + timing (Phase 7)
```bash
openlane scripts/openlane_config.json           # copy picorv32.v into src/ first; run both baseline and scan netlists
NETLIST=<final netlist> LIB=<lib> sta -no_init -exit scripts/sta_scan.tcl
```
Report: area/power delta, setup WNS, and **hold on scan paths in shift mode** (and how you fixed it: hold buffers, lock-up latches for clock-domain crossings between chains).

## Results table (fill it with YOUR numbers)
| Metric | Before DFT | After DFT |
|---|---|---|
| Area (µm²) | | |
| Flops / scan flops | | |
| Stuck-at coverage | n/a | |
| Patterns | n/a | |
| Chains x length | n/a | |
| WNS functional / shift | | |
| MBIST detect (SA0, SA1, TF, CFin) | n/a | 4/4 (this repo) |
| LBIST coverage @16 / @1024 patterns | n/a | 100% / 100% on CUT (this repo) |

## Interview prep tied to this repo
- Why March C- is 10N and which faults it covers/misses.
- Why the TAP updates on TCK falling edge, why IR capture ends in `01`, why TDO is tri-state-enabled only in shift.
- Aliasing probability of a 16-bit MISR ≈ 2^-16; why X's kill signatures.
- Stuck-at vs transition faults; launch-on-capture vs launch-on-shift; scan-enable timing; lock-up latches; scan compression.
- Known simplifications here: boundary register has output cells only; one MBIST algorithm with solid data background; CDC uses a level + 2-flop sync (fine for static control).
