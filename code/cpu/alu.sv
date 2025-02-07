import defs::*;

module aluE (
  input logic [7:0] src1, src2,
  input alu_op_t aluOp,
  output logic [3:0] flg,
  output logic [7:0] aluOut
);

  // add/subtract
  assign {bcarry, bsum} = src1[3:0] + src2[3:0];
  assign {carry, tsum} = src1[7:4] + src2[7:4] + bcarry;

  // select output
  always_comb begin
    case(aluOp)
      ALU_ADD: aluOut = {tsum,bsum};
      ALU_SRC1: aluOut = src1; // *** could move to mux at end
      default: aluOut = 'x;
    endcase
  end

  // calculate flags
  always_comb begin
    case(aluOp) // flg = {zero,neg,halfcarry,carry}
      ALU_ADD: flg = {~|(bsum|tsum),1'b0,bcarry,carry};
      default: flg = 'x;
    endcase
  end

endmodule