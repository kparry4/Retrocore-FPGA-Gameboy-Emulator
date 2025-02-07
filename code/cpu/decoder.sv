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
  logic [3:0][7:0] preInstr;
  logic [4:0][7:0] instr;
  logic addInstr;
  logic instrValid;

  
  // flopenr #(32) instrBuf(clk, rst, 1'b1, instr[3:0], preInstr);
  always_ff @(posedge clk) begin : instrbuf
    // fill with an illegal instruction
    if(rst) preInstr = 32'hdddddddd;
    else preInstr = instr[3:0];
  end
  // put data in proper position
  assign instr = {8'hdd, instrValid ? {memData, preInstr[3:2]} : preInstr};
  // tried getting new instruction if prempc > 2
  assign addInstr = |prempc[2:1];
  // is the instruction in memData valid
  assign instrValid = memValid & addInstr;
  // subtract 2 if get new instruction
  assign mpc = prempc - {instrValid,1'b0};
  assign newmpc = mpc+ctrl.instrSz;
  
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
      // illegal
      8'hDD: ctrl = {PC_ADD,1'b0,ALU_DC,DC,DC,DC,1'b0,RD_DC};
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
      default: ctrl = {PC_ADD,1'b0,ALU_DC,DC,DC,DC,1'b0,RD_DC};

    endcase
    ctrl.adjpc = newmpc[1] & ~newmpc[2];
  end

endmodule