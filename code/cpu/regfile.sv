
module regfile (
  input logic clk,
  input  logic [2:0] addr1, addr2, rdAddr,
  input  logic rdWen,
  input  logic [7:0] rd,
  output logic [7:0] rs1, rs2
);
  // *** may have trouble with timing later. add internal forwarding to fix timing issues
  // B C D E H L F A
  // 0 1 2 3 4 5 6 7
  logic [7:0][7:0] regs;
  always_ff @(negedge clk) begin : rf
    if(rdWen) regs[rdAddr] = rd;
  end

  assign rs1 = regs[addr1];
  assign rs2 = regs[addr2];

endmodule