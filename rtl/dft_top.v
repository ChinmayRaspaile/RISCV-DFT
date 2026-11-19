`ifndef MEM_FAULT
`define MEM_FAULT 0
`endif
// Integration: JTAG TAP -> (CDC sync) -> MBIST wrapper around a 64x8 SRAM
module dft_top(
  input        clk, rst_n,                 // system clock domain
  input        tck, tms, tdi, trst_n,      // JTAG
  output       tdo, tdo_en,
  input        func_en, func_we,
  input  [5:0] func_addr,
  input  [7:0] func_wdata,
  output [7:0] pad_rdata
);
  wire [7:0] ram_rdata;
  wire       bist_busy, bist_done, bist_fail;
  wire [5:0] bist_fail_addr;
  wire       mbist_go;

  // tck -> clk : 2-flop sync + rising-edge detect
  reg [2:0] go_s;
  always @(posedge clk or negedge rst_n)
    if (!rst_n) go_s <= 0; else go_s <= {go_s[1:0], mbist_go};
  wire bist_start = go_s[1] & ~go_s[2];

  // clk -> tck : 2-flop sync of status
  reg [2:0] busy_s, done_s, fail_s;
  always @(posedge tck or negedge trst_n)
    if (!trst_n) begin busy_s <= 0; done_s <= 0; fail_s <= 0; end
    else begin
      busy_s <= {busy_s[1:0], bist_busy};
      done_s <= {done_s[1:0], bist_done};
      fail_s <= {fail_s[1:0], bist_fail};
    end

  mem_bist_wrap #(.AW(6), .DW(8), .FAULT_TYPE(`MEM_FAULT)) u_mem (
    .clk(clk), .rst_n(rst_n),
    .func_en(func_en), .func_we(func_we), .func_addr(func_addr), .func_wdata(func_wdata), .func_rdata(ram_rdata),
    .bist_start(bist_start), .bist_busy(bist_busy), .bist_done(bist_done), .bist_fail(bist_fail),
    .bist_fail_addr(bist_fail_addr));

  jtag_tap #(.BSR_LEN(8)) u_tap (
    .tck(tck), .tms(tms), .tdi(tdi), .trst_n(trst_n), .tdo(tdo), .tdo_en(tdo_en),
    .core_out(ram_rdata), .pad_out(pad_rdata),
    .mbist_busy(busy_s[1]), .mbist_done(done_s[1]), .mbist_fail(fail_s[1]), .mbist_go(mbist_go));
endmodule
