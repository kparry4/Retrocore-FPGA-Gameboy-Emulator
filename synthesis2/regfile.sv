//import defs::*;
`include "defs.svh"
module regfile (
  input logic clk, rst,
  input  logic [3:0] adr1, adr2, rdAdr, rd2Adr,
  input  logic rdWen, rdW16, rd2Wen, 
  input  logic [3:0] flgWen,
  input  logic [15:0] rd,
  input  logic [7:0] rd2,
  input  logic [3:0] flg,
  output logic [15:0] rs16,
  output logic carry, hcarry, nflg, zflg,
  output logic [7:0] rs1, rs2
);
  // B C D E H L F A W Z SP
  // 0 1 2 3 4 5 6 7 8 9 10/11
  logic [11:0][7:0] regs;
  always_ff @(posedge clk) begin : rf
    if(rst) begin 
      // `ifdef DOC
       regs[A] = 8'h01;
       regs[F] = 8'hB0;
       regs[B] = 8'h00;
       regs[C] = 8'h13;
       regs[D] = 8'h00;
       regs[E] = 8'hd8;
       regs[H] = 8'h01;
       regs[L] = 8'h4d;
      // `else
      // regs = '0;
      // `endif
      {regs[SP], regs[SPL]} = 16'hfffe;
    end
    else if(rdWen) // if write
      if(rdW16) case(rdAdr) // if 16 bit write
        B: {regs[B], regs[C]} = rd;
        D: {regs[D], regs[E]} = rd;
        H: {regs[H], regs[L]} = rd;
        W: {regs[W], regs[Z]} = rd;
        SP: {regs[SP], regs[SPL]} = rd;
        F: {regs[SP], regs[SPL]} = rd; // opcode has SP as 110=F
      endcase
      // if 8-bit write
      else regs[rdAdr] = rd[7:0];
    // second 8 bit write if needed
    if(~rst && rd2Wen) regs[rd2Adr] = rd2;
      // write to flags if needed
    if(~rst) begin 
      if(flgWen[0]) regs[F][4] = flg[0];
      if(flgWen[1]) regs[F][5] = flg[1];
      if(flgWen[2]) regs[F][6] = flg[2];
      if(flgWen[3]) regs[F][7] = flg[3];
    end
    regs[F][3:0] = 4'b0;
  end

  assign carry = regs[F][4];
  assign hcarry = regs[F][5];
  assign nflg = regs[F][6];
  assign zflg = regs[F][7];
  assign rs1 = regs[adr1];
  assign rs2 = regs[adr2];
  always_comb case(adr1)
    B: rs16 = {regs[B], regs[C]};
    D: rs16 = {regs[D], regs[E]};
    H: rs16 = {regs[H], regs[L]};
    W: rs16 = {regs[W], regs[Z]};
    SP: rs16 = {regs[SP], regs[SPL]};
    F: rs16 = {regs[SP], regs[SPL]};
    default: rs16 = 'x;
  endcase

endmodule
