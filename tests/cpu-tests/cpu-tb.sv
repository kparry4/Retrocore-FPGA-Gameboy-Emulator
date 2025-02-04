`define INSTRS 20
`define PATH "code/"

module tb;
  string tests[];
  // solution in the first 3 words
  logic [15:0] prog[`INSTRS-1:0];
  int progNum;
  logic [15:0] pc, memData;
  string testname;
  logic [7:0][7:0] soln;
  logic rst=0, clk=0;


  // set solution
  assign soln = {prog[3][7:0],prog[3][15:8],
                prog[2][7:0],prog[2][15:8],
                prog[1][7:0],prog[1][15:8],
                prog[0][7:0],prog[0][15:8]};
  
  assign memData = prog[pc[15:1]+6];
  cpu cpu (.memData, .pc, .rst, .clk);

  always #5 clk = ~clk;

  initial begin
    rst = 1;
    #9;
    rst = 0;
  end

  initial begin
    $display("Test mode: %s\n",`TEST);

    if(`TEST == "ld" || `TEST == "all") begin
      tests = {tests, "ld"};
    end

    testname = {`PATH, tests[0], ".txt"};
    $display("\n\nRunning %s test ", tests[0]);
    $readmemh(testname, prog);
    // set the test index to 0
    progNum = 0;
    
  end

  always @(pc) begin
    if(prog[pc/2+6] === 'x && ~rst) begin
      #20; // to finish last two opperations
      if(cpu.regfile.regs !== soln)
        $display("ERROR\n AFLHEDCB %h %h", cpu.regfile.regs, soln);
      else $display("YAY IT WORKS!\n");
      $finish;
    end
  end
  
  

  // assign ans = (x+y)*(x+y);
  // always begin
  //   #1;
  //   x++;
  //   if(y=={`SZ{1'b1}} && x=={`SZ{1'b1}})begin
  //     #1; $finish;
  //   end
  //   if(x=={`SZ{1'b1}})begin
  //     y++;
  //     // #1; $finish;
  //   end
  //   if(res !== ans) begin $display("res: %h ans: %h x: %h y: %h", res, ans, x-1, y); $finish; end

  // end

endmodule
 