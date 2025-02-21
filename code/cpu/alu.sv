import defs::*;

module alu (
  input logic [7:0] src1, src2,
  input alu_op_t aluOp,
  input logic cin,
  output logic [3:0] flg,
  output logic [7:0] aluOut
);

  logic [7:0] addIn2;
  logic [3:0] bsum,tsum;

  // add/subtract
  assign addIn2 = aluOp==ALU_ADD2 ? {8{src2[7]}} : src2;
  // assign addIn1 = aluOp==ALU_ADD2 ? 0 : src1;
  assign {bcarry, bsum} = src1[3:0] + addIn2[3:0] + ((aluOp==ALU_ADD2)&cin);
  assign {carry, tsum} = src1[7:4] + addIn2[7:4] + bcarry;

  // select output
  always_comb begin
    case(aluOp)
      ALU_ADD: aluOut = {tsum,bsum};
      ALU_ADD2: aluOut = {tsum,bsum};
      ALU_R:   aluOut = src1;
      default: aluOut = 'x;
    endcase
  end

  // calculate flags
  always_comb begin
    case(aluOp) // flg = {zero,neg,halfcarry,carry}
      ALU_ADD: flg = {~|(bsum|tsum),1'b0,bcarry,carry};
      ALU_ADD2: flg = {2'b0,bcarry,carry};
      default: flg = 'x;
    endcase
  end

endmodule