import defs::*;

module decoder (
  input logic rst, clk,
  input  logic [7:0] instr,
  input  logic memValid,
  output ctrl_t ctrl
);

  mpc_t mpc_enum;
  logic [$bits(mpc_enum)-1:0] mpc,nmpc;
  logic [7:0] op;

  assign mpc_enum = mpc_t'(mpc);
  // opcode flop
  flopenr #(8) opflop (clk,rst,ctrl.done,instr,op);
  
  // microcode flop
  flopr #($bits(mpc)) mpcflop (clk,rst,nmpc,mpc);
  
  // select the proper next microcode addr
  always_comb begin
    if(memValid) begin
      // if finished an instr then get new mpc
      if(ctrl.done) casez(instr)
        8'b00000000: nmpc=NOP;
        8'b00???110: nmpc=LD_RN;
        8'b01??????: nmpc=LD_RR; // ld r,r'
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

  // microcode LUT
  always_comb begin
    // basic case
    ctrl.pcSel = PC_IDU;
    ctrl.adrSel = ADR_PC;
    ctrl.iduSel = IDU_PC;
    ctrl.iduSub = 0;
    ctrl.rs1 = DC;
    ctrl.rs2 = DC;
    ctrl.aluOp = ALU_DC;
    ctrl.rd = DC;
    ctrl.rdSel = RD_DC;
    ctrl.rdWen = 0;
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
      // add r    op rs2
      // rd = A+r

    endcase
  end

endmodule