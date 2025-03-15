`timescale 1ns/1ps
`default_nettype none

//==================================================================
// CGB PPU Data Structures
//------------------------------------------------------------------
// pixel_t: holds x,y position, 2-bit pixel value, 16-bit color (RGB555),
//          and a sprite priority flag.
// sprite_t: holds sprite attributes from OAM.
//   For CGB, flags are interpreted as:
//     Bit 7: OBJ-to-BG priority
//     Bit 6: Vertical flip
//     Bit 5: Horizontal flip
//     Bit 4: VRAM bank select (0: bank0; 1: bank1)
//     Bits 2-0: OBJ palette number
//==================================================================
typedef struct packed {
  logic [9:0] x;
  logic [9:0] y;
  logic [1:0] pixel;
  logic [15:0] palette;
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
// Description: Generates dot/line counters, current mode, and FIFO clear.
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
  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      mode <= 2'd2; // Start in OAM search (Mode 2)
    else begin
      if (line < 8'd144) begin
        if (dot < 9'd80)
          mode <= 2'd2;
        else if (~scanline_processed)
          mode <= 2'd3;
        else
          mode <= 2'd0;
      end else
        mode <= 2'd1;
    end
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      dot        <= 9'd0;
      line       <= 8'd0;
      fifo_clear <= 1'b1;
    end else begin
      fifo_clear <= (dot < 9'd80);
      if (dot < 9'd455)
        dot <= dot + 9'd1;
      else begin
        dot <= 9'd0;
        if (line < 8'd153)
          line <= line + 8'd1;
        else
          line <= 8'd0;
      end
    end
  end
endmodule

//==================================================================
// Module: STAT_handler
// Description: Updates the STAT register and issues STAT interrupts.
// CGB: STAT now includes bits for HBlank, VBlank, OAM, and coincidence IE.
//==================================================================
module STAT_handler (
  input  logic        clk,
  input  logic        reset,
  input  logic [1:0]  mode,
  input  logic [7:0]  LY,
  input  logic [7:0]  LYC,
  input  logic [7:0]  STAT_in,
  output logic [7:0]  STAT,
  output logic        stat_interrupt
);
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      STAT           <= 8'd0;
      stat_interrupt <= 1'b0;
    end else begin
      STAT[1:0] <= mode;
      STAT[2]   <= (LY == LYC);
      STAT[3]   <= STAT_in[3];
      STAT[4]   <= STAT_in[4];
      STAT[5]   <= STAT_in[5];
      STAT[6]   <= STAT_in[6];
      STAT[7]   <= 1'b0;
      stat_interrupt <= ((mode == 0 && STAT_in[3]) ||
                         (mode == 1 && STAT_in[4]) ||
                         (mode == 2 && STAT_in[5]) ||
                         ((LY == LYC) && STAT_in[6]));
    end
  end
endmodule

//==================================================================
// Module: OAM_Search
// Description: Scans OAM and selects up to 10 sprites for the current scanline.
// CGB: If LCDC[1] (OBJ enable) is off, no sprites are selected.
//==================================================================
module OAM_Search (
  input  logic          clk,
  input  logic          reset,
  input  logic          start,
  input  logic [7:0]    current_line,
  input  logic [7:0]    LCDC,   // Bit 1: Sprite enable; Bit 2: Sprite size.
  output logic [15:0]   oam_port0_addr,
  input  logic [15:0]   oam_port0_data,
  output logic [15:0]   oam_port1_addr,
  input  logic [15:0]   oam_port1_data,
  output logic          done,
  output logic [3:0]    sprite_count,
  output sprite_t       selected_sprites [0:9]
);
  localparam OAM_TABLE_BASE_ADDRESS = 16'hFE00;
  logic [7:0] sprite_height;
  always_comb begin
    sprite_height = (LCDC[2] ? 8'd16 : 8'd8);
  end
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
  assign sprite_count = (LCDC[1] ? selected_count : 4'd0);
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
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
            if (!LCDC[1])
              state <= OAM_DONE;
            else begin
              oam_index      <= 6'd0;
              selected_count <= 4'd0;
              sort_i         <= 4'd0;
              sort_j         <= 4'd0;
              sort_phase     <= SORT_EVEN;
            end
          end
        end
        OAM_FETCH: begin
          oam_port0_addr <= OAM_TABLE_BASE_ADDRESS + (oam_index << 2);
          oam_port1_addr <= OAM_TABLE_BASE_ADDRESS + (oam_index << 2) + 16'd2;
          temp_sprite.y           = oam_port0_data[7:0];
          temp_sprite.x           = oam_port0_data[15:8];
          temp_sprite.tile_index  = oam_port1_data[7:0];
          temp_sprite.flags       = oam_port1_data[15:8];
          if ((current_line >= (oam_port0_data[7:0] - 8'd16)) &&
              (current_line < (oam_port0_data[7:0] - 8'd16 + sprite_height))) begin
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
            end else begin
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
          // Final state.
        end
        default: ;
      endcase
    end
  end

  always_comb begin
    for (int j = 0; j < 10; j = j + 1)
      selected_sprites[j] = selected_sprites_reg[j];
  end

  always_comb begin
    case (state)
      OAM_IDLE: next_state = start ? OAM_FETCH : OAM_IDLE;
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
      OAM_DONE: next_state = OAM_IDLE;
      default: next_state = OAM_IDLE;
    endcase
  end
endmodule

//==================================================================
// Module: FIFO
// Description: Generic FIFO for pixels with configurable depth.
//==================================================================
module FIFO #(
  parameter DEPTH = 16,
  parameter THRESHOLD = 8
) (
  input  logic clk,
  input  logic reset,
  input  logic clear,
  input  logic push,
  input  pixel_t data_in,
  input  logic pop,
  output pixel_t data_out,
  output logic empty,
  output logic full,
  output logic [$clog2(DEPTH+1)-1:0] size,
  output logic out_valid
);
  localparam FIFO_ADDR_WIDTH = $clog2(DEPTH);
  logic [FIFO_ADDR_WIDTH-1:0] wr_ptr;
  logic [FIFO_ADDR_WIDTH-1:0] rd_ptr;
  logic [$clog2(DEPTH+1)-1:0] count;
  pixel_t fifo_mem [0:DEPTH-1];
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
      count  <= 0;
    end else if(clear) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
      count  <= 0;
    end else begin
      if ((push && !full) && (pop && (count > THRESHOLD))) begin 
        fifo_mem[wr_ptr] <= data_in;
        wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
        rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
        count  <= count;
      end else if(push && !full) begin
        fifo_mem[wr_ptr] <= data_in;
        wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
        count  <= count + 1;
      end else if(pop && (count > THRESHOLD)) begin
        rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
        count  <= count - 1;
      end
    end
  end
  assign empty     = (count == 0);
  assign full      = (count == DEPTH);
  assign size      = count;
  assign out_valid = (count > THRESHOLD);
  assign data_out  = (out_valid) ? fifo_mem[rd_ptr] : '0;
endmodule

//==================================================================
// Module: Render_BG
// Description: Renders BG/Window pixels for a scanline (CGB version).
//   - When LCDC[0]==0, BG is disabled (transparent).
//   - The tile map entry is 16 bits: lower 8 for tile index, upper 8 for attributes.
//   - The attribute byte: bit4 selects VRAM bank, bit5 hflip, bit6 vflip,
//     and bits [2:0] select BG palette from the computed palette array.
//   - Tile data address = 0x8000 + (tile_index * 16) + row_offset + bank_offset (0x2000 if bit4 set).
//==================================================================
module Render_BG (
  input  logic         clk,
  input  logic         reset,
  input  logic         start,
  input  logic         fifo_clear,
  input  logic [7:0]   LCDC,
  input  logic [7:0]   SCX,
  input  logic [7:0]   SCY,
  input  logic [7:0]   WX,
  input  logic [7:0]   WY,
  input  logic [7:0]   LY,
  input  logic [7:0]   BG_palettes [0:7],
  output logic [15:0]  port0_addr,
  output logic         port0_read_en,
  input  logic [15:0]  port0_data,
  input  logic         port0_data_valid,
  output pixel_t       bg_fifo_data,
  output logic         bg_done,
  output logic         bg_push  
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
  logic [7:0] pixel_total;
  logic [2:0] pixel_index;
  logic [7:0] tile_map_index_reg;
  logic [7:0] tile_attr_reg; // bit4: bank, bit5: hflip, bit6: vflip, bits [2:0]: palette index.
  logic [15:0] bg_tile_data_word;
  logic [7:0] scx_latched;
  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      scx_latched <= 8'd0;
    else if (state == BG_IDLE && start)
      scx_latched <= SCX;
  end
  logic use_window;
  always_comb begin
    use_window = (LCDC[5] && (LY >= WY) && ((scx_latched + pixel_total) >= (WX - 7)));
  end
  logic [8:0] screen_x;
  assign screen_x = (use_window ? (pixel_total + (WX - 7)) : (SCX + pixel_total));
  logic [7:0] bg_y;
  assign bg_y = LY + SCY;
  logic [7:0] effective_line;
  assign effective_line = (use_window ? (LY - WY) : bg_y);
  logic [4:0] tile_x, tile_y;
  always_comb begin
    if (!use_window) begin
      tile_x = ((scx_latched + pixel_total) >> 3) & 5'b11111;
      tile_y = (bg_y >> 3) & 5'b11111;
    end else begin
      tile_x = (((screen_x - (WX - 7)) >> 3)) & 5'b11111;
      tile_y = ((LY - WY) >> 3) & 5'b11111;
    end
  end
  logic [15:0] base_addr;
  always_comb begin
    if (!use_window)
      base_addr = (LCDC[3] == 1'b0) ? 16'h9800 : 16'h9C00;
    else
      base_addr = (LCDC[6] == 1'b0) ? 16'h9800 : 16'h9C00;
  end
  logic [15:0] computed_tile_map_addr;
  assign computed_tile_map_addr = base_addr + (tile_y * 16'd32) + tile_x;
  logic [2:0] row_index;
  always_comb begin
    if (tile_attr_reg[6])
      row_index = 3'd7 - effective_line[2:0];
    else
      row_index = effective_line[2:0];
  end
  logic [3:0] tile_row_offset;
  assign tile_row_offset = row_index * 2;
  logic [15:0] bank_offset;
  assign bank_offset = (tile_attr_reg[4] ? 16'h2000 : 16'h0000);
  logic [15:0] base_tile_addr;
  assign base_tile_addr = 16'h8000;
  logic [15:0] tile_data_addr;
  assign tile_data_addr = base_tile_addr + (tile_map_index_reg * 16) + tile_row_offset + bank_offset;
  pixel_t bg_pixel;
  logic push_bg;
  logic [1:0] temp_pixel;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state       <= BG_IDLE;
      pixel_index <= 3'd0;
      pixel_total <= 8'd0;
      bg_pixel    <= '0;
      push_bg     <= 1'b0;
    end else begin
      state <= next_state;
      case (state)
        BG_IDLE: begin
          pixel_index <= 3'd0;
          pixel_total <= 8'd0;
          push_bg <= 1'b0;
        end
        BG_FETCH_TILE: begin
          push_bg <= 1'b0;
        end
        BG_FETCH_TILE_MAP: begin
          push_bg <= 1'b0;
          bg_pixel.pixel <= 2'b00;
          if (port0_data_valid) begin
            tile_map_index_reg <= port0_data[7:0];
            tile_attr_reg      <= port0_data[15:8];
          end
        end
        BG_FETCH_TILE_DATA: begin
          if (port0_data_valid)
            bg_tile_data_word <= port0_data;
          push_bg <= 1'b0;
          bg_pixel.pixel <= 2'b00;
        end
        BG_PROCESS_PIXELS: begin
          bg_pixel.x <= (use_window ? (pixel_total + (WX - 7))
                                     : ((scx_latched + pixel_total) & 8'hFF))
                        + pixel_index;
          bg_pixel.y <= effective_line;
          if (!LCDC[0])
            bg_pixel.pixel <= 2'b00;
          else begin
            if (tile_attr_reg[5])
              temp_pixel <= { bg_tile_data_word[pixel_index], bg_tile_data_word[pixel_index+8] };
            else
              temp_pixel <= { bg_tile_data_word[7 - pixel_index], bg_tile_data_word[15 - pixel_index] };
            bg_pixel.pixel <= temp_pixel;
          end 
          bg_pixel.palette <= BG_palettes[tile_attr_reg[2:0]];
          bg_pixel.sprite_priority <= 1'b0;
          if (pixel_index < 3'd7) begin
            pixel_index <= pixel_index + 1;
            push_bg <= 1'b1;
          end else begin
            pixel_index <= 3'd0;
            pixel_total <= pixel_total + 8;
            push_bg <= 1'b1;
          end
        end
        BG_DONE: begin
          push_bg <= 1'b0;
        end
        default: push_bg <= 1'b0;
      endcase
    end
  end
  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      bg_done <= 1'b0;
    else if (fifo_clear)
      bg_done <= 1'b0;
    else if (state == BG_DONE)
      bg_done <= 1'b1;
    else
      bg_done <= bg_done;
  end 
  always_comb begin
    if (!LCDC[0])
      case (state)
        BG_IDLE:         next_state = (start) ? BG_PROCESS_PIXELS : BG_IDLE;
        BG_PROCESS_PIXELS: next_state = ((pixel_total + 8) < 8'd160) ? BG_PROCESS_PIXELS : BG_DONE;
        BG_DONE:         next_state = BG_IDLE;
        default:         next_state = BG_PROCESS_PIXELS;
      endcase
    else
      case (state)
        BG_IDLE:              next_state = (start) ? BG_FETCH_TILE : BG_IDLE;
        BG_FETCH_TILE:        next_state = BG_FETCH_TILE_MAP;
        BG_FETCH_TILE_MAP:    next_state = (port0_data_valid) ? BG_FETCH_TILE_DATA : BG_FETCH_TILE_MAP;
        BG_FETCH_TILE_DATA:   next_state = (port0_data_valid) ? BG_PROCESS_PIXELS : BG_FETCH_TILE_DATA;
        BG_PROCESS_PIXELS: begin
          if (pixel_index < 3'd7)
            next_state = BG_PROCESS_PIXELS;
          else if ((pixel_total + 8) < 8'd160)
            next_state = BG_FETCH_TILE;
          else
            next_state = BG_DONE;
        end
        BG_DONE:              next_state = BG_IDLE;
        default:              next_state = BG_IDLE;
      endcase
  end
  assign bg_fifo_data = bg_pixel;
  assign bg_push = push_bg;
endmodule

//==================================================================
// Module: Render_Sprites
// Description: Renders sprite pixels for a scanline (CGB version).
//   - Adjusts sprite X by subtracting 8.
//   - Interprets attribute bits: bit7 priority, bit6 vflip, bit5 hflip,
//     bit4 bank select, bits [2:0] select OBJ palette from OBJ_palettes.
//   - Effective sprite X = (sprite.x – 8) + pixel_index.
//   - Adds bank offset (0x2000) if flag[4] is set.
//==================================================================
module Render_Sprites (
  input  logic         clk,
  input  logic         reset,
  input  logic         start,
  input  logic         fifo_clear, 
  input  logic [7:0]   LCDC,
  input  logic [7:0]   SCX,
  input  logic [7:0]   SCY,
  input  logic [7:0]   LY,
  input  logic [7:0]   OBJ_palettes [0:7],
  input  logic [3:0]   sprite_count,
  input  sprite_t      sprites[0:9],
  output pixel_t       sprite_pixel,
  output logic         sprite_done,
  output logic         sprite_push, 
  output logic [15:0]  port_addr,
  output logic         port_read_en,
  input  logic [15:0]  port_data,
  input  logic         port_data_valid
);
  typedef enum logic [2:0] {
    IDLE,
    SCAN_CHECK,
    FETCH_TILE,
    DUMP_PIXELS,
    DONE
  } state_t;
  state_t state, next_state;
  logic [9:0] x_coord;
  logic [2:0] pixel_index;
  logic use_sprite;
  logic         candidate_valid;
  logic [3:0]   candidate_index;
  logic [15:0]  tile_data_word;
  logic [7:0]   row_offset;
  pixel_t       candidate_pixel;
  integer i;
  logic [7:0] best_x;
  always_comb begin
    candidate_valid = 1'b0;
    candidate_index = 4'd0;
    best_x = 8'hFF;
    for (i = 0; i < 10; i = i + 1) begin
      logic [7:0] adjusted_x = sprites[i].x - 8;
      if ((i < sprite_count) && (x_coord >= adjusted_x) && (x_coord < (adjusted_x + 8))) begin
        if (!candidate_valid) begin
          candidate_valid = 1'b1;
          candidate_index = i[3:0];
          best_x = adjusted_x;
        end else if (adjusted_x < best_x) begin
          candidate_index = i[3:0];
          best_x = adjusted_x;
        end
      end
    end
  end
  always_ff @(posedge clk or posedge reset) begin
    if (state == SCAN_CHECK) begin
      if (sprites[candidate_index].flags[6])
        row_offset <= ((7 - ((LY - sprites[candidate_index].y) & 3'b111)) << 1);
      else
        row_offset <= (((LY - sprites[candidate_index].y) & 3'b111) << 1);
    end
  end
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= IDLE;
      x_coord <= 10'd0;
      pixel_index <= 3'd0;
      use_sprite <= 1'b0;
      candidate_pixel <= '0;
    end else begin
      state <= next_state;
      if (state == IDLE && start) begin
        x_coord <= SCX;
        pixel_index <= 3'd0;
        sprite_push <= 1'b0;
      end
      if (state == SCAN_CHECK) begin
        use_sprite <= candidate_valid;
        if (!candidate_valid) begin
          candidate_pixel.x <= x_coord;
          candidate_pixel.y <= LY + SCY;
          candidate_pixel.pixel <= 2'b00;
          candidate_pixel.palette <= 16'd0;
          candidate_pixel.sprite_priority <= 1'b1;
          x_coord <= x_coord + 1;
          sprite_push <= 1'b1;
        end else begin 
          sprite_push <= 1'b0;
        end
      end else if (state == FETCH_TILE) begin
        sprite_push <= 1'b0;
      end else if (state == DUMP_PIXELS && use_sprite) begin
        candidate_pixel.x <= (sprites[candidate_index].x - 8) + pixel_index;
        candidate_pixel.y <= LY + SCY;
        if (sprites[candidate_index].flags[5])
          candidate_pixel.pixel <= { tile_data_word[pixel_index], tile_data_word[pixel_index+8] };
        else
          candidate_pixel.pixel <= { tile_data_word[7 - pixel_index], tile_data_word[15 - pixel_index] };
        candidate_pixel.palette <= OBJ_palettes[sprites[candidate_index].flags[2:0]];
        candidate_pixel.sprite_priority <= sprites[candidate_index].flags[7];
        sprite_push <= 1'b1;
        if (pixel_index < 3'd7)
          pixel_index <= pixel_index + 1;
        else begin
          pixel_index <= 3'd0;
          x_coord <= x_coord + 8;
        end
      end
    end
  end
  always_comb begin
    case (state)
      IDLE: next_state = start ? SCAN_CHECK : IDLE;
      SCAN_CHECK: begin
        if (x_coord >= 10'd160)
          next_state = DONE;
        else if (candidate_valid)
          next_state = FETCH_TILE;
        else
          next_state = SCAN_CHECK;
      end
      FETCH_TILE: begin
        if (port_data_valid)
          next_state = DUMP_PIXELS;
        else
          next_state = FETCH_TILE;
      end
      DUMP_PIXELS: begin
        if (pixel_index < 3'd7)
          next_state = DUMP_PIXELS;
        else
          next_state = SCAN_CHECK;
      end
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
  assign port_addr = (state == SCAN_CHECK && candidate_valid) ?
         ((sprites[candidate_index].flags[4] ? 16'hA000 : 16'h8000)
         + (sprites[candidate_index].tile_index * 16) + row_offset) : 16'd0;
  assign port_read_en = (state == SCAN_CHECK && candidate_valid);
  always_ff @(posedge clk) begin
    if (state == FETCH_TILE)
      tile_data_word <= port_data;
  end
  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      sprite_done <= 1'b0;
    else if (fifo_clear)
      sprite_done <= 1'b0;
    else if (state == DONE)
      sprite_done <= 1'b1;
    else
      sprite_done <= sprite_done;
  end
  assign sprite_pixel = candidate_pixel;
endmodule

//==================================================================
// Module: Pixel_Gen
// Description: Generates BG and sprite pixels for the current scanline.
// CGB: Receives external palette RAM arrays (BGCRAM, OBCRAM) and palette registers (BGPI, BCPD, OBPI, OBPD),
// then computes local palette arrays which are passed to the render modules.
//==================================================================
module Pixel_Gen (
  input  logic         clk,
  input  logic         reset,
  input  logic         start,
  input  logic         fifo_clear,
  input  logic [7:0]   LCDC,
  input  logic [7:0]   SCX,
  input  logic [7:0]   SCY,
  input  logic [7:0]   WX,
  input  logic [7:0]   WY,
  input  logic [7:0]   LY,
  // External palette RAM and registers.
  input  logic [7:0]   BGCRAM [0:63],
  input  logic [7:0]   OBCRAM [0:63],
  input  logic [7:0]   BGPI,
  input  logic [7:0]   BCPD,
  input  logic [7:0]   OBPI,
  input  logic [7:0]   OBPD,
  input  logic [3:0]   sprite_count,
  input  sprite_t      selected_sprites [0:9],
  output logic [15:0]  bg_port_addr,
  output logic         bg_port_read_en,
  input  logic [15:0]  bg_port_data,
  input  logic         bg_port_data_valid,
  output logic [15:0]  sprite_port_addr,
  output logic         sprite_port_read_en,
  input  logic [15:0]  sprite_port_data,
  input  logic         sprite_port_data_valid,
  output pixel_t       bg_fifo_data,
  output pixel_t       sprite_fifo_data,
  input  logic         pop,
  output logic         scanline_processed,
  output logic         bg_out_valid,
  output logic         sprite_out_valid
);
  // Generate local palette arrays from external CRAM.
  wire [15:0] BG_palettes [0:7];
  wire [15:0] OBJ_palettes [0:7];
  genvar j;
  generate
    for (j = 0; j < 8; j = j + 1) begin : palette_gen
      assign BG_palettes[j] = { BGCRAM[j*4+1], BGCRAM[j*4] };
      assign OBJ_palettes[j] = { OBCRAM[j*4+1], OBCRAM[j*4] };
    end
  endgenerate

  logic [30:0] internal_bg_pixel;
  logic [30:0] internal_sprite_pixel;
  logic bg_push;
  logic sprite_push;
  logic bg_done, sprite_done;
  assign scanline_processed = bg_done & sprite_done;
  
  Render_BG render_bg_inst (
    .clk(clk),
    .reset(reset),
    .start(start),
    .fifo_clear(fifo_clear),
    .LCDC(LCDC),
    .SCX(SCX),
    .SCY(SCY),
    .WX(WX),
    .WY(WY),
    .LY(LY),
    .BG_palettes(BG_palettes),
    .port0_addr(bg_port_addr),
    .port0_read_en(bg_port_read_en),
    .port0_data(bg_port_data),
    .port0_data_valid(bg_port_data_valid),
    .bg_fifo_data(internal_bg_pixel),
    .bg_done(bg_done),
    .bg_push(bg_push)
  );
  
  Render_Sprites render_sprites_inst (
    .clk(clk),
    .reset(reset),
    .start(start),
    .fifo_clear(fifo_clear),
    .LCDC(LCDC),
    .SCX(SCX),
    .SCY(SCY),
    .LY(LY),
    .OBJ_palettes(OBJ_palettes),
    .sprite_count(sprite_count),
    .sprites(selected_sprites),
    .sprite_pixel(internal_sprite_pixel),
    .sprite_done(sprite_done),
    .sprite_push(sprite_push),
    .port_addr(sprite_port_addr),
    .port_read_en(sprite_port_read_en),
    .port_data(sprite_port_data),
    .port_data_valid(sprite_port_data_valid)
  );
  
  FIFO #(
    .DEPTH(16),
    .THRESHOLD(0)
  ) bg_fifo_inst (
    .clk(clk),
    .reset(reset),
    .clear(fifo_clear),
    .push(bg_push),
    .data_in(internal_bg_pixel),
    .pop(pop),
    .data_out(bg_fifo_data),
    .empty(),
    .full(),
    .size(),
    .out_valid(bg_out_valid)
  );
  
  FIFO #(
    .DEPTH(64),
    .THRESHOLD(0)
  ) sprite_fifo_inst (
    .clk(clk),
    .reset(reset),
    .clear(fifo_clear),
    .push(sprite_push),
    .data_in(internal_sprite_pixel),
    .pop(pop),
    .data_out(sprite_fifo_data),
    .empty(),
    .full(),
    .size(),
    .out_valid(sprite_out_valid)
  );
endmodule

//==================================================================
// Module: Pixel_Mixer
// Description: Selects between BG and sprite pixel based on priority.
// For CGB, if the sprite pixel is nonzero, its full 16-bit color is used;
// otherwise, the BG pixel color is used.
//==================================================================
module Pixel_Mixer (
  input  logic        clk,
  input  logic        reset,
  input  logic        bg_pixel_ready,
  input  logic        sprite_pixel_ready,
  input  pixel_t      bg_pixel_in,
  input  pixel_t      sprite_pixel_in,
  output logic        fetch_pixel,
  output logic        pixel_out_valid,
  output logic [15:0] pixel_out
);
  assign fetch_pixel = bg_pixel_ready & sprite_pixel_ready;
  always_ff @(posedge clk or posedge reset) begin
    if(reset) begin 
      pixel_out <= 16'd0;
      pixel_out_valid <= 1'b0;
    end else begin
      pixel_out_valid <= fetch_pixel;
      if(sprite_pixel_in.pixel != 2'b00)
        pixel_out <= sprite_pixel_in.palette;
      else
        pixel_out <= bg_pixel_in.palette;
    end 
  end 
endmodule

//==================================================================
// Module: VGA_Controller
// Description: Generates VGA sync signals and converts the 16-bit RGB555
// from the PPU to a 24-bit sRGB color for output.
//==================================================================
module VGA_Controller (
  input  logic clk,
  input  logic reset,
  input  logic [15:0] fb_color,
  output logic hsync,
  output logic vsync,
  output logic [23:0] vga_color
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
      end else
        h_count <= h_count + 1;
    end
  end
  assign hsync = ~((h_count >= (H_ACTIVE + H_FRONT)) && (h_count < (H_ACTIVE + H_FRONT + H_SYNC)));
  assign vsync = ~((v_count >= (V_ACTIVE + V_FRONT)) && (v_count < (V_ACTIVE + V_FRONT + V_SYNC)));
  function automatic [7:0] conv5to8(input logic [4:0] in);
    conv5to8 = {in, in[4:2]};
  endfunction
  logic [7:0] r, g, b;
  assign r = conv5to8(fb_color[14:10]);
  assign g = conv5to8(fb_color[9:5]);
  assign b = conv5to8(fb_color[4:0]);
  assign vga_color = {r, g, b};
endmodule

//==================================================================
// Module: PPU_Wrapper
// Description: Top-level CGB PPU integrating mode control, STAT,
// OAM search, pixel generation/mixing, and VGA output.
//   - Receives external palette RAM (BGCRAM, OBCRAM) and palette register inputs
//     (BGPI, BCPD, OBPI, OBPD).
//   - Converts these into local palette arrays which are passed to Pixel_Gen.
//==================================================================
module PPU_Wrapper (
  input  logic         clk,
  input  logic         reset,
  input  logic [7:0]   LCDC,
  input  logic [7:0]   STAT_in,
  input  logic [7:0]   LY,
  input  logic [7:0]   LYC,
  input  logic [7:0]   SCX,
  input  logic [7:0]   SCY,
  input  logic [7:0]   WX,
  input  logic [7:0]   WY,
  // External palette RAM and registers.
  input  logic [7:0]   BGCRAM [0:63],
  input  logic [7:0]   OBCRAM [0:63],
  input  logic [7:0]   BGPI,
  input  logic [7:0]   BCPD,
  input  logic [7:0]   OBPI,
  input  logic [7:0]   OBPD,
  output logic [1:0]   mode, 
  output logic [15:0]  port0_addr,
  output logic         port0_read_en,
  input  logic [15:0]  port0_data,
  output logic [15:0]  port1_addr,
  output logic         port1_read_en,
  input  logic [15:0]  port1_data,
  output logic [15:0]  frame_color,
  output logic         frame_color_valid
);
  // Generate palette arrays from external CRAM.
  wire [15:0] BG_palettes [0:7];
  wire [15:0] OBJ_palettes [0:7];
  genvar j;
  generate
    for(j = 0; j < 8; j = j + 1) begin : palette_gen
      assign BG_palettes[j] = { BGCRAM[j*4+1], BGCRAM[j*4] };
      assign OBJ_palettes[j] = { OBCRAM[j*4+1], OBCRAM[j*4] };
    end
  endgenerate

  logic [8:0] dot;
  logic [7:0] line;
  logic       fifo_clear;
  logic [7:0] STAT_out;
  logic       stat_interrupt;
  logic       oam_search_done;
  logic [3:0] oam_sprite_count;
  logic       tile_pix_out_valid;
  logic [15:0] oam0_addr_sig, oam1_addr_sig;
  logic [15:0] bg_addr_sig, sprite_addr_sig;
  logic        bg_read_en_sig, sprite_read_en_sig;
  logic        bg_out_valid, sprite_out_valid, pixel_out_valid;
  logic        fetch_pixel;
  sprite_t selected_sprites [0:9];
  pixel_t bg_fifo_data;
  pixel_t sprite_fifo_data;
  logic [15:0] mixed_color;
  
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
    .STAT_in(STAT_in),
    .STAT(STAT_out),
    .stat_interrupt(stat_interrupt)
  );
  
  OAM_Search oam_search (
    .clk(clk),
    .reset(reset),
    .start((dot == 9'd0) ? 1'b1 : 1'b0),
    .current_line(LY),
    .LCDC(LCDC),
    .oam_port0_addr(oam0_addr_sig),
    .oam_port0_data(port0_data),
    .oam_port1_addr(oam1_addr_sig),
    .oam_port1_data(port1_data),
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
    .WX(WX),
    .WY(WY),
    .LY(LY),
    .BGCRAM(BGCRAM),
    .OBCRAM(OBCRAM),
    .BGPI(BGPI),
    .BCPD(BCPD),
    .OBPI(OBPI),
    .OBPD(OBPD),
    .sprite_count(oam_sprite_count),
    .selected_sprites(selected_sprites), 
    .bg_port_addr(bg_addr_sig),
    .bg_port_read_en(bg_read_en_sig),
    .bg_port_data(port0_data),
    .bg_port_data_valid(1'b1),
    .sprite_port_addr(sprite_addr_sig),
    .sprite_port_read_en(sprite_read_en_sig),
    .sprite_port_data(port1_data),
    .sprite_port_data_valid(1'b1),
    .bg_fifo_data(bg_fifo_data),
    .sprite_fifo_data(sprite_fifo_data),
    .pop(fetch_pixel),
    .scanline_processed(tile_pix_out_valid),
    .bg_out_valid(bg_out_valid),
    .sprite_out_valid(sprite_out_valid)
  );
  
  assign port0_addr    = (mode == 2) ? oam0_addr_sig : bg_addr_sig;
  assign port0_read_en = (mode == 2) ? 1'b1          : bg_read_en_sig;
  assign port1_addr    = (mode == 2) ? oam1_addr_sig : sprite_addr_sig;
  assign port1_read_en = (mode == 2) ? 1'b1          : sprite_read_en_sig;
  
  Pixel_Mixer pixel_mixer_inst (
    .clk(clk),
    .reset(reset),
    .bg_pixel_ready(bg_out_valid),
    .sprite_pixel_ready(sprite_out_valid),
    .bg_pixel_in(bg_fifo_data),
    .sprite_pixel_in(sprite_fifo_data),
    .fetch_pixel(fetch_pixel),
    .pixel_out_valid(pixel_out_valid),
    .pixel_out(mixed_color)
  );
  
  assign frame_color_valid = pixel_out_valid;
  assign frame_color       = mixed_color;
endmodule
