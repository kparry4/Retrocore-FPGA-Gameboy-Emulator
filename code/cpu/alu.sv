//import defs::*;
`include "defs.svh"

module alu (
  input logic [7:0] src1, src2,
  input alu_op_t aluOp,
  input logic cin,
  input logic [3:0] flgKill, flgSet,
  output logic [3:0] flg,
  output logic [7:0] aluOut
);

  logic [7:0] addIn2;
  logic [3:0] bsum,tsum;
  logic bcarry;
  logic carry;
  logic [7:0] addCin;
  logic useC, sub;

  assign useC = (aluOp==ALU_ADD2)|(aluOp==ALU_ADC)|(aluOp==ALU_SBC);
  assign sub = (aluOp==ALU_SUB)|(aluOp==ALU_SBC);

  // add/subtract
  assign addIn2 = sub ? -(aluOp==ALU_ADD2 ? {7{src2[7]}} : src2) : (aluOp==ALU_ADD2 ? {7{src2[7]}} : src2);
  assign addCin = sub ? -(useC&cin) : useC&cin;
  // assign addIn1 = aluOp==ALU_ADD2 ? 0 : src1;
  assign {bcarry, bsum} = src1[3:0] + addIn2[3:0] + addCin[3:0];
  assign {carry, tsum} = src1[7:4] + addIn2[7:4] + bcarry + addCin[7:4];

  // select output
  always_comb begin
    case(aluOp)
      ALU_ADD: aluOut = {tsum,bsum};
      ALU_ADD2: aluOut = {tsum,bsum};
      ALU_ADC: aluOut = {tsum,bsum};
      ALU_SUB: aluOut = {tsum,bsum};
      ALU_SBC: aluOut = {tsum,bsum};
      ALU_AND: aluOut = src1&src2;
      ALU_OR: aluOut = src1|src2;
      ALU_XOR: aluOut = src1^src2;
      ALU_R:   aluOut = src1;
      default: aluOut = 'x;
    endcase
  end

  // zero flag
  assign flg[3] = (~|aluOut)&flgKill[3]|flgSet[3];
  // neg flag
  assign flg[2] = flgSet[2];
  // half carry flag
  assign flg[1] = ((bcarry^sub)&flgKill[1])|flgSet[1];
  // carry flag
  assign flg[0] = ((carry^sub)&flgKill[0])|flgSet[0];

endmodule