
module decode (
  input  logic [31:0] memData,
  output ctrl_t ctrl
);

  logic [7:0] op,n;
  logic [1:0] mpc;
  logic [63:0] nextInstr;
  
  flopenr #(64) instrBuf(clk, flush, ~stallD, nextInstr, instrD);
  // if go through all of first mank intructions move
  // the second bank into the first and adjust the micro pc
  assign getInstr = n > 3;
  assign mpcNext = getInstr ? mpc-4 : mpc+instrSz;
  assign nextInstr = getInstr ? {memData, instrD[7:4]} : instrD;

  flopenr #(2) mpcflop(clk, rst, stallD, mpcNext, mpc);

  // select the proper parts of instruction
  assign op = instrs[mpc];
  assign n = instrs[mpc+1];

  // register layout
  // B C D E H L F A SP PC WZ(temp storage)
  // 0 1 2 3 4 5 6 7

  // pcSel_instrSz_aluOp_addr1_addr2_rdAddr_rdWen_rdSel
  always_comb begin
    case(op)
      // nop
      8'b00000000: ctrl = {PC_ADD,2'h1,ALU_DC,DC,DC,1'b0,RD_DC};
      // ld r, n    op rs1 | n
      // rd = A+r
      8'b00???110: ctrl = {PC_ADD,2'h2,ALU_DC,DC,DC,instr[7:4],1'b1,RD_N};
      // add r    op rs2
      // rd = A+r
      8'b10000???: ctrl = {PC_ADD,2'h1,ALU_ADD,A,instr[2:0],A,1'b1,RD_ALU};
      // ld r, r' op rs1 rs2
      // r <- r'
      // 8'b01??????: ctrl = {PC_ADD,2'h1};
      default: ctrl = 'x;

    endcase
  end

endmodule