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
    $readmemh("../ppu/tetris/frame1/vram.txt", vram);

    // oam.txt should have 160 hex bytes.
    $readmemh("../ppu/tetris/frame1/oam.txt", oam);
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

module frame_buffer_vga (
  input  logic         clk,
  input  logic         reset,
  input  logic [1:0]   pixel_in,
  input  logic         pixel_valid,
  output logic         hsync,
  output logic         vsync,
  output logic [23:0]  vga_color
);
  localparam int FRAME_WIDTH  = 640;
  localparam int FRAME_HEIGHT = 480;
  localparam int MEM_SIZE     = FRAME_WIDTH * FRAME_HEIGHT;
  localparam int SCALE        = 3;
  localparam int H_ACTIVE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48;
  localparam int H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
  localparam int V_ACTIVE = 480, V_FRONT = 10, V_SYNC = 2, V_BACK = 33;
  localparam int V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;
  
  logic [1:0] mem [0:MEM_SIZE-1];
  
  logic [7:0] src_x, src_y;
  logic [3:0] rep_count;
  logic [15:0] base_addr;
  
  typedef enum logic [1:0] {IDLE, WRITE_BLOCK} write_state_t;
  write_state_t write_state;
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      src_x <= 0;
      src_y <= 0;
      write_state <= IDLE;
      rep_count <= 0;
    end else begin
      case (write_state)
        IDLE: if (pixel_valid) begin
                base_addr <= (src_y * SCALE) * FRAME_WIDTH + (src_x * SCALE);
                rep_count <= 0;
                write_state <= WRITE_BLOCK;
              end
        WRITE_BLOCK: begin
                       mem[base_addr + ((rep_count / SCALE) * FRAME_WIDTH) + (rep_count % SCALE)] <= pixel_in;
                       if (rep_count == SCALE*SCALE - 1) begin
                         write_state <= IDLE;
                         if (src_x == 8'd159) begin
                           src_x <= 0;
                           if (src_y == 8'd143)
                             src_y <= 0;
                           else
                             src_y <= src_y + 1;
                         end else
                           src_x <= src_x + 1;
                       end else
                         rep_count <= rep_count + 1;
                     end
      endcase
    end
  end
  
  logic [9:0] h_count, v_count;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      h_count <= 0;
      v_count <= 0;
    end else begin
      if (h_count == H_TOTAL - 1) begin
        h_count <= 0;
        if (v_count == V_TOTAL - 1)
          v_count <= 0;
        else
          v_count <= v_count + 1;
      end else
        h_count <= h_count + 1;
    end
  end
  
  logic [15:0] read_addr;
  logic [1:0] pixel_val;
  assign read_addr = (h_count < H_ACTIVE && v_count < V_ACTIVE) ? (v_count * FRAME_WIDTH + h_count) : 16'd0;
  assign pixel_val = (h_count < H_ACTIVE && v_count < V_ACTIVE) ? mem[read_addr] : 2'd0;

  
  function automatic [23:0] map_color(input logic [1:0] p);
    case (p)
      2'd0: map_color = 24'hFFFFFF;
      2'd1: map_color = 24'hCCCCCC;
      2'd2: map_color = 24'h888888;
      2'd3: map_color = 24'h000000;
      default: map_color = 24'h000000;
    endcase
  endfunction
  
  assign vga_color = map_color(pixel_val);
  assign hsync = ~((h_count >= (H_ACTIVE + H_FRONT)) && (h_count < (H_ACTIVE + H_FRONT + H_SYNC)));
  assign vsync = ~((v_count >= (V_ACTIVE + V_FRONT)) && (v_count < (V_ACTIVE + V_FRONT + V_SYNC)));
endmodule

module top_de2_115 (
  input  logic         CLOCK_50,
  input  logic [3:0]   KEY,
  output logic [3:0]   VGA_R,
  output logic [3:0]   VGA_G,
  output logic [3:0]   VGA_B,
  output logic         VGA_HS,
  output logic         VGA_VS,
  output logic [7:0]   LED
);
  logic reset;
  assign reset = ~KEY[0];
  
  logic sys_clk;
  assign sys_clk = CLOCK_50;
  
  localparam logic [7:0] DEFAULT_LCDC   = 8'h91,
                          DEFAULT_STAT   = 8'd0,
                          DEFAULT_LY     = 8'd0,
                          DEFAULT_LYC    = 8'd0,
                          DEFAULT_SCX    = 8'd0,
                          DEFAULT_SCY    = 8'd0,
                          DEFAULT_WX     = 8'd7,
                          DEFAULT_WY     = 8'd0,
                          DEFAULT_BGP    = 8'he4,
                          DEFAULT_OBP0   = 8'hd0,
                          DEFAULT_OBP1   = 8'he0;
  
  logic [1:0] frame_pixel;
  logic         frame_pixel_valid;
  logic [1:0]   mode;
  logic [15:0]  port0_addr, port1_addr;
  logic         port0_read_en, port1_read_en;
  logic [15:0]  port0_data, port1_data;
  logic [23:0] vga_color;
  
  PPU_Wrapper ppu_inst (
    .clk(sys_clk),
    .reset(reset),
    .LCDC(DEFAULT_LCDC),
    .STAT_in(DEFAULT_STAT),
    .LY(DEFAULT_LY),
    .LYC(DEFAULT_LYC),
    .SCX(DEFAULT_SCX),
    .SCY(DEFAULT_SCY),
    .WX(DEFAULT_WX),
    .WY(DEFAULT_WY),
    .BGP(DEFAULT_BGP),
    .OBP0(DEFAULT_OBP0),
    .OBP1(DEFAULT_OBP1),
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
  
  frame_buffer_vga fbvga_inst (
    .clk(sys_clk),
    .reset(reset),
    .pixel_in(frame_pixel),
    .pixel_valid(frame_pixel_valid),
    .hsync(VGA_HS),
    .vsync(VGA_VS),
    .vga_color(vga_color)
  );
  
  assign VGA_R = vga_color[19:16];
  assign VGA_G = vga_color[11:8];
  assign VGA_B = vga_color[3:0];

  assign LED[0] = reset;
  assign LED[1] = VGA_HS;
  assign LED[7:2] = 6'b0;
endmodule
