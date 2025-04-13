//import defs::*;
`include "defs.svh"
module cpu (
  input logic clk,
  input  logic rst,
  input  logic [15:0] memData,
  input logic memValid,
  input  logic [7:0] ie,
  input  logic [7:0] iflg,
  output logic interupt,
  output logic stop,
  output logic [15:0] memWdata,
  output logic [15:0] memWadr,
  output logic memWen,
  output logic [15:0] memAdr,
  output logic [15:0] pc,
  output logic [15:0] npc,
  output logic done
  
);  
  logic [7:0] rs1, rs2;
  logic [7:0] src1, src2;
  logic [7:0] aluOut;
  logic [15:0] iduIn, iduOut;
  logic [7:0] rd2;
  logic [15:0] rd;
  logic [15:0] rs16;
  logic [7:0] mem, n, pre, intAdr;
  logic [3:0] flg;
  logic [7:0] newiflg;
  logic carry, hcarry, nflg, jmp, zflg;
  //logic [15:0] npc, pc;
  ctrl_t ctrl;
  logic preAdr; // lsb of previous acessed memory
  assign done = ctrl.done;
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
                  .interupt_mmu(interupt),
                  .ie,
                  .iflg,
                  .stop,
                  .pre, 
                  .jmp,
                  .clk);

  always_comb casez(ie[4:0]&iflg[4:0])
    5'b10000: intAdr = 8'h60;
    5'b?1000: intAdr = 8'h58;
    5'b??100: intAdr = 8'h50;
    5'b???10: intAdr = 8'h48;
    5'b????1: intAdr = 8'h40;
    default: intAdr = 'x;
  endcase
  // pc register
  flopenr #(16,16'h100) pcflop(clk, rst, ctrl.pcen, npc, pc);
  // select next pc
  always_comb case(ctrl.pcSel)
    PC_1: npc = pc+1;
    PC_M1: npc = pc-1;
    PC_IDU: npc = iduOut+1;
    PC_RS: npc = rs16+1;
    PC_PRE: npc = pre+1;
    PC_INT: npc = intAdr+1;
    default: npc = 'x;
  endcase
  always_comb case(ctrl.cc)
    CC_NZ: jmp = ~zflg;
    CC_Z: jmp =  zflg;
    CC_NC: jmp =  ~carry;
    CC_C: jmp =  carry;
    default: jmp = 'x;
  endcase

  // select the data
  always_comb case(ctrl.adrSel)
    ADR_PC: memAdr = pc;
    ADR_FF: memAdr = {8'hff,rs1};
    ADR_FFN: memAdr = {8'hff,mem};
    ADR_RS: memAdr = rs16;
    ADR_NRS: memAdr = {mem,rs1};
    ADR_IDU: memAdr = iduOut;
    ADR_PRE: memAdr = pre;
    ADR_INT: memAdr = intAdr;
    default: memAdr = 'x;
  endcase

  regfile regfile(.clk, 
                  .rst, 
                  .rd, 
                  .rd2,
                  .flg,
                  .zflg,
                  .rs1, 
                  .rs2,
                  .rs16, 
                  .carry,
                  .hcarry,
                  .nflg,
                  .rdAdr(ctrl.rd), 
                  .rd2Adr(ctrl.rd2), 
                  .adr1(ctrl.rs1), 
                  .adr2(ctrl.rs2),
                  .rdW16(ctrl.rdW16),
                  .flgWen(ctrl.flgWen),
                  .rdWen(ctrl.rdWen),
                  .rd2Wen(ctrl.rd2Wen));
                  
  always_comb case(ctrl.rs1Sel)
    RS1_RS1: src1 = rs1;
    RS1_MEM: src1 = mem;
    default: src1 = 'x;
  endcase
  
  always_comb case(ctrl.rs2Sel)
    RS2_RS2: src2 = rs2;
    RS2_MEM: src2 = mem;
    RS2_1: src2 = 1;
    default: src2 = 'x;
  endcase


  alu alu(.src1, 
          .src2,
          .aluOp(ctrl.aluOp),
          .flg,
          .b(ctrl.b),
          .nflg,
          .flgKill(ctrl.flgKill),
          .flgSet(ctrl.flgSet),
          .cin(carry),
          .hcin(hcarry),
          .aluOut);
  
  //seclet the input to the idu
  always_comb case(ctrl.iduSel)
    IDU_PCE: iduIn = pc;
    IDU_RS: iduIn = rs16;
    default: iduIn = 'x;
  endcase

  // do idu opperation
  assign iduOut = ctrl.iduSub ? iduIn-1 : 
                  iduIn+((ctrl.iduSel==IDU_PCE) ? {{8{src1[7]}},src1} : 1);

  // new flag register write data
  always_comb casez(ie[4:0]&iflg[4:0])
    5'b10000: newiflg = {4'b0,iflg[3:0]};
    5'b?1000: newiflg = {4'b0,iflg[4],4'b0};
    5'b??100: newiflg = {4'b0,iflg[4:3],3'b0};
    5'b???10: newiflg = {4'b0,iflg[4:2],2'b0};
    5'b????1: newiflg = {4'b0,iflg[4:1],1'b0};
    default: newiflg = 'x;
  endcase
  // memory write data calculation
  always_comb case(ctrl.wadrSel)
    WADR_RS: memWadr = rs16;
    WADR_FF: memWadr = {8'hff,rs1};
    WADR_FLG: memWadr = 16'hff0f;
    default: memWadr = 'x;
  endcase

  logic [7:0] rs2old;
  logic [15:1] wadrOld;
  logic [15:1] tmp;
  assign tmp = memWadr[15:1];
  flopenr #(23) memfwdflop(clk,rst,memWen,{memWadr[0]?memWdata[15:8]:memWdata[7:0],tmp},{rs2old,wadrOld});
  always_comb case(ctrl.wdatSel)
    WDAT_RS2: memWdata = memWadr[0] ? memWadr[15:1]==wadrOld ? {rs2, rs2old} : {rs2, memData[7:0]} : 
                                      memWadr[15:1]==wadrOld ? {rs2old, rs2} : {memData[15:8], rs2};
    // if youre writting pc you better be writting the entire pc
    WDAT_PCL: memWdata = memWadr[0] ? {pc[7:0], memData[7:0]} : pc;
    WDAT_PC: memWdata = memWadr[0] ? pc : {memData[15:8], pc[15:8]}; 
    WDAT_FLG: memWdata = {newiflg,8'b0}; 
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
      RD_NRS: rd = {mem,rs1};
      RD_RS16: rd = rs16;
      default: rd = 'x;
    endcase
  assign rd2 = mem;


  

endmodule
