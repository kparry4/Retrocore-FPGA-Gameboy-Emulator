
module cpu (
  input  logic [31:0] memData,
  output logic [15:0] pc,
);  
  logic [3:0][7:0] instrD;
  logic stallE,stallM,stallD;
  assign stallE = 0;
  assign stallD = 0;
  assign stallM = 0;
  ctrlD_t ctrlD;
  ctrlE_t ctrlE;
  ctrlM_t ctrlM;
  //////////////////////////////////////////////////////////////////////////////////////
  // DECODE
  //////////////////////////////////////////////////////////////////////////////////////


  // instruction buffer, holds 4 bytes
  // *** might be able to merge fetch and decode and hold the instrD

  // control unit
  ctrl ctrl(.memData, .ctrl(ctrlD));

  // pc register
  flopen pcflop(clk, ~stallD, pcNext, pc);
  
  // select the next pc
  always_comb 
    case(ctrlD.pcSel):
      PC_ADD: pcNext = pc + ctrlD.instrSz;
      default: pcNext = 'x;
    endcase

  flopenr #($bits(ctrlE)) ctrlflopDE (clk, flush, ~stallE, ctrlD, ctrlE);
  //////////////////////////////////////////////////////////////////////////////////////
  // EXECUTE
  //////////////////////////////////////////////////////////////////////////////////////

  regfile regfile(.rd, .rs1(rs1E), .rs2(rs2E), 
                  .rdAddr(ctrlE.rdAddr), .addr1(ctrlE.addr1), .addr2(ctrlE.addr2),
                  .rdWen(ctrlE.rdWen));

  aluE aluE (.src1, .src2, aluOp(ctrlE.aluOpM) .aluOut(aluOutE), .flg(flgE));

  flopenr #($bits(ctrlM)) ctrlflopEM (clk, flush, ~stallM, ctrlD, ctrlE);
  flopenr #(12) aluflopEM (clk, flush, ~stallM, {aluOutE, flgE}, {aluOutM, flgM});
  //////////////////////////////////////////////////////////////////////////////////////
  // MEMORY
  //////////////////////////////////////////////////////////////////////////////////////

  

endmodule