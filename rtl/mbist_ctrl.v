// March C- MBIST controller  (10N)
//  e0: up   (w0)
//  e1: up   (r0,w1)
//  e2: up   (r1,w0)
//  e3: down (r0,w1)
//  e4: down (r1,w0)
//  e5: down (r0)
// Detects SAF, TF, AF and unlinked CFin/CFid/CFst. Solid 0/1 data background.
module mbist_ctrl #(parameter AW = 6, DW = 8)(
  input               clk,
  input               rst_n,
  input               start,
  output              busy,
  output reg          done,
  output reg          fail,          // sticky
  output reg [AW-1:0] fail_addr,     // first failing address
  output              mem_en,
  output              mem_we,
  output [AW-1:0]     mem_addr,
  output [DW-1:0]     mem_wdata,
  input  [DW-1:0]     mem_rdata
);
  localparam S_IDLE = 3'd0, S_RD = 3'd1, S_CMP = 3'd2, S_WR = 3'd3, S_NEXT = 3'd4, S_DONE = 3'd5;
  reg [2:0]    st;
  reg [2:0]    elem;
  reg [AW-1:0] addr;

  function dir_up (input [2:0] e);   dir_up = (e <= 3'd2); endfunction
  function has_rd (input [2:0] e);   has_rd = (e != 3'd0); endfunction
  function has_wr (input [2:0] e);   has_wr = (e != 3'd5); endfunction
  function exp_v  (input [2:0] e);   exp_v  = (e == 3'd2) || (e == 3'd4); endfunction
  function wr_v   (input [2:0] e);   wr_v   = (e == 3'd1) || (e == 3'd3); endfunction

  wire [AW-1:0] last_addr = dir_up(elem) ? {AW{1'b1}} : {AW{1'b0}};
  wire          elem_end  = (addr == last_addr);
  wire [2:0]    elem_n    = elem + 3'd1;

  assign busy      = (st != S_IDLE) && (st != S_DONE);
  assign mem_en    = (st == S_RD) || (st == S_WR);
  assign mem_we    = (st == S_WR);
  assign mem_addr  = addr;
  assign mem_wdata = {DW{wr_v(elem)}};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= S_IDLE; elem <= 0; addr <= 0; done <= 0; fail <= 0; fail_addr <= 0;
    end else begin
      case (st)
        S_IDLE, S_DONE: begin
          if (start) begin
            elem <= 0; addr <= 0; done <= 0; fail <= 0; fail_addr <= 0;
            st <= S_WR;                       // element 0 is write-only
          end
        end
        S_RD:  st <= S_CMP;
        S_CMP: begin
          if (mem_rdata != {DW{exp_v(elem)}}) begin
            if (!fail) fail_addr <= addr;
            fail <= 1'b1;
          end
          st <= has_wr(elem) ? S_WR : S_NEXT;
        end
        S_WR:  st <= S_NEXT;
        S_NEXT: begin
          if (!elem_end) begin
            addr <= dir_up(elem) ? addr + 1'b1 : addr - 1'b1;
            st   <= has_rd(elem) ? S_RD : S_WR;
          end else if (elem == 3'd5) begin
            done <= 1'b1; st <= S_DONE;
          end else begin
            elem <= elem_n;
            addr <= dir_up(elem_n) ? {AW{1'b0}} : {AW{1'b1}};
            st   <= has_rd(elem_n) ? S_RD : S_WR;
          end
        end
        default: st <= S_IDLE;
      endcase
    end
  end
endmodule
