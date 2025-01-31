
module regfile (
  input  logic [2:0] addr1, addr2, rdAddr,
  input  logic rdWen,
  input  logic [7:0] rd,
  output logic [7:0] rs1, rs2
);
  
  logic [2:0][7:0] regs;
  always_ff @(negedge clk) begin : rf
    if(rdWen) regs[rdAddr] = rd;
  end

  assign rs1 = regs[add1];
  assign rs2 = regs[add2];

endmodule