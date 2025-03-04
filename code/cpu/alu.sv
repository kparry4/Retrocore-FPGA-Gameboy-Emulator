//import defs::*;
`include "defs.svh"

module alu (
  input logic [7:0] src1, src2,
  input alu_op_t aluOp,
  input logic cin, hcin, nflg,
  input logic [3:0] flgKill, flgSet,
  input logic [2:0] b,
  output logic [3:0] flg,
  output logic [7:0] aluOut
);

  logic [7:0] addIn2;
  logic [3:0] bsum,tsum;
  logic bcarry;
  logic carry;
  logic selb;
  logic [7:0] addCin, adj, bitRes;
  logic useC, sub, daa;

  assign useC = (aluOp==ALU_ADD2)|(aluOp==ALU_ADC)|(aluOp==ALU_SBC);
  assign sub = (aluOp==ALU_SUB)|(aluOp==ALU_SBC);
  assign daa = (aluOp==ALU_DAA);

  // add/subtract
  assign addIn2 = daa ? nflg ? -adj : adj : sub ? -(aluOp==ALU_ADD2 ? {7{src2[7]}} : src2) : (aluOp==ALU_ADD2 ? {7{src2[7]}} : src2);
  assign addCin = sub ? -(useC&cin) : useC&cin;
  // assign addIn1 = aluOp==ALU_ADD2 ? 0 : src1;
  assign {bcarry, bsum} = src1[3:0] + addIn2[3:0] + addCin[3:0];
  assign {carry, tsum} = src1[7:4] + addIn2[7:4] + bcarry + addCin[7:4];

  always_comb begin
    adj=0;
    if((~nflg&(src1[3:0] > 9))|hcin) adj[3:0] = 6;
    if((~nflg&(src1 > 8'h99))|cin) adj[7:4] = 6;
  end

  always_comb begin
    bitRes = src1;
    bitRes[b] = aluOp==ALU_SET;
  end


  // select output
  always_comb begin
    case(aluOp)
      ALU_ADD: aluOut = {tsum,bsum};
      ALU_ADD2: aluOut = {tsum,bsum};
      ALU_ADC: aluOut = {tsum,bsum};
      ALU_SUB: aluOut = {tsum,bsum};
      ALU_SBC: aluOut = {tsum,bsum};
      ALU_DAA: aluOut = {tsum,bsum};
      ALU_RLC: aluOut = {src1[6:0],src1[7]};
      ALU_RRC: aluOut = {src1[0],src1[7:1]};
      ALU_RL: aluOut = {src1[6:0],cin};
      ALU_RR: aluOut = {cin,src1[7:1]};
      ALU_SLA: aluOut = {src1[6:0],1'b0};
      ALU_SRA: aluOut = {src1[7],src1[7:1]};
      ALU_SRL: aluOut = {1'b0,src1[7:1]};
      ALU_SWAP: aluOut = {src1[3:0],src1[7:4]};
      ALU_RES: aluOut = bitRes;
      ALU_SET: aluOut = bitRes;
      ALU_AND: aluOut = src1&src2;
      ALU_OR: aluOut = src1|src2;
      ALU_XOR: aluOut = src1^src2;
      ALU_NOT: aluOut = ~src1;
      ALU_R:   aluOut = src1;
      default: aluOut = 'x;
    endcase
  end

  // select bit from rs1
  assign selb = src1[b];

  // zero flag
  assign flg[3] = ((aluOp == ALU_BIT) ? selb : ~|aluOut)&flgKill[3]|flgSet[3];
  // neg flag
  assign flg[2] = flgSet[2];
  // half carry flag
  assign flg[1] = ((bcarry^sub)&flgKill[1])|flgSet[1];
  // carry flag
  assign flg[0] = (aluOp == ALU_DAA) ? |adj[7:4] : 
                  (aluOp==ALU_RLC)|(aluOp==ALU_RL)|(aluOp==ALU_SLA) ? src1[7] : 
                  (aluOp==ALU_RRC)|(aluOp==ALU_RR)|(aluOp==ALU_SRA)|(aluOp==ALU_SRL) ? src1[0] : 
                  (aluOp == ALU_CCF) ? ~cin : 
                  ((carry^sub)&flgKill[0])|flgSet[0];

endmodule