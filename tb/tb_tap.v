`timescale 1ns/1ps
module tb_tap;
  reg tck = 0, tms = 1, tdi = 0, trst_n = 0;
  wire tdo, tdo_en, mbist_go;
  reg  [7:0] core_out = 8'hA5;
  wire [7:0] pad_out;
  reg  mb_busy = 0, mb_done = 1, mb_fail = 0;

  jtag_tap #(.BSR_LEN(8)) dut (.tck(tck), .tms(tms), .tdi(tdi), .trst_n(trst_n), .tdo(tdo), .tdo_en(tdo_en),
    .core_out(core_out), .pad_out(pad_out), .mbist_busy(mb_busy), .mbist_done(mb_done), .mbist_fail(mb_fail),
    .mbist_go(mbist_go));

  integer errors = 0;

  // One TCK cycle: drive TMS/TDI while TCK low, rising edge, then falling edge. TDO is valid after falling edge.
  task clk_tck(input t_ms, input t_di);
    begin
      tms = t_ms; tdi = t_di; #10 tck = 1; #10 tck = 0; #1;
    end
  endtask

  task tap_reset; integer i; begin for (i = 0; i < 6; i = i + 1) clk_tck(1, 0); clk_tck(0, 0); end endtask // -> RTI

  // From RTI: shift IR
  task shift_ir(input [3:0] val);
    integer i;
    begin
      clk_tck(1,0); clk_tck(1,0); clk_tck(0,0); clk_tck(0,0);    // SELDR, SELIR, CAPIR, SHIR
      for (i = 0; i < 4; i = i + 1) clk_tck(i == 3, val[i]);     // last bit with TMS=1 -> EX1IR
      clk_tck(1,0); clk_tck(0,0);                                // UPDIR, RTI
    end
  endtask

  // From RTI: shift N bits of DR, return captured bits in 'rd'
  reg [63:0] rd;
  task shift_dr(input integer n, input [63:0] wr);
    integer i;
    begin
      rd = 0;
      clk_tck(1,0); clk_tck(0,0); clk_tck(0,0);                  // SELDR, CAPDR, SHDR (TDO now shows bit0)
      for (i = 0; i < n; i = i + 1) begin
        rd[i] = tdo;
        clk_tck(i == n-1, wr[i]);
      end
      clk_tck(1,0); clk_tck(0,0);                                // UPDDR, RTI
    end
  endtask

  task expect64(input [255:0] name, input [63:0] got, input [63:0] exp);
    begin
      if (got !== exp) begin $display("[FAIL] %0s got=%h exp=%h", name, got, exp); errors = errors + 1; end
      else $display("[PASS] %0s = %h", name, got);
    end
  endtask

  initial begin
    $dumpfile("results/tap.vcd"); $dumpvars(0, tb_tap);
    #50 trst_n = 1;
    tap_reset;

    // 1) After reset IR=IDCODE: read IDCODE directly
    shift_dr(32, 64'h0);
    expect64("IDCODE after reset", rd, 64'h1DF70001);

    // 2) IR capture pattern (shift IR bits out): expect 0001
    //    shift in BYPASS(F) while reading captured value
    clk_tck(1,0); clk_tck(1,0); clk_tck(0,0); clk_tck(0,0);
    begin : irread
      integer i; reg [3:0] c;
      for (i = 0; i < 4; i = i + 1) begin c[i] = tdo; clk_tck(i == 3, 1'b1); end
      clk_tck(1,0); clk_tck(0,0);
      expect64("IR capture value", {60'b0, c}, 64'h1);
    end

    // 3) BYPASS: 1-bit register => data delayed by one clock
    //    shift pattern 0b1011_0010 (8 bits) + extra 1 bit: observed rd[8:1] == pattern
    shift_dr(9, 64'b0_1011_0010);
    expect64("BYPASS delay", rd[8:1], 64'b1011_0010);

    // 4) SAMPLE/PRELOAD: capture core_out
    shift_ir(4'h1);
    shift_dr(8, 64'h3C);                     // also PRELOADs 0x3C
    expect64("SAMPLE captured core_out", rd[7:0], 64'hA5);
    if (pad_out !== 8'hA5) begin $display("[FAIL] pad_out must follow core in SAMPLE"); errors = errors + 1; end
    else $display("[PASS] pad_out transparent in SAMPLE");

    // 5) EXTEST: drive pad_out from boundary register
    shift_ir(4'h0);
    if (pad_out !== 8'h3C) begin $display("[FAIL] EXTEST should drive preloaded 0x3C, got %h", pad_out); errors = errors + 1; end
    else $display("[PASS] EXTEST drives preloaded value 0x3C");
    shift_dr(8, 64'hC3);
    if (pad_out !== 8'hC3) begin $display("[FAIL] EXTEST new value got %h", pad_out); errors = errors + 1; end
    else $display("[PASS] EXTEST drives new value 0xC3");

    // 6) MBIST instruction: status capture + start bit
    shift_ir(4'h4);
    mb_busy = 0; mb_done = 1; mb_fail = 1;
    shift_dr(3, 64'b001);                    // write start=1
    expect64("MBIST status {fail,done,busy}", rd[2:0], 64'b110);
    if (mbist_go !== 1'b1) begin $display("[FAIL] mbist_go not set"); errors = errors + 1; end
    else $display("[PASS] mbist_go asserted");
    shift_dr(3, 64'b000);
    if (mbist_go !== 1'b0) begin $display("[FAIL] mbist_go not cleared"); errors = errors + 1; end
    else $display("[PASS] mbist_go cleared");

    // 7) Test-logic-reset returns to IDCODE and EXTEST mode off
    tap_reset;
    shift_dr(32, 64'h0);
    expect64("IDCODE after TLR", rd, 64'h1DF70001);

    if (errors == 0) $display("TAP TEST PASSED"); else $display("TAP TEST FAILED (%0d)", errors);
    $finish;
  end
  initial begin #5000000; $display("TIMEOUT"); $finish; end
endmodule
