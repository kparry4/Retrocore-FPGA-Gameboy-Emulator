import defs::*;

module decoder (
  input logic rst, clk,
  input  logic [15:0] memData,
  input  logic memValid,
  output logic [7:0] n,
  output ctrlD_t ctrl
);

  logic [7:0] op;
  logic [2:0] mpc, prempc, newmpc;
  logic [1:0] preInstrSz;
  logic [3:0][7:0] instr, preInstr;
  logic gotInstr;
  logic instrValid;

  
  flopenr #(32) instrBuf(clk, flush, ~stallD, instr, preInstr);
  // put data in proper position
  assign instr = instrValid ? {memData, preInstr[3:2]} : preInstr;
  // tried getting new instruction if prempc > 2
  assign gotInstr = |prempc[2:1];
  // assign ctrl.getInstr = |newmpc[2:1];
  // is the instruction in memData valid
  assign instrValid = memValid & gotInstr;
  // subtract 2 if get new instruction
  assign mpc = prempc - {instrValid,1'b0};
  assign newmpc = instrValid ? mpc+ctrl.instrSz : mpc;
  
  // flopenr #(2) instrSzBuf(clk, flush, ~stallD, ctrl.instrSz, preInstrSz);
  always_ff @(posedge clk) begin : mpcflop
    if(rst) prempc = 4;
    else prempc = newmpc;
  end

  // select the proper parts of instruction
  assign op = instr[mpc];
  assign n = instr[mpc+1];

  // register layout
  // B C D E H L F A SP PC WZ(temp storage)
  // 0 1 2 3 4 5 6 7
  // you can't load to F

  // pcSel_instrSz_aluOp_addr1_addr2_rdAddr_rdWen_rdSel
  always_comb begin
    casez(op)
      // nop
      8'b00000000: ctrl = {PC_ADD,2'h1,ALU_DC,DC,DC,DC,1'b0,RD_DC};
      // ld r, n    op rd | n
      // rd = r
      8'b00???110: ctrl = {PC_ADD,2'h2,ALU_DC,DC,DC,op[5:3],1'b1,RD_N};
      // ld r, r' op rd rs2
      // r <- r'
      8'b01??????: ctrl = {PC_ADD,2'h1,ALU_SRC1,op[2:0],DC,op[5:3],1'b1,RD_ALU};
      // add r    op rs2
      // rd = A+r
      8'b10000???: ctrl = {PC_ADD,2'h1,ALU_ADD,A,instr[2:0],A,1'b1,RD_ALU};
      default: ctrl = {PC_DC,1'b0,ALU_DC,DC,DC,DC,1'b0,RD_DC};

    endcase
  end

endmodule