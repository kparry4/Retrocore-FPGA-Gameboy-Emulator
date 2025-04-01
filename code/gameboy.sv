`define DOC
`include "Integration/MMU/RegisterPkg.svh"
module gameboy(
  input logic clk,clk2, //*** make a second clock
  input  logic rst,
  input logic [7:0] LY,
  output logic [1:0] frame_pixel,
  output logic frame_pixel_valid
);
  logic ppu_clk=1,cpu_clk=1;
  logic [15:0] memData,mmu_memData;
  logic memValid;
  logic [7:0] mmu_ie,ie;
  logic [7:0] mmu_iflg,iflg;
  logic stop;
  logic [15:0] memWdata;
  logic [15:0] memWadr;
  logic memWen;
  logic [7:0] ppu_LY;
  logic [1:0] ppu_mode;
  logic [15:0] memAdr;



  //PPU bullshit
  logic[7:0] LCDC_R;
  logic[7:0] STAT_R; //mixed r/w register
  PPU_DATA PPU_R;

  logic interupt;

  logic [15:0] port0_addr, port1_addr;
  logic [15:0] port0_data, port1_data;
  logic [1:0] cnt=0;



  flopenr #(1) validflop(cpu_clk,rst,memAdr===16'h100,1'b1,memValid);
  flop #(16) memflop(cpu_clk,mmu_memData, memData);
  flop #(16) memflg(cpu_clk,{mmu_ie,mmu_iflg}, {ie,iflg});
  always_ff @(posedge clk) begin
    // if (rst) begin
    //   cpu_clk = clk;
    //   cnt = 0;
    //   //cpu_ppu = 0;
    // end
    if(&cnt) cpu_clk = ~cpu_clk;
    if(cnt[0]) ppu_clk = ~ppu_clk;
    cnt++;
  end
    

  cpu cpu(.clk(cpu_clk),
          .rst,
          .memData(memData),
          .memValid,
          .ie,.iflg,
          .stop,
          .interupt,
          .memWdata,
          .memWadr,
          .memWen,
          .memAdr);

  MMU mmu(.CLK_4MHZ(clk),
          .ppu_clock(clk2),//*** change
          .cpu_clock(cpu_clk),//*** change
          .rst,
          .cpu_addr_read(memAdr),
          .cpu_addr_write(memWadr),
          .cpu_wren(memWen),
          .cpu_in_data(memWdata),
          .stop_inst_hit(stop),
          .ppu_addr1(port0_addr),
          .ppu_addr2(port1_addr),
          .ppu_mode(ppu_mode),
          .ppu_LY,
          .interupt,
          .hblank(ppu_mode==0),
          .vblank(ppu_mode==1),
          .joypad_select(1'b0),
          .joypad_start(1'b0),
          .joypad_dpad_up(1'b0),
          .joypad_dpad_down(1'b0),
          .joypad_dpad_left(1'b0),
          .joypad_dpad_right(1'b0),
          .joypad_a_button(1'b0),
          .joypad_b_button(1'b0),
          .APU_NR52(4'b0),
          .LCDC_R,
          .STAT_R,
          .PPU_R,
          .IF_R(mmu_iflg),
          .IE_R(mmu_ie),
          .cpu_out_data(mmu_memData),
          // .cpu_data_valid(memValid),
          .ppu_out_data1(port0_data),
          .ppu_out_data2(port1_data),
          .ppu_data_valid(), //no longer used
          .restart_after_stop()
          );

          PPU_Wrapper ppu(.clk(clk2),
                          .reset(rst),
                          // .LCDC(8'hd3),
                          .LCDC(LCDC_R),
                          .STAT_in(STAT_R),
                          .LY(ppu_LY),
                          .LYC(PPU_R.LYC_R),
                          .SCX(PPU_R.SCX_R),
                          .SCY(PPU_R.SCY_R),
                          .WX(PPU_R.WX_R),
                          .WY(PPU_R.WY_R),
                          .BGP(PPU_R.BGP_R),
                          // .OBP0(8'he4),
                          // .OBP1(8'he4),
                          .OBP0(PPU_R.OBP0_R),
                          .OBP1(PPU_R.OBP1_R),
                          .mode(ppu_mode),
                          .port0_addr,
                          .port0_read_en(), //unneedd output
                          .port0_data,
                          .port1_addr,
                          .port1_read_en(), //unneeded output
                          .port1_data,
                          .frame_pixel,
                          .frame_pixel_valid
                          );
endmodule
