// Behavioral synchronous SRAM with injectable memory faults (simulation only)
// FAULT_TYPE: 0 none | 1 cell stuck-at-0 | 2 cell stuck-at-1
//             3 transition fault (cell cannot rise 0->1)
//             4 inversion coupling fault: a bit0 transition in AGG_ADDR flips victim cell
module sram_model #(
  parameter AW = 6, DW = 8,
  parameter FAULT_TYPE = 0,
  parameter F_ADDR = 10,     // victim / faulty cell address
  parameter F_BIT  = 2,      // victim / faulty cell bit
  parameter AGG_ADDR = 3     // aggressor address (coupling fault only)
)(
  input               clk,
  input               en,
  input               we,
  input  [AW-1:0]     addr,
  input  [DW-1:0]     wdata,
  output reg [DW-1:0] rdata
);
  reg [DW-1:0] mem [0:(1<<AW)-1];
  reg [DW-1:0] nv;
  integer i;
  initial begin
    for (i = 0; i < (1<<AW); i = i + 1) mem[i] = {DW{1'b1}} ^ 8'h55; // unknown power-up content
    rdata = 0;
  end

  always @(posedge clk) begin
    if (en) begin
      if (we) begin
        nv = wdata;
        if (addr == F_ADDR) begin
          case (FAULT_TYPE)
            1: nv[F_BIT] = 1'b0;
            2: nv[F_BIT] = 1'b1;
            3: if (!mem[addr][F_BIT]) nv[F_BIT] = 1'b0;
            default: ;
          endcase
        end
        if (FAULT_TYPE == 4 && addr == AGG_ADDR && (wdata[0] != mem[addr][0]))
          mem[F_ADDR][F_BIT] = ~mem[F_ADDR][F_BIT];
        mem[addr] = nv;
      end else begin
        rdata <= mem[addr];
      end
    end
  end
endmodule
