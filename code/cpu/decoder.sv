
module decode (
  input  logic [3:0][7:0] instr,
  output ctrl_t ctrl
);

  // register layout
  // B C D E H L SP A F(flags) PC mPC(microcode pc) WZ(temp storage)
  // 0 1 2 3 4 5 6  7

  // pcSel_instrSz
  always_comb begin
    case(instr)
      // nop
      16'b00000000: ctrl = {PC_ADD,2'h1};
      // ld r, r' op rs1 rs2
      // r <- r'
      16'b01??????: ctrl = {PC_ADD,2'h1};
      default: ctrl = 'x;

    endcase
  end

endmodule