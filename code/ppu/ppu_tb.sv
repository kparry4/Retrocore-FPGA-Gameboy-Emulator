`timescale 1ns/1ps
`default_nettype none


module dualport_readonly_mem (
  input  logic        clk,

  // ----------------------
  // Port A
  // ----------------------
  input  logic [15:0] addr_a,
  input  logic        read_en_a,
  output logic [15:0] data_a,

  // ----------------------
  // Port B
  // ----------------------
  input  logic [15:0] addr_b,
  input  logic        read_en_b,
  output logic [15:0] data_b
);

  // ----------------------------------------------------------------
  // Address Map and Array Sizes
  // ----------------------------------------------------------------
  localparam logic [15:0] VRAM_START = 16'h8000;
  localparam logic [15:0] VRAM_END   = 16'h9FFF;
  localparam integer      VRAM_SIZE  = VRAM_END - VRAM_START + 1;

  localparam logic [15:0] OAM_START  = 16'hFE00;
  localparam logic [15:0] OAM_END    = 16'hFE9F;
  localparam integer      OAM_SIZE   = OAM_END - OAM_START + 1;

  // ----------------------------------------------------------------
  // VRAM and OAM Arrays (8-bit wide) with readmemh
  // ----------------------------------------------------------------
  // VRAM holds 0x2000 bytes (8 KB) in the range [0x8000..0x9FFF]
  reg [7:0] vram [0:VRAM_SIZE-1];

  // OAM holds 0xA0 bytes (160 bytes) in the range [0xFE00..0xFE9F]
  reg [7:0] oam  [0:OAM_SIZE-1];

  // Initialize each array from a HEX file. Provide the correct file names:
  initial begin
    // vram.txt should have 8192 hex bytes.
    $readmemh("../ppu/drmario/vram.txt", vram);

    // oam.txt should have 160 hex bytes.
    $readmemh("../ppu/drmario/oam.txt", oam);
  end

  // ----------------------------------------------------------------
  // Port A Read Logic
  // ----------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (read_en_a) begin
      // Check if address is in VRAM range
      if (addr_a >= VRAM_START && addr_a <= VRAM_END) begin
        // Combine two bytes into a 16-bit word
        //   Lower byte = vram[addr - VRAM_START]
        //   Upper byte = vram[addr - VRAM_START + 1]
        data_a <= {
          vram[addr_a - VRAM_START + 1],
          vram[addr_a - VRAM_START]
        };
      end
      // Check if address is in OAM range
      else if (addr_a >= OAM_START && addr_a <= OAM_END) begin
        data_a <= {
          oam[addr_a - OAM_START + 1],
          oam[addr_a - OAM_START]
        };
      end
      // Otherwise, default value
      else begin
        data_a <= 16'hDEAD;
      end
    end
    else begin
      data_a <= 16'h0000;
    end
  end

  // ----------------------------------------------------------------
  // Port B Read Logic
  // ----------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (read_en_b) begin
      if (addr_b >= VRAM_START && addr_b <= VRAM_END) begin
        data_b <= {
          vram[addr_b - VRAM_START + 1],
          vram[addr_b - VRAM_START]
        };
      end
      else if (addr_b >= OAM_START && addr_b <= OAM_END) begin
        data_b <= {
          oam[addr_b - OAM_START + 1],
          oam[addr_b - OAM_START]
        };
      end
      else begin
        data_b <= 16'hDEAD;
      end
    end
    else begin
      data_b <= 16'h0000;
    end
  end

endmodule


//------------------------------------------------------------------
// Testbench for PPU_Wrapper with File Output in PPM Format
//------------------------------------------------------------------
module tb_PPU;
  // Clock and reset signals.
  logic         clk;
  logic         reset;
  
  // PPU control registers.
  logic [7:0]   LCDC, STAT_in, LY, LYC, SCX, SCY, WX, WY, BGP, OBP0, OBP1;
  
  // Memory interface signals.
  logic [15:0]  port0_addr;
  logic         port0_read_en;
  logic [15:0]  port0_data;
  logic [15:0]  port1_addr;
  logic         port1_read_en;
  logic [15:0]  port1_data;
  
  // Frame outputs from the PPU_Wrapper.
  logic [1:0]   frame_pixel;
  logic         frame_pixel_valid;
  logic         hsync, vsync;
  logic [11:0]  vga_color;
  
  // Instantiate the PPU_Wrapper.
  PPU_Wrapper uut (
    .clk(clk),
    .reset(reset),
    .LCDC(LCDC),
    .STAT_in(STAT_in),
    .LY(LY),
    .LYC(LYC),
    .SCX(SCX),
    .SCY(SCY),
    .WX(WX),
    .WY(WY),
    .BGP(BGP),
    .OBP0(OBP0),
    .OBP1(OBP1),
    .port0_addr(port0_addr),
    .port0_read_en(port0_read_en),
    .port0_data(port0_data),
    .port1_addr(port1_addr),
    .port1_read_en(port1_read_en),
    .port1_data(port1_data),
    .frame_pixel(frame_pixel),
    .frame_pixel_valid(frame_pixel_valid),
    .hsync(hsync),
    .vsync(vsync),
    .vga_color(vga_color)
  );
  
  // Instantiate the dual-port memory.
  dualport_readonly_mem mem_model (
    .clk(clk),
    .addr_a(port0_addr),
    .read_en_a(port0_read_en),
    .data_a(port0_data),
    .addr_b(port1_addr),
    .read_en_b(port1_read_en),
    .data_b(port1_data)
  );
  
  // Clock generation: 100 MHz (10 ns period).
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Basic initialization.
  initial begin
    reset = 1;
    LCDC   = 8'h91;
    STAT_in = 8'd0;
    LY     = 8'd0;
    LYC    = 8'd0;
    SCX    = 8'd0;
    SCY    = 8'd0;
    WX     = 8'd7;
    WY     = 8'd0;
    BGP    = 8'he4;
    OBP0   = 8'hd2;
    OBP1   = 8'hd2;
    #20;
    reset = 0;
    
    // Drive LY for one frame (154 scanlines, 456 cycles each).
    for (integer line = 0; line < 154; line = line + 1) begin
      LY = line;
      repeat (456) @(posedge clk);
    end
    repeat (10) @(posedge clk);
    $finish;
  end
  
  //------------------------------------------------------------------
  // Frame Capture and PPM File Writing
  //------------------------------------------------------------------
  localparam WIDTH  = 160;
  localparam HEIGHT = 144;
  
  // 2D frame buffer for storing 12-bit VGA colors.
  reg [1:0] frame_buffer [0:HEIGHT-1][0:WIDTH-1];
  
  // Declare pixel_count and loop variables.
  integer pixel_count;
  integer r, c, red, green, blue, file;
  
  // Capture pixels and update pixel_count in one always_ff block.
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      pixel_count <= 0;
    end else if (frame_pixel_valid) begin
      integer row, col;
      row = pixel_count / WIDTH;
      col = pixel_count % WIDTH;
      if (row < HEIGHT) begin
        frame_buffer[row][col] <= frame_pixel;
        pixel_count <= pixel_count + 1;
      end
    end
  end
  
  // Write the captured frame to a PPM file when a full frame is captured.
  initial begin
    wait(pixel_count >= WIDTH * HEIGHT);
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
            2'b10: {red, green, blue} = {160,160,160};
            2'b01: {red, green, blue} = {211,211,211};
            2'b00: {red, green, blue} = {255,255,255};
        endcase 
        $fwrite(file, "%0d %0d %0d ", red, green, blue);
      end
      $fwrite(file, "\n");
    end
    $fclose(file);
    $display("Frame written to frame.ppm");
  end

endmodule
