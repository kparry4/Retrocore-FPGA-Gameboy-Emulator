//import defs::*;
`include "defs.svh"
module decoder (
  input logic rst, clk,
  input  logic [7:0] instr,
  input  logic memValid,
  output ctrl_t ctrl
);

  mpc_t mpc_enum;
  logic [$bits(mpc_enum)-1:0] mpc,nmpc;
  logic [7:0] op, nextOp;
  logic [7:0] nextInstr;

  assign mpc_enum = mpc_t'(mpc);
  assign nextInstr = ctrl.useOp ? nextOp : instr;
  // opcode flop
  flopenr #(8) curropreg (clk,rst,ctrl.done&memValid,nextInstr,op);
  flopenr #(8) nextopreg (clk,rst,ctrl.iren,instr,nextOp);
  
  // microcode flop
  flopr #($bits(mpc)) mpcflop (clk,rst,nmpc,mpc);
  
  // select the proper next microcode addr
  always_comb begin
    if(memValid) begin
      // if finished an instr then get new mpc
      if(ctrl.done) casez(nextInstr)
        // 8'hCB: nmpc=;
        8'b00000000: nmpc=NOP;
        8'b00001010: nmpc=LD_ABC;
        8'b00011010: nmpc=LD_ADE;
        8'b00000010: nmpc=LD_BCA;
        8'b00010010: nmpc=LD_DEA;
        8'b11111010: nmpc=LD_ANN;
        8'b00110110: nmpc=LD_HLN;
        8'b11110010: nmpc=LDH_AC;
        8'b11100010: nmpc=LDH_CA;
        8'b11110000: nmpc=LDH_AN;
        8'b11100010: nmpc=LDH_NA;
        8'b00111010: nmpc=LD_AHLD;
        8'b00110010: nmpc=LD_HLDA;
        8'b00101010: nmpc=LD_AHLI;
        8'b00100010: nmpc=LD_HLIA;
        8'b00001000: nmpc=LD_NNSP;
        8'b11111001: nmpc=LD_SPHL;
        8'b11111000: nmpc=LD_HLSPE;
        8'b10000110: nmpc=ADD_HL;
        8'b11000110: nmpc=ADD_N;
        8'b10001110: nmpc=ADC_HL;
        8'b11001110: nmpc=ADC_N;
        8'b10010110: nmpc=SUB_HL;
        8'b11010110: nmpc=SUB_N;
        8'b10011110: nmpc=SBC_HL;
        8'b11011110: nmpc=SBC_N;
        8'b10011110: nmpc=CP_HL;
        8'b11111110: nmpc=CP_N;
        8'b10100110: nmpc=AND_HL;
        8'b11100110: nmpc=AND_N;
        8'b10110110: nmpc=OR_HL;
        8'b11110110: nmpc=OR_N;
        8'b10101110: nmpc=XOR_HL;
        8'b11101110: nmpc=XOR_N;
        8'b00110100: nmpc=INC_HL;
        8'b00110101: nmpc=DEC_HL;
        8'b00111111: nmpc=CCF;
        8'b00110111: nmpc=SCF;
        8'b00100111: nmpc=DAA;
        8'b00101111: nmpc=CPL;
        8'b11101000: nmpc=ADD_SPE;
        8'b00000111: nmpc=RLCA;
        8'b00001111: nmpc=RRCA;
        8'b00010111: nmpc=RRCA;
        8'b00011111: nmpc=RRA;
        8'b11000011: nmpc=JP_NN;
        8'b11101001: nmpc=JP_HL;
        8'b00011000: nmpc=JR_E;
        8'b11001101: nmpc=CALL_NN;
        8'b11001001: nmpc=RET;
        8'b11011001: nmpc=RETI;
        8'b11110011: nmpc=DI;
        8'b11111011: nmpc=EI;
        8'b00010000: nmpc=STOP;
        8'b01110110: nmpc=HALT;
        8'b11???111: nmpc=RST_N;
        8'b110??000: nmpc=RET_CC;
        8'b110??100: nmpc=CALL_CCNN;
        8'b110??010: nmpc=JP_CCNN;
        8'b001??000: nmpc=JR_CCE;
        8'b00??0011: nmpc=INC_RR;
        8'b00??1011: nmpc=DEC_RR;
        8'b00??1001: nmpc=ADD_HLRR;
        8'b11??0101: nmpc=PUSH;
        8'b11??0001: nmpc=POP;
        8'b00??0001: nmpc=LD_RRNN;
        8'b10000???: nmpc=ADD_R;
        8'b10001???: nmpc=ADC_R;
        8'b10010???: nmpc=SUB_R;
        8'b10011???: nmpc=SBC_R;
        8'b10111???: nmpc=CP_R;
        8'b10100???: nmpc=AND_R;
        8'b10110???: nmpc=OR_R;
        8'b10101???: nmpc=XOR_R;
        8'b00???110: nmpc=LD_RN;
        8'b01???110: nmpc=LD_RHL;
        8'b00???100: nmpc=INC_R;
        8'b00???101: nmpc=DEC_R;
        8'b01110???: nmpc=LD_HLR;
        8'b01??????: nmpc=LD_RR;
        default: nmpc = BAD;
      endcase
      // CB-prefixed
      // casez(nextInstr)
      //   8'b00000110: nmpc=RLC_HL;
      //   8'b00001110: nmpc=RRC_HL;
      //   8'b00010110: nmpc=RL_HL;
      //   8'b00011110: nmpc=RR_HL;
      //   8'b00100110: nmpc=SLA_HL;
      //   8'b00101110: nmpc=SLA_HL;
      //   8'b00110110: nmpc=SWAP_HL;
      //   8'b00111110: nmpc=SRL_HL;
      //   8'b01???110: nmpc=BIT_HL;
      //   8'b10???110: nmpc=RES_HL;
      //   8'b11???110: nmpc=SET_HL;
      //   8'b00000???: nmpc=RLC_R;
      //   8'b00001???: nmpc=RRC_R;
      //   8'b00010???: nmpc=RL_R;
      //   8'b00011???: nmpc=RR_R;
      //   8'b00100???: nmpc=SLA_R;
      //   8'b00101???: nmpc=SRA_R;
      //   8'b00110???: nmpc=SWAP_R;
      //   8'b00111???: nmpc=SRL_R;
      //   8'b01??????: nmpc=BIT_R;
      //   8'b10??????: nmpc=RES_R;
      //   8'b11??????: nmpc=SET_R;
      //   default: nmpc = BAD;
      // endcase

      // if instr not done mpc++
      else nmpc = mpc+1;
    end else nmpc = mpc;
  end

  // register layout
  // B C D E H L F A SP PC WZ(temp storage)
  // 0 1 2 3 4 5 6 7
  // you can't load to F

  // OTHER:
  //   - pc's are incremented by the prev instr
  // microcode LUT
  always_comb begin
    // basic case
    ctrl.pcSel = PC_IDU;
    ctrl.adrSel = ADR_PC;
    ctrl.wadrSel = WADR_DC;
    ctrl.wdatSel = WDAT_DC;
    ctrl.memWen = 0;
    ctrl.iduSel = IDU_PC;
    ctrl.pcen = 1;
    ctrl.iduSub = 0;
    ctrl.rs1 = DC;
    ctrl.rs2 = DC;
    ctrl.aluOp = ALU_DC;
    ctrl.rd = DC;
    ctrl.rd2 = DC;
    ctrl.rd2Sel = RD2_DC;
    ctrl.rd2Wen = 0;
    ctrl.rdSel = RD_DC;
    ctrl.rdWen = 0;
    ctrl.rdW16 = 0;
    ctrl.flgWen = 0;
    ctrl.iren = 0;
    ctrl.useOp = 0;
    ctrl.flgKill = 4'b1111;
    ctrl.done = 0;
    // manual selection case
    case(mpc)
      BAD:  begin
      end
      // nop
      NOP: begin
        ctrl.done = 1;
      end
      // ld r, n    op rd | n
      // rd = r
      LD_RN:  begin
        ctrl.rd = Z;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
      end
      LD_RN2: begin
        ctrl.rs1 = Z;
        ctrl.aluOp = ALU_R;
        ctrl.rd = reg_t'(op[5:3]);
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // ld r, r' op rd rs2
      // r <- r'
      LD_RR:  begin
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_R;
        ctrl.rd = reg_t'(op[5:3]);
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // ld r,(hl)
      // r <- r'
      LD_RHL:  begin
        // get hl and send as addr
        // grab the next op code
        ctrl.rs1 = H;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_RHL2:  begin
        // get the next instr
        // load the previously grabbed memory 
        ctrl.rd = reg_t'(op[5:3]);
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld (hl),r
      // (hl) <- r
      LD_HLR:  begin
        // read HL from memory
        ctrl.rs1 = H;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_HLR2:  begin
        // use H to insert data in correct word
        // then write to memory
        ctrl.rs1 = H;
        ctrl.rs2 = reg_t'(op[2:0]);
        ctrl.wadrSel = WADR_RS;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld (hl),n
      // (hl) <- n
      LD_HLN:  begin
        // read HL from memory and save n in Z
        ctrl.rs1 = H;
        ctrl.rd = Z;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_HLN2:  begin
        // use H to insert rs2 data into correct spot
        // then write to memory
        ctrl.rs1 = H;
        ctrl.rs2 = Z;
        ctrl.wadrSel = WADR_RS;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.useOp = 1;
        ctrl.memWen = 1;
      end
      LD_HLN3:  begin
        // nothin
        ctrl.done = 1;
      end
      // ld A,(BC)
      // A <- BC
      LD_ABC:  begin
        // get bc and send as addr
        // grab the next op code
        ctrl.rs1 = B;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_ABC2:  begin
        // get the next instr
        // load the previously grabbed memory 
        ctrl.rd = A;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld A,(DE)
      // A <- DE
      LD_ADE:  begin
        // get DE and send as addr
        // grab the next op code
        ctrl.rs1 = D;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_ADE2:  begin
        // get the next instr
        // load the previously grabbed memory 
        ctrl.rd = A;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld (bc),a
      // (bc) <- a
      LD_BCA:  begin
        // *** could improve by storing in WZ?
        // read bc from memory
        ctrl.rs1 = B;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_BCA2:  begin
        // use BC to insert data in correct word
        // then write to memory
        ctrl.rs1 = B;
        ctrl.rs2 = A;
        ctrl.wadrSel = WADR_RS;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld (de),a
      // (de) <- a
      LD_DEA:  begin
        // *** could improve by storing in WZ?
        // read bc from memory
        ctrl.rs1 = D;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_DEA2:  begin
        // use de to insert data in correct word
        // then write to memory
        ctrl.rs1 = D;
        ctrl.rs2 = A;
        ctrl.wadrSel = WADR_RS;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld A,nn
      // (nn)<-A
      LD_ANN:  begin
        // save lsbs nn in Z
        ctrl.rd = Z;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
      end
      LD_ANN2:  begin
        // save msbs nn in W
        ctrl.rd = W;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
      end
      LD_ANN3:  begin
        // read addr from memory
        ctrl.rs1 = W;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_ANN4:  begin
        // write memory into A
        ctrl.rd = A;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld nn,a
      // A<-(nn)
      LD_NNA:  begin
        // save lsbs nn in Z
        ctrl.rd = Z;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
      end
      LD_NNA2:  begin
        // save msbs nn in W
        ctrl.rd = W;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
      end
      LD_NNA3:  begin
        // read addr from memory
        ctrl.rs1 = W;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_NNA4:  begin
        // use W to write to correct byte
        // and write to memory
        ctrl.rs1 = W;
        ctrl.rs2 = A;
        ctrl.wadrSel = WADR_RS;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld A,(ff00+C)
      // A <- (ff00+C)
      LDH_AC:  begin
        // get ff00+C and send as addr
        // grab the next op code
        ctrl.rs1 = C;
        ctrl.adrSel = ADR_FF;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LDH_AC2:  begin
        // get the next instr
        // load the previously grabbed memory 
        ctrl.rd = A;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld (ff00+C),a
      // (ff00+C) <- a
      LDH_CA:  begin
        // read ffc from memory
        ctrl.rs1 = C;
        ctrl.adrSel = ADR_FF;
        ctrl.pcen = 0;
        // no iren
      end
      LDH_CA2:  begin
        // use de to insert data in correct word
        // then write to memory
        ctrl.rs1 = C;
        ctrl.rs2 = A;
        ctrl.wadrSel = WADR_FF;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        ctrl.done = 1;
      end
      // ld A,(n)
      // A <- (n)
      LDH_AN:  begin
        // save n in Z
        ctrl.rd = Z;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
      end
      LDH_AN2:  begin
        // read addr from memory
        ctrl.rs1 = Z;
        ctrl.adrSel = ADR_FF;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LDH_AN3:  begin
        // write memory into A
        ctrl.rd = A;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld (n), A
      // (n) <- A
      LDH_NA:  begin
        // save n in Z
        ctrl.rd = Z;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
      end
      LDH_NA2:  begin
        // read addr from memory
        ctrl.rs1 = Z;
        ctrl.adrSel = ADR_FF;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LDH_NA3:  begin
        // write A into memory
        ctrl.rs1 = Z;
        ctrl.rs2 = A;
        ctrl.wadrSel = WADR_FF;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld A,(hl-)
      // A <- (HL) HL--
      LD_AHLD:  begin
        // get hl and send as addr
        // decremnt HL
        // grab the next op code
        ctrl.rs1 = H;
        ctrl.adrSel = ADR_RS;
        ctrl.iduSel = IDU_RS;
        ctrl.iduSub = 1;
        ctrl.rdSel = RD_IDU;
        ctrl.rd = H;
        ctrl.rdWen = 1;
        ctrl.rdW16 = 1;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_AHLD2:  begin
        // get the next instr
        // load the previously grabbed memory 
        ctrl.rd = A;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld (hl-),A
      // (hl-) <- A
      LD_HLDA:  begin
        // read HL from memory
        ctrl.rs1 = H;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_HLDA2:  begin
        // use H to insert data in correct word
        // decrement HL
        // then write to memory
        ctrl.rs1 = H;
        ctrl.rs2 = A;
        ctrl.wadrSel = WADR_RS;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        ctrl.iduSel = IDU_RS;
        ctrl.iduSub = 1;
        ctrl.rdSel = RD_IDU;
        ctrl.rd = H;
        ctrl.rdWen = 1;
        ctrl.rdW16 = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld A,(hl-)
      // A <- (HL) HL--
      LD_AHLI:  begin
        // get hl and send as addr
        // decremnt HL
        // grab the next op code
        ctrl.rs1 = H;
        ctrl.adrSel = ADR_RS;
        ctrl.iduSel = IDU_RS;
        ctrl.rdSel = RD_IDU;
        ctrl.rd = H;
        ctrl.rdWen = 1;
        ctrl.rdW16 = 1;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_AHLI2:  begin
        // get the next instr
        // load the previously grabbed memory 
        ctrl.rd = A;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld (hl-),A
      // (hl-) <- A
      LD_HLIA:  begin
        // read HL from memory
        ctrl.rs1 = H;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_HLIA2:  begin
        // use H to insert data in correct word
        // decrement HL
        // then write to memory
        ctrl.rs1 = H;
        ctrl.rs2 = A;
        ctrl.wadrSel = WADR_RS;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        ctrl.iduSel = IDU_RS;
        ctrl.rdSel = RD_IDU;
        ctrl.rd = H;
        ctrl.rdWen = 1;
        ctrl.rdW16 = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld rr, nn
      // rd = nn
      LD_RRNN:  begin
        ctrl.rd = Z;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
      end
      LD_RRNN2:  begin
        ctrl.rd = W;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
      end
      LD_RRNN3: begin
        ctrl.rs1 = W;
        ctrl.rd = reg_t'(op[5:3]);
        ctrl.rdW16 = 1;
        ctrl.rdSel = RD_RS16;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // ld (nn),sp
      // (nn) = sp
      LD_NNSP:  begin
        // save lsb of nn
        ctrl.rd = Z;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
      end
      LD_NNSP2:  begin
        // save msb of nn
        // read data from mem
        ctrl.rd = W;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
        ctrl.rs1 = Z;
        ctrl.adrSel = ADR_NRS;
        ctrl.pcen = 0;
        // dont set iren!
      end
      LD_NNSP3: begin
        // write lsbs of sp to addr
        ctrl.rs1 = W;
        ctrl.rs2 = SPL;
        ctrl.wadrSel = WADR_RS;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        // WZ++
        ctrl.iduSel = IDU_RS;
        ctrl.rdSel = RD_IDU;
        ctrl.rd = W;
        ctrl.rdW16 = 1;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
        // dont set iren!
      end
      LD_NNSP4: begin
        // read nn+1
        ctrl.rs1 = W;
        ctrl.adrSel = ADR_RS;
        // ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_NNSP5: begin
        // write msbs of sp 
        ctrl.rs1 = W;
        ctrl.rs2 = SP;
        ctrl.wadrSel = WADR_RS;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld sp, hl
      // sp = hl
      LD_SPHL:  begin
        ctrl.rs1 = H;
        ctrl.rd = SP;
        ctrl.rdSel = RD_RS16;
        ctrl.rdWen = 1;
        ctrl.rdW16 = 1;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_SPHL2:  begin
        // do nothin
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // push rr
      // sp-- (sp)= msb rr sp-- (sp)=lsb rr
      PUSH:  begin
        // subtract sp
        ctrl.rd = SP;
        ctrl.rs1 = SP;
        ctrl.iduSel = IDU_RS;
        ctrl.iduSub = 1;
        ctrl.rdSel = RD_IDU;
        ctrl.rdWen = 1;
        ctrl.rdW16 = 1;
        ctrl.pcen = 0;
        ctrl.iren = 1;
        // read sp-- from memory
        ctrl.adrSel = ADR_IDU;
      end
      PUSH2:  begin
        // write msbs of sp to memory
        ctrl.rs1 = SP;
        ctrl.rs2 = reg_t'({op[5:4],&op[5:4]}); // A is 111 others are xx0
        ctrl.wadrSel = WADR_RS;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        ctrl.pcen = 0;
        // dont set iren!
      end
      PUSH3: begin
        // SP--
        ctrl.rs1 = SP;
        ctrl.iduSel = IDU_RS;
        ctrl.iduSub = 1;
        ctrl.rdSel = RD_IDU;
        ctrl.rd = SP;
        ctrl.rdW16 = 1;
        ctrl.rdWen = 1;
        // read sp-- from memory
        ctrl.adrSel = ADR_IDU;
        ctrl.pcen = 0;
        // dont set iren!
      end
      PUSH4: begin
        // write lsbs to memory
        ctrl.rs1 = SP;
        ctrl.rs2 = reg_t'({op[5:4],~&op[5:4]}); // F is 110 others are xx1
        ctrl.wadrSel = WADR_RS;
        ctrl.wdatSel = WDAT_RS2;
        ctrl.memWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // pop rr
      // rr lsb = (sp) sp++ rr msb = (sp) sp++
      POP:  begin
        // add sp
        ctrl.rd = SP;
        ctrl.rs1 = SP;
        ctrl.iduSel = IDU_RS;
        ctrl.rdSel = RD_IDU;
        ctrl.rdWen = 1;
        ctrl.rdW16 = 1;
        // read sp
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      POP2:  begin
        // store lsbs
        ctrl.rd = reg_t'({op[5:4],~&op[5:4]}); // F is 110 others are xx1
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
        // read from sp
        ctrl.rs1 = SP;
        ctrl.iduSel = IDU_RS;
        ctrl.adrSel = ADR_RS;
        ctrl.pcen = 0;
        // dont set iren!
      end
      POP3: begin
        // store msbs
        ctrl.rd2 = reg_t'({op[5:4],&op[5:4]}); // A is 111 others are xx0
        ctrl.rd2Sel = RD2_MEM;
        ctrl.rd2Wen = 1;
        // SP++
        ctrl.rd = SP;
        ctrl.rs1 = SP;
        ctrl.iduSel = IDU_RS;
        ctrl.rdSel = RD_IDU;
        // ctrl.adrSel = ADR_IDU;
        ctrl.rdWen = 1;
        ctrl.rdW16 = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ld hl,sp+e
      // hl = sp+e
      LD_HLSPE:  begin
        // store e
        ctrl.rd = Z;
        ctrl.rdSel = RD_MEM;
        ctrl.rdWen = 1;
      end
      LD_HLSPE2:  begin
        // L = lsbs sp + e
        ctrl.rs1 = SPL;
        ctrl.rs2 = Z;
        ctrl.rd = L;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.aluOp = ALU_ADD;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      LD_HLSPE3: begin
        // H = msbs sp + carry
        ctrl.rs1 = SP;
        ctrl.rs2 = Z;
        ctrl.rd = H;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b0011;
        ctrl.aluOp = ALU_ADD2;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // add r
      // A += R z0hc
      ADD_R:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_ADD;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // adc r
      // A += R+c z0hc
      ADC_R:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_ADC;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end

    endcase
  end

endmodule