
module decode (
  input  logic [3:0][7:0] instr,
  output logic [2:0] rd, rs1
);

  // register layout
  // B C D E H L SP A F(flags) PC mPC(microcode pc) WZ(temp storage)
  // 0 1 2 3 4 5 6  7

  always_comb begin
    case(instr)
      16'b00000000: begin // nop
      end
      16'b01??????: begin // ld r, r'
        // 1 cycle
        // 1 byte
        // r <- r'
        assign rd = instr[5:3];
        assign rs1 = instr[2:0];
        assign mpc = 0;
      end
      16'b00???110: begin // ld r, imm
        // 2 cycle
        // 2 byte - op - imm
        // r <- imm
        assign rd = instr[5:3];
        assign mpc = 1;
      end

    endcase
  end
  // done_aluOp_npc_rdSel_WWen_ZWen
  logic [][] lut = {
    {1'b1,ALU_RS1,PC_PLUS1,RD_ALU,2'bxx}, // ld r,r'
    {1'b0,ALU_DC, PC_PLUS1,RD_DC ,2'b01}, // ld r,imm
    {1'b1,ALU_NOP,PC_PLUS1,RD_Z  ,1'bxx}
  }

// assign rd write en to be 0 if RD_NON


endmodule