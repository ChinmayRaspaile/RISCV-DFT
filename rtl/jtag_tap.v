// IEEE 1149.1 TAP controller + IR + DRs (IDCODE, BYPASS, SAMPLE/PRELOAD, EXTEST, MBIST_CTRL)
// Simplification: boundary register holds N *output* cells (capture core_out, drive pad_out in EXTEST).
module jtag_tap #(
  parameter BSR_LEN = 8,
  parameter [31:0] IDCODE = 32'h1DF70001   // version[31:28]=1, part=0xDF70, mfr=0, LSB must be 1
)(
  input                 tck, tms, tdi, trst_n,
  output reg            tdo,
  output reg            tdo_en,
  // boundary scan
  input  [BSR_LEN-1:0]  core_out,
  output [BSR_LEN-1:0]  pad_out,
  // MBIST access (tck domain; sync outside)
  input                 mbist_busy, mbist_done, mbist_fail,
  output reg            mbist_go
);
  // instructions
  localparam [3:0] I_EXTEST = 4'h0, I_SAMPLE = 4'h1, I_IDCODE = 4'h2, I_MBIST = 4'h4, I_BYPASS = 4'hF;
  // TAP states (standard encodings)
  localparam [3:0] TLR=4'hF, RTI=4'hC, SELDR=4'h7, CAPDR=4'h6, SHDR=4'h2, EX1DR=4'h1, PADR=4'h3, EX2DR=4'h0,
                   UPDDR=4'h5, SELIR=4'h4, CAPIR=4'hE, SHIR=4'hA, EX1IR=4'h9, PAIR=4'hB, EX2IR=4'h8, UPDIR=4'hD;

  reg [3:0] state;
  always @(posedge tck or negedge trst_n) begin
    if (!trst_n) state <= TLR;
    else case (state)
      TLR:   state <= tms ? TLR   : RTI;
      RTI:   state <= tms ? SELDR : RTI;
      SELDR: state <= tms ? SELIR : CAPDR;
      CAPDR: state <= tms ? EX1DR : SHDR;
      SHDR:  state <= tms ? EX1DR : SHDR;
      EX1DR: state <= tms ? UPDDR : PADR;
      PADR:  state <= tms ? EX2DR : PADR;
      EX2DR: state <= tms ? UPDDR : SHDR;
      UPDDR: state <= tms ? SELDR : RTI;
      SELIR: state <= tms ? TLR   : CAPIR;
      CAPIR: state <= tms ? EX1IR : SHIR;
      SHIR:  state <= tms ? EX1IR : SHIR;
      EX1IR: state <= tms ? UPDIR : PAIR;
      PAIR:  state <= tms ? EX2IR : PAIR;
      EX2IR: state <= tms ? UPDIR : SHIR;
      UPDIR: state <= tms ? SELDR : RTI;
      default: state <= TLR;
    endcase
  end

  // ---------------- Instruction register ----------------
  reg [3:0] ir_sr, ir;
  always @(posedge tck) begin
    if (state == CAPIR)      ir_sr <= 4'b0001;            // mandatory "01" LSBs
    else if (state == SHIR)  ir_sr <= {tdi, ir_sr[3:1]};
  end
  always @(negedge tck or negedge trst_n) begin
    if (!trst_n)               ir <= I_IDCODE;            // reset selects IDCODE
    else if (state == TLR)     ir <= I_IDCODE;
    else if (state == UPDIR)   ir <= ir_sr;
  end

  // ---------------- Data registers ----------------
  reg        bypass_r;
  reg [31:0] id_sr;
  reg [BSR_LEN-1:0] bsr_sr, bsr_up;
  reg        extest_mode;
  reg [2:0]  mb_sr;

  wire sel_bsr  = (ir == I_EXTEST) || (ir == I_SAMPLE);
  wire sel_id   = (ir == I_IDCODE);
  wire sel_mb   = (ir == I_MBIST);

  always @(posedge tck) begin
    if (state == CAPDR) begin
      bypass_r <= 1'b0;
      id_sr    <= IDCODE;
      bsr_sr   <= core_out;
      mb_sr    <= {mbist_fail, mbist_done, mbist_busy};
    end else if (state == SHDR) begin
      bypass_r <= tdi;
      id_sr    <= {tdi, id_sr[31:1]};
      bsr_sr   <= {tdi, bsr_sr[BSR_LEN-1:1]};
      mb_sr    <= {tdi, mb_sr[2:1]};
    end
  end

  always @(negedge tck or negedge trst_n) begin
    if (!trst_n) begin
      bsr_up <= 0; extest_mode <= 1'b0; mbist_go <= 1'b0;
    end else begin
      if (state == TLR) begin extest_mode <= 1'b0; mbist_go <= 1'b0; end
      if (state == UPDDR) begin
        if (sel_bsr) bsr_up <= bsr_sr;       // PRELOAD / EXTEST update
        if (sel_mb)  mbist_go <= mb_sr[0];
      end
      if (state == UPDIR) extest_mode <= (ir_sr == I_EXTEST);   // mode takes effect on the new instruction
    end
  end

  assign pad_out = extest_mode ? bsr_up : core_out;

  // ---------------- TDO ----------------
  reg dr_bit;
  always @* begin
    if (sel_bsr)      dr_bit = bsr_sr[0];
    else if (sel_id)  dr_bit = id_sr[0];
    else if (sel_mb)  dr_bit = mb_sr[0];
    else              dr_bit = bypass_r;
  end
  always @(negedge tck or negedge trst_n) begin
    if (!trst_n) begin tdo <= 1'b0; tdo_en <= 1'b0; end
    else begin
      tdo_en <= (state == SHIR) || (state == SHDR);
      tdo    <= (state == SHIR) ? ir_sr[0] : (state == SHDR) ? dr_bit : 1'b0;
    end
  end
endmodule
