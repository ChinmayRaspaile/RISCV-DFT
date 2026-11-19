// 32-bit Galois LFSR PRPG, x^32 + x^22 + x^2 + x + 1
module lfsr32 #(parameter [31:0] SEED = 32'hACE1_2468)(
  input clk, rst_n, load, en,
  output reg [31:0] q
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)      q <= SEED;
    else if (load)   q <= SEED;
    else if (en)     q <= {q[30:0], 1'b0} ^ (q[31] ? 32'h0040_0007 : 32'h0);
  end
endmodule
