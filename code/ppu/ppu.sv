`timescale 1ns/1ps
`default_nettype none

//==================================================================
// Data Structures
//==================================================================
typedef struct packed {
  logic [9:0] x;
  logic [9:0] y;
  logic [1:0] pixel;
  logic [7:0] palette;
  logic       sprite_priority;
} pixel_t;

typedef struct packed {
  logic [7:0] y;
  logic [7:0] x;
  logic [7:0] tile_index;
  logic [7:0] flags;
} sprite_t;

//==================================================================
// Module: PPU_Mode_controller
//==================================================================
module PPU_Mode_controller (
  input  logic         clk,
  input  logic         reset,
  input  logic         scanline_processed,
  output logic [8:0]   dot,
  output logic [7:0]   line,
  output logic [1:0]   mode,
  output logic         fifo_clear
);
  always_comb begin
    if(line < 8'd144) begin
      if(dot < 9'd80)
        mode = 2;
      else if(~scanline_processed)
        mode = 3;
      else
        mode = 0;
    end else begin
      mode = 1;
    end
  end

  always_ff @(posedge clk or posedge reset) begin
    if(reset) begin
      dot        <= 9'd0;
      line       <= 8'd0;
      fifo_clear <= 1'b1;
    end else begin
      fifo_clear <= (dot == 9'd0);
      if(dot < 9'd455)
        dot <= dot + 9'd1;
      else begin
        dot <= 9'd0;
        if(line < 8'd153)
          line <= line + 8'd1;
        else
          line <= 8'd0;
      end
    end
  end
endmodule

//==================================================================
// Module: STAT_handler
//==================================================================
module STAT_handler (
  input  logic        clk,
  input  logic        reset,
  input  logic [1:0]  mode,
  input  logic [7:0]  LY,
  input  logic [7:0]  LYC,
  input  logic [7:0]  LCDC,
  output logic [7:0]  STAT,
  output logic        stat_interrupt
);
  always_ff @(posedge clk or posedge reset) begin
    if(reset) begin
      STAT           <= 8'd0;
      stat_interrupt <= 1'b0;
    end else begin
      STAT[1:0] <= mode;
      STAT[2]   <= (LY == LYC);
      stat_interrupt <= ((mode==0)||(mode==1)||(mode==2)||(LY==LYC)) ? 1'b1 : 1'b0;
    end
  end
endmodule

//==================================================================
// Module: OAM_Search
//==================================================================
module OAM_Search (
  input  logic          clk,
  input  logic          reset,
  input  logic          start,
  input  logic [7:0]    current_line,
  output logic [15:0]   oam_port0_addr,
  input  logic [15:0]   oam_port0_data,
  output logic [15:0]   oam_port1_addr,
  input  logic [15:0]   oam_port1_data,
  output logic          done,
  output logic [3:0]    sprite_count,
  output sprite_t       selected_sprites [0:9]
);

  parameter SPRITE_HEIGHT = 8;

  typedef enum logic [1:0] {
    OAM_IDLE,
    OAM_FETCH,
    OAM_SORT,
    OAM_DONE
  } oam_state_t;
  oam_state_t state, next_state;

  logic [5:0] oam_index;
  logic [3:0] selected_count;
  sprite_t selected_sprites_reg [0:9];
  logic [3:0] sort_i, sort_j;
  sprite_t temp_sprite;
  
  typedef enum logic { SORT_EVEN, SORT_ODD } sort_phase_t;
  sort_phase_t sort_phase;

  assign sprite_count = selected_count;
  // Drive done from a single always_ff block.
  always_ff @(posedge clk or posedge reset) begin
    if(reset) begin
      state          <= OAM_IDLE;
      oam_index      <= 6'd0;
      selected_count <= 4'd0;
      sort_i         <= 4'd0;
      sort_j         <= 4'd0;
      sort_phase     <= SORT_EVEN;
      done           <= 1'b0;
    end else begin
      state <= next_state;
      if(state == OAM_DONE)
        done <= 1'b1;
      else
        done <= 1'b0;
      case (state)
        OAM_IDLE: begin
          if(start) begin
            oam_index      <= 6'd0;
            selected_count <= 4'd0;
            sort_i         <= 4'd0;
            sort_j         <= 4'd0;
            sort_phase     <= SORT_EVEN;
          end
        end
        OAM_FETCH: begin
          oam_port0_addr <= oam_index << 1;
          oam_port1_addr <= (oam_index << 1) + 16'd1;
          temp_sprite.y           = oam_port0_data[7:0];
          temp_sprite.x           = oam_port0_data[15:8];
          temp_sprite.tile_index  = oam_port1_data[7:0];
          temp_sprite.flags       = oam_port1_data[15:8];
          if ((current_line >= (temp_sprite.y - 8'd16)) &&
              (current_line < (temp_sprite.y - 8'd16 + SPRITE_HEIGHT))) begin
            if (selected_count < 4'd10) begin
              selected_sprites_reg[selected_count] <= temp_sprite;
              selected_count <= selected_count + 1;
            end
          end
          oam_index <= oam_index + 1;
        end
        OAM_SORT: begin
          if (sort_i < (selected_count - 1)) begin
            if (sort_phase == SORT_EVEN) begin
              if (sort_j < selected_count - 1) begin
                if (selected_sprites_reg[sort_j].x > selected_sprites_reg[sort_j+1].x) begin
                  sprite_t tmp;
                  tmp = selected_sprites_reg[sort_j];
                  selected_sprites_reg[sort_j]   <= selected_sprites_reg[sort_j+1];
                  selected_sprites_reg[sort_j+1] <= tmp;
                end
              end
              if ((sort_j + 2) < selected_count - 1) begin
                if (selected_sprites_reg[sort_j+2].x > selected_sprites_reg[sort_j+3].x) begin
                  sprite_t tmp2;
                  tmp2 = selected_sprites_reg[sort_j+2];
                  selected_sprites_reg[sort_j+2] <= selected_sprites_reg[sort_j+3];
                  selected_sprites_reg[sort_j+3] <= tmp2;
                end
              end
              sort_j <= sort_j + 4;
              if (sort_j + 4 >= selected_count) begin
                sort_j     <= 4'd0;
                sort_phase <= SORT_ODD;
                sort_i     <= sort_i + 1;
              end
            end else begin // SORT_ODD phase
              if ((sort_j + 1) < selected_count - 1) begin
                if (selected_sprites_reg[sort_j+1].x > selected_sprites_reg[sort_j+2].x) begin
                  sprite_t tmp;
                  tmp = selected_sprites_reg[sort_j+1];
                  selected_sprites_reg[sort_j+1] <= selected_sprites_reg[sort_j+2];
                  selected_sprites_reg[sort_j+2] <= tmp;
                end
              end
              if ((sort_j + 3) < selected_count - 1) begin
                if (selected_sprites_reg[sort_j+3].x > selected_sprites_reg[sort_j+4].x) begin
                  sprite_t tmp2;
                  tmp2 = selected_sprites_reg[sort_j+3];
                  selected_sprites_reg[sort_j+3] <= selected_sprites_reg[sort_j+4];
                  selected_sprites_reg[sort_j+4] <= tmp2;
                end
              end
              sort_j <= sort_j + 4;
              if (sort_j + 4 >= selected_count) begin
                sort_j     <= 4'd0;
                sort_phase <= SORT_EVEN;
                sort_i     <= sort_i + 1;
              end
            end
          end
        end
        OAM_DONE: begin
          // done is driven above.
        end
        default: ;
      endcase
    end
  end

  // Output selected sprites.
  always_comb begin
    for (int j = 0; j < 10; j = j + 1)
      selected_sprites[j] = selected_sprites_reg[j];
  end

  // Compute next state without driving outputs.
  always_comb begin
    case (state)
      OAM_IDLE: begin
        if (start)
          next_state = OAM_FETCH;
        else
          next_state = OAM_IDLE;
      end
      OAM_FETCH: begin
        if (oam_index == 40)
          next_state = (selected_count > 4'd0) ? OAM_SORT : OAM_DONE;
        else
          next_state = OAM_FETCH;
      end
      OAM_SORT: begin
        if (sort_i >= (selected_count - 1))
          next_state = OAM_DONE;
        else
          next_state = OAM_SORT;
      end
      OAM_DONE: begin
        next_state = OAM_IDLE;
      end
      default: next_state = OAM_IDLE;
    endcase
  end
endmodule

//==================================================================
// Module: FIFO
//==================================================================
module FIFO #(
  parameter DEPTH = 16,
  parameter THRESHOLD = 8,
  parameter type T = pixel_t
) (
  input  logic clk,
  input  logic reset,
  input  logic clear,
  input  logic push,
  input  T data_in,
  input  logic pop,
  output T data_out,
  output logic empty,
  output logic full,
  output logic [$clog2(DEPTH+1)-1:0] size,
  output logic out_valid
);
  localparam FIFO_ADDR_WIDTH = $clog2(DEPTH);
  reg [FIFO_ADDR_WIDTH-1:0] wr_ptr;
  reg [FIFO_ADDR_WIDTH-1:0] rd_ptr;
  reg [$clog2(DEPTH+1)-1:0] count;
  T fifo_mem [0:DEPTH-1];

  always_ff @(posedge clk or posedge reset) begin
    if(reset) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
      count  <= 0;
    end else if(clear) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
      count  <= 0;
    end else begin
      if(push && !full) begin
        fifo_mem[wr_ptr] <= data_in;
        wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
        count  <= count + 1;
      end
      if(pop && (count >= THRESHOLD)) begin
        rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
        count  <= count - 1;
      end
    end
  end
  
  assign empty     = (count == 0);
  assign full      = (count == DEPTH);
  assign size      = count;
  assign out_valid = (count >= THRESHOLD);
  assign data_out  = (out_valid) ? fifo_mem[rd_ptr] : '0;
endmodule

//==================================================================
// Module: Render_BG
//==================================================================
module Render_BG (
  input  logic clk,
  input  logic reset,
  input  logic start,
  input  logic fifo_clear,
  input  logic [7:0] LCDC,
  input  logic [7:0] SCX,
  input  logic [7:0] SCY,
  input  logic [7:0] LY,
  input  logic [7:0] BGP,
  output logic [15:0] port0_addr,
  output logic port0_read_en,
  input  logic [15:0] port0_data,
  input  logic        port0_data_valid,
  output pixel_t       bg_fifo_data,
  output logic       bg_done
);
  typedef enum logic [2:0] {
    BG_IDLE,
    BG_FETCH_TILE,
    BG_FETCH_TILE_MAP,
    BG_FETCH_TILE_DATA,
    BG_PROCESS_PIXELS,
    BG_DONE
  } bg_state_t;
  bg_state_t state, next_state;

  logic [7:0] effective_line;
  logic [15:0] tile_map_addr;
  logic [7:0] tile_map_byte;
  logic [15:0] tile_data_addr;
  logic [15:0] bg_tile_data_word;
  // Combine the pixel index updates into a single process.
  logic [2:0] pixel_index;
  pixel_t bg_pixel;
  logic push_bg;

  // State machine for BG rendering.
  always_ff @(posedge clk or posedge reset) begin
    if(reset) begin
      state <= BG_IDLE;
      pixel_index <= 3'd0;
      bg_pixel <= '0;
      push_bg <= 1'b0;
    end else begin
      state <= next_state;
      if(state == BG_PROCESS_PIXELS) begin
        bg_pixel.x <= SCX + pixel_index;
        bg_pixel.y <= effective_line;
        bg_pixel.pixel <= { bg_tile_data_word[15 - pixel_index], bg_tile_data_word[7 - pixel_index] };
        bg_pixel.palette <= BGP;
        bg_pixel.sprite_priority <= 1'b0;
        push_bg <= 1'b1;
        if(pixel_index < 3'd7)
          pixel_index <= pixel_index + 1;
        else
          pixel_index <= 3'd0;
      end else begin
        push_bg <= 1'b0;
      end
    end
  end

  always_comb begin
    effective_line = LY + SCY;
    case(state)
      BG_IDLE: next_state = (start) ? BG_FETCH_TILE : BG_IDLE;
      BG_FETCH_TILE: begin
        if(LCDC[3] == 1'b0)
          tile_map_addr = 16'h9800 + {8'd0, effective_line} + SCX;
        else
          tile_map_addr = 16'h9C00 + {8'd0, effective_line} + SCX;
        next_state = BG_FETCH_TILE_MAP;
      end
      BG_FETCH_TILE_MAP: next_state = (port0_read_en) ? BG_FETCH_TILE_DATA : BG_FETCH_TILE_MAP;
      BG_FETCH_TILE_DATA: begin
        tile_data_addr = 16'h8000 + {8'd0, tile_map_byte};
        next_state = (port0_read_en) ? BG_PROCESS_PIXELS : BG_FETCH_TILE_DATA;
      end
      BG_PROCESS_PIXELS: next_state = (pixel_index < 3'd7) ? BG_PROCESS_PIXELS : BG_DONE;
      BG_DONE: next_state = BG_IDLE;
      default: next_state = BG_IDLE;
    endcase
  end

  assign port0_addr = (state == BG_FETCH_TILE_MAP) ? tile_map_addr :
                      (state == BG_FETCH_TILE_DATA) ? tile_data_addr : 16'd0;
  assign port0_read_en = (state == BG_FETCH_TILE_MAP) || (state == BG_FETCH_TILE_DATA);

  always_ff @(posedge clk) begin
    if(state == BG_FETCH_TILE_MAP && port0_read_en)
      tile_map_byte <= port0_data[7:0];
    if(state == BG_FETCH_TILE_DATA && port0_read_en)
      bg_tile_data_word <= port0_data;
  end

  assign bg_done = (state == BG_DONE);
  assign bg_fifo_data = bg_pixel;
endmodule

//==================================================================
// Module: Render_Sprites
//==================================================================
module Render_Sprites (
  input  logic clk,
  input  logic reset,
  input  logic start,
  input  logic [7:0] LCDC,
  input  logic [7:0] LY,
  input  logic [7:0] obj0,
  input  logic [7:0] obj1,
  input  logic [3:0] sprite_count,
  input  sprite_t selected_sprites [0:9],
  input  logic [9:0] current_x,
  output logic [15:0] port1_addr,
  output logic port1_read_en,
  input  logic [15:0] port1_data,
  input  logic        port1_data_valid,
  output pixel_t       sprite_fifo_data,
  output logic       sprite_done
);
  typedef enum logic [2:0] {
    SPR_IDLE,
    SPR_CHECK,
    SPR_FETCH_DATA,
    SPR_PROCESS_PIXELS,
    SPR_DONE
  } spr_state_t;
  spr_state_t state, next_state;

  logic [7:0] sprite_row_offset;
  logic [15:0] sprite_data_addr;
  logic [15:0] sprite_data_word;
  // Combine sprite_pixel_index updates in one always_ff.
  logic [2:0] sprite_pixel_index;
  // Use 4 bits for sprite_loop_max.
  logic [3:0] sprite_loop_max;
  pixel_t sprite_pixel;
  logic push_sprite;

  always_ff @(posedge clk or posedge reset) begin
    if(reset) begin
      state <= SPR_IDLE;
      sprite_pixel_index <= 3'd0;
      sprite_pixel <= '0;
      push_sprite <= 1'b0;
    end else begin
      state <= next_state;
      if(state == SPR_PROCESS_PIXELS) begin
        sprite_pixel.x <= selected_sprites[0].x + sprite_pixel_index; // (using index 0 for example)
        sprite_pixel.y <= LY;
        sprite_pixel.pixel <= { sprite_data_word[15 - sprite_pixel_index], sprite_data_word[7 - sprite_pixel_index] };
        sprite_pixel.sprite_priority <= 1'b1;
        sprite_pixel.palette <= (selected_sprites[0].flags[4]) ? obj1 : obj0;
        push_sprite <= 1'b1;
        if(sprite_pixel_index < (sprite_loop_max - 1))
          sprite_pixel_index <= sprite_pixel_index + 1;
        else
          sprite_pixel_index <= 3'd0;
      end else begin
        push_sprite <= 1'b0;
      end
    end
  end

  always_comb begin
    case(state)
      SPR_IDLE: next_state = (start) ? SPR_CHECK : SPR_IDLE;
      SPR_CHECK: next_state = (sprite_count > 0) ? SPR_FETCH_DATA : SPR_PROCESS_PIXELS;
      SPR_FETCH_DATA: next_state = (port1_data_valid) ? SPR_PROCESS_PIXELS : SPR_FETCH_DATA;
      SPR_PROCESS_PIXELS: next_state = (sprite_pixel_index < (sprite_loop_max - 1)) ? SPR_PROCESS_PIXELS : SPR_DONE;
      SPR_DONE: next_state = SPR_IDLE;
      default: next_state = SPR_IDLE;
    endcase
  end

  assign port1_addr = (state == SPR_FETCH_DATA) ? sprite_data_addr : 16'd0;
  assign port1_read_en = (state == SPR_FETCH_DATA);

  always_ff @(posedge clk) begin
    if(state == SPR_FETCH_DATA && port1_data_valid)
      sprite_data_word <= port1_data;
  end

  always_ff @(posedge clk) begin
    if(state == SPR_CHECK) begin
      sprite_row_offset <= LY - (selected_sprites[0].y - 8'd16);
      sprite_data_addr <= 16'h8000 + (selected_sprites[0].tile_index * 16) + sprite_row_offset;
      if(LCDC[2] == 1'b0)
        sprite_loop_max <= 4'd8;
      else
        sprite_loop_max <= 4'd4;
    end
  end

  assign sprite_done = (state == SPR_DONE);
  assign sprite_fifo_data = sprite_pixel;
endmodule

//==================================================================
// Module: Pixel_Gen
//==================================================================
module Pixel_Gen (
  input  logic         clk,
  input  logic         reset,
  input  logic         start,
  input  logic         fifo_clear,
  input  logic [7:0]   LCDC,
  input  logic [7:0]   SCX,
  input  logic [7:0]   SCY,
  input  logic [7:0]   LY,
  input  logic [7:0]   BGP,
  input  logic [7:0]   obj0,
  input  logic [7:0]   obj1,
  input  logic [3:0]   sprite_count,
  input  sprite_t      selected_sprites [0:9],
  // Background port interface
  output logic [15:0]  bg_port_addr,
  output logic         bg_port_read_en,
  input  logic [15:0]  bg_port_data,
  input  logic         bg_port_data_valid,
  // Sprite port interface
  output logic [15:0]  sprite_port_addr,
  output logic         sprite_port_read_en,
  input  logic [15:0]  sprite_port_data,
  input  logic         sprite_port_data_valid,
  // FIFO pixel outputs
  output pixel_t       bg_fifo_data,
  output pixel_t       sprite_fifo_data,
  output logic         scanline_processed
);
  logic bg_done, sprite_done;
  logic [9:0] current_x;
  assign current_x = SCX;
  
  Render_BG render_bg_inst (
    .clk(clk),
    .reset(reset),
    .start(start),
    .fifo_clear(fifo_clear),
    .LCDC(LCDC),
    .SCX(SCX),
    .SCY(SCY),
    .LY(LY),
    .BGP(BGP),
    .port0_addr(bg_port_addr),
    .port0_read_en(bg_port_read_en),
    .port0_data(bg_port_data),
    .port0_data_valid(bg_port_data_valid),
    .bg_fifo_data(bg_fifo_data),
    .bg_done(bg_done)
  );
  
  Render_Sprites render_sprites_inst (
    .clk(clk),
    .reset(reset),
    .start(start),
    .LCDC(LCDC),
    .LY(LY),
    .obj0(obj0),
    .obj1(obj1),
    .sprite_count(sprite_count),
    .selected_sprites(selected_sprites),
    .current_x(current_x),
    .port1_addr(sprite_port_addr),
    .port1_read_en(sprite_port_read_en),
    .port1_data(sprite_port_data),
    .port1_data_valid(sprite_port_data_valid),
    .sprite_fifo_data(sprite_fifo_data),
    .sprite_done(sprite_done)
  );
  
  assign scanline_processed = bg_done & sprite_done;
endmodule

//==================================================================
// Module: Pixel_Mixer
//==================================================================
module Pixel_Mixer (
  input  logic clk,
  input  logic reset,
  input  logic pixel_valid,
  input  pixel_t bg_pixel_in,
  input  pixel_t sprite_pixel_in,
  output logic [1:0] pixel_out
);
  function automatic [1:0] map_palette(
    input logic [1:0] pixel_idx,
    input logic [7:0] palette_reg
  );
    case(pixel_idx)
      2'd0: map_palette = palette_reg[1:0];
      2'd1: map_palette = palette_reg[3:2];
      2'd2: map_palette = palette_reg[5:4];
      2'd3: map_palette = palette_reg[7:6];
      default: map_palette = 2'b00;
    endcase
  endfunction
  
  always_ff @(posedge clk or posedge reset) begin
    if(reset)
      pixel_out <= 2'b00;
    else if(pixel_valid) begin
      if(sprite_pixel_in.sprite_priority && (sprite_pixel_in.pixel != 2'b00))
        pixel_out <= map_palette(sprite_pixel_in.pixel, sprite_pixel_in.palette);
      else
        pixel_out <= map_palette(bg_pixel_in.pixel, bg_pixel_in.palette);
    end
  end
endmodule

//==================================================================
// Module: DMG_Color_Mapper
//==================================================================
module DMG_Color_Mapper(
  input  logic [1:0] dmg_color,
  output logic [11:0] vga_color
);
  always_comb begin
    case(dmg_color)
      2'd0: vga_color = 12'hFFF;
      2'd1: vga_color = 12'hCCC;
      2'd2: vga_color = 12'h888;
      2'd3: vga_color = 12'h000;
      default: vga_color = 12'h000;
    endcase
  end
endmodule

//==================================================================
// Module: VGA_Controller
//==================================================================
module VGA_Controller (
  input  logic clk,
  input  logic reset,
  input  logic [1:0] fb_pixel,
  output logic hsync,
  output logic vsync,
  output logic [11:0] vga_color
);
  parameter H_ACTIVE = 160, H_FRONT = 8, H_SYNC = 16, H_BACK = 8;
  parameter V_ACTIVE = 144, V_FRONT = 4, V_SYNC = 2, V_BACK = 4;
  parameter H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
  parameter V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;
  
  logic [9:0] h_count, v_count;
  
  always_ff @(posedge clk or posedge reset) begin
    if(reset) begin
      h_count <= 0;
      v_count <= 0;
    end else begin
      if(h_count == H_TOTAL - 1) begin
        h_count <= 0;
        if(v_count == V_TOTAL - 1)
          v_count <= 0;
        else
          v_count <= v_count + 1;
      end else begin
        h_count <= h_count + 1;
      end
    end
  end
  
  assign hsync = ~((h_count >= (H_ACTIVE + H_FRONT)) &&
                   (h_count < (H_ACTIVE + H_FRONT + H_SYNC)));
  assign vsync = ~((v_count >= (V_ACTIVE + V_FRONT)) &&
                   (v_count < (V_ACTIVE + V_FRONT + V_SYNC)));
  
  DMG_Color_Mapper mapper (
    .dmg_color(fb_pixel),
    .vga_color(vga_color)
  );
endmodule

//==================================================================
// Module: PPU_Wrapper
//==================================================================
module PPU_Wrapper (
  input  logic clk,
  input  logic reset,
  input  logic [7:0] LCDC,
  input  logic [7:0] STAT_in,
  input  logic [7:0] LY,
  input  logic [7:0] LYC,
  input  logic [7:0] SCX,
  input  logic [7:0] SCY,
  input  logic [7:0] WX,
  input  logic [7:0] WY,
  input  logic [7:0] BGP,
  input  logic [7:0] OBP0,
  input  logic [7:0] OBP1,
  // OAM ports (for OAM_Search; active when dot < 80)
  output logic [15:0] oam_port0_addr,
  output logic        oam_port0_read_en,
  input  logic [15:0] oam_port0_data,
  output logic [15:0] oam_port1_addr,
  output logic        oam_port1_read_en,
  input  logic [15:0] oam_port1_data,
  // VRAM ports (for BG and Sprite rendering; active when dot >= 80)
  output logic [15:0] bg_port_addr,
  output logic        bg_port_read_en,
  input  logic [15:0] bg_port_data,
  input  logic        bg_port_data_valid,
  output logic [15:0] sprite_port_addr,
  output logic        sprite_port_read_en,
  input  logic [15:0] sprite_port_data,
  input  logic        sprite_port_data_valid,
  output pixel_t      frame_pixel,
  output logic        frame_pixel_valid,
  output logic        hsync,
  output logic        vsync,
  output logic [11:0] vga_color
);

  // Internal timing signals.
  logic [8:0] dot;
  logic [7:0] line;
  logic [1:0] mode;
  logic fifo_clear;
  logic [7:0] STAT_out;
  logic stat_interrupt;
  logic oam_search_done;
  logic [3:0] oam_sprite_count;
  // Rename output from Pixel_Gen.
  logic tile_pix_out_valid;
  
  // Signals from OAM_Search.
  logic [15:0] oam0_addr_sig, oam1_addr_sig;
  // Signals from Pixel_Gen.
  logic [15:0] bg_addr_sig, sprite_addr_sig;
  logic         bg_read_en_sig, sprite_read_en_sig;

  sprite_t       selected_sprites [0:9];
  
  // Intermediate pixel FIFO outputs.
  pixel_t bg_fifo_data;
  pixel_t sprite_fifo_data;
  // Declare mixed_pixel as 2 bits.
  logic [1:0] mixed_pixel;
  
  PPU_Mode_controller mode_ctrl (
    .clk(clk),
    .reset(reset),
    .scanline_processed(tile_pix_out_valid),
    .dot(dot),
    .line(line),
    .mode(mode),
    .fifo_clear(fifo_clear)
  );
  STAT_handler stat_hdl (
    .clk(clk),
    .reset(reset),
    .mode(mode),
    .LY(LY),
    .LYC(LYC),
    .LCDC(LCDC),
    .STAT(STAT_out),
    .stat_interrupt(stat_interrupt)
  );
  OAM_Search oam_search (
    .clk(clk),
    .reset(reset),
    .start((dot == 9'd0) ? 1'b1 : 1'b0),
    .current_line(LY),
    .oam_port0_addr(oam0_addr_sig),
    .oam_port0_data(oam_port0_data),
    .oam_port1_addr(oam1_addr_sig),
    .oam_port1_data(oam_port1_data),
    .done(oam_search_done),
    .sprite_count(oam_sprite_count),
    .selected_sprites(selected_sprites)
  );
  Pixel_Gen Pixel_Gen_inst (
    .clk(clk),
    .reset(reset),
    .start((dot == 9'd80) ? 1'b1 : 1'b0),
    .fifo_clear(fifo_clear),
    .LCDC(LCDC),
    .SCX(SCX),
    .SCY(SCY),
    .LY(LY),
    .BGP(BGP),
    .obj0(OBP0),
    .obj1(OBP1),
    .sprite_count(oam_sprite_count),
    .selected_sprites(selected_sprites), 
    .bg_port_addr(bg_addr_sig),
    .bg_port_read_en(bg_read_en_sig),
    .bg_port_data(bg_port_data),
    .bg_port_data_valid(bg_port_data_valid),
    .sprite_port_addr(sprite_addr_sig),
    .sprite_port_read_en(sprite_read_en_sig),
    .sprite_port_data(sprite_port_data),
    .sprite_port_data_valid(sprite_port_data_valid),
    .bg_fifo_data(bg_fifo_data),
    .sprite_fifo_data(sprite_fifo_data),
    .scanline_processed(tile_pix_out_valid)
  );
  // Multiplex OAM and VRAM signals based on dot.
  assign oam_port0_addr    = oam0_addr_sig;
  assign oam_port0_read_en = (dot < 9'd80) ? 1'b1 : 1'b0;
  assign oam_port1_addr    = oam1_addr_sig;
  assign oam_port1_read_en = (dot < 9'd80) ? 1'b1 : 1'b0;
  
  assign bg_port_addr      = (dot >= 9'd80) ? bg_addr_sig : 16'd0;
  assign bg_port_read_en   = (dot >= 9'd80) ? bg_read_en_sig : 1'b0;
  assign sprite_port_addr  = (dot >= 9'd80) ? sprite_addr_sig : 16'd0;
  assign sprite_port_read_en = (dot >= 9'd80) ? sprite_read_en_sig : 1'b0;
  
  Pixel_Mixer pixel_mixer_inst (
    .clk(clk),
    .reset(reset),
    .pixel_valid(tile_pix_out_valid),
    .bg_pixel_in(bg_fifo_data),
    .sprite_pixel_in(sprite_fifo_data),
    .pixel_out(mixed_pixel)
  );
  VGA_Controller vga_ctrl_inst (
    .clk(clk),
    .reset(reset),
    .fb_pixel(mixed_pixel),
    .hsync(hsync),
    .vsync(vsync),
    .vga_color(vga_color)
  );
  
  assign frame_pixel_valid = tile_pix_out_valid;
  assign frame_pixel = mixed_pixel;
endmodule
