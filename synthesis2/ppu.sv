//`timescale 1ns/1ps
//`default_nettype none
//==================================================================
// Data Structures
//==================================================================
// pixel_t: holds x,y position, 2-bit color, palette and priority flag.
// sprite_t: holds sprite attributes from OAM (y, x, tile index, flags).
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
// Description: Generates dot/line counters, current mode, and FIFO clear.
// Inputs:
//   clk, reset, scanline_processed - timing sync signals.
// Outputs:
//   dot        - current dot (pixel) count.
//   line       - current scanline number.
//   mode       - current PPU mode (2 bits).
//   fifo_clear - asserted at start of line to clear FIFO.
//==================================================================
module PPU_Mode_controller (
  input  logic         clk,
  input  logic         reset,
  input  logic [7:0]   LCDC, SCX, SCY,
  input  logic         scanline_processed,
  output logic [8:0]   dot,
  output logic [7:0]   line,
  output logic [1:0]   mode,
  output logic [7:0]   scx_latched, scy_latched,
  output logic         fifo_clear,
  output logic         full_frame_done
);


  logic LCD_disabled_prev;

  always_ff @(posedge clk) begin
    if (LCDC[7]) begin
      LCD_disabled_prev <= (full_frame_done) ? 1'b0 : LCD_disabled_prev;
    end else begin
      LCD_disabled_prev <= 1'b1;
    end
  end

  // Update mode register on each clock.
  always_ff @(posedge clk) begin
    if (reset) begin
      mode <= 2'd2; // start in OAM search mode
      // scx_latched <= SCX;
      // scy_latched <= SCY;
    end else if (LCD_disabled_prev && line == 8'd0) begin
      if (dot < 9'd76)
        mode <= 2'd0;
      else if((~scanline_processed))
        mode <= 2'd3;
      else
        mode <= 2'd0;
    end else begin
      if(line < 8'd144) begin
        if(dot < 9'd80)
          mode <= 2'd2;
        else if((~scanline_processed))
          mode <= 2'd3;
        else
          mode <= 2'd0;
      end else begin
        mode <= 2'd1;
      end
    end
  end


  // Dot and line counters are updated on the clock.
  always_ff @(posedge clk) begin
    if (reset || ~LCDC[7]) begin
      dot        <= 9'd0;
      line       <= 8'h0;
      fifo_clear <= 1'b1;
      full_frame_done <= 1'b0;
      scx_latched <= SCX;
      scy_latched <= SCY;
    end else if (LCD_disabled_prev && line == 8'd0) begin
      fifo_clear <= (dot < 9'd76);
      if(dot < 9'd451) begin
        dot <= dot + 9'd1;
        full_frame_done <= 1'b0;
      end
      else begin
        dot <= 9'd0;
        scx_latched <= SCX;
        scy_latched <= SCY;
        if(line < 8'd149) begin
          line <= line + 8'd1;
          full_frame_done <= 1'b0;
        end else begin
          line <= 8'd0;
          full_frame_done <= 1'bx;
        end
      end
    end else begin
      fifo_clear <= (dot < 9'd80);
      if(dot < 9'd455) begin
        dot <= dot + 9'd1;
        full_frame_done <= 1'b0;
      end
      else begin
        dot <= 9'd0;
        scx_latched <= SCX;
        scy_latched <= SCY;
        if(line < 8'd153) begin
          line <= line + 8'd1;
          full_frame_done <= 1'b0;
        end else begin
          line <= 8'd0;
          full_frame_done <= 1'b1;
        end
      end
    end
  end

endmodule

//==================================================================
// Module: OAM_Search
// Description: Scans OAM and selects up to 10 sprites for the current line.
// Inputs:
//   clk, reset, start - begin OAM search.
//   current_line    - current scanline.
// Outputs:
//   oam_port0_addr, oam_port1_addr - addresses for OAM reads.
//   done            - search completion flag.
//   sprite_count    - number of sprites found.
//   selected_sprites- array of selected sprite_t.
//==================================================================
module OAM_Search (
  input  logic          clk,
  input  logic          reset,
  input  logic          start,
  input  logic [7:0]    current_line,
  input  logic [7:0]    LCDC,
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

  assign sprite_count = selected_count;

  // Sequential logic for fetching and sorting OAM sprites.
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
          // Final state: search complete.
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
// Description: Generic FIFO for pixels with configurable depth.
// Parameters:
//   DEPTH: FIFO size; THRESHOLD: minimum count for valid output; T: data type.
// Inputs:
//   clk, reset, clear - control signals.
//   push, data_in   - push data.
//   pop             - pop data.
// Outputs:
//   data_out        - output data.
//   empty, full     - FIFO status flags.
//   size            - current FIFO count.
//   out_valid       - data output valid flag.
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
    if(reset) begin
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
      end
      else if(push && !full) begin
        fifo_mem[wr_ptr] <= data_in;
        wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
        count  <= count + 1;
      end
      else if(pop && (count > THRESHOLD)) begin
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
// Description: Renders BG or Window pixels for a scanline.
//   - If LCDC[0]==0, BG is disabled so transparent (00) pixels are output.
//   - When Window is enabled (LCDC[5]==1) and active (LY>=WY and
//     (SCX+pixel_total) >= (WX–7)), the window tile map is used with
//     effective Y = (LY–WY) and X computed from (pixel_total).
//   - Otherwise, BG uses SCX/SCY with wrap-around.
// Inputs:
//   clk, reset, start, fifo_clear : control signals.
//   LCDC       : LCD control register (bit 0 enables BG).
//   SCX, SCY   : BG scroll offsets (0–255).
//   WX, WY     : Window registers (window appears at (WX–7, WY)).
//   LY         : Current scanline.
//   BGP        : BG palette register.
// Outputs:
//   port0_addr, port0_read_en : VRAM interface for tile maps/data.
//   port0_data, port0_data_valid: VRAM data signals.
//   bg_fifo_data : pixel data output (pixel_t).
//   bg_done      : scanline complete flag.
//   bg_push      : asserted for one clock when a pixel is pushed.
//==================================================================
module Render_BG (
  input  logic         clk,
  input  logic         reset,
  input  logic         start, full_frame_done,
  input  logic         fifo_clear,
  input  logic [7:0]   LCDC,      // Bit 0 enables BG, bit 4 selects tile data addressing mode,
                                  // bit 3 selects BG tile map; Bit 5 enables window; Bit 6 selects window map.
  input  logic [7:0]   SCX,
  input  logic [7:0]   SCY,
  input  logic [7:0]   WX,
  input  logic [7:0]   WY,
  input  logic [7:0]   LY,
  input  logic [7:0]   BGP,       // BG palette register
  output logic [15:0]  port0_addr,
  output logic         port0_read_en,
  input  logic [15:0]  port0_data,
  input  logic         port0_data_valid,
  output pixel_t       bg_fifo_data,
  output logic         bg_done,
  output logic         bg_push
);

  //==================================================================
  // State Machine Declarations
  //==================================================================
  typedef enum logic [2:0] {
    BG_IDLE,
    BG_FETCH_TILE,      // Request tile index from the tile map.
    BG_FETCH_TILE_MAP,  // Latch tile index and initiate tile data fetch.
    BG_FETCH_TILE_DATA, // Latch tile data (16-bit word for the row).
    BG_PROCESS_PIXELS,  // Process 8 pixels from the tile row.
    BG_DONE
  } bg_state_t;
  bg_state_t state, next_state;

  //==================================================================
  // Counters and Registers
  //==================================================================
  // Overall horizontal pixel counter and pixel index within a tile (0–7)
  logic [7:0] pixel_total;
  logic [2:0] pixel_index;
  logic [4:0] tile_x, tile_y;

  // Register for the tile index read from the tile map.
  logic [7:0] tile_map_index_reg;

  // Register to hold the fetched tile data word (16 bits covering the current tile row).
  logic [15:0] bg_tile_data_word;

  // Latch SCX at start of scanline.
  logic [7:0] scx_latched;
  always_ff @(posedge clk or posedge reset) begin
    if(reset)
      scx_latched <= 8'd0;
    else if(state == BG_IDLE && start)
      scx_latched <= SCX;
  end

  //==================================================================
  // Window / BG Mode Calculations
  //==================================================================
  // Window mode is active if LCDC[5] is set, LY >= WY, and (SCX + pixel_total) >= (WX - 7)
  logic use_window;
  always_comb begin
    use_window = (LCDC[5] && (LY >= WY) && ((pixel_total + 7) >= (WX)));
  end

  // Compute the effective screen X coordinate.
  // BG mode: (SCX + pixel_total)
  // Window mode: (WX - 7) + pixel_total
  logic [8:0] screen_x;
  assign screen_x = (use_window ? (pixel_total) : (SCX + pixel_total));

  // Window internal counter
  logic [7:0] wly, wly_reg;
  logic prev_use_window;
  always_ff @(posedge clk) begin
    wly_reg <= wly;
    if (reset || full_frame_done) begin
      wly <= 8'd0;
      prev_use_window <= 1'b0;
    end else begin
      if (!prev_use_window && use_window)
        wly <= wly + 1;
      prev_use_window <= use_window;
    end
  end


  // Compute the effective Y coordinate.
  // BG mode: LY + SCY; Window mode: LY - WY.
  logic [7:0] bg_y;
  assign bg_y = LY + SCY;
  logic [7:0] effective_line;
  assign effective_line = (use_window ? ((!prev_use_window && use_window) ? wly : wly_reg) : bg_y);

  //==================================================================
  // Tile Map Coordinate Calculation
  //==================================================================
  // Calculate tile coordinates (tile_x, tile_y) with wrap-around.

  always_comb begin
    if (!use_window) begin
      tile_x = ((scx_latched + pixel_total) >> 3) & 5'b11111;
      tile_y = (bg_y >> 3) & 5'b11111;
    end else begin
      tile_x = (((screen_x - (WX - 7)) >> 3)) & 5'b11111;
      tile_y = (effective_line >> 3) & 5'b11111;
    end
  end

  //==================================================================
  // Tile Map Base Address Selection
  //==================================================================
  // When not in window mode, LCDC[3] selects the BG tile map:
  //   0: 0x9800, 1: 0x9C00.
  // When in window mode, LCDC[6] selects the window tile map similarly.
  logic [15:0] base_addr;
  always_comb begin
    if (!use_window)
      base_addr = (LCDC[3] == 1'b0) ? 16'h9800 : 16'h9C00;
    else
      base_addr = (LCDC[6] == 1'b0) ? 16'h9800 : 16'h9C00;
  end

  // Computed tile map address from which the tile index is read.
  logic [15:0] computed_tile_map_addr;
  assign computed_tile_map_addr = base_addr + (tile_y * 16'd32) + tile_x;

  //==================================================================
  // Tile Data Address Calculation
  //==================================================================
  logic [3:0] tile_row_offset;
  assign tile_row_offset = (effective_line[2:0] * 2);
  logic signed [7:0] tile_number;
  assign tile_map_index_reg = (tile_x[0]) ? port0_data[15:8] : port0_data[7:0];
  assign tile_number = tile_map_index_reg;
  logic [15:0] tile_data_addr;

  always_comb begin
    if (LCDC[4]) begin
      tile_data_addr = 16'h8000 + (tile_map_index_reg * 16) + tile_row_offset;
    end else begin
      if (tile_number > 8'd127) begin
        tile_data_addr = 16'h8800 + ((tile_number - 8'd128) * 16) + tile_row_offset;
      end else begin
        tile_data_addr = 16'h9000 + (tile_number * 16) + tile_row_offset;
      end
    end
  end

  //==================================================================
  // Pixel Data Generation
  //==================================================================
  pixel_t bg_pixel;
  // Flag to indicate that a pixel is pushed to the FIFO.
  logic push_bg;
  logic [1:0] temp_pixel;

  //==================================================================
  // Combinational Logic for Memory Interface Signals
  //==================================================================
  // The VRAM interface signals are generated combinationally based on the state.
  always_comb begin
    // Default values.
    port0_addr     = 16'd0;
    port0_read_en  = 1'b0;
    case (state)
      BG_FETCH_TILE: begin
        port0_addr    = computed_tile_map_addr;
        port0_read_en = 1'b1;
      end
      BG_FETCH_TILE_MAP: begin
        port0_addr    = tile_data_addr;
        port0_read_en = 1'b1;
      end
      default: begin
        port0_addr    = 16'h9800;//***
        port0_read_en = 1'b0;
      end
    endcase
  end

  //==================================================================
  // Main State Machine
  //==================================================================
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state              <= BG_IDLE;
      pixel_index        <= 3'd0;
      pixel_total        <= 8'd0;
      bg_pixel           <= '0;
      push_bg            <= 1'b0;
    end else begin
      state <= next_state;
      case (state)
        BG_IDLE: begin
          pixel_index <= 3'd0;
          pixel_total <= 8'd0;
          push_bg     <= 1'b0;
        end

        // In BG_FETCH_TILE, nothing is captured; the address is driven combinationally.
        BG_FETCH_TILE: begin
          push_bg <= 1'b0;
        end

        // In BG_FETCH_TILE_MAP, capture the tile index when data is valid.
        BG_FETCH_TILE_MAP: begin
          push_bg <= 1'b0;
          bg_pixel.pixel <= 2'b00;
        end

        // In BG_FETCH_TILE_DATA, capture the 16-bit tile data word.
        BG_FETCH_TILE_DATA: begin
          if (port0_data_valid)
            bg_tile_data_word <= port0_data;
          push_bg <= 1'b0;
          bg_pixel.pixel <= 2'b00;
        end

        // In BG_PROCESS_PIXELS, generate the pixel data and update counters.
        BG_PROCESS_PIXELS: begin
          // Compute the X coordinate for the current pixel.
          bg_pixel.x <= (use_window ? (pixel_total + (WX - 7))
                                     : ((scx_latched + pixel_total) & 8'hFF))
                        + pixel_index;
          bg_pixel.y <= effective_line;
          // If BG is disabled, output transparent pixel (00); otherwise, extract pixel data.
          if (!LCDC[0]) begin
            bg_pixel.pixel <= 2'b00;
            temp_pixel <= 2'b00;
          end
          else begin
            temp_pixel <= {bg_tile_data_word[7 - pixel_index], bg_tile_data_word[15 - pixel_index]};
            bg_pixel.pixel <= {bg_tile_data_word[7 - pixel_index], bg_tile_data_word[15 - pixel_index]};
          end
          bg_pixel.palette         <= BGP;
          bg_pixel.sprite_priority <= 1'b0;
          // Advance pixel index; after 8 pixels, reset index and advance pixel_total.
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

  //==================================================================
  // BG Done Flag: Assert when a complete scanline (160 pixels) is processed.
  //==================================================================
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

  //==================================================================
  // Next State Logic
  //==================================================================
  always_comb begin
    if (!LCDC[0]) begin
      // If BG is disabled, output transparent pixels.
      case (state)
        BG_IDLE:         next_state = (start) ? BG_PROCESS_PIXELS : BG_IDLE;
        BG_PROCESS_PIXELS: begin
          if (pixel_index < 3'd7) begin
            next_state = BG_PROCESS_PIXELS;
          end
          else begin
              if (pixel_total + 8 < 8'd160)
                next_state = BG_PROCESS_PIXELS;
              else
                next_state = BG_DONE;
          end
        end
        BG_DONE:         next_state = BG_IDLE;
        default:         next_state = BG_PROCESS_PIXELS;
      endcase
    end else begin
      // BG enabled: step through fetching tile index, tile data, and processing pixels.
      case (state)
        BG_IDLE:              next_state = (start) ? BG_FETCH_TILE : BG_IDLE;
        BG_FETCH_TILE:        next_state = BG_FETCH_TILE_MAP;
        BG_FETCH_TILE_MAP:    next_state = (port0_data_valid) ? BG_FETCH_TILE_DATA : BG_FETCH_TILE_MAP;
        BG_FETCH_TILE_DATA:   next_state = (port0_data_valid) ? BG_PROCESS_PIXELS : BG_FETCH_TILE_DATA;
        BG_PROCESS_PIXELS: begin
          if (pixel_index < 3'd7)
            next_state = BG_PROCESS_PIXELS;
          else begin
            if (pixel_total + 8 < 8'd160)
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

  //==================================================================
  // Output Assignments
  //==================================================================
  assign bg_fifo_data = bg_pixel;
  assign bg_push      = push_bg;

endmodule



//==================================================================
// Module: Render_Sprites
// Description: Renders sprite pixels for a scanline. If no sprite is
//              found at the current X coordinate, outputs a transparent
//              pixel (00). Otherwise, fetches sprite tile data and dumps
//              8 pixels from the candidate sprite.
// Inputs:
//   clk, reset, start       : control signals.
//   fifo_clear              : clears internal FIFO if asserted.
//   LCDC                    : LCD control register.
//   SCX, SCY, LY            : current BG X offset, BG Y offset, and scanline.
//   OBP0, OBP1              : sprite palette registers.
//   sprite_count            : number of sprites in OAM.
//   sprites                 : array of candidate sprite_t objects.
// Outputs:
//   sprite_pixel            : sprite pixel output (pixel_t).
//   sprite_done             : asserted when the sprite scanline is complete.
//   sprite_push             : asserted for one clock when a pixel is pushed.
//   port_addr, port_read_en  : interface for sprite VRAM access.
//   port_data, port_data_valid : sprite VRAM data.
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
  input  logic [7:0]   OBP0,
  input  logic [7:0]   OBP1,
  input  logic [3:0]   sprite_count,
  input  sprite_t      sprites[0:9],
  output pixel_t       sprite_pixel,
  output logic         sprite_done,
  output logic         sprite_push,
  // Memory interface for sprite tile data:
  output logic [15:0]  port_addr,
  output logic         port_read_en,
  input  logic [15:0]  port_data,
  input  logic         port_data_valid
);

  //==================================================================
  // State Machine Declarations
  //==================================================================
  typedef enum logic [2:0] {
    IDLE,
    SCAN_CHECK,
    FETCH_TILE,
    DUMP_PIXELS,
    DONE
  } state_t;
  state_t state, next_state;

  // X coordinate for scanline (0 to 159)
  logic [9:0] x_coord;
  // Pixel index within an 8-pixel block.
  logic [2:0] pixel_index;
  // Flag indicating whether a candidate sprite is active.
  logic use_sprite;
  // Candidate selection signals.
  logic         candidate_valid;
  logic [3:0]   candidate_index;
  // Fetched tile data.
  logic [15:0]  tile_data_word;
  // Row offset for sprite tile data.
  logic [7:0]   row_offset;
  // Output candidate pixel.
  pixel_t       candidate_pixel;

  // Candidate selection with priority: choose the sprite overlapping x_coord
  // with the smallest x (tie-breaker: lower OAM index).
  integer i;
  logic [7:0] best_x;
  always_comb begin
    candidate_valid = 1'b0;
    candidate_index = 4'd0;
    best_x = 8'hFF;
    for (i = 0; i < 10; i = i + 1) begin
      if ((i < sprite_count) && (sprites[i].x != 8'd0) && (sprites[i].x < 8'd168)
          && (x_coord < sprites[i].x) && (x_coord >= (sprites[i].x - 8))) begin
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

  // Merge candidate_pixel updates into one always_ff block.
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
        x_coord <= 10'd0;
        pixel_index <= 3'd0;
        sprite_push <= 1'b0;
      end
      if (state == SCAN_CHECK) begin
        use_sprite <= candidate_valid;
        if (!candidate_valid) begin
          // No sprite candidate: immediately push an empty (transparent) pixel.
          candidate_pixel.x <= x_coord;
          candidate_pixel.y <= LY + SCY;
          candidate_pixel.pixel <= 2'b00;
          candidate_pixel.palette <= 8'd0;
          candidate_pixel.sprite_priority <= 1'b1;
          // Advance x_coord by one pixel.
          x_coord <= x_coord + 1;
          sprite_push <= 1'b1;
        end
        else begin
          sprite_push <= 1'b0;
        end
        // Otherwise, if candidate_valid is true, we don't push here.
      end
      else if (state == FETCH_TILE) begin
        // In FETCH_TILE, we do not output any pixel; we wait for tile data.
        sprite_push <= 1'b0;
      end
      else if (state == DUMP_PIXELS && use_sprite) begin
        // Dump sprite pixel data.
        candidate_pixel.x <= x_coord + pixel_index;
        candidate_pixel.y <= LY + SCY;
        if (~LCDC[1]) begin
            candidate_pixel.pixel <= 2'b00;
        end else if (sprites[candidate_index].flags[5]) begin
            candidate_pixel.pixel <= { tile_data_word[pixel_index], tile_data_word[8 + pixel_index] };
        end else begin
            candidate_pixel.pixel <= { tile_data_word[7 - pixel_index], tile_data_word[15 - pixel_index] };
        end
        candidate_pixel.palette <= (sprites[candidate_index].flags[4]) ? OBP1 : OBP0;
        candidate_pixel.sprite_priority <= (LCDC[1]) ? sprites[candidate_index].flags[7] : 1'b1;
        sprite_push <= 1'b1;
        if (pixel_index < 3'd7) begin
          pixel_index <= pixel_index + 1;
        end
        else begin
          pixel_index <= 3'd0;
          x_coord <= x_coord + 8;
        end
      end
    end
  end

  // Next state logic.
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
          next_state = SCAN_CHECK;  // Remain in SCAN_CHECK to output an empty pixel.
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

  // Update row_offset on SCAN_CHECK.
  /*
  logic [7:0] sprite_height;
  always_comb begin
    sprite_height = (LCDC[2] ? 8'd16 : 8'd8) - 8'd1;
  end

  always_ff @(posedge clk) begin
    if (state == SCAN_CHECK)
      row_offset <= (sprites[candidate_index].flags[6]) ? ((( (sprite_height) - (LY - (sprites[candidate_index].y)) & 8'd7)) << 1) : ((LY - (sprites[candidate_index].y)) & 8'd7) << 1;
  end
  */
 logic [7:0] sprite_line;
logic [2:0] tile_line;
logic [7:0] effective_tile_index;

always_comb begin
  sprite_line = LY - sprites[candidate_index].y;
  // 8x8 sprites
  if (!LCDC[2]) begin
    tile_line = sprite_line[2:0];
    if (sprites[candidate_index].flags[6])
      tile_line = 3'd7 - tile_line;
    effective_tile_index = sprites[candidate_index].tile_index;
    row_offset = tile_line << 1;
  end else begin
  // 8x16 sprites
    if (sprite_line < 8) begin
      if (sprites[candidate_index].flags[6]) begin
        effective_tile_index = (sprites[candidate_index].tile_index & 8'hFE) + 1;
        tile_line = 3'd7 - sprite_line[2:0];
      end else begin
        effective_tile_index = sprites[candidate_index].tile_index & 8'hFE;
        tile_line = sprite_line[2:0];
      end
    end else begin
      if (sprites[candidate_index].flags[6]) begin
        effective_tile_index = sprites[candidate_index].tile_index & 8'hFE;
        tile_line = 3'd7 - ((sprite_line - 8'd8) & 8'd7);
      end else begin
        effective_tile_index = (sprites[candidate_index].tile_index & 8'hFE) + 1;
        tile_line = (sprite_line - 8'd8) & 8'd7;
      end
    end
    row_offset = tile_line << 1;
  end
end


  // Memory interface for sprite tile data.
  /*
  logic [7:0] effective_tile_index;
  always_comb begin
    if (LCDC[2])    // If using 8x16 sprites, force the LSB to 0.
      effective_tile_index = sprites[candidate_index].tile_index & 8'hFE;
    else
      effective_tile_index = sprites[candidate_index].tile_index;
  end
  */

  assign port_addr = (state == SCAN_CHECK && candidate_valid) ?
         (16'h8000 + (effective_tile_index * 16) + row_offset) : 16'h8000;

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
//   Instantiates Render_BG and Render_Sprites modules and FIFOs to buffer
//   their pixel streams. A new "pop" signal is used to pop pixels from both FIFOs.
// Inputs:
//   clk, reset, start, fifo_clear    - control signals.
//   LCDC         - LCD control register.
//   SCX, SCY     - BG scroll offsets.
//   WX, WY       - Window registers (window appears at (WX–7, WY)).
//   LY           - current scanline; BGP - BG palette register.
//   OBP0, OBP1   - Sprite palette registers.
//   sprite_count - number of sprites; selected_sprites - array of sprite_t.
//   bg_port_addr, bg_port_read_en, bg_port_data, bg_port_data_valid - BG VRAM interface.
//   sprite_port_addr, sprite_port_read_en, sprite_port_data, sprite_port_data_valid - Sprite VRAM interface.
//   pop          - when asserted, pops one pixel from both FIFOs.
// Outputs:
//   bg_fifo_data, sprite_fifo_data - FIFO outputs (pixel_t) for Pixel_Mixer.
//   scanline_processed             - high when both BG and Sprite processing are complete.
 //==================================================================
module Pixel_Gen (
  input  logic         clk,
  input  logic         reset,
  input  logic         start, full_frame_done,
  input  logic         fifo_clear,
  input  logic [7:0]   LCDC,
  input  logic [7:0]   SCX,
  input  logic [7:0]   SCY,
  input  logic [7:0]   WX,
  input  logic [7:0]   WY,
  input  logic [7:0]   LY,
  input  logic [7:0]   BGP,
  input  logic [7:0]   OBP0,
  input  logic [7:0]   OBP1,
  input  logic [3:0]   sprite_count,
  input  sprite_t      selected_sprites [0:9],
  // BG port interface:
  output logic [15:0]  bg_port_addr,
  output logic         bg_port_read_en,
  input  logic [15:0]  bg_port_data,
  input  logic         bg_port_data_valid,
  // Sprite port interface:
  output logic [15:0]  sprite_port_addr,
  output logic         sprite_port_read_en,
  input  logic [15:0]  sprite_port_data,
  input  logic         sprite_port_data_valid,
  // FIFO pixel outputs (to Pixel_Mixer):
  output pixel_t       bg_fifo_data,
  output pixel_t       sprite_fifo_data,
  // New pop signal for both FIFOs:
  input  logic         pop,
  output logic         scanline_processed,

  output logic         bg_out_valid,
  output logic         sprite_out_valid
);

  // Adjust internal pixel logics to be 31 bits wide (pixel_t is 31 bits).
  logic [30:0] internal_bg_pixel;
  logic [30:0] internal_sprite_pixel;

  // Push signals from render modules.
  logic bg_push;
  logic sprite_push;
  logic bg_done, sprite_done;

  // Instantiate Render_BG.
  Render_BG render_bg_inst (
    .clk(clk),
    .reset(reset),
    .start(start),
    .full_frame_done,
    .fifo_clear(fifo_clear),
    .LCDC(LCDC),
    .SCX(SCX),
    .SCY(SCY),
    .WX(WX),
    .WY(WY),
    .LY(LY),
    .BGP(BGP),
    .port0_addr(bg_port_addr),
    .port0_read_en(bg_port_read_en),
    .port0_data(bg_port_data),
    .port0_data_valid(bg_port_data_valid),
    .bg_fifo_data(internal_bg_pixel),  // 31-bit pixel_t
    .bg_done(bg_done),
    .bg_push(bg_push)                   // Push signal output
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
    .OBP1(OBP1),
    .sprite_count(sprite_count),
    .sprites(selected_sprites),
    .sprite_pixel(internal_sprite_pixel), // 31-bit pixel_t
    .sprite_done(sprite_done),
    .sprite_push(sprite_push),            // Push signal output
    .port_addr(sprite_port_addr),
    .port_read_en(sprite_port_read_en),
    .port_data(sprite_port_data),
    .port_data_valid(sprite_port_data_valid)
  );

  // Instantiate FIFO for background pixels.
  FIFO #(
    .DEPTH(64),
    .THRESHOLD(0)
  ) bg_fifo_inst (
    .clk(clk),
    .reset(reset),
    .clear(fifo_clear),
    .push(bg_push),
    .data_in(internal_bg_pixel),
    .pop(pop),
    .data_out(bg_fifo_data),
    .empty(), // Unused
    .full(),  // Unused
    .size(),  // Unused
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
    .empty(), // Unused
    .full(),  // Unused
    .size(),  // Unused
    .out_valid(sprite_out_valid)
  );

  // Scanline is processed when both render modules are done.
  assign scanline_processed = bg_done & sprite_done;

endmodule


//==================================================================
// Module: Pixel_Mixer
// Description: Selects between BG and sprite pixel based on priority.
// Inputs:
//   clk, reset, sprite_out_valid, bg_out_valid  - control signals.
//   bg_pixel_in - background pixel (pixel_t).
//   sprite_pixel_in - sprite pixel (pixel_t).
// Output:
//   pixel_out - final 2-bit pixel index.
//==================================================================

// `define map_palette(idx,pal)  \
//     begin case(idx) \
//       2'd0: pixel_out <= pal[1:0]; \
//       2'd1: pixel_out <= pal[3:2]; \
//       2'd2: pixel_out <= pal[5:4]; \
//       2'd3: pixel_out <= pal[7:6]; \
//       default: pixel_out <= 2'b00; \
//     endcase end
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
  // function automatic [1:0] `map_palette(
  //   input logic [1:0] pixel_idx,
  //   input logic [7:0] palette_reg,
  // );
  //   case(pixel_idx)
  //     2'd0: `map_palette = palette_reg[1:0];
  //     2'd1: `map_palette = palette_reg[3:2];
  //     2'd2: `map_palette = palette_reg[5:4];
  //     2'd3: `map_palette = palette_reg[7:6];
  //     default: `map_palette = 2'b00;
  //   endcase
  // endfunction

  assign fetch_pixel = bg_pixel_ready & sprite_pixel_ready;

  always_ff @(posedge clk or posedge reset) begin
    if(reset) begin
      pixel_out <= 2'b00;
      pixel_out_valid <= '0;
    end
    else begin
      pixel_out_valid <= fetch_pixel;
      if (~sprite_pixel_in.sprite_priority && sprite_pixel_in.pixel != 2'b00)
        case(sprite_pixel_in.pixel)
          2'd0: pixel_out = sprite_pixel_in.palette[1:0];
          2'd2: pixel_out = sprite_pixel_in.palette[3:2];
          2'd1: pixel_out = sprite_pixel_in.palette[5:4];
          2'd3: pixel_out = sprite_pixel_in.palette[7:6];
          default: pixel_out = 2'bx;
        endcase
      else
        case(bg_pixel_in.pixel)
          2'd0: pixel_out = bg_pixel_in.palette[1:0];
          2'd2: pixel_out = bg_pixel_in.palette[3:2];
          2'd1: pixel_out = bg_pixel_in.palette[5:4];
          2'd3: pixel_out = bg_pixel_in.palette[7:6];
          default: pixel_out = 2'bx;
        endcase
    end
  end

endmodule


//==================================================================
// Module: DMG_Color_Mapper
// Description: Maps a 2-bit DMG color index to a 12-bit VGA color.
// Inputs:
//   dmg_color - 2-bit DMG color index.
// Output:
//   vga_color - 12-bit VGA color.
//==================================================================
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
// Module: PPU_Wrapper
// Description: Top-level PPU module integrating mode control, STAT,
//              OAM search, pixel generation/mixing, and VGA output.
//              When mode == 2, the two memory ports serve as OAM ports.
//              When mode == 3, port0 is used for BG VRAM and port1 for Sprite VRAM.
// Inputs:
//   clk, reset, LCDC, STAT_in, LY, LYC, SCX, SCY, WX, WY,
//   BGP, OBP0, OBP1 - various LCD/PPU registers.
//   OAM port data (oam_port0_data, oam_port1_data).
//   VRAM port data (bg_port_data, bg_port_data_valid, sprite_port_data, sprite_port_data_valid).
// Outputs:
//   Memory interface: port0_addr, port0_read_en, port1_addr, port1_read_en.
//   Frame outputs: frame_pixel/valid, hsync, vsync, vga_color.
//==================================================================
module PPU_Wrapper (
  input  logic         clk,
  input  logic         reset,
  input  logic [7:0]   LCDC,
  input  logic [7:0]   STAT_in,
  input  logic [7:0]   LYC,
  input  logic [7:0]   SCX,
  input  logic [7:0]   SCY,
  input  logic [7:0]   WX,
  input  logic [7:0]   WY,
  input  logic [7:0]   BGP,
  input  logic [7:0]   OBP0,
  input  logic [7:0]   OBP1,
  output logic [1:0]   mode,

  output logic [7:0]   LY,
  // Memory ports (used either for OAM or for VRAM depending on mode)
  output logic [15:0]  port0_addr,
  output logic         port0_read_en,
  input  logic [15:0]  port0_data,
  output logic [15:0]  port1_addr,
  output logic         port1_read_en,
  input  logic [15:0]  port1_data,
  output logic [1:0]   frame_pixel,
  output logic         frame_pixel_valid
);

  // Internal timing signals from the mode controller.
  logic [8:0] dot;
  logic [7:0] line, scx_latched, scy_latched;
  logic       fifo_clear;
  logic       oam_search_done;
  logic [3:0] oam_sprite_count;
  logic       tile_pix_out_valid;

  // Internal memory interface signals for each purpose.
  // For OAM accesses (used in mode 2)
  logic [15:0] oam0_addr_sig, oam1_addr_sig;
  // For VRAM accesses (used in mode 3)
  logic [15:0] bg_addr_sig, sprite_addr_sig;
  logic        bg_read_en_sig, sprite_read_en_sig;
  logic        bg_out_valid, sprite_out_valid, pixel_out_valid;
  logic        fetch_pixel;
  logic        full_frame_done;

  // OAM search and sprite selection.
  sprite_t selected_sprites [0:9];

  // Pixel FIFO outputs.
  pixel_t bg_fifo_data;
  pixel_t sprite_fifo_data;
  // Final pixel (2-bit index) after mixing.
  logic [1:0] mixed_pixel;

  // Mode controller instantiation.
  PPU_Mode_controller mode_ctrl (
    .clk(clk),
    .reset(reset || (!LCDC[7])),
    .LCDC(LCDC), .SCX, .SCY,
    .scanline_processed(tile_pix_out_valid),
    .dot(dot),
    .line(LY),
    .scx_latched, .scy_latched,
    .mode(mode),
    .fifo_clear(fifo_clear),
    .full_frame_done(full_frame_done)
  );

  // OAM search instantiation.
  OAM_Search oam_search (
    .clk(clk),
    .reset(reset || (!LCDC[7])),
    .start((dot == 9'd0) ? 1'b1 : 1'b0),
    .current_line(LY),
    .LCDC(LCDC),
    .oam_port0_addr(oam0_addr_sig),
    .oam_port0_data(port0_data),  // In OAM mode, port0_data comes from memory.
    .oam_port1_addr(oam1_addr_sig),
    .oam_port1_data(port1_data),  // In OAM mode, port1_data comes from memory.
    .done(oam_search_done),
    .sprite_count(oam_sprite_count),
    .selected_sprites(selected_sprites)
  );

  // Pixel generation instantiation.
  Pixel_Gen Pixel_Gen_inst (
    .clk(clk),
    .reset(reset || (!LCDC[7])),
    .start((dot == 9'd80) ? 1'b1 : 1'b0),
    .full_frame_done,
    .fifo_clear(fifo_clear),
    .LCDC(LCDC),
    .SCX(scx_latched),
    .SCY(scy_latched),
    .WX(WX),
    .WY(WY),
    .LY(LY),
    .BGP(BGP),
    .OBP0(OBP0),
    .OBP1(OBP1),
    .sprite_count(oam_sprite_count),
    .selected_sprites(selected_sprites),
    .bg_port_addr(bg_addr_sig),
    .bg_port_read_en(bg_read_en_sig),
    .bg_port_data(port0_data),        // In VRAM mode, port0_data is used for BG.
    .bg_port_data_valid(1'b1),
    .sprite_port_addr(sprite_addr_sig),
    .sprite_port_read_en(sprite_read_en_sig),
    .sprite_port_data(port1_data),    // In VRAM mode, port1_data is used for sprites.
    .sprite_port_data_valid(1'b1),
    .bg_fifo_data(bg_fifo_data),
    .pop(fetch_pixel),
    .bg_out_valid(bg_out_valid),
    .sprite_out_valid(sprite_out_valid),
    .sprite_fifo_data(sprite_fifo_data),
    .scanline_processed(tile_pix_out_valid)
  );

  // Memory port assignments based on current mode.
  // When mode == 2, use ports as OAM ports; when mode == 3, use port0 for BG and port1 for sprites.
  assign port0_addr    = (mode == 2) ? oam0_addr_sig : bg_addr_sig;
  assign port0_read_en = (mode == 2) ? 1'b1          : bg_read_en_sig;
  assign port1_addr    = (mode == 2) ? oam1_addr_sig : sprite_addr_sig;
  assign port1_read_en = (mode == 2) ? 1'b1          : sprite_read_en_sig;

  // Pixel mixer instantiation.
  Pixel_Mixer pixel_mixer_inst (
    .clk(clk),
    .reset(reset || (!LCDC[7])),
    .bg_pixel_ready(bg_out_valid),
    .sprite_pixel_ready(sprite_out_valid),
    .bg_pixel_in(bg_fifo_data),
    .sprite_pixel_in(sprite_fifo_data),
    .fetch_pixel(fetch_pixel),
    .pixel_out_valid(pixel_out_valid),
    .pixel_out(mixed_pixel)
  );

  // Frame pixel outputs.
  assign frame_pixel_valid = pixel_out_valid && (mode != 2'b1);
  assign frame_pixel       = mixed_pixel;

endmodule
