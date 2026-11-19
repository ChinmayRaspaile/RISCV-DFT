# DFT project Makefile  -  `make test` runs every simulation; `make synth` runs generic Yosys synthesis
IVL  = iverilog -g2012
RTL_MB  = rtl/sram_model.v rtl/mbist_ctrl.v rtl/mem_bist_wrap.v
RTL_LB  = rtl/lfsr32.v rtl/misr16.v rtl/cut_adder.v rtl/lbist_top.v
RTL_TOP = $(RTL_MB) rtl/jtag_tap.v rtl/dft_top.v

.PHONY: all test mbist tap lbist top synth picorv32 clean
all: test

results:
	mkdir -p results

mbist: results
	$(IVL) -o results/mbist.vvp $(RTL_MB) tb/tb_mbist.v && vvp results/mbist.vvp | grep -E "PASS|FAIL"
tap: results
	$(IVL) -o results/tap.vvp rtl/jtag_tap.v tb/tb_tap.v && vvp results/tap.vvp | grep -E "PASS|FAIL"
lbist: results
	$(IVL) -o results/lbist.vvp $(RTL_LB) tb/tb_lbist.v && vvp results/lbist.vvp
top: results
	$(IVL) -DMEM_FAULT=0 -o results/top0.vvp $(RTL_TOP) tb/tb_dft_top.v && vvp results/top0.vvp | grep -E "TEST|status"
	$(IVL) -DMEM_FAULT=2 -o results/top2.vvp $(RTL_TOP) tb/tb_dft_top.v && vvp results/top2.vvp | grep -E "TEST|status"
test: mbist tap lbist top

synth: results
	yosys -l results/synth_generic.log scripts/synth_generic.ys > /dev/null
	yosys -l results/synth_lbist.log   scripts/synth_lbist.ys   > /dev/null
	@grep -h "Number of cells" results/synth_generic.log results/synth_lbist.log

picorv32:
	git clone https://github.com/YosysHQ/picorv32.git third_party/picorv32 || true

clean:
	rm -rf results/*
