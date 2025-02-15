`define INSTRS 65536
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
  logic memWen;
  logic [15:0] memWadr;
  logic [15:0] memWdata;


  // set solution
  assign soln = {prog[3][7:0],prog[3][15:8],
                prog[2][7:0],prog[2][15:8],
                prog[1][7:0],prog[1][15:8],
                prog[0][7:0],prog[0][15:8]};
  
  always @(posedge clk) begin 
    pc = memAdr; 
    #1; // little memory delay
    memData = prog[pc[15:1]+6];
    if(memWen) prog[memWadr[15:1]+6] = memWdata;
  end
  cpu cpu (.memData, .memAdr, .memValid, .rst, .clk,
           .memWen, .memWadr, .memWdata);

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
    end if(`TEST == "ldhlr" || `TEST == "all") begin
      tests = {tests, "ldhlr"};
    end if(`TEST == "ldhln" || `TEST == "all") begin
      tests = {tests, "ldhln"};
    end if(`TEST == "ldabc" || `TEST == "all") begin
      tests = {tests, "ldabc"};
    end if(`TEST == "ldade" || `TEST == "all") begin
      tests = {tests, "ldade"};
    // end if(`TEST == "ldbca" || `TEST == "all") begin
    //   tests = {tests, "ldbca"};
    // end if(`TEST == "lddea" || `TEST == "all") begin
    //   tests = {tests, "lddea"};
    // end if(`TEST == "ldann" || `TEST == "all") begin
    //   tests = {tests, "ldann"};
    // end if(`TEST == "ldnna" || `TEST == "all") begin
    //   tests = {tests, "ldnna"};
    // end if(`TEST == "ldhac" || `TEST == "all") begin
    //   tests = {tests, "ldhac"};
    // end if(`TEST == "ldhca" || `TEST == "all") begin
    //   tests = {tests, "ldhca"};
    // end if(`TEST == "ldan" || `TEST == "all") begin
    //   tests = {tests, "ldan"};
    // end if(`TEST == "ldna" || `TEST == "all") begin
    //   tests = {tests, "ldna"};
    // end if(`TEST == "ldahl-" || `TEST == "all") begin
    //   tests = {tests, "ldahl-"};
    // end if(`TEST == "ldhl-a" || `TEST == "all") begin
    //   tests = {tests, "ldhl-a"};
    // end if(`TEST == "ldahl+" || `TEST == "all") begin
    //   tests = {tests, "ldahl+"};
    // end if(`TEST == "ldhl+a" || `TEST == "all") begin
    //   tests = {tests, "ldhl+a"};
    // end if(`TEST == "ldrrnn" || `TEST == "all") begin
    //   tests = {tests, "ldrrnn"};
    // end if(`TEST == "ldnnsp" || `TEST == "all") begin
    //   tests = {tests, "ldnnsp"};
    // end if(`TEST == "ldsphl" || `TEST == "all") begin
    //   tests = {tests, "ldsphl"};
    // end if(`TEST == "pushrr" || `TEST == "all") begin
    //   tests = {tests, "pushrr"};
    // end if(`TEST == "poprr" || `TEST == "all") begin
    //   tests = {tests, "poprr"};
    // end if(`TEST == "ldhlps+e" || `TEST == "all") begin
    //   tests = {tests, "ldhlps+e"};
    end if(tests[0] == "") begin
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
      $display("Running %s test ", tests[progNum]);
      $readmemh(testname, prog);
    end
  end

endmodule
 
