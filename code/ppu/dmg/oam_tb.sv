`timescale 1ns/1ps

module tb_OAM_Search;

  // Clock, reset and control signals.
  logic clk;
  logic reset;
  logic start;
  logic [7:0] current_line;

  // DUT memory interface signals.
  logic [15:0] oam_port0_addr;
  logic [15:0] oam_port1_addr;
  logic [15:0] oam_port0_data;
  logic [15:0] oam_port1_data;

  // DUT output signals.
  logic done;
  logic [3:0] sprite_count;
  // Declare selected_sprites as an unpacked array of sprite_t.
  sprite_t selected_sprites [0:9];

  // Simulated OAM memory: 80 words (for 40 sprites, two words per sprite).
  reg [15:0] oam_mem [0:79];

  // Clock generation: 10 ns period.
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Drive the memory data based on the DUT address outputs.
  assign oam_port0_data = oam_mem[oam_port0_addr];
  assign oam_port1_data = oam_mem[oam_port1_addr];

  // Instantiate the DUT.
  OAM_Search uut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .current_line(current_line),
    .oam_port0_addr(oam_port0_addr),
    .oam_port0_data(oam_port0_data),
    .oam_port1_addr(oam_port1_addr),
    .oam_port1_data(oam_port1_data),
    .done(done),
    .sprite_count(sprite_count),
    .selected_sprites(selected_sprites)
  );

  reg [7:0] x_val, y_val, tile_val, flag_val;
  integer i;
  initial begin
    for (i = 0; i < 40; i = i + 1) begin
      x_val = 200 - i * 3;
      y_val = 60;
      tile_val = 8'hF0 + i;
      flag_val = i % 2;
      oam_mem[i*2]   = { x_val, y_val };
      oam_mem[i*2+1] = { flag_val, tile_val };
    end
  end

  // Print the original OAM data.
  initial begin
    #10; // Allow initialization to complete.
    $display("Original OAM Data:");
    for (i = 0; i < 40; i = i + 1) begin
      $display("Sprite %0d: y = %0d, x = %0d, tile_index = %0d, flags = %0d",
               i,
               oam_mem[i*2][7:0],
               oam_mem[i*2][15:8],
               oam_mem[i*2+1][7:0],
               oam_mem[i*2+1][15:8]);
    end
  end

  // Testbench stimulus: Reset, pulse start, and set current_line.
  initial begin
    reset = 1;
    start = 0;
    current_line = 8'd50;  // Choose a current line to select some sprites.
    #20;
    reset = 0;
    #10;
    start = 1;    // Pulse start.
    #10;
    start = 0;
  end

  initial begin
    wait(done);
    #10; // Wait a bit after done is asserted.
    $display("\nSorted Selected Sprites (Count = %0d):", sprite_count);
    for (i = 0; i < sprite_count; i = i + 1) begin
      $display("Sprite %0d: y = %0d, x = %0d, tile_index = %0d, flags = %0d",
               i,
               selected_sprites[i].y,
               selected_sprites[i].x,
               selected_sprites[i].tile_index,
               selected_sprites[i].flags);
    end
    $finish;
  end

endmodule
