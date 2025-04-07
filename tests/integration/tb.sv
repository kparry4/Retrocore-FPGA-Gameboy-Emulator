`include "../../code/Integration/cpu/defs.svh"
`timescale 1 ps / 1 ps
`define INSTRS (32'hFFFF)
`define PATH "games/"
`define PROG(a) {prog[(a&~1)+1],prog[(a&~1)]}
import defs::*;
`define PCSTOP 16'hx // tetris 2f2 important
`define CNTSTOP 2069534//1000000
`define BTN 614441//1000000
`define BTN2 1569534//1000000

module tb;
  string tests[];
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
  logic clk2=0; //*** make a second clock
  logic ppu_mode;

  localparam WIDTH  = 160;
  localparam HEIGHT = 144;
  logic [1:0]   frame_pixel;
  logic         frame_pixel_valid;

  logic [7:0]   LY;
  logic predone;


  // 2D frame buffer for storing 12-bit VGA colors.
  reg [1:0] frame_buffer [0:HEIGHT-1][0:WIDTH-1];
  integer f;

  // Declare pixel_count and loop variables.
  integer pixel_count;
  integer r, c, red, green, blue, file;
  logic joypad_select=0,joypad_start=0,joypad_dpad_up=0,joypad_dpad_down=0,joypad_dpad_left=0,joypad_dpad_right=0,joypad_a_button=0,joypad_b_button=0;

  assign pc = gb.memAdr&{16{predone}};
  always @(posedge clk2) begin
    // pc = gb.memAdr;
    tmp = (pc==16'hff44) ? 16'h90 : `PROG(pc);
    if(gb.memWen) `PROG(gb.memWadr) = gb.memWdata;
    predone = gb.cpu.decoder.ctrl.done;
    #1; // little memory delay
    // memData = tmp;
  end
  gameboy gb (.clk,.clk2, .rst, .frame_pixel, .LY, .frame_pixel_valid,
          .joypad_select,
          .joypad_start,
          .joypad_dpad_up,
          .joypad_dpad_down,
          .joypad_dpad_left,
          .joypad_dpad_right,
          .joypad_a_button,
          .joypad_b_button);

  always #5 clk = ~clk;
  always #10 clk2 = ~clk2;

  initial begin
  	for (integer line = 0; line < 154; line = line + 1) begin
		LY = line;
        	repeat (456) @(posedge clk2);
  	end
  end

  initial begin
    rst = 1;
    memValid = 0;
    #360;
    rst = 0;
    #720;
    memValid = 1;
  end
  initial begin
    f = $fopen("output.txt", "w");
    for(int i=0; i<`INSTRS+1; i++) prog[i] = '0;
    $display("Test mode: %s\n",`TEST);

    if(`TEST == "tetris") begin
      tests = {tests, "tetris"};
    end if(`TEST == "Dr.Mario") begin
      tests = {tests, "Dr.Mario"};
    end if(`TEST == "dmg-acid-test") begin
      tests = {tests, "dmg-acid-test"};
    end if(`TEST == "06") begin
      tests = {tests, "06-ldr,r"}; //241012
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

      integer row, col;
  // Capture pixels and update pixel_count in one always_ff block.
  always_ff @(posedge clk2 or posedge rst) begin : fb
    if(rst || !gb.ppu.LCDC[7]) for(int i=0; i<HEIGHT; i++) for(int j=0; j<WIDTH; j++) frame_buffer[i][j] = '0;
    if (rst|(pixel_count >= WIDTH * HEIGHT) || !gb.ppu.LCDC[7] || gb.ppu.mode==2'b1) begin
      pixel_count <= 0;
    end else if (frame_pixel_valid) begin
      row = pixel_count / WIDTH;
      col = pixel_count % WIDTH;
      if (row < HEIGHT) begin
        frame_buffer[row][col] <= frame_pixel;
        pixel_count <= pixel_count + 1;
      end
    end
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
    end
    if(gb.cpu.ctrl.done&(gb.cpu.decoder.cb!==1'b1)) begin
      cnt++;
    end
    if(`BTN<cnt & cnt<`BTN+1000)begin
      joypad_select = 0;
      joypad_start = 1;
      joypad_dpad_up = 0;
      joypad_dpad_down = 0;
      joypad_dpad_left = 0;
      joypad_dpad_right = 0;
      joypad_a_button = 0;
      joypad_b_button = 0;
    end else begin
      joypad_select = 0;
      joypad_start = 0;
      joypad_dpad_up = 0;
      joypad_dpad_down = 0;
      joypad_dpad_left = 0;
      joypad_dpad_right = 0;
      joypad_a_button = 0;
      joypad_b_button = 0;
    end
    if(`BTN2<cnt & cnt<`BTN2+1000)begin
      joypad_select = 0;
      joypad_start = 1;
      joypad_dpad_up = 0;
      joypad_dpad_down = 0;
      joypad_dpad_left = 0;
      joypad_dpad_right = 0;
      joypad_a_button = 0;
      joypad_b_button = 0;
    end else begin
      joypad_select = 0;
      joypad_start = 0;
      joypad_dpad_up = 0;
      joypad_dpad_down = 0;
      joypad_dpad_left = 0;
      joypad_dpad_right = 0;
      joypad_a_button = 0;
      joypad_b_button = 0;
    end
    if(cnt>`CNTSTOP || pc == `PCSTOP) begin
      $display("finish");
      // output ppu data
      // wait(pixel_count >= WIDTH * HEIGHT);
      #1;
      file = $fopen("frame.ppm", "w");
      if (file == 0) begin
        $display("ERROR: Could not open frame.ppm for writing.");
        $finish;
      end
      $fwrite(file, "P3\n%0d %0d\n255\n", WIDTH, HEIGHT);
      for (r = 0; r < HEIGHT; r = r + 1) begin
        for (c = 0; c < WIDTH; c = c + 1) begin
          case (frame_buffer[r][c])
              2'b11: {red, green, blue} = {0,0,0};
              2'b10: {red, green, blue} = {85,85,85};
              2'b01: {red, green, blue} = {170,170,170};
              2'b00: {red, green, blue} = {255,255,255};
          endcase
          $fwrite(file, "%0d %0d %0d ", red, green, blue);
        end
        $fwrite(file, "\n");
      end
      $fclose(file);
      $fclose(f);
      $display("Frame written to frame.ppm");
      $finish;

      end

    if(gb.stop) begin
      $display("Finshed %s\n", tests[progNum]);
      $finish;
    end
  end

endmodule

