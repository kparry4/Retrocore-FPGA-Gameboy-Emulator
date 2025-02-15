import defs::*;

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
  flopenr #(8) curropreg (clk,rst,ctrl.done,nextInstr,op);
  flopenr #(8) nextopreg (clk,rst,ctrl.iren,instr,nextOp);
  
  // microcode flop
  flopr #($bits(mpc)) mpcflop (clk,rst,nmpc,mpc);
  
  // select the proper next microcode addr
  always_comb begin
    if(memValid) begin
      // if finished an instr then get new mpc
      if(ctrl.done) casez(nextInstr)
        8'b00000000: nmpc=NOP;
        8'b00???110: nmpc=LD_RN;
        8'b01???110: nmpc=LD_RHL;
        8'b01110???: nmpc=LD_HLR;
        8'b01??????: nmpc=LD_RR;
        default: nmpc = BAD;
      endcase

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
    ctrl.memWen = 0;
    ctrl.iduSel = IDU_PC;
    ctrl.pcen = 1;
    ctrl.iduSub = 0;
    ctrl.rs1 = DC;
    ctrl.rs2 = DC;
    ctrl.aluOp = ALU_DC;
    ctrl.rd = DC;
    ctrl.rdSel = RD_DC;
    ctrl.rdWen = 0;
    ctrl.iren = 0;
    ctrl.useOp = 0;
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
        // *** could improve by storing in WZ?
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
        ctrl.memWen = 1;
        ctrl.useOp = 1;
        ctrl.done = 1;
      end
      // add r    op rs2
      // rd = A+r

    endcase
  end

endmodule