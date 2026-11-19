`timescale 1ns/1ps
// Fault-simulates all 64 stuck-at faults of the CUT for increasing LBIST lengths.
module tb_lbist;
  reg clk = 0, rst_n = 0, start = 0;
  reg [15:0] npat = 16;
  reg fault_en = 0; reg [5:0] fault_node = 0; reg fault_val = 0;
  wire busy, done; wire [15:0] sig;
  always #5 clk = ~clk;

  lbist_top dut(.clk(clk), .rst_n(rst_n), .start(start), .num_patterns(npat), .busy(busy), .done(done),
                .signature(sig), .fault_en(fault_en), .fault_node(fault_node), .fault_val(fault_val));

  task run_lbist; begin
    @(negedge clk); start = 1; @(negedge clk); start = 0;
    wait (done); @(negedge clk);
  end endtask

  integer k, f, det, total, idx;
  reg [15:0] golden;
  integer lens [0:8];
  integer fd;

  initial begin
    lens[0]=4; lens[1]=8; lens[2]=16; lens[3]=32; lens[4]=64; lens[5]=128; lens[6]=256; lens[7]=512; lens[8]=1024;
    fd = $fopen("results/lbist_coverage.csv", "w");
    $fdisplay(fd, "patterns,detected,total,coverage_pct");
    #22 rst_n = 1;
    $display("LBIST: 32-bit LFSR -> 8-bit adder CUT -> 16-bit MISR");
    $display("patterns | golden sig | detected/64 | coverage");
    for (k = 0; k < 9; k = k + 1) begin
      npat = lens[k];
      fault_en = 0; run_lbist; golden = sig;
      det = 0; total = 0;
      for (f = 0; f < 32; f = f + 1) begin
        for (idx = 0; idx < 2; idx = idx + 1) begin
          fault_en = 1; fault_node = f; fault_val = idx[0];
          run_lbist;
          total = total + 1;
          if (sig !== golden) det = det + 1;
        end
      end
      fault_en = 0;
      $display("%8d |    %04h    |   %2d/%2d     | %0d.%0d%%", npat, golden, det, total, (det*100)/total, ((det*1000)/total)%10);
      $fdisplay(fd, "%0d,%0d,%0d,%0d", npat, det, total, (det*100)/total);
    end
    $fclose(fd);
    $finish;
  end
  initial begin #50000000; $display("TIMEOUT"); $finish; end
endmodule
