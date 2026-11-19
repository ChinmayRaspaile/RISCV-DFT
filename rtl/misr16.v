// 16-bit MISR signature compactor, x^16 + x^15 + x^13 + x^4 + 1 (Galois form)
module misr16(
  input clk, rst_n, clear, en,
  input  [15:0] din,
  output reg [15:0] sig
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)      sig <= 16'h0;
    else if (clear)  sig <= 16'h0;
    else if (en)     sig <= ({sig[14:0], 1'b0} ^ (sig[15] ? 16'hA011 : 16'h0)) ^ din;
  end
endmodule
