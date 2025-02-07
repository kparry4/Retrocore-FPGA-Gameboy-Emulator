import defs::*;

module cpu (
  input logic clk,
  input  logic rst,
  input  logic [15:0] memData,
  input logic memValid,
  output logic [15:0] memAddr
);  
  logic [3:0][7:0] instrD;
  logic stallE,stallM,stallD;
  logic [7:0] rs1E, rs2E;
  logic [7:0] src1, src2;
  logic [7:0] aluOutE;
  logic [7:0] rdM;
  assign stallE = 0;
  assign stallD = 0;
  assign stallM = 0;
  logic [15:0] pcNext, pc;
  ctrlD_t ctrlD;
  ctrlE_t ctrlE;
  ctrlM_t ctrlM;
  datD_t datD;
  datE_t datE;
  datM_t datM;
  //////////////////////////////////////////////////////////////////////////////////////
  // DECODE
  //////////////////////////////////////////////////////////////////////////////////////


  // instruction buffer, holds 4 bytes
  // *** might be able to merge fetch and decode and hold the instrD

  // control unit
  decoder decoder(.memData, .memValid, .ctrl(ctrlD), .rst, .clk, .n(datD.n));

  // pc register
  flopenr #(16) pcflop(clk, rst, ~stallD, pcNext, pc);
  
  // select the next pc
  always_comb 
    case(ctrlD.pcSel)
      PC_ADD: pcNext = pc + ctrlD.instrSz;
      default: pcNext = 'x;
    endcase
  // get the next instruction
  assign memAddr = pcNext + {ctrlD.adjpc,1'b0};
  // assign memAddr = pc + {ctrlD.adjpc,1'b0};

  flopenr #($bits(ctrlE)) ctrlflopDE (clk, rst, ~stallE, ctrlD[$bits(ctrlE)-1:0], ctrlE);
  flopenr #($bits(datD)) datflopDE (clk, rst, ~stallM, datD, datE[$bits(datD)-1:0]);
  //////////////////////////////////////////////////////////////////////////////////////
  // EXECUTE
  //////////////////////////////////////////////////////////////////////////////////////

  regfile regfile(.clk, .rd(rdM), .rs1(rs1E), .rs2(rs2E), 
                  .rdAddr(ctrlM.rdAddr), .addr1(ctrlE.addr1), .addr2(ctrlE.addr2),
                  .rdWen(ctrlM.rdWen));

  assign src1 = rs1E;
  assign src2 = rs2E;

  aluE aluE (.src1, .src2, .aluOp(ctrlE.aluOp), .aluOut(datE.aluOut), .flg(datE.flg));

  flopenr #($bits(ctrlM)) ctrlflopEM (clk, rst, ~stallM, ctrlE, ctrlM);
  flopenr #($bits(datE)) datflopEM (clk, rst, ~stallM, datE, datM);
  //////////////////////////////////////////////////////////////////////////////////////
  // MEMORY
  //////////////////////////////////////////////////////////////////////////////////////
  always_comb 
    case(ctrlM.rdSel)
      RD_N: rdM = datM.n;
      RD_ALU: rdM = datM.aluOut;
      default: rdM = 'x;
    endcase
  

endmodule