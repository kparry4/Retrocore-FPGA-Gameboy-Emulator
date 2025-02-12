import defs::*;

module cpu (
  input logic clk,
  input  logic rst,
  input  logic [15:0] memData,
  input logic memValid,
  output logic [15:0] memAdr
);  
  logic [7:0] rs1, rs2;
  logic [7:0] src1, src2;
  logic [7:0] aluOut;
  logic [15:0] iduIn, iduOut;
  logic [7:0] rd;
  logic [7:0] mem;
  logic [3:0] flg;
  logic [15:0] npc, pc;
  ctrl_t ctrl;
  //////////////////////////////////////////////////////////////////////////////////////
  // DECODE/FETCH
  //////////////////////////////////////////////////////////////////////////////////////

  assign mem = pc[0] ? memData[7:0] : memData[15:8];
  // control unit
  decoder decoder(.instr(mem), 
                  .memValid, 
                  .ctrl(ctrl), 
                  .rst, 
                  .clk);


  //////////////////////////////////////////////////////////////////////////////////////
  // EXECUTE/MEMORY
  //////////////////////////////////////////////////////////////////////////////////////

  // pc register
  flopr #(16) pcflop(clk, rst, npc, pc);
  // select next pc
  always_comb case(ctrl.pcSel)
    PC_IDU: npc = iduOut;
    default: npc = 'x;
  endcase

  // select the data
  always_comb case(ctrl.adrSel)
    ADR_PC: memAdr = pc;
    default: memAdr = 'x;
  endcase

  regfile regfile(.clk, .rd, .rs1, .rs2, 
                  .rdAdr(ctrl.rd), .adr1(ctrl.rs1), .adr2(ctrl.rs2),
                  .rdWen(ctrl.rdWen));
                  
  assign src1 = rs1;
  assign src2 = rs2;

  alu alu(.src1, 
          .src2,
          .aluOp(ctrl.aluOp),
          .flg,
          .aluOut);
  
  assign iduIn = pc;

  assign iduOut = iduIn+1;

  always_comb
    case(ctrl.rdSel)
      RD_ALU: rd = aluOut;
      RD_MEM: rd = mem;
      default: rd = 'x;
    endcase


  

endmodule