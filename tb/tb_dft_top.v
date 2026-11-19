`timescale 1ns/1ps
// System-level: run MBIST entirely through JTAG, read status back. Compile with -DMEM_FAULT=0 (good) or 2 (bad)
module tb_dft_top;
  reg clk = 0, rst_n = 0, tck = 0, tms = 1, tdi = 0, trst_n = 0;
  wire tdo, tdo_en; wire [7:0] pad;
  always #5 clk = ~clk;

  dft_top dut(.clk(clk), .rst_n(rst_n), .tck(tck), .tms(tms), .tdi(tdi), .trst_n(trst_n), .tdo(tdo), .tdo_en(tdo_en),
              .func_en(1'b0), .func_we(1'b0), .func_addr(6'd0), .func_wdata(8'd0), .pad_rdata(pad));

  task clk_tck(input t_ms, input t_di); begin tms = t_ms; tdi = t_di; #40 tck = 1; #40 tck = 0; #1; end endtask
  task tap_reset; integer i; begin for (i = 0; i < 6; i = i + 1) clk_tck(1,0); clk_tck(0,0); end endtask
  task shift_ir(input [3:0] v); integer i; begin
    clk_tck(1,0); clk_tck(1,0); clk_tck(0,0); clk_tck(0,0);
    for (i = 0; i < 4; i = i + 1) clk_tck(i == 3, v[i]);
    clk_tck(1,0); clk_tck(0,0); end endtask
  reg [7:0] rd;
  task shift_dr(input integer n, input [7:0] w); integer i; begin
    rd = 0; clk_tck(1,0); clk_tck(0,0); clk_tck(0,0);
    for (i = 0; i < n; i = i + 1) begin rd[i] = tdo; clk_tck(i == n-1, w[i]); end
    clk_tck(1,0); clk_tck(0,0); end endtask

  initial begin
    $dumpfile("results/dft_top.vcd"); $dumpvars(0, tb_dft_top);
    #100 rst_n = 1; trst_n = 1;
    tap_reset;
    shift_ir(4'h4);                 // MBIST instruction
    shift_dr(3, 3'b001);            // start
    shift_dr(3, 3'b000);            // deassert go
    repeat (40) clk_tck(0,0);       // give BIST time (needs ~ 6*64*3 clk cycles)
    begin : poll
      integer n; n = 0; rd = 0;
      while (!rd[1] && n < 200) begin shift_dr(3, 3'b000); n = n + 1; repeat (20) clk_tck(0,0); end
    end
    $display("MBIST status via JTAG: busy=%b done=%b fail=%b", rd[0], rd[1], rd[2]);
    if (rd[1] && (rd[2] == (`MEM_FAULT != 0))) $display("DFT_TOP TEST PASSED (MEM_FAULT=%0d)", `MEM_FAULT);
    else $display("DFT_TOP TEST FAILED (MEM_FAULT=%0d)", `MEM_FAULT);
    $finish;
  end
  initial begin #100000000; $display("TIMEOUT"); $finish; end
endmodule
