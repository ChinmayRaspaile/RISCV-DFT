// Combinational logic under test: 8-bit ripple-carry adder with explicit stuck-at fault injection
// Fault sites (32 nodes x SA0/SA1 = 64 faults):
//   node  0..7  : p[i] = a^b      node  8..15 : g[i] = a&b
//   node 16..23 : carry c[i+1]    node 24..31 : sum s[i]
module cut_adder(
  input  [7:0] a, b,
  input        cin,
  output [7:0] s,
  output       cout,
  input        fault_en,
  input  [5:0] fault_node,
  input        fault_val
);
  wire [7:0] p, g, sm;
  wire [8:0] c;
  assign c[0] = cin;
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : blk
      wire p_raw = a[i] ^ b[i];
      wire g_raw = a[i] & b[i];
      assign p[i] = (fault_en && fault_node == i)      ? fault_val : p_raw;
      assign g[i] = (fault_en && fault_node == 8 + i)  ? fault_val : g_raw;
      wire c_raw  = g[i] | (p[i] & c[i]);
      assign c[i+1] = (fault_en && fault_node == 16 + i) ? fault_val : c_raw;
      wire s_raw  = p[i] ^ c[i];
      assign sm[i] = (fault_en && fault_node == 24 + i) ? fault_val : s_raw;
    end
  endgenerate
  assign s = sm;
  assign cout = c[8];
endmodule
