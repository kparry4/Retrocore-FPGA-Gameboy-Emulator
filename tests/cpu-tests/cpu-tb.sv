`define INSTRS 20
`define PATH "code/"

module tb;
  string tests[];
  // solution in the first 3 words
  logic [15:0] prog[`INSTRS-1:0];
  int progNum;
  logic [15:0] pc, memData,memAdr;
  string testname;
  logic memValid;
  logic [7:0][7:0] soln;
  logic rst=0, clk=0;


  // set solution
  assign soln = {prog[3][7:0],prog[3][15:8],
                prog[2][7:0],prog[2][15:8],
                prog[1][7:0],prog[1][15:8],
                prog[0][7:0],prog[0][15:8]};
  
  always @(posedge clk) begin 
    pc = memAdr; 
    #1; // little memory delay
    memData = prog[pc[15:1]+6];
  end
  cpu cpu (.memData, .memAdr, .memValid, .rst, .clk);

  always #5 clk = ~clk;

  initial begin
    rst = 1;
    memValid = 0;
    #9;
    rst = 0;
    #7;
    memValid = 1;
  end

  initial begin
    $display("Test mode: %s\n",`TEST);

    if(`TEST == "ldn" || `TEST == "all") begin
      tests = {tests, "ldn"};
    end if(`TEST == "ldrr" || `TEST == "all") begin
      tests = {tests, "ldrr"};
    end if(`TEST == "ldrhl" || `TEST == "all") begin
      tests = {tests, "ldrhl"};
    end else begin
      $display("ERROR: %s doesn't exist", `TEST);
      $finish;
    end
    tests = {tests, "end"};

    testname = {`PATH, tests[0], ".txt"};
    $display("\n\nRunning %s test ", tests[0]);
    $readmemh(testname, prog);
    // set the test index to 0
    progNum = 0;
    
  end

  always @(pc) begin
    if(prog[pc/2+6] === 'x && ~rst) begin
      #30; // to finish last two opperations
      if(cpu.regfile.regs[7:0] !== soln) begin
        $display("ERROR\n AFLHEDCB %h %h", cpu.regfile.regs[7:0], soln);
        $finish;
      end else $display("YAY %s WORKS!\n", tests[progNum]);
      progNum++;
      // reset cpu
      rst=1; memValid = 0; #15; rst=0;#6; memValid=1;
      for(int i=0; i<`INSTRS; i++) prog[i] = 'x;
      // check if finished tests
      if(tests[progNum] === "end") begin
        $display("YAY ALL TESTS WORK!\n");
        $finish;
      end
      // read next test
      testname = {`PATH, tests[progNum], ".txt"};
      $display("\n\nRunning %s test ", tests[progNum]);
      $readmemh(testname, prog);
    end
  end

endmodule
 
