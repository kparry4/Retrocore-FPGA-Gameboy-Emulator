import defs::*;

module decoder (
  input  logic [15:0] memData,
  input  logic memValid,
  input logic rst,
  output logic [7:0] n,
  output ctrlD_t ctrl
);

  logic [7:0] op;
  logic [2:0] mpc;
  logic [3:0][7:0] instr;
  
  // flopenr #(32) instrBuf(clk, flush, ~stallD, nextInstr, instr);
  // *** add instr buffer
  assign instr = {memData, 16'b0};
  assign mpc = 2;
  
  // always_ff @(negedge clk) begin : mpcflop
  //   if(rst) prempc = 4;
  //   else prempc = mpc;
  // end

  // select the proper parts of instruction
  assign op = instr[mpc];
  assign n = instr[mpc+1];

  // register layout
  // B C D E H L F A SP PC WZ(temp storage)
  // 0 1 2 3 4 5 6 7

  // pcSel_instrSz_aluOp_addr1_addr2_rdAddr_rdWen_rdSel
  always_comb begin
    casez(op)
      // nop
      8'b00000000: ctrl = {PC_ADD,2'h1,ALU_DC,DC,DC,DC,1'b0,RD_DC};
      // ld r, n    op rd | n
      // rd = r
      8'b00???110: ctrl = {PC_ADD,2'h2,ALU_DC,DC,DC,op[5:3],1'b1,RD_N};
      // add r    op rs2
      // rd = A+r
      8'b10000???: ctrl = {PC_ADD,2'h1,ALU_ADD,A,instr[2:0],A,1'b1,RD_ALU};
      // ld r, r' op rs1 rs2
      // r <- r'
      // 8'b01??????: ctrl = {PC_ADD,2'h1};
      default: ctrl = {PC_DC,1'bx,ALU_DC,DC,DC,DC,1'b0,RD_DC};

    endcase
  end

endmodule