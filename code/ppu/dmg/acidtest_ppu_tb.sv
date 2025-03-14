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
    $readmemh("../ppu/dmgacid2/vram.txt", vram);

    // oam.txt should have 160 hex bytes.
    $readmemh("../ppu/dmgacid2/oam.txt", oam);
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
`timescale 1ns/1ps
`default_nettype none

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
  logic [1:0]   mode;
  
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
    .mode(mode),
    .port0_addr(port0_addr),
    .port0_read_en(port0_read_en),
    .port0_data(port0_data),
    .port1_addr(port1_addr),
    .port1_read_en(port1_read_en),
    .port1_data(port1_data),
    .frame_pixel(frame_pixel),
    .frame_pixel_valid(frame_pixel_valid)
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
  
  // Basic initialization and dynamic register updates.
  // The following loop simulates one frame (154 scanlines, 456 cycles each)
  // and updates registers at specific scanlines to mimic the assembly routines.
  initial begin
    reset   = 1;
    // Set initial registers (matching your original testbench values)
    LCDC    = 8'hd1;  // Initially: LCD on, window map $9C00, BG on, and (sprite size = 8x16)
    STAT_in = 8'd0;
    LY      = 8'd0;
    LYC     = 8'h08;  // Schedule first mid‑frame change at scanline 8.
    SCX     = 8'hf3;
    SCY     = 8'h20;
    WX      = 8'h5F;  // On‑screen position (0x58+7)
    WY      = 8'h28;
    BGP     = 8'he4;
    OBP0    = 8'he4;
    OBP1    = 8'h2c;
    #20;
    reset = 0;
    
    // For each scanline, update LY and check for mid‑frame changes.
    for (integer line = 0; line < 154; line = line + 1) begin
      LY = line;
      
      // Implement the same mid‑frame changes as in the assembly routines:
      if (line == 8) begin
        // LY_08: disable background (clear bit0) then set LYC = 0x10.
        LCDC = LCDC & ~8'h01;
        LYC  = 8'h10;
      end else if (line == 16) begin
        // LY_10: enable background (set bit0) and window (set bit5); set LYC = 0x30.
        LCDC = LCDC | 8'h01;  // set bit0
        LCDC = LCDC | 8'h20;  // set bit5
        LYC  = 8'h30;
      end else if (line == 48) begin
        // LY_30: disable alternate tile data (clear bit4); set LYC = 0x38.
        LCDC = LCDC & ~8'h10;
        LYC  = 8'h38;
      end else if (line == 56) begin
        // LY_38: disable window by moving WX off‐screen and re‑enable tile data (set bit4); set LYC = 0x3F.
        WX   = 8'd240;       // 240 is off‐screen.
        LCDC = LCDC | 8'h10;  // set bit4
        LYC  = 8'h3F;
      end else if (line == 63) begin
        // LY_3F: again ensure window is disabled (WX remains off‑screen); set LYC = 0x58.
        WX   = 8'd240;
        LYC  = 8'h58;
      end else if (line == 88) begin
        // LY_58: set sprite size to 8x16 (set bit2); set LYC = 0x68.
        LCDC = LCDC | 8'h04;  // set bit2
        LYC  = 8'h68;
      end else if (line == 104) begin
        // LY_68: change sprite size to 8x8 (clear bit2) and disable sprites (clear bit1); set LYC = 0x70.
        LCDC = LCDC & ~8'h04;  // clear bit2
        LCDC = LCDC & ~8'h02;  // clear bit1
        LYC  = 8'h70;
      end else if (line == 112) begin
        // LY_70: enable window by positioning WX on‑screen (0x5F) and disable window map $9800 (clear bit6); set LYC = 0x80.
        WX   = 8'h5F;
        LCDC = LCDC & ~8'h40;  // clear bit6
        LYC  = 8'h80;
      end else if (line == 128) begin
        // LY_80: enable bg map $9C00 (set bit3) and disable alternate tile data (clear bit4); set LYC = 0x81.
        LCDC = LCDC | 8'h08;   // set bit3
        LCDC = LCDC & ~8'h10;  // clear bit4
        LYC  = 8'h81;
      end else if (line == 129) begin
        // LY_81: disable window (clear bit5) and switch to window map $9C00 (set bit6); set LYC = 0x82.
        LCDC = LCDC & ~8'h20;  // clear bit5
        LCDC = LCDC | 8'h40;   // set bit6
        LYC  = 8'h82;
      end else if (line == 130) begin
        // LY_82: adjust SCX for proper footer positioning; set LYC = 0x8F.
        SCX  = 8'hf3;
        LYC  = 8'h8F;
      end else if (line == 143) begin
        // LY_8F: disable bg map $9800 (clear bit3) and enable tile data bank $8000-8FFF (set bit4); set LYC = 0x90.
        LCDC = LCDC & ~8'h08;  // clear bit3
        LCDC = LCDC | 8'h10;   // set bit4
        LYC  = 8'h90;
      end else if (line == 144) begin
        // LY_90: enable sprites (set bit1) and restore SCX to 0; then cycle LYC back to 0x08.
        LCDC = LCDC | 8'h02;   // set bit1
        SCX  = 8'h00;
        LYC  = 8'h08;
        // (In the assembly code a frame counter is decremented here.)
      end
      
      // Simulate each scanline taking 456 clock cycles.
      repeat (456) @(posedge clk);
    end
    repeat (10) @(posedge clk);
    $finish;
  end
  
  //------------------------------------------------------------------
  // Frame Capture and PPM File Writing (unchanged)
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
    file = $fopen("dmgacid2_new2.ppm", "w");
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
