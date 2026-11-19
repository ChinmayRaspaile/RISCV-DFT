// SRAM + March C- MBIST with functional/BIST mux (what a real memory wrapper does)
module mem_bist_wrap #(
  parameter AW = 6, DW = 8,
  parameter FAULT_TYPE = 0, parameter F_ADDR = 10, parameter F_BIT = 2, parameter AGG_ADDR = 3
)(
  input               clk,
  input               rst_n,
  // functional port
  input               func_en,
  input               func_we,
  input  [AW-1:0]     func_addr,
  input  [DW-1:0]     func_wdata,
  output [DW-1:0]     func_rdata,
  // BIST interface
  input               bist_start,
  output              bist_busy,
  output              bist_done,
  output              bist_fail,
  output [AW-1:0]     bist_fail_addr
);
  wire            m_en, m_we, b_en, b_we;
  wire [AW-1:0]   m_addr, b_addr;
  wire [DW-1:0]   m_wdata, b_wdata, m_rdata;

  mbist_ctrl #(.AW(AW), .DW(DW)) u_bist (
    .clk(clk), .rst_n(rst_n), .start(bist_start), .busy(bist_busy), .done(bist_done),
    .fail(bist_fail), .fail_addr(bist_fail_addr),
    .mem_en(b_en), .mem_we(b_we), .mem_addr(b_addr), .mem_wdata(b_wdata), .mem_rdata(m_rdata));

  assign m_en    = bist_busy ? b_en    : func_en;
  assign m_we    = bist_busy ? b_we    : func_we;
  assign m_addr  = bist_busy ? b_addr  : func_addr;
  assign m_wdata = bist_busy ? b_wdata : func_wdata;
  assign func_rdata = m_rdata;

  sram_model #(.AW(AW), .DW(DW), .FAULT_TYPE(FAULT_TYPE), .F_ADDR(F_ADDR),
               .F_BIT(F_BIT), .AGG_ADDR(AGG_ADDR)) u_ram (
    .clk(clk), .en(m_en), .we(m_we), .addr(m_addr), .wdata(m_wdata), .rdata(m_rdata));
endmodule
