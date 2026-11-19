// Logic BIST: LFSR (PRPG) -> CUT -> MISR, run for N patterns, compare signature externally/with golden
module lbist_top(
  input         clk, rst_n,
  input         start,
  input  [15:0] num_patterns,
  output        busy,
  output reg    done,
  output [15:0] signature,
  // fault injection into CUT (for coverage experiments)
  input         fault_en,
  input  [5:0]  fault_node,
  input         fault_val
);
  wire [31:0] pat;
  wire [7:0]  s;
  wire        cout;
  reg         run;
  reg  [15:0] cnt;
  reg         ld;

  lfsr32 u_prpg (.clk(clk), .rst_n(rst_n), .load(ld), .en(run), .q(pat));

  cut_adder u_cut (.a(pat[7:0]), .b(pat[15:8]), .cin(pat[16]), .s(s), .cout(cout),
                   .fault_en(fault_en), .fault_node(fault_node), .fault_val(fault_val));

  misr16 u_misr (.clk(clk), .rst_n(rst_n), .clear(ld), .en(run), .din({7'b0, cout, s}), .sig(signature));

  assign busy = run;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin run <= 0; done <= 0; cnt <= 0; ld <= 0; end
    else begin
      ld <= 1'b0;
      if (!run && start) begin ld <= 1'b1; done <= 0; cnt <= 0; run <= 1'b1; end
      else if (run) begin
        cnt <= cnt + 1'b1;
        if (cnt == num_patterns - 1) begin run <= 0; done <= 1; end
      end
    end
  end
endmodule
