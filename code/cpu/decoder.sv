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
  logic cb,cbpre;

  assign mpc_enum = mpc_t'(mpc);
  assign nextInstr = ctrl.useOp ? nextOp : instr;
  // opcode flop
  flopenr #(8) curropreg (clk,rst,ctrl.done&memValid,nextInstr,op);
  flopenr #(8) nextopreg (clk,rst,ctrl.iren,instr,nextOp);
  flopr #(1) cbprereg (clk,rst,cb,cbpre);
  
  // microcode flop
  flopr #($bits(mpc)) mpcflop (clk,rst,nmpc,mpc);
  
  // select the proper next microcode addr
  always_comb begin
    if(memValid) begin
      cb=0;
      // if finished an instr then get new mpc
      if(ctrl.done) begin
        if(nextInstr == 8'hCB) cb=1;
        casez(nextInstr)
          8'hCB: nmpc=NOP;
          8'b00000000: nmpc=NOP;
          8'b00001010: nmpc=LD_ABC;
          8'b00011010: nmpc=LD_ADE;
          8'b00000010: nmpc=LD_BCA;
          8'b00010010: nmpc=LD_DEA;
          8'b11111010: nmpc=LD_ANN;
          8'b11101010: nmpc=LD_NNA;
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
        if(cbpre)
          casez(nextInstr)
            8'b00000110: nmpc=RLC_HL;
            8'b00001110: nmpc=RRC_HL;
            8'b00010110: nmpc=RL_HL;
            8'b00011110: nmpc=RR_HL;
            8'b00100110: nmpc=SLA_HL;
            8'b00101110: nmpc=SLA_HL;
            8'b00110110: nmpc=SWAP_HL;
            8'b00111110: nmpc=SRL_HL;
            8'b01???110: nmpc=BIT_HL;
            8'b10???110: nmpc=RES_HL;
            8'b11???110: nmpc=SET_HL;
            8'b00000???: nmpc=RLC_R;
            8'b00001???: nmpc=RRC_R;
            8'b00010???: nmpc=RL_R;
            8'b00011???: nmpc=RR_R;
            8'b00100???: nmpc=SLA_R;
            8'b00101???: nmpc=SRA_R;
            8'b00110???: nmpc=SWAP_R;
            8'b00111???: nmpc=SRL_R;
            8'b01??????: nmpc=BIT_R;
            8'b10??????: nmpc=RES_R;
            8'b11??????: nmpc=SET_R;
            default: nmpc = BAD;
          endcase
      end

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
    ctrl.rs2Sel = RS2_RS2;
    ctrl.rs1Sel = RS1_RS1;
    ctrl.rd2Wen = 0;
    ctrl.rdSel = RD_DC;
    ctrl.rdWen = 0;
    ctrl.rdW16 = 0;
    ctrl.flgWen = 0;
    ctrl.iren = 0;
    ctrl.useOp = 0;
    ctrl.flgKill = 4'b1111;
    ctrl.flgSet = 4'b0000;
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
      // add (HL)
      // A += (HL) z0hc
      ADD_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      ADD_HL2:  begin
        // get the next instr
        // load the previously grabbed memory 
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2Sel = RS2_MEM;
        ctrl.aluOp = ALU_ADD;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // add n
      // A += n z0hc
      ADD_N:  begin
        `READN
      end
      ADD_N2: begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = Z;
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
      // adc (HL)
      // A += (HL)+c z0hc
      ADC_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      ADC_HL2:  begin
        // get the next instr
        // do op
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2Sel = RS2_MEM;
        ctrl.aluOp = ALU_ADC;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // adc n
      // A += n + c z0hc
      ADC_N:  begin
        `READN
      end
      ADC_N2: begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = Z;
        ctrl.aluOp = ALU_ADC;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // sub r
      // A -= R z1hc
      SUB_R:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_SUB;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0100;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // sub (HL)
      // A -= (HL) z0hc
      SUB_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      SUB_HL2:  begin
        // get the next instr
        // do op
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2Sel = RS2_MEM;
        ctrl.aluOp = ALU_SUB;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0100;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // sub n
      // A -= n  z0hc
      SUB_N:  begin
        `READN
      end
      SUB_N2: begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = Z;
        ctrl.aluOp = ALU_SUB;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0100;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // sbc r
      // A = A-R-c z1hc
      SBC_R:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_SBC;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0100;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // sbc (HL)
      // A = A-(HL)-c z0hc
      SBC_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      SBC_HL2:  begin
        // get the next instr
        // do op
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2Sel = RS2_MEM;
        ctrl.aluOp = ALU_SBC;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0100;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // sbc n
      // A -= n + c z0hc
      SBC_N:  begin
        `READN
      end
      SBC_N2: begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = Z;
        ctrl.aluOp = ALU_SBC;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0100;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // cp r
      // A-R z1hc
      CP_R:  begin
        ctrl.rs1 = A;
        ctrl.rs2 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_SUB;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0100;
        ctrl.done = 1;
      end
      // sub (HL)
      // A - (HL) z0hc
      CP_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      CP_HL2:  begin
        // get the next instr
        // do op
        ctrl.rs1 = A;
        ctrl.rs2Sel = RS2_MEM;
        ctrl.aluOp = ALU_SUB;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0100;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // cp n
      // A - n  z0hc
      CP_N:  begin
        `READN
      end
      CP_N2: begin
        ctrl.rs1 = A;
        ctrl.rs2 = Z;
        ctrl.aluOp = ALU_SUB;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0100;
        ctrl.done = 1;
      end
      // and r
      // A=A&R z010
      AND_R:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_AND;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0010;
        ctrl.flgKill = 4'b1010;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // and (HL)
      // A = A&(HL) z010
      AND_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      AND_HL2:  begin
        // get the next instr
        // do op
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2Sel = RS2_MEM;
        ctrl.aluOp = ALU_AND;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0010;
        ctrl.flgKill = 4'b1010;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // and r
      // A=A&R z010
      AND_N:  begin
        `READN
      end
      AND_N2: begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = Z;
        ctrl.aluOp = ALU_AND;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgSet = 4'b0010;
        ctrl.flgKill = 4'b1010;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // or r
      // A=A|R z000
      OR_R:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_OR;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1000;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // or (HL)
      // A = A|(HL) z000
      OR_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      OR_HL2:  begin
        // get the next instr
        // do op
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2Sel = RS2_MEM;
        ctrl.aluOp = ALU_OR;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1000;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // or r
      // A=A|R z000
      OR_N:  begin
        `READN
      end
      OR_N2: begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = Z;
        ctrl.aluOp = ALU_OR;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1000;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // xor r
      // A=A^R z000
      XOR_R:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_XOR;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1000;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // Xor (HL)
      // A = A^(HL) z000
      XOR_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      XOR_HL2:  begin
        // get the next instr
        // do op
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2Sel = RS2_MEM;
        ctrl.aluOp = ALU_XOR;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1000;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // xor r
      // A=A^R z000
      XOR_N:  begin
        `READN
      end
      XOR_N2: begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.rs2 = Z;
        ctrl.aluOp = ALU_XOR;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1000;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // inc rr
      // rr++
      INC_RR:  begin
        ctrl.rd = reg_t'({op[5:4],1'b0});
        ctrl.rs1 = reg_t'({op[5:4],1'b0});
        ctrl.iduSel = IDU_RS;
        ctrl.rdSel = RD_IDU;
        ctrl.rdWen = 1;
        ctrl.rdW16 = 1;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      INC_RR2: begin
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // dec rr
      // rr--
      DEC_RR:  begin
        ctrl.rd = reg_t'({op[5:4],1'b0});
        ctrl.rs1 = reg_t'({op[5:4],1'b0});
        ctrl.iduSel = IDU_RS;
        ctrl.rdSel = RD_IDU;
        ctrl.iduSub = 1;
        ctrl.rdWen = 1;
        ctrl.rdW16 = 1;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      DEC_RR2: begin
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // inc r
      // r++
      INC_R:  begin
        ctrl.rd = reg_t'(op[5:3]);
        ctrl.rs1 = reg_t'(op[5:3]);
        ctrl.rs2Sel = RS2_1;
        ctrl.aluOp = ALU_ADD;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1110;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // inc (HL)
      // (HL)++
      INC_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      INC_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.rs2Sel = RS2_1;
        ctrl.aluOp = ALU_ADD;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1110;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      INC_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // dec r
      // r--
      DEC_R:  begin
        ctrl.rd = reg_t'(op[5:3]);
        ctrl.rs1 = reg_t'(op[5:3]);
        ctrl.rs2Sel = RS2_1;
        ctrl.aluOp = ALU_SUB;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1110;
        ctrl.flgSet = 4'b0100;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // dec (HL)
      // (HL)--
      DEC_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      DEC_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.rs2Sel = RS2_1;
        ctrl.aluOp = ALU_SUB;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1110;
        ctrl.flgSet = 4'b0100;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      DEC_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // ccf
      // -00~c
      CCF:  begin
        ctrl.aluOp = ALU_CCF;
        ctrl.flgWen = 4'b0111;
        ctrl.flgKill = 4'b1001;
        ctrl.done = 1;
      end
      // scf
      // -001
      SCF:  begin
        ctrl.aluOp = ALU_CCF;
        ctrl.flgWen = 4'b0111;
        ctrl.flgKill = 4'b1001;
        ctrl.flgSet = 4'b0001;
        ctrl.done = 1;
      end
      // daa
      // adjust decimal value in A
      DAA: begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.aluOp = ALU_DAA;
        ctrl.rdSel = RD_ALU;
        ctrl.flgWen = 4'b1011;
        ctrl.flgKill = 4'b1101;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // cpl
      // A = ~A -11-
      CPL:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.aluOp = ALU_NOT;
        ctrl.flgWen = 4'b0110;
        ctrl.flgSet = 4'b0110;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // add hl,rr
      // HL = HL + rr -0hc
      ADD_HLRR:  begin
        ctrl.rd = L;
        ctrl.rs1 = L;
        ctrl.rs2 = &op[5:4] ? SPL : reg_t'({op[5:4],1'b1});
        ctrl.aluOp = ALU_ADD;
        ctrl.flgWen = 4'b0111;
        ctrl.flgKill = 4'b1011;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      ADD_HLRR2:  begin
        ctrl.rd = H;
        ctrl.rs1 = H;
        ctrl.rs2 = &op[5:4] ? SP : reg_t'({op[5:4],1'b0});
        ctrl.aluOp = ALU_ADC;
        ctrl.flgWen = 4'b0111;
        ctrl.flgKill = 4'b1011;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // add sp,e
      // SP = SP + e 00hc
      ADD_SPE:  begin
        `READN
      end
      ADD_SPE2:  begin
        ctrl.rd = SPL;
        ctrl.rs1 = SPL;
        ctrl.rs2 = Z;
        ctrl.aluOp = ALU_ADD;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b0011;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
        ctrl.iren = 1;
      end
      ADD_SPE3:  begin
        ctrl.rd = SP;
        ctrl.rs1 = SP;
        ctrl.rs2 = Z;
        ctrl.aluOp = ALU_ADD2;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      ADD_SPE4:  begin
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // rlca
      // A = {A,b7}<<1 000b7
      RLCA:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.aluOp = ALU_RLC;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b0001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // rrca
      // A = {b0,A}>>1 000b0
      RRCA:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.aluOp = ALU_RRC;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b0001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // rla
      // A = {A,c}<<1 000b7
      RLA:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.aluOp = ALU_RL;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b0001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // rra
      // A = {c,A}>>1 000b0
      RRA:  begin
        ctrl.rd = A;
        ctrl.rs1 = A;
        ctrl.aluOp = ALU_RR;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b0001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // rlcr
      // R = {R,b7}<<1 z00b7
      RLC_R:  begin
        ctrl.rd = reg_t'(op[2:0]);
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_RLC;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // rlc (HL)
      // (HL) = {(HL),b7}<<1 z00b7
      RLC_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      RLC_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.aluOp = ALU_RLC;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      RLC_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // rrcr
      // R = {b0,R}>>1 z00b0
      RRC_R:  begin
        ctrl.rd = reg_t'(op[2:0]);
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_RRC;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // rrc (HL)
      // (HL) = {b0,(HL)}>>1 z00b0
      RRC_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      RRC_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.aluOp = ALU_RRC;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      RRC_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // rl r
      // R = {R,c}<<1 z00b7
      RL_R:  begin
        ctrl.rd = reg_t'(op[2:0]);
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_RL;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // rl (HL)
      // (HL) = {(HL),c}<<1 z00b7
      RL_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      RL_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.aluOp = ALU_RL;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      RL_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // rr r
      // R = {c,R}>>1 z00b0
      RR_R:  begin
        ctrl.rd = reg_t'(op[2:0]);
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_RR;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // rr (HL)
      // (HL) = {c,(HL)}>>1 z00b0
      RR_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      RR_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.aluOp = ALU_RR;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      RR_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // sla r
      // R = {R,0}<<1 z00b7
      SLA_R:  begin
        ctrl.rd = reg_t'(op[2:0]);
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_SLA;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // sla (HL)
      // (HL) = {(HL),0}<<1 z00b7
      SLA_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      SLA_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.aluOp = ALU_SLA;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      SLA_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // sra r
      // R = {b7,R}>>1 z00b0
      SRA_R:  begin
        ctrl.rd = reg_t'(op[2:0]);
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_SRA;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // sra (HL)
      // (HL) = {b7,(HL)}>>1 z00b0
      SRA_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      SRA_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.aluOp = ALU_SRA;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      SRA_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // srL r
      // R = {0,R}>>1 z00b0
      SRL_R:  begin
        ctrl.rd = reg_t'(op[2:0]);
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_SRL;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // srl (HL)
      // (HL) = {0,(HL)}>>1 z00b0
      SRL_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      SRL_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.aluOp = ALU_SRL;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1001;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      SRL_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // swap r
      // R = {b3-0,b7-4} z000
      SWAP_R:  begin
        ctrl.rd = reg_t'(op[2:0]);
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.aluOp = ALU_SWAP;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1000;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // swap (HL)
      // (HL) = {b3-0,b7-4} z000
      SWAP_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      SWAP_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.aluOp = ALU_SWAP;
        ctrl.flgWen = 4'b1111;
        ctrl.flgKill = 4'b1000;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      SWAP_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // bit r
      // z = bit b in r z01-
      BIT_R:  begin
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.b = reg_t'(op[5:3]);
        ctrl.aluOp = ALU_BIT;
        ctrl.flgWen = 4'b1110;
        ctrl.flgSet = 4'b0010;
        ctrl.flgKill = 4'b1011;
        ctrl.done = 1;
      end
      // swap (HL)
      // (HL) = {b3-0,b7-4} z000
      BIT_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      BIT_HL2:  begin
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.aluOp = ALU_BIT;
        ctrl.flgWen = 4'b1110;
        ctrl.flgSet = 4'b0010;
        ctrl.flgKill = 4'b1011;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // res r
      // bit b in r = 0
      RES_R:  begin
        ctrl.rd = reg_t'(op[2:0]);
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.b = reg_t'(op[5:3]);
        ctrl.aluOp = ALU_RES;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // res (HL)
      // bit b in (HL) = 0
      RES_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      RES_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.b = reg_t'(op[5:3]);
        ctrl.aluOp = ALU_RES;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      RES_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // set r
      // set b in r = 1
      SET_R:  begin
        ctrl.rd = reg_t'(op[2:0]);
        ctrl.rs1 = reg_t'(op[2:0]);
        ctrl.b = reg_t'(op[5:3]);
        ctrl.aluOp = ALU_SET;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.done = 1;
      end
      // set (HL)
      // set b in (HL) = 1
      SET_HL:  begin
        `READHL
        ctrl.iren = 1;
      end
      SET_HL2:  begin
        `READHL
        ctrl.rd = Z;
        ctrl.rs1Sel = RS1_MEM;
        ctrl.b = reg_t'(op[5:3]);
        ctrl.aluOp = ALU_SET;
        ctrl.rdSel = RD_ALU;
        ctrl.rdWen = 1;
        ctrl.pcen = 0;
      end
      SET_HL3:  begin
        ctrl.rs2 = Z;
        `WRITEHL
        ctrl.useOp = 1;
        ctrl.done = 1;
      end

    endcase
  end

endmodule