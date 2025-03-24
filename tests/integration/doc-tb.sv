`include "../../code/cpu/defs.svh"
`timescale 1 ps / 1 ps
`define INSTRS (32'hFFFF)
`define PATH "../cpu-tests/cpu_instrs/"
`define PROG(a) {prog[(a&~1)+1],prog[(a&~1)]}
import defs::*;

module tb;
  string tests[];
  int cnts[];
  // solution in the first 3 words
  logic [7:0] prog [`INSTRS:0];
  int cnt=0;
  int progNum;
  logic [15:0] pc, memData,memAdr;
  string testname;
  logic memValid;
  logic [9:0][7:0] soln;
  logic rst=0, clk=1;
  logic memWen, iflgen, stop;
  logic [15:0] newie, ie, iflg;
  logic [15:0] memWadr;
  logic [15:0] memWdata, tmp;
  int file;
  logic clk2=0; //*** make a second clock
  logic ppu_mode;
  
  always @(posedge clk2) begin 
    pc = gb.memAdr; 
    tmp = (pc==16'hff44) ? 16'h90 : `PROG(pc);
    if(gb.memWen) `PROG(gb.memWadr) = gb.memWdata;
    #1; // little memory delay
    // memData = tmp;
  end
  // flopenr #(16) iflgflop(clk,rst,(memWadr==16'hff0f)&gb.memWen, gb.memWdata, iflg);
  // flopenr #(16) ieflop(clk,rst,(memWadr==16'hffff)&memWen, memWdata, ie);
  gameboy gb (.clk,.clk2, .rst,.ppu_mode(2'b0));

  always #5 clk = ~clk;
  always #10 clk2 = ~clk2;

  initial begin
    rst = 1;
    memValid = 0;
    #18;
    rst = 0;
    #14;
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
      cnts = {cnts, 1256634}; // works
    end if(`TEST == "intr" || `TEST == "2" || `TEST == "all") begin
      tests = {tests, "02-interrupts"};
      cnts = {cnts, 161058}; // test later
    end if(`TEST == "sphl" || `TEST == "3" || `TEST == "all") begin
      tests = {tests, "03-opsp,hl"};
      cnts = {cnts, 1066161}; // works
    end if(`TEST == "rimm" || `TEST == "4" || `TEST == "all") begin
      tests = {tests, "04-opr,imm"};
      cnts = {cnts, 1260505};
    end if(`TEST == "rp" || `TEST == "5" || `TEST == "all") begin
      tests = {tests, "05-oprp"};
      cnts = {cnts, 1761127};
    end if(`TEST == "ldrr" || `TEST == "6" || `TEST == "all") begin
      tests = {tests, "06-ldr,r"};
      cnts = {cnts, 241012}; // works
    end if(`TEST == "jp" || `TEST == "7" || `TEST == "all") begin
      tests = {tests, "07-jr,jp,call,ret,rst"};
      cnts = {cnts, 587416};
    end if(`TEST == "misc" || `TEST == "8" || `TEST == "all") begin
      tests = {tests, "08-miscinstrs"};
      cnts = {cnts, 221631};
    end if(`TEST == "rr" || `TEST == "9" || `TEST == "all") begin
      tests = {tests, "09-opr,r"};
      cnts = {cnts, 4418121}; // works
    end if(`TEST == "bit" || `TEST == "10" || `TEST == "all") begin
      tests = {tests, "10-bitops"};
      cnts = {cnts, 6712462};
    end if(`TEST == "ahl" || `TEST == "11" || `TEST == "all") begin
      tests = {tests, "11-opa,(hl)"};
      cnts = {cnts, 7427501};
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


  always @(negedge clk2) begin
    if(gb.cpu.ctrl.done&(gb.cpu.decoder.cb!==1'b1)&(gb.cpu.decoder.mpc!==INTERUPT5)) begin
      @(posedge clk2);
      $fwrite(f,"A:%02h F:%02h B:%02h C:%02h D:%02h E:%02h H:%02h L:%02h SP:%04h PC:%04h PCMEM:%02h,%02h,%02h,%02h\n",
              gb.cpu.regfile.regs[A],gb.cpu.regfile.regs[F],
              gb.cpu.regfile.regs[B],gb.cpu.regfile.regs[C],
              gb.cpu.regfile.regs[D],gb.cpu.regfile.regs[E],
              gb.cpu.regfile.regs[H],gb.cpu.regfile.regs[L],
              {gb.cpu.regfile.regs[SP],gb.cpu.regfile.regs[SPL]},gb.memAdr,
              prog[gb.memAdr],prog[gb.memAdr+1],prog[gb.memAdr+2],prog[gb.memAdr+3]
              );
    cnt++;
    end
    if(cnt>cnts[progNum]) begin $display("finish");$fclose(f); $finish; end
    //if(cnt>31464) begin $display("finish early");$fclose(f); $finish; end
    if(gb.stop) begin
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
      #30; rst=0;#14; memValid=1;
    end
  end

endmodule
 
