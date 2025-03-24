module gameboy(
  input logic clk,clk2, //*** make a second clock
  input  logic rst,
  input  logic [1:0] ppu_mode
);

  logic [15:0] memData;
  logic memValid;
  logic [15:0] ie;
  logic [15:0] iflg;
  logic stop;
  logic [15:0] memWdata;
  logic [15:0] memWadr;
  logic memWen;
  logic [15:0] memAdr;
  cpu cpu(.clk(clk2),
          .rst,
          .memData,
          .memValid,
          .ie,.iflg,
          .stop,
          .memWdata,
          .memWadr,
          .memWen,
          .memAdr);

  MMU mmu(.CLK_4MHZ(clk),
          .cpu_clock(clk2),
          .rst,
          .cpu_addr_read(memAdr),
          .cpu_addr_write(memWadr),
          .cpu_wren(memWen),
          .cpu_in_data(memWdata),
          .stop_inst_hit(stop),
          .ppu_addr1(),
          .ppu_addr2(),
          .ppu_mode(ppu_mode),
          .hblank(ppu_mode==0),
          .vblank(ppu_mode==1),
          .joypad_select(1'b1),
          .joypad_start(1'b1),
          .joypad_dpad_up(1'b0),
          .joypad_dpad_down(1'b0),
          .joypad_dpad_left(1'b0),
          .joypad_dpad_right(1'b0),
          .joypad_a_button(1'b1),
          .joypad_b_button(1'b1),
          .APU_NR52(4'b0),
          .cpu_out_data(memData),
          .cpu_data_valid(memValid),
          .ppu_out_data1(),
          .ppu_out_data2(),
          .ppu_data_valid(),
          .restart_after_stop()
          );

endmodule
