`include "../../code/cpu/defs.svh"
`define INSTRS (32'hFFFF)
`define PATH "cpu_instrs/"
`define PROG(a) {prog[(a&~1)+1],prog[(a&~1)]}
import defs::*;

module tb;
  string tests[];
  int cnts[];
  // solution in the first 3 words
  logic [7:0] prog [`INSTRS:0];
  int cnt=0;;
  int progNum;
  logic [15:0] pc, memData,memAdr;
  string testname;
  logic memValid;
  logic [9:0][7:0] soln;
  logic rst=0, clk=0;
  logic memWen, iflgen, stop;
  logic [15:0] newie, ie, iflg;
  logic [15:0] memWadr;
  logic [15:0] memWdata, tmp;
  int file;
  
  always @(posedge clk) begin 
    pc = memAdr; 
    tmp = (pc==16'hff44) ? 16'h90 : `PROG(pc);
    if(memWen) `PROG(memWadr) = memWdata;
    #1; // little memory delay
    memData = tmp;
  end
  flopenr #(16) iflgflop(clk,rst,(memWadr==16'hff0f)&memWen, memWdata, iflg);
  flopenr #(16) ieflop(clk,rst,(memWadr==16'hffff)&memWen, memWdata, ie);
  cpu cpu (.memData, .memAdr, .memValid, .rst, .clk,
           .memWen, .memWadr, .memWdata, .*);

  always #5 clk = ~clk;

  initial begin
    rst = 1;
    memValid = 0;
    #9;
    rst = 0;
    #7;
    memValid = 1;
      // $fwrite(f,"A:%02h F:%02h B:%02h C:%02h D:%02h E:%02h H:%02h L:%02h SP:%04h PC:%04h PCMEM:%02h,%02h,%02h,%02h\n",
      //         cpu.regfile.regs[A],cpu.regfile.regs[F],
      //         cpu.regfile.regs[B],cpu.regfile.regs[C],
      //         cpu.regfile.regs[D],cpu.regfile.regs[E],
      //         cpu.regfile.regs[H],cpu.regfile.regs[L],
      //         {cpu.regfile.regs[SP],cpu.regfile.regs[SPL]},16'h100,
      //         prog[16'h100],prog[16'h100+1],prog[16'h100+2],prog[16'h100+3]
      //         );
  end
  integer f;
  initial begin
    for(int i=0; i<`INSTRS+1; i++) prog[i] = '0;
    f = $fopen("output.txt", "w");
    $display("Test mode: %s\n",`TEST);

    if(`TEST == "spec" || `TEST == "1" || `TEST == "all") begin
      tests = {tests, "01-special"};
      cnts = {cnts, 1256634};
    end if(`TEST == "intr" || `TEST == "2" || `TEST == "all") begin
      tests = {tests, "02-interrupts"};
      cnts = {cnts, 0};
    end if(`TEST == "sphl" || `TEST == "3" || `TEST == "all") begin
      tests = {tests, "03-opsp,hl"};
      cnts = {cnts, 0};
    end if(`TEST == "rimm" || `TEST == "4" || `TEST == "all") begin
      tests = {tests, "04-opr,imm"};
      cnts = {cnts, 0};
    end if(`TEST == "rp" || `TEST == "5" || `TEST == "all") begin
      tests = {tests, "05-oprp"};
      cnts = {cnts, 0};
    end if(`TEST == "ldrr" || `TEST == "6" || `TEST == "all") begin
      tests = {tests, "06-ldr,r"};
      cnts = {cnts, 241012};
    end if(`TEST == "jp" || `TEST == "7" || `TEST == "all") begin
      tests = {tests, "07-jr,jp,call,ret,rst"};
      cnts = {cnts, 0};
    end if(`TEST == "misc" || `TEST == "8" || `TEST == "all") begin
      tests = {tests, "08-misc instrs"};
      cnts = {cnts, 0};
    end if(`TEST == "rr" || `TEST == "9" || `TEST == "all") begin
      tests = {tests, "09-opr,r"};
      cnts = {cnts, 0};
    end if(`TEST == "bit" || `TEST == "10" || `TEST == "all") begin
      tests = {tests, "10-bit ops"};
      cnts = {cnts, 0};
    end if(`TEST == "ahl" || `TEST == "11" || `TEST == "all") begin
      tests = {tests, "11-opa,(hl)"};
      cnts = {cnts, 0};
    end if(tests[0] == "") begin
      $display("ERROR: %s doesn't exist", `TEST);
      $finish;
    end
    tests = {tests, "end"};

    testname = {`PATH, tests[0], ".txt"};
    $display("\n\nRunning %s test ", tests[0]);
    $readmemh(testname, prog);
    progNum = 0;
  end


  always @(negedge clk) begin
    if(cpu.ctrl.done&(cpu.decoder.cb!==1'b1)) begin
      @(posedge clk);
      $fwrite(f,"A:%02h F:%02h B:%02h C:%02h D:%02h E:%02h H:%02h L:%02h SP:%04h PC:%04h PCMEM:%02h,%02h,%02h,%02h\n",
              cpu.regfile.regs[A],cpu.regfile.regs[F],
              cpu.regfile.regs[B],cpu.regfile.regs[C],
              cpu.regfile.regs[D],cpu.regfile.regs[E],
              cpu.regfile.regs[H],cpu.regfile.regs[L],
              {cpu.regfile.regs[SP],cpu.regfile.regs[SPL]},memAdr,
              prog[memAdr],prog[memAdr+1],prog[memAdr+2],prog[memAdr+3]
              );
    cnt++;
    end
    if(cnt>cnts[progNum]) begin $display("finish early");$fclose(f); $finish; end
    if(stop) begin
      $display("Finshed %s\n", tests[progNum]);
      progNum++;
      // reset cpu
      rst=1; memValid = 0; 
      for(int i=0; i<`INSTRS+1; i++) prog[i] = '0;
      // check if finished tests
      if(tests[progNum] === "end") begin
        $display("FINISHED\n");
        $fclose(f);
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
 
