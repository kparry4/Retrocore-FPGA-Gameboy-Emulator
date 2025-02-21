import defs::*;

module cpu (
  input logic clk,
  input  logic rst,
  input  logic [15:0] memData,
  input logic memValid,
  output logic [15:0] memWdata,
  output logic [15:0] memWadr,
  output logic memWen,
  output logic [15:0] memAdr
);  
  logic [7:0] rs1, rs2;
  logic [7:0] src1, src2;
  logic [7:0] aluOut;
  logic [15:0] iduIn, iduOut;
  logic [7:0] rd2;
  logic [15:0] rd;
  logic [15:0] rs16;
  logic [7:0] mem, n;
  logic [3:0] flg;
  logic [15:0] npc, pc;
  ctrl_t ctrl;
  logic preAdr; // lsb of previous acessed memory

//*** had to add a new adder for the pc in order to keep 
//    cycle accuracy with our diffrent type of memory
//    the other option was adding a register for rs1
//    which woulve cost more logic.

  flopr #(1) memAdrflop(clk, rst, memAdr[0], preAdr);
  assign mem = preAdr ? memData[15:8] : memData[7:0];
  assign n = mem;
  // control unit
  decoder decoder(.instr(mem), 
                  .memValid, 
                  .ctrl(ctrl), 
                  .rst, 
                  .clk);

  // pc register
  flopenr #(16) pcflop(clk, rst, ctrl.pcen, npc, pc);
  // select next pc
  always_comb case(ctrl.pcSel)
    PC_IDU: npc = pc+1;
    default: npc = 'x;
  endcase

  // select the data
  always_comb case(ctrl.adrSel)
    ADR_PC: memAdr = pc;
    ADR_FF: memAdr = {8'hff,rs1};
    ADR_RS: memAdr = rs16;
    ADR_NRS: memAdr = {mem,rs1};
    ADR_IDU: memAdr = iduOut;
    default: memAdr = 'x;
  endcase

  regfile regfile(.clk, 
                  .rst, 
                  .rd, 
                  .rd2, 
                  .rs1, 
                  .rs2,
                  .rs16, 
                  .rdAdr(ctrl.rd), 
                  .rd2Adr(ctrl.rd2), 
                  .adr1(ctrl.rs1), 
                  .adr2(ctrl.rs2),
                  .rdW16(ctrl.rdW16),
                  .rdWen(ctrl.rdWen),
                  .rd2Wen(ctrl.rd2Wen));
                  
  assign src1 = rs1;
  assign src2 = rs2;

  alu alu(.src1, 
          .src2,
          .aluOp(ctrl.aluOp),
          .flg,
          .aluOut);
  
  //seclet the input to the idu
  always_comb case(ctrl.iduSel)
    // IDU_PC: iduIn = pc;
    IDU_RS: iduIn = rs16;
    default: iduIn = 'x;
  endcase

  // do idu opperation
  assign iduOut = ctrl.iduSub ? iduIn-1 : iduIn+1;

  // memory write data calculation
  always_comb case(ctrl.wadrSel)
    WADR_RS: memWadr = rs16;
    WADR_FF: memWadr = rs16;
    default: memWadr = 'x;
  endcase
  always_comb case(ctrl.wadrSel)
    WADR_RS: memWdata = memWadr[0] ? {rs2, memData[7:0]} : {memData[15:8], rs2};
    // WADR_RS: memWdata = memWadr[0] ? {n, memData[7:0]} : {memData[15:8], n};
    default: memWdata = 'x;
  endcase
  assign memWen = ctrl.memWen;

  // select result to be written into register file
  always_comb
    case(ctrl.rdSel)
      RD_ALU: rd = {'0,aluOut};
      RD_MEM: rd = {'0,mem};
      RD_IDU: rd = iduOut;
      RD_RS16: rd = rs16;
      default: rd = 'x;
    endcase
  assign rd2 = mem;


  

endmodule