`define INSTRS ((65536/2)+6)
`define PATH "code/"
import defs::*;

module tb;
  string tests[];
  // solution in the first 3 words
  logic [15:0] prog[`INSTRS-1:0];
  int progNum;
  logic [15:0] pc, memData,memAdr;
  string testname;
  logic memValid;
  logic [9:0][7:0] soln;
  logic rst=0, clk=0;
  logic memWen, ieen, stop;
  logic [7:0] newie, ie, iflg;
  logic [15:0] memWadr;
  logic [15:0] memWdata, tmp;


  // set solution
  assign soln = {prog[4][7:0],prog[4][15:8],
                prog[3][7:0],prog[3][15:8],
                prog[2][7:0],prog[2][15:8],
                prog[1][7:0],prog[1][15:8],
                prog[0][7:0],prog[0][15:8]};
  
  always @(posedge clk) begin 
    // if(ieen) ie = newie;
    pc = memAdr; 
    tmp = prog[pc[15:1]+6];
    if(memWen) prog[memWadr[15:1]+6] = memWdata;
    #1; // little memory delay
    memData = tmp;
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
    end if(`TEST == "ldbca" || `TEST == "all") begin
      tests = {tests, "ldbca"};
    end if(`TEST == "lddea" || `TEST == "all") begin
      tests = {tests, "lddea"};
    end if(`TEST == "ldann" || `TEST == "all") begin
      tests = {tests, "ldann"};
    end if(`TEST == "ldnna" || `TEST == "all") begin
      tests = {tests, "ldnna"};
    end if(`TEST == "ldhca" || `TEST == "all") begin
      tests = {tests, "ldhca"};
    end if(`TEST == "ldhna" || `TEST == "all") begin
      tests = {tests, "ldhna"};
    end if(`TEST == "ldahl-" || `TEST == "all") begin
      tests = {tests, "ldahl-"};
    end if(`TEST == "ldhl-a" || `TEST == "all") begin
      tests = {tests, "ldhl-a"};
    end if(`TEST == "ldahl+" || `TEST == "all") begin
      tests = {tests, "ldahl+"};
    end if(`TEST == "ldhl+a" || `TEST == "all") begin
      tests = {tests, "ldhl+a"};
    end if(`TEST == "ldrrnn" || `TEST == "all") begin
      tests = {tests, "ldrrnn"};
    end if(`TEST == "ldnnsp" || `TEST == "all") begin
      tests = {tests, "ldnnsp"};
    end if(`TEST == "ldsphl" || `TEST == "all") begin
      tests = {tests, "ldsphl"};
    end if(`TEST == "pushrr" || `TEST == "all") begin
      tests = {tests, "pushrr"};
    end if(`TEST == "poprr" || `TEST == "all") begin
      tests = {tests, "poprr"};
    end if(`TEST == "ldhlsppe" || `TEST == "all") begin
      tests = {tests, "ldhlsp+e"};
    end if(`TEST == "addr" || `TEST == "all") begin
      tests = {tests, "addr"};
    end if(`TEST == "addhl" || `TEST == "all") begin
      tests = {tests, "addhl"};
    end if(`TEST == "addn" || `TEST == "all") begin
      tests = {tests, "addn"};
    end if(`TEST == "adcr" || `TEST == "all") begin
      tests = {tests, "adcr"};
    end if(`TEST == "adchl" || `TEST == "all") begin
      tests = {tests, "adchl"};
    end if(`TEST == "adcn" || `TEST == "all") begin
      tests = {tests, "adcn"};
    end if(`TEST == "subr" || `TEST == "all") begin
      tests = {tests, "subr"};
    end if(`TEST == "subhl" || `TEST == "all") begin
      tests = {tests, "subhl"};
    end if(`TEST == "subn" || `TEST == "all") begin
      tests = {tests, "subn"};
    end if(`TEST == "sbcr" || `TEST == "all") begin
      tests = {tests, "sbcr"};
    end if(`TEST == "sbchl" || `TEST == "all") begin
      tests = {tests, "sbchl"};
    end if(`TEST == "sbcn" || `TEST == "all") begin
      tests = {tests, "sbcn"};
    end if(`TEST == "cpr" || `TEST == "all") begin
      tests = {tests, "cpr"};
    end if(`TEST == "cphl" || `TEST == "all") begin
      tests = {tests, "cphl"};
    end if(`TEST == "cpn" || `TEST == "all") begin
      tests = {tests, "cpn"};
    end if(`TEST == "andr" || `TEST == "all") begin
      tests = {tests, "andr"};
    end if(`TEST == "andhl" || `TEST == "all") begin
      tests = {tests, "andhl"};
    end if(`TEST == "andn" || `TEST == "all") begin
      tests = {tests, "andn"};
    end if(`TEST == "orr" || `TEST == "all") begin
      tests = {tests, "orr"};
    end if(`TEST == "orhl" || `TEST == "all") begin
      tests = {tests, "orhl"};
    end if(`TEST == "orn" || `TEST == "all") begin
      tests = {tests, "orn"};
    end if(`TEST == "xorr" || `TEST == "all") begin
      tests = {tests, "xorr"};
    end if(`TEST == "xorhl" || `TEST == "all") begin
      tests = {tests, "xorhl"};
    end if(`TEST == "xorn" || `TEST == "all") begin
      tests = {tests, "xorn"};
    end if(`TEST == "incr" || `TEST == "all") begin
      tests = {tests, "incr"};
    end if(`TEST == "inchl" || `TEST == "all") begin
      tests = {tests, "inchl"};
    end if(`TEST == "decr" || `TEST == "all") begin
      tests = {tests, "decr"};
    end if(`TEST == "dechl" || `TEST == "all") begin
      tests = {tests, "dechl"};
    end if(`TEST == "ccf" || `TEST == "all") begin
      tests = {tests, "ccf"};
    end if(`TEST == "scf" || `TEST == "all") begin
      tests = {tests, "scf"};
    end if(`TEST == "daa" || `TEST == "all") begin
      tests = {tests, "daa"};
    end if(`TEST == "cpl" || `TEST == "all") begin
      tests = {tests, "cpl"};
    end if(`TEST == "incrr" || `TEST == "all") begin
      tests = {tests, "incrr"};
    end if(`TEST == "decrr" || `TEST == "all") begin
      tests = {tests, "decrr"};
    end if(`TEST == "addhlrr" || `TEST == "all") begin
      tests = {tests, "addhlrr"};
    end if(`TEST == "addspe" || `TEST == "all") begin
      tests = {tests, "addspe"};
    end if(`TEST == "rlca" || `TEST == "all") begin
      tests = {tests, "rlca"};
    end if(`TEST == "rrca" || `TEST == "all") begin
      tests = {tests, "rrca"};
    end if(`TEST == "rla" || `TEST == "all") begin
      tests = {tests, "rla"};
    end if(`TEST == "rra" || `TEST == "all") begin
      tests = {tests, "rra"};
    end if(`TEST == "rlcr" || `TEST == "all") begin
      tests = {tests, "rlcr"};
    end if(`TEST == "rlchl" || `TEST == "all") begin
      tests = {tests, "rlchl"};
    end if(`TEST == "rrcr" || `TEST == "all") begin
      tests = {tests, "rrcr"};
    end if(`TEST == "rrchl" || `TEST == "all") begin
      tests = {tests, "rrchl"};
    end if(`TEST == "rlr" || `TEST == "all") begin
      tests = {tests, "rlr"};
    end if(`TEST == "rlhl" || `TEST == "all") begin
      tests = {tests, "rlhl"};
    end if(`TEST == "rrr" || `TEST == "all") begin
      tests = {tests, "rrr"};
    end if(`TEST == "rrhl" || `TEST == "all") begin
      tests = {tests, "rrhl"};
    end if(`TEST == "slar" || `TEST == "all") begin
      tests = {tests, "slar"};
    end if(`TEST == "slahl" || `TEST == "all") begin
      tests = {tests, "slahl"};
    end if(`TEST == "srar" || `TEST == "all") begin
      tests = {tests, "srar"};
    end if(`TEST == "srahl" || `TEST == "all") begin
      tests = {tests, "srahl"};
    end if(`TEST == "swapr" || `TEST == "all") begin
      tests = {tests, "swapr"};
    end if(`TEST == "swaphl" || `TEST == "all") begin
      tests = {tests, "swaphl"};
    end if(`TEST == "srlr" || `TEST == "all") begin
      tests = {tests, "srlr"};
    end if(`TEST == "srlhl" || `TEST == "all") begin
      tests = {tests, "srlhl"};
    end if(`TEST == "bitbr" || `TEST == "all") begin
      tests = {tests, "bitbr"};
    end if(`TEST == "bitbhl" || `TEST == "all") begin
      tests = {tests, "bitbhl"};
    end if(`TEST == "resbr" || `TEST == "all") begin
      tests = {tests, "resbr"};
    end if(`TEST == "resbhl" || `TEST == "all") begin
      tests = {tests, "resbhl"};
    end if(`TEST == "setbr" || `TEST == "all") begin
      tests = {tests, "setbr"};
    end if(`TEST == "setbhl" || `TEST == "all") begin
      tests = {tests, "setbhl"};
    end if(`TEST == "jpnn" || `TEST == "all") begin
      tests = {tests, "jpnn"};
    end if(`TEST == "jphl" || `TEST == "all") begin
      tests = {tests, "jphl"};
    end if(`TEST == "jpccnn" || `TEST == "all") begin
      tests = {tests, "jpccnn"};
    end if(`TEST == "jre" || `TEST == "all") begin
      tests = {tests, "jre"};
    end if(`TEST == "jrcce" || `TEST == "all") begin
      tests = {tests, "jrcce"};
    end if(`TEST == "callnn" || `TEST == "all") begin
      tests = {tests, "callnn"};
    end if(`TEST == "callccnn" || `TEST == "all") begin
      tests = {tests, "callccnn"};
    end if(`TEST == "ret" || `TEST == "all") begin
      tests = {tests, "ret"};
    end if(`TEST == "retcc" || `TEST == "all") begin
      tests = {tests, "retcc"};
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
    if(prog[pc/2+6] === 'x && cpu.ctrl.adrSel==ADR_PC && ~rst) begin
      #30; // to finish last two opperations
      if({cpu.regfile.regs[SPL:SP],cpu.regfile.regs[7:0]} !== soln) begin
        $display("ERROR res ans\nB %h %h", cpu.regfile.regs[B], soln[B]);
        $display("\nC %h %h", cpu.regfile.regs[C], soln[C]);
        $display("\nD %h %h", cpu.regfile.regs[D], soln[D]);
        $display("\nE %h %h", cpu.regfile.regs[E], soln[E]);
        $display("\nH %h %h", cpu.regfile.regs[H], soln[H]);
        $display("\nL %h %h", cpu.regfile.regs[L], soln[L]);
        $display("\nA %h %h", cpu.regfile.regs[A], soln[A]);
        $display("\nF %h %h", cpu.regfile.regs[F], soln[F]);
        $display("\nSP %h %h", {cpu.regfile.regs[SP],cpu.regfile.regs[SPL]}, {soln[8], soln[9]});
        $finish;
      end else $display("YAY %s WORKS!\n", tests[progNum]);
      progNum++;
      // reset cpu
      rst=1; memValid = 0; 
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
      #15; rst=0;#7; memValid=1;
    end
  end

endmodule
 
