import defs::*;

module regfile (
  input logic clk, rst,
  input  logic [3:0] adr1, adr2, rdAdr, rd2Adr,
  input  logic rdWen, rdW16, rd2Wen,
  input  logic [15:0] rd,
  input  logic [7:0] rd2,
  output logic [15:0] rs16,
  output logic [7:0] rs1, rs2
);
  // B C D E H L F A W Z SP
  // 0 1 2 3 4 5 6 7 8 9 10/11
  logic [11:0][7:0] regs;
  always_ff @(posedge clk) begin : rf
    if(rst) begin 
      regs = 0; 
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
  end

  assign rs1 = regs[adr1];
  assign rs2 = regs[adr2];
  always_comb case(adr1)
    B: rs16 = {regs[B], regs[C]};
    D: rs16 = {regs[D], regs[E]};
    H: rs16 = {regs[H], regs[L]};
    W: rs16 = {regs[W], regs[Z]};
    SP: rs16 = {regs[SP], regs[SPL]};
    // F: rs16 = {regs[SP], regs[SPL]};
    default: rs16 = 'x;
  endcase

endmodule