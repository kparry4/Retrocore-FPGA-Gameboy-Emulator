`timescale 1ns/1ps
`default_nettype none

//==================================================================
// Data Structures
//==================================================================
// pixel_t: holds x,y position, 2-bit pixel value, palette info and a sprite priority flag.
typedef struct packed {
  logic [9:0] x;
  logic [9:0] y;
  logic [1:0] pixel;
  logic [7:0] palette; // In CGB, this will be selected from an array of palettes.
  logic       sprite_priority;
} pixel_t;

// sprite_t: holds sprite attributes from OAM.
// For CGB, flags are interpreted as:
// Bit 7: OBJ-to-BG priority, Bit 6: Vertical flip, Bit 5: Horizontal flip,
// Bit 4: VRAM bank select, Bits 2-0: OBJ palette number.
typedef struct packed {
  logic [7:0] y;
  logic [7:0] x;
  logic [7:0] tile_index;
  logic [7:0] flags;
} sprite_t;

//==================================================================
// Module: PPU_Mode_controller
// Description: Generates dot/line counters, current mode, and FIFO clear.
module PPU_Mode_controller (
  input  logic         clk,
  input  logic         reset,
  input  logic         scanline_processed,
  output logic [8:0]   dot,
  output logic [7:0]   line,
  output logic [1:0]   mode,
  output logic         fifo_clear
);
  // Update mode register on each clock.
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      mode <= 2'd2; // Start in OAM search (Mode 2)
    end else begin
      if (line < 8'd144) begin
        if (dot < 9'd80)
          mode <= 2'd2; // OAM search
        else if (~scanline_processed)
          mode <= 2'd3; // Pixel Drawing (Mode 3)
        else
          mode <= 2'd0; // HBlank (Mode 0)
      end else begin
        mode <= 2'd1; // VBlank (Mode 1)
      end
    end
  end

  // Dot and line counters.
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
// CGB: STAT now includes bits for HBlank, VBlank, OAM, and coincidence interrupt enables.
module STAT_handler (
  input  logic        clk,
  input  logic        reset,
  input  logic [1:0]  mode,
  input  logic [7:0]  LY,
  input  logic [7:0]  LYC,
  input  logic [7:0]  STAT_in,  // Contains interrupt enable bits for HBlank, VBlank, OAM, and coincidence.
  output logic [7:0]  STAT,
  output logic        stat_interrupt
);
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      STAT           <= 8'd0;
      stat_interrupt <= 1'b0;
    end else begin
      STAT[1:0] <= mode;          // Mode bits [1:0]
      STAT[2]   <= (LY == LYC);     // Coincidence flag
      STAT[3]   <= STAT_in[3];      // HBlank interrupt enable
      STAT[4]   <= STAT_in[4];      // VBlank interrupt enable
      STAT[5]   <= STAT_in[5];      // OAM interrupt enable
      STAT[6]   <= STAT_in[6];      // Coincidence interrupt enable
      STAT[7]   <= 1'b0;            // Unused
      
      // Assert interrupt only when the corresponding enable is active.
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
// (No major change for CGB beyond what was in DMG; extended attributes are used later.)
module OAM_Search (
  input  logic          clk,
  input  logic          reset,
  input  logic          start,
  input  logic [7:0]    current_line,
  input  logic [7:0]    LCDC,   // Bit [1]: sprite enable; Bit [2]: sprite size (0:8, 1:16)
  output logic [15:0]   oam_port0_addr,
  input  logic [15:0]   oam_port0_data,
  output logic [15:0]   oam_port1_addr,
  input  logic [15:0]   oam_port1_data,
  output logic          done,
  output logic [3:0]    sprite_count,
  output sprite_t       selected_sprites [0:9]
);
  // Determine sprite height from LCDC[2]
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

  assign sprite_count = selected_count;
  
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
      if (state == OAM_DONE)
        done <= 1'b1;
      else
        done <= 1'b0;
      case (state)
        OAM_IDLE: begin
          if (start) begin
            if (!LCDC[1]) begin
              state <= OAM_DONE; // Sprites disabled.
            end else begin
              oam_index      <= 6'd0;
              selected_count <= 4'd0;
              sort_i         <= 4'd0;
              sort_j         <= 4'd0;
              sort_phase     <= SORT_EVEN;
            end
          end
        end
        OAM_FETCH: begin
          oam_port0_addr <= 16'hFE00 + (oam_index << 2);
          oam_port1_addr <= 16'hFE00 + (oam_index << 2) + 16'd2;
          temp_sprite.y           = oam_port0_data[7:0];
          temp_sprite.x           = oam_port0_data[15:8];
          temp_sprite.tile_index  = oam_port1_data[7:0];
          temp_sprite.flags       = oam_port1_data[15:8];
          if ((current_line >= (temp_sprite.y - 8'd16)) &&
              (current_line < (temp_sprite.y - 8'd16 + sprite_height))) begin
            if (selected_count < 4'd10) begin
              selected_sprites_reg[selected_count] <= temp_sprite;
              selected_count <= selected_count + 1;
            end
          end
          oam_index <= oam_index + 1;
        end
        OAM_SORT: begin
          // (Simple bubble-sort-like pass based on sprite.x)
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
          // Final state.
        end
        default: ;
      endcase
    end
  end

  // Output sorted sprites.
  always_comb begin
    for (int j = 0; j < 10; j = j + 1)
      selected_sprites[j] = selected_sprites_reg[j];
  end

  // Next state logic.
  always_comb begin
    case (state)
      OAM_IDLE: begin
        if (start)
          next_state = (!LCDC[1]) ? OAM_DONE : OAM_FETCH;
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
// Description: Generic FIFO for pixels with configurable depth.
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
    end else if (clear) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
      count  <= 0;
    end else begin
      if ((push && !full) && (pop && (count > THRESHOLD))) begin 
        fifo_mem[wr_ptr] <= data_in;
        wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
        rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
        count  <= count;
      end else if (push && !full) begin
        fifo_mem[wr_ptr] <= data_in;
        wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
        count  <= count + 1;
      end else if (pop && (count > THRESHOLD)) begin
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
// Description: Renders BG/Window pixels for a scanline.
// CGB: Now latches SCX and reads a 16-bit tile map entry (tile index and attributes).
// Also uses tile attributes to choose VRAM bank, apply vertical/horizontal flip,
// and select the BG palette from an array.
module Render_BG (
  input  logic         clk,
  input  logic         reset,
  input  logic         start,
  input  logic         fifo_clear,
  input  logic [7:0]   LCDC,      // Bit 0: BG enable, Bit 3: BG tile map select, Bit 4: addressing mode
                                  // Bit 5: Window enable, Bit 6: Window tile map select.
  input  logic [7:0]   SCX,
  input  logic [7:0]   SCY,
  input  logic [7:0]   WX,
  input  logic [7:0]   WY,
  input  logic [7:0]   LY,
  input  logic [7:0]   BGP,       // (DMG fallback)
  input  logic [7:0]   BG_palettes [0:7], // CGB: Array of 8 BG palette registers.
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
    BG_FETCH_TILE,      // Request tile map entry.
    BG_FETCH_TILE_MAP,  // Latch tile index and attribute.
    BG_FETCH_TILE_DATA, // Fetch tile data from VRAM.
    BG_PROCESS_PIXELS,  // Generate 8 pixels.
    BG_DONE
  } bg_state_t;
  bg_state_t state, next_state;

  logic [7:0] pixel_total;
  logic [2:0] pixel_index;

  // Latch for tile map entry:
  logic [7:0] tile_map_index_reg;
  logic [7:0] tile_attr_reg; // CGB: New attribute byte.
  // Fetched tile data word:
  logic [15:0] bg_tile_data_word;

  // Latch SCX at the start of the scanline.
  logic [7:0] scx_latched;
  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      scx_latched <= 8'd0;
    else if (state == BG_IDLE && start)
      scx_latched <= SCX;
  end

  // Calculate window mode.
  logic use_window;
  always_comb begin
    use_window = (LCDC[5] && (LY >= WY) && ((scx_latched + pixel_total) >= (WX - 7)));
  end

  logic [8:0] screen_x;
  assign screen_x = (use_window ? (pixel_total + (WX - 7)) : (scx_latched + pixel_total));

  logic [7:0] bg_y;
  assign bg_y = LY + SCY;
  logic [7:0] effective_line;
  assign effective_line = (use_window ? (LY - WY) : bg_y);

  // Tile map coordinate calculation.
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

  // Tile map base address selection.
  logic [15:0] base_addr;
  always_comb begin
    if (!use_window)
      base_addr = (LCDC[3] == 1'b0) ? 16'h9800 : 16'h9C00;
    else
      base_addr = (LCDC[6] == 1'b0) ? 16'h9800 : 16'h9C00;
  end

  logic [15:0] computed_tile_map_addr;
  assign computed_tile_map_addr = base_addr + (tile_y * 16'd32) + tile_x;

  // Tile Data Address Calculation:
  // Use the attribute’s bank bit (tile_attr_reg[4]) and LCDC[4] (addressing mode).
  // CGB: Also adjust for vertical flip.
  logic [2:0] row_index;
  always_comb begin
    row_index = (tile_attr_reg[6]) ? (3'd7 - effective_line[2:0]) : effective_line[2:0];
  end
  logic [3:0] tile_row_offset;
  assign tile_row_offset = row_index * 2;
  
  // Base address for tile data.
  logic [15:0] base_tile_addr;
  always_comb begin
    if (LCDC[4])
      base_tile_addr = (tile_attr_reg[4] ? 16'hA000 : 16'h8000);
    else
      base_tile_addr = (tile_attr_reg[4] ? 16'h9800 : 16'h8800);
  end
  logic [15:0] tile_data_addr;
  assign tile_data_addr = base_tile_addr + (tile_map_index_reg * 16) + tile_row_offset;

  // Pixel Data Generation.
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
          push_bg     <= 1'b0;
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
          if (!LCDC[0]) begin
            bg_pixel.pixel <= 2'b00;
            temp_pixel <= 2'b00;
          end else begin
            // CGB: Apply horizontal flip if tile_attr_reg[5] is set.
            if (tile_attr_reg[5])
              temp_pixel <= { bg_tile_data_word[pixel_index], bg_tile_data_word[pixel_index+8] };
            else
              temp_pixel <= { bg_tile_data_word[7 - pixel_index], bg_tile_data_word[15 - pixel_index] };
            bg_pixel.pixel <= temp_pixel;
          end 
          // CGB: Use BG palette from the array based on tile_attr_reg[2:0].
          bg_pixel.palette <= BG_palettes[tile_attr_reg[2:0]];
          // BG is always drawn behind sprites (priority bit false here).
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
        default: begin
          push_bg <= 1'b0;
        end
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
    if (!LCDC[0]) begin
      case (state)
        BG_IDLE:         next_state = (start) ? BG_PROCESS_PIXELS : BG_IDLE;
        BG_PROCESS_PIXELS: next_state = ((pixel_total + 8) < 8'd160) ? BG_PROCESS_PIXELS : BG_DONE;
        BG_DONE:         next_state = BG_IDLE;
        default:         next_state = BG_PROCESS_PIXELS;
      endcase
    end else begin
      case (state)
        BG_IDLE:              next_state = (start) ? BG_FETCH_TILE : BG_IDLE;
        BG_FETCH_TILE:        next_state = BG_FETCH_TILE_MAP;
        BG_FETCH_TILE_MAP:    next_state = (port0_data_valid) ? BG_FETCH_TILE_DATA : BG_FETCH_TILE_MAP;
        BG_FETCH_TILE_DATA:   next_state = (port0_data_valid) ? BG_PROCESS_PIXELS : BG_FETCH_TILE_DATA;
        BG_PROCESS_PIXELS: begin
          if (pixel_index < 3'd7)
            next_state = BG_PROCESS_PIXELS;
          else begin
            if ((pixel_total + 8) < 8'd160)
              next_state = BG_FETCH_TILE;
            else
              next_state = BG_DONE;
          end
        end
        BG_DONE:              next_state = BG_IDLE;
        default:              next_state = BG_IDLE;
      endcase
    end
  end

  assign bg_fifo_data = bg_pixel;
  assign bg_push      = push_bg;
endmodule

//==================================================================
// Module: Render_Sprites
// Description: Renders sprite pixels for a scanline.
// CGB: Now interprets extended OAM flags to apply vertical/horizontal flips,
// select the proper VRAM bank, and choose a palette from an array.
module Render_Sprites (
  input  logic         clk,
  input  logic         reset,
  input  logic         start,
  input  logic         fifo_clear, 
  input  logic [7:0]   LCDC,
  input  logic [7:0]   SCX,
  input  logic [7:0]   SCY,
  input  logic [7:0]   LY,
  input  logic [7:0]   OBP0, // (DMG fallback)
  input  logic [7:0]   OBJ_palettes [0:7], // CGB: Array of 8 OBJ palette registers.
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
      if ((i < sprite_count) && (x_coord >= sprites[i].x) && (x_coord < (sprites[i].x + 8))) begin
        if (!candidate_valid) begin
          candidate_valid = 1'b1;
          candidate_index = i[3:0];
          best_x = sprites[i].x;
        end else if (sprites[i].x < best_x) begin
          candidate_index = i[3:0];
          best_x = sprites[i].x;
        end
      end
    end
  end
  
  // In this module, adjust row_offset based on vertical flip.
  always_ff @(posedge clk or posedge reset) begin
    if (state == SCAN_CHECK) begin
      // Compute the sprite's row index. If vertical flip (flag[6]) is set,
      // row_index = 7 - ((LY - sprite.y) & 3'b111), else normal.
      row_offset <= (((sprites[candidate_index].flags[6]) 
                      ? (3'd7 - ((LY - sprites[candidate_index].y) & 3'b111))
                      : ((LY - sprites[candidate_index].y) & 3'b111)) << 1);
    end
  end
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state           <= IDLE;
      x_coord         <= 10'd0;
      pixel_index     <= 3'd0;
      use_sprite      <= 1'b0;
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
          candidate_pixel.palette <= 8'd0;
          candidate_pixel.sprite_priority <= 1'b1;
          x_coord <= x_coord + 1;
          sprite_push <= 1'b1;
        end else begin 
          sprite_push <= 1'b0;
        end 
      end else if (state == FETCH_TILE) begin
        sprite_push <= 1'b0;
      end else if (state == DUMP_PIXELS && use_sprite) begin
        candidate_pixel.x <= x_coord + pixel_index;
        candidate_pixel.y <= LY + SCY;
        // CGB: Apply horizontal flip if flag[5] is set.
        if (sprites[candidate_index].flags[5])
          candidate_pixel.pixel <= { tile_data_word[pixel_index], tile_data_word[pixel_index+8] };
        else
          candidate_pixel.pixel <= { tile_data_word[7 - pixel_index], tile_data_word[15 - pixel_index] };
        // CGB: Select OBJ palette from OBJ_palettes using lower 3 bits of flags.
        candidate_pixel.palette <= OBJ_palettes[sprites[candidate_index].flags[2:0]];
        // Also, pass the OBJ-to-BG priority bit (flag[7]) to sprite_priority.
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
    next_state = state;
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
  
  // CGB: For sprite tile data, use the OBJ attribute's bank bit (flag[4]).
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
// CGB: Now passes down the BG and OBJ palette arrays to the render modules.
// (Penalty logic is removed.)
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
  input  logic [7:0]   BGP,       // DMG fallback
  input  logic [7:0]   BG_palettes [0:7], // CGB: BG palettes.
  input  logic [7:0]   OBP0,      // DMG fallback for OBJ (unused in CGB)
  input  logic [7:0]   OBJ_palettes [0:7], // CGB: OBJ palettes.
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

  logic [30:0] internal_bg_pixel;
  logic [30:0] internal_sprite_pixel;
  
  logic bg_push;
  logic sprite_push;
  logic bg_done, sprite_done;
  
  // Scanline is processed when both render modules are done.
  assign scanline_processed = bg_done & sprite_done;
  
  // Instantiate Render_BG.
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
    .BGP(BGP),
    .BG_palettes(BG_palettes),
    .port0_addr(bg_port_addr),
    .port0_read_en(bg_port_read_en),
    .port0_data(bg_port_data),
    .port0_data_valid(bg_port_data_valid),
    .bg_fifo_data(internal_bg_pixel),
    .bg_done(bg_done),
    .bg_push(bg_push)
  );
  
  // Instantiate Render_Sprites.
  Render_Sprites render_sprites_inst (
    .clk(clk),
    .reset(reset),
    .start(start),
    .fifo_clear(fifo_clear),
    .LCDC(LCDC),
    .SCX(SCX),
    .SCY(SCY),
    .LY(LY),
    .OBP0(OBP0),
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
  
  // Instantiate FIFO for BG pixels.
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
  
  // Instantiate FIFO for sprite pixels.
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
module Pixel_Mixer (
  input  logic        clk,
  input  logic        reset,
  input  logic        bg_pixel_ready,
  input  logic        sprite_pixel_ready,
  input  pixel_t      bg_pixel_in,
  input  pixel_t      sprite_pixel_in,
  output logic        fetch_pixel,
  output logic        pixel_out_valid,
  output logic [1:0]  pixel_out
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

  assign fetch_pixel = bg_pixel_ready & sprite_pixel_ready;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin 
      pixel_out <= 2'b00;
      pixel_out_valid <= 1'b0;
    end else begin
      pixel_out_valid <= fetch_pixel;
      if (sprite_pixel_in.pixel != 2'b00)
        pixel_out <= map_palette(sprite_pixel_in.pixel, sprite_pixel_in.palette);
      else
        pixel_out <= map_palette(bg_pixel_in.pixel, bg_pixel_in.palette);
    end 
  end 
endmodule

//==================================================================
// Module: DMG_Color_Mapper
// Description: Maps a 2-bit DMG color index to a 24-bit VGA color.
// (This example remains unchanged.)
module DMG_Color_Mapper(
  input  logic [1:0] dmg_color,
  output logic [23:0] vga_color
);
  always_comb begin
    case(dmg_color)
      2'd0: vga_color = 24'hFFFFFF;
      2'd1: vga_color = 24'hCCCCCC;
      2'd2: vga_color = 24'h888888;
      2'd3: vga_color = 24'h000000;
      default: vga_color = 24'h000000;
    endcase
  end
endmodule

//==================================================================
// Module: VGA_Controller
// Description: Generates VGA sync signals and outputs final VGA color.
module VGA_Controller (
  input  logic clk,
  input  logic reset,
  input  logic [1:0] fb_pixel,
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
// Description: Top-level PPU module integrating mode control, STAT,
// OAM search, pixel generation/mixing, and VGA output.
// CGB: Added inputs for BG_palettes and OBJ_palettes.
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
  input  logic [7:0]   BGP,         // DMG fallback
  input  logic [7:0]   OBP0,        // DMG fallback
  input  logic [7:0]   BG_palettes [0:7],  // CGB: 8 BG palette registers.
  input  logic [7:0]   OBJ_palettes [0:7], // CGB: 8 OBJ palette registers.
  output logic [1:0]   mode, 
  output logic [15:0]  port0_addr,
  output logic         port0_read_en,
  input  logic [15:0]  port0_data,
  output logic [15:0]  port1_addr,
  output logic         port1_read_en,
  input  logic [15:0]  port1_data,
  output logic [1:0]   frame_pixel,
  output logic         frame_pixel_valid
);
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

  // OAM search and sprite selection.
  sprite_t selected_sprites [0:9];
  
  pixel_t bg_fifo_data;
  pixel_t sprite_fifo_data;
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
    .BGP(BGP),
    .BG_palettes(BG_palettes),
    .OBP0(OBP0),
    .OBJ_palettes(OBJ_palettes),
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
    .pop(fetch_pixel),
    .bg_out_valid(bg_out_valid),
    .sprite_out_valid(sprite_out_valid),
    .sprite_fifo_data(sprite_fifo_data),
    .scanline_processed(tile_pix_out_valid)
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
    .pixel_out(mixed_pixel)
  );
  
  assign frame_pixel_valid = pixel_out_valid;
  assign frame_pixel       = mixed_pixel;
endmodule
