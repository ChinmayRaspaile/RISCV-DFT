`timescale 1ns/1ps
// Five memories in parallel, each with a different injected fault. Expect: golden passes, all faults caught.
module tb_mbist;
  reg clk = 0, rst_n = 0, start = 0;
  always #5 clk = ~clk;

  wire [4:0] done, fail;
  wire [5:0] fa0, fa1, fa2, fa3, fa4;
  wire [7:0] r0, r1, r2, r3, r4;

  mem_bist_wrap #(.FAULT_TYPE(0)) u0 (clk,rst_n,1'b0,1'b0,6'd0,8'd0,r0,start,,done[0],fail[0],fa0); // fault free
  mem_bist_wrap #(.FAULT_TYPE(1), .F_ADDR(10), .F_BIT(2)) u1 (clk,rst_n,1'b0,1'b0,6'd0,8'd0,r1,start,,done[1],fail[1],fa1); // SA0
  mem_bist_wrap #(.FAULT_TYPE(2), .F_ADDR(33), .F_BIT(7)) u2 (clk,rst_n,1'b0,1'b0,6'd0,8'd0,r2,start,,done[2],fail[2],fa2); // SA1
  mem_bist_wrap #(.FAULT_TYPE(3), .F_ADDR(5),  .F_BIT(0)) u3 (clk,rst_n,1'b0,1'b0,6'd0,8'd0,r3,start,,done[3],fail[3],fa3); // TF
  mem_bist_wrap #(.FAULT_TYPE(4), .F_ADDR(10), .F_BIT(4), .AGG_ADDR(3)) u4 (clk,rst_n,1'b0,1'b0,6'd0,8'd0,r4,start,,done[4],fail[4],fa4); // CFin

  integer errors = 0;
  task check(input [175:0] name, input exp_fail, input got_done, input got_fail, input [5:0] fa);
    begin
      if (!got_done || (got_fail !== exp_fail)) begin
        $display("[FAIL] %0s : done=%b fail=%b (expected fail=%b)", name, got_done, got_fail, exp_fail);
        errors = errors + 1;
      end else
        $display("[PASS] %0s : done=%b fail=%b first_fail_addr=%0d", name, got_done, got_fail, fa);
    end
  endtask

  initial begin
    $dumpfile("results/mbist.vcd"); $dumpvars(0, tb_mbist);
    #25 rst_n = 1;
    #20 start = 1; #10 start = 0;
    wait (&done);
    #20;
    check("golden RAM        ", 0, done[0], fail[0], fa0);
    check("stuck-at-0 cell   ", 1, done[1], fail[1], fa1);
    check("stuck-at-1 cell   ", 1, done[2], fail[2], fa2);
    check("transition fault  ", 1, done[3], fail[3], fa3);
    check("inversion coupling", 1, done[4], fail[4], fa4);
    if (errors == 0) $display("MBIST TEST PASSED"); else $display("MBIST TEST FAILED (%0d)", errors);
    $finish;
  end
  initial begin #2000000; $display("TIMEOUT"); $finish; end
endmodule
