//import defs::*;
`include "defs.svh"

module alu (
  input logic [7:0] src1, src2,
  input alu_op_t aluOp,
  input logic cin,
  input logic [3:0] flgKill,
  output logic [3:0] flg,
  output logic [7:0] aluOut
);

  logic [7:0] addIn2;
  logic [3:0] bsum,tsum;
  logic bcarry,carry;
  logic useC;

  assign useC = (aluOp==ALU_ADD2)|(aluOp==ALU_ADC);

  // add/subtract
  assign addIn2 = aluOp==ALU_ADD2 ? {8{src2[7]}} : src2;
  // assign addIn1 = aluOp==ALU_ADD2 ? 0 : src1;
  assign {bcarry, bsum} = src1[3:0] + addIn2[3:0] + (useC&cin);
  assign {carry, tsum} = src1[7:4] + addIn2[7:4] + bcarry;

  // select output
  always_comb begin
    case(aluOp)
      ALU_ADD: aluOut = {tsum,bsum};
      ALU_ADD2: aluOut = {tsum,bsum};
      ALU_ADC: aluOut = {tsum,bsum};
      ALU_R:   aluOut = src1;
      default: aluOut = 'x;
    endcase
  end

  // zero flag
  assign flg[3] = (~|(bsum|tsum))&flgKill[3];
  // neg flag
  assign flg[2] = 0;
  // half carry flag
  assign flg[1] = bcarry;
  // carry flag
  assign flg[0] = carry;

endmodule