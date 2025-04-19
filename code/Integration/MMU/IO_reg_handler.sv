// `default_nettype none
`include "RegisterPkg.svh"
`include "addresses.svh"
`include "select.svh"


module IO_handler(input logic clock,
                  input logic cpu_clock,
                  input logic ppu_clock,
                  input logic reset,

                  input logic vblank,


                  input logic [15:0] cpu_addr_read,
                  input logic [15:0] cpu_addr_write,
                  input logic        cpu_wren,

                  input logic [15:0] cpu_in_data,

                  input logic         joypad_select,
                  input logic         joypad_start,

                  input logic         joypad_dpad_up,
                  input logic         joypad_dpad_down,
                  input logic         joypad_dpad_left,
                  input logic         joypad_dpad_right,
                  input logic         joypad_a_button,
                  input logic         joypad_b_button,

                  input logic [3:0] APU_NR52_bits,
                  input logic [1:0] ppu_mode,
                  input logic [7:0] ppu_LY,
                  input logic       interupt,

                  input logic stop_inst_hit,

                  output logic [7:0] cpu_out_data,
                  output logic        cpu_data_valid,

                  output logic restart_after_stop,
                  output logic halted,

                  output logic [7:0] JOYPAD_R,
                  output logic [7:0] JOYPAD_OUTPUT,

                  output logic[7:0] NR52_R, //Audio registers
                  output APU_DATA   APU_R,

                  output logic [7:0] SB_R, //Serial transfer data
                  output logic [7:0] SC_R, //Serial transfer control

                  output logic[7:0] LCDC_R, //PPU Registers
                  output logic[7:0] STAT_R,
                  output PPU_DATA   PPU_R,

                  output logic[7:0] DIV_R,// (FF04)
                  output logic[7:0] TIMA_R,  // (FF05)
                  output logic[7:0] TMA_R,  // (FF06)
                  output logic[7:0] TAC_R, // (FF07)

                  output logic [7:0] IF_R, //interrupt flag
                  output logic [7:0] IE_R, //interrupt enable

                  output logic [7:0] DMA_R,
                  output logic [7:0] BOOT_ROM_EN_R,

                  output logic start_dma);

    localparam integer clock_freq = 8_000_000;
    localparam integer DIV_TICK_COUNT = clock_freq/16384; //should be 244
    localparam integer SERIAL_TRANSFER_TICK_COUNT = clock_freq/8192
    logic [11:0] TIMA_TICK_COUNT; //this would be local param but it gets set during runtime


    logic[10:0] tima_ticks, divider_ticks, serial_ticks;

    enum logic[1:0] {IDLE, SERIAL_TRANSFER} SC_state, SC_nextState;
    logic en_serial_cycle_ctr, transfer_complete;
    logic [3:0] serial_cycles;

    logic vblank_sync;
    logic vblank_posedge;

    logic tima_overflow;
    assign tima_overflow = (tima_ticks == TIMA_TICK_COUNT - 1 && TAC_R[2] && TIMA_R == 16'hFF);

    assign vblank_posedge = ~vblank_sync && vblank;

    logic joypad_press;
    assign joypad_press = |({joypad_select, joypad_start, joypad_b_button, joypad_a_button}
                              || {joypad_dpad_down, joypad_dpad_up, joypad_dpad_left, joypad_dpad_right});


    logic [7:0] cpu_IO_in_data;

    logic even_cpu_write_io_addr;
    assign even_cpu_write_io_addr = is_even(cpu_addr_write);
    assign cpu_IO_in_data = is_even(cpu_addr_write) ? cpu_in_data[7:0] : cpu_in_data[15:8];

    logic [7:0] out_data;

    always_comb begin
        case(SC_state)
            IDLE: begin
                transfer_complete = 1'b0;
                en_serial_cycle_ctr = 1'b0;
                if(SC_R == 8'h81) begin
                    SC_nextState = SERIAL_DATA_TRANSFER;
                end else begin
                    SC_nextState = IDLE;
                end
           end
            SERIAL_DATA_TRANSFER: begin
                if(serial_cycles == 4'h7) begin
                    //once we've hit 8 cycles, then serial transfer shift
                    //register routine should be complete
                    SC_nextState = IDLE;
                    transfer_complete = 1'b1;
                    en_serial_cycle_ctr = 1'b1;
                end else begin
                    SC_nextState = SERIAL_DATA_TRANSFER;
                    transfer_complete = 1'b0;
                    en_serial_cycle_ctr = 1'b0;
                end
            end
            default: begin
                SC_nextState = IDLE; //hopefully unreachable
                transfer_complete = 1'b0;
                en_serial_cycle_ctr = 1'b0;
            end
        endcase

    end

    always_comb begin
        casez(cpu_addr_read)
        `JOYPAD:         begin
                              out_data       = JOYPAD_OUTPUT;
                              cpu_data_valid = 1'b1;
                         end
        `SB:             begin
                              out_data       = SB_R;
                              cpu_data_valid = 1'b1;
                         end
        `SC:             begin
                              out_data       = SC_R;
                              cpu_data_valid = 1'b1;
                         end
        `DIV:            begin
                              out_data       = DIV_R;
                              cpu_data_valid = 1'b1;
                         end
        `TIMA:           begin
                              out_data       = TIMA_R;
                              cpu_data_valid = 1'b1;
                         end
        `TMA:            begin
                              out_data       = TMA_R;
                              cpu_data_valid = 1'b1;
                         end
        `TAC:            begin
                              out_data       = TAC_R;
                              cpu_data_valid = 1'b1;
                         end
        `IF:             begin
                              out_data       = IF_R;
                              cpu_data_valid = 1'b1;
                         end

        `NR10,
        `NR11,
        `NR12,
        `NR13,
        `NR14:           begin
                              out_data       = APU_R.NR1x_R[cpu_addr_read - `NR10][7:0];
                              cpu_data_valid = 1'b1;
                         end

        `NR21,
        `NR22,
        `NR23,
        `NR24:           begin
                              out_data       = APU_R.NR2x_R[cpu_addr_read - `NR21][7:0];
                              cpu_data_valid = 1'b1;
                         end

        `NR30,
        `NR31,
        `NR32,
        `NR33,
        `NR34:           begin
                              out_data       = APU_R.NR3x_R[cpu_addr_read - `NR30][7:0];
                              cpu_data_valid = 1'b1;
                         end

        `NR41,
        `NR42,
        `NR43,
        `NR44:           begin
                              out_data       = APU_R.NR4x_R[cpu_addr_read - `NR41][7:0];
                              cpu_data_valid = 1'b1;
                         end

        `NR50:           begin
                              out_data       = APU_R.NR50_R;
                              cpu_data_valid = 1'b1;
                         end
        `NR51:           begin
                              out_data       = APU_R.NR51_R;
                              cpu_data_valid = 1'b1;
                         end
        `NR52:           begin
                              out_data       = NR52_R;
                              cpu_data_valid = 1'b1;
                         end


        16'hFF3?:        begin
                              out_data       = APU_R.WAV_RAM_R[cpu_addr_read - `WAV_RAM_START][7:0];
                              cpu_data_valid = 1'b1;
                         end


        `LCDC:           begin
                              out_data       = LCDC_R;
                              cpu_data_valid = 1'b1;
                         end
        `STAT:           begin
                              out_data       = STAT_R;
                              cpu_data_valid = 1'b1;
                         end
        `SCY:            begin
                              out_data       = PPU_R.SCY_R;
                              cpu_data_valid = 1'b1;
                         end
        `SCX:            begin
                              out_data       = PPU_R.SCX_R;
                              cpu_data_valid = 1'b1;
                         end
        `LY:             begin
                              out_data        = PPU_R.LY_R;
                              cpu_data_valid = 1'b1;
                         end
        `LYC:            begin
                              out_data           = PPU_R.LYC_R;
                              cpu_data_valid = 1'b1;
                         end
        `DMA:            begin
                              out_data       = DMA_R;
                              cpu_data_valid = 1'b1;
                         end
        `BGP:            begin
                              out_data       = PPU_R.BGP_R;
                              cpu_data_valid = 1'b1;
                         end
        `OBP0:           begin
                              out_data       = PPU_R.OBP0_R;
                              cpu_data_valid = 1'b1;
                         end
        `OBP1:           begin
                              out_data       = PPU_R.OBP1_R;
                              cpu_data_valid = 1'b1;
                         end
        `WY:            begin
                              out_data       = PPU_R.WY_R;
                              cpu_data_valid = 1'b1;
                        end
        `WX:            begin
                              out_data       = PPU_R.WX_R;
                              cpu_data_valid = 1'b1;
                        end

        `IE:            begin
                              out_data       = IE_R;
                              cpu_data_valid = 1'b1;
                        end
        default:        begin
                              out_data       = 16'hxx;
                              cpu_data_valid = 1'b0;
                        end
        endcase
    end

    logic debug_skip_ppu;


    always_comb begin
        case(TAC_R[1:0])
        2'b00: TIMA_TICK_COUNT = 2048; //1024 cpu cycles
        2'b01: TIMA_TICK_COUNT = 32; //16 cpu cycles
        2'b10: TIMA_TICK_COUNT = 128; //64 cpu cycles
        2'b11: TIMA_TICK_COUNT = 512; //256 cpu cycles
        default: TIMA_TICK_COUNT = 0; //HOPEFULLY unreachable
        endcase
    end
    logic [3:0] DPAD_R, BTN_R;
    always_ff @(posedge clock) begin
      if(reset) {DPAD_R,BTN_R} <= 8'hff;
      else if(joypad_start|joypad_select|joypad_b_button|joypad_a_button)
        BTN_R <= {~joypad_start, ~joypad_select, ~joypad_b_button, ~joypad_a_button};
      else if(joypad_dpad_down|joypad_dpad_up|joypad_dpad_left|joypad_dpad_right)
        DPAD_R <= {~joypad_dpad_down, ~joypad_dpad_up, ~joypad_dpad_left, ~joypad_dpad_right};
      else {DPAD_R,BTN_R} <= {DPAD_R,BTN_R};
    end

    always_comb begin
        casex(JOYPAD_R[5:4])
        2'bx0: JOYPAD_OUTPUT = {2'b11,JOYPAD_R[5:4],DPAD_R};
        2'b0x: JOYPAD_OUTPUT = {2'b11,JOYPAD_R[5:4],BTN_R};
        default: JOYPAD_OUTPUT = 16'h3f; //unreachable?
        endcase
    end

    // always_ff @(posedge cpu_clock)
        // cpu_out_data <= out_data; //delay by a cycle to be consistent with BRAM behavior
        assign cpu_out_data = out_data; //delay by a cycle to be consistent with BRAM behavior

    logic stat_sync;
    logic stat_posedge;

    logic hidden_stat;
    assign hidden_stat = (STAT_R[6] & STAT_R[2]) | (STAT_R[5] & (STAT_R[1:0] == 2'd2)) | (STAT_R[4] & (STAT_R[1:0] == 2'd1)) | (STAT_R[3] & (STAT_R[1:0] == 2'd0));

    // assign stat_posedge = ~stat_sync && hidden_stat;

    // always_ff @(posedge cpu_clock or posedge reset) begin
    //     if (reset)
    //         stat_sync <= 1'b0;
    //     else if(stop_inst_hit || halted)
    //         stat_sync <= 1'b0;
    //     else
    //         stat_sync <= hidden_stat;
    // end




    always_ff@(posedge clock) begin
        if(reset) begin
            halted             <= 1'b0;
            restart_after_stop <= 1'b0;
            vblank_sync        <= 1'b0;
            tima_ticks         <= '0;
            divider_ticks      <= '0;
            serial_ticks       <= '0;
            serial_cycles      <= '0;
            SC_state <= IDLE;

            JOYPAD_R   <= 8'hcf;
            NR52_R     <= 8'hf1;


            //Serial data control registers
            SB_R <= 8'h00;
            SC_R <= 8'h7E;
            //TODO: audio registers are hardcoded to zero for NOW
            APU_R      <= '0;

            //PPU REGISTERS
            LCDC_R       <= 8'h91;
            STAT_R       <= 8'h81; //1 in MSB for dmg mode
            PPU_R.SCY_R  <= 8'h00;
            PPU_R.SCX_R  <= 8'h00;
            PPU_R.LY_R   <= 8'h90;
            PPU_R.LYC_R  <= 8'h00;
            PPU_R.BGP_R  <= 8'he4;
            PPU_R.OBP0_R <= 8'h00;
            PPU_R.OBP1_R <= 8'h00;
            PPU_R.WY_R   <= 8'h00;
            PPU_R.WX_R   <= 8'h00;



            DIV_R      <= 8'hab;
            TIMA_R     <= '0;
            TMA_R      <= '0;
            TAC_R      <= 8'hf8;
            IF_R       <= 8'he1;
            IE_R       <= '0;
            DMA_R      <= 8'hff;
            BOOT_ROM_EN_R <= 1'b1;

        end else if(stop_inst_hit || halted) begin
            //if stop instruction, FREEZE everything, turn off LCDC
            //keep it this way until a joypad press

            if(joypad_press) begin
                halted <= 1'b0;
                restart_after_stop <= 1'b1;
            end
            else begin
                halted <= 1'b1;
                restart_after_stop <= 1'b0;
            end

            SC_state <= SC_nextState;


            LCDC_R        <= 1'b0;
            vblank_sync   <= 1'b0;
            JOYPAD_R      <= JOYPAD_R;
            NR52_R        <= NR52_R; //apu register
            APU_R         <= APU_R; //apu regisTERS
            STAT_R        <= STAT_R; //ppu register
            PPU_R         <= PPU_R;  //ppu regisTERS
            DIV_R         <= DIV_R; //timers
            TIMA_R        <= TIMA_R;
            TMA_R         <= TMA_R;
            TAC_R         <= TAC_R;
            IF_R          <= IF_R; //interrupts
            IE_R          <= IE_R;
            DMA_R         <= DMA_R; //dma
            BOOT_ROM_EN_R <= BOOT_ROM_EN_R; //boot rom switch
        end else begin
            halted <= 1'b0;
            restart_after_stop <= 1'b0;
            vblank_sync <= vblank;
            SC_state <= SC_nextState;

            //HANDLE joypad:
            if(cpu_addr_write == `JOYPAD && cpu_wren) begin
                //7,6,5 are empty
                // cpu can write to only the upper nibble lower nibble is read only
                //JOYPAD_R[5:4] <= cpu_IO_in_data[1:0]; //double check this
                JOYPAD_R[7:4] <= cpu_IO_in_data[7:4];
		            // JOYPAD_R <= cpu_IO_in_data;
            end else begin
		            JOYPAD_R[7:4] <= JOYPAD_R[7:4];
  	        end

            //HANDLE DIV: Divider
            if(cpu_addr_write == `DIV && cpu_wren) begin
                DIV_R <= 8'd0;
            end else begin
                //based on speed switch (tbd, this can increment double speed)
                if(divider_ticks == DIV_TICK_COUNT - 1) begin
                    divider_ticks <= '0;
                    DIV_R <= DIV_R + 8'd1;
                end else begin
                    divider_ticks <= divider_ticks + 1;
                    DIV_R <= DIV_R;
                end
            end

            //HANDLE TMA: timer modulo
            if(cpu_addr_write == `TMA && cpu_wren) begin
                TMA_R <= cpu_IO_in_data;
            end else begin
                TMA_R <= TMA_R;
            end

            //HANDLE TIMA: Timer Counter
            if(cpu_addr_write == `TIMA && cpu_wren) begin
                TIMA_R <= cpu_IO_in_data; //unexplained in pandocs but dr mario apparently can write to tima
            end else if(tima_ticks == TIMA_TICK_COUNT - 1 && TAC_R[2]) begin
                if(TIMA_R == 8'hFF) begin
                    TIMA_R <= TMA_R;
                    tima_ticks <= '0;
                end else if(TAC_R[2]) begin
                    TIMA_R <= TIMA_R + 8'h1;
                    tima_ticks <= '0;
                end else begin
                    TIMA_R <= TIMA_R;
                    tima_ticks <= '0;
                end
            end else begin
                TIMA_R <= TIMA_R;
                tima_ticks <= tima_ticks + 1'b1;
            end

            //HANDLE TAC: timer control
            if(cpu_addr_write == `TAC && cpu_wren) begin
                TAC_R <= cpu_IO_in_data;
            end else begin
                TAC_R <= TAC_R;
            end

            if(cpu_addr_write == `SB && cpu_wren) begin
                SB_R <= cpu_IO_in_data;
            end else begin
                SB_R <= SB_R;
            end

            if(cpu_addr_write == `SC && cpu_wren) begin
                SC_R <= cpu_IO_in_data;
            end else begin
                if(transfer_complete) begin
                    SC_R <= (1'b0, SC_R[6:0]);
                end else begin
                    SC_R <= SC_R;
                end
            end

            if(en_serial_cycle_ctr) begin
                if(serial_ticks == SERIAL_TRANSFER_TICK_COUNT - 1) begin
                    serial_cycles <= serial_cycles + 4'h1;
                    serial_ticks <= '0;
                end else begin
                    serial_cycles <= serial_cycles;
                    serial_ticks <= serial_ticks + 11'h1;
                end
            end else begin
                serial_cycles <= '0;
                serial_ticks <= '0;
            end


            if(cpu_addr_write == `IF && cpu_wren) begin
                IF_R <= cpu_IO_in_data;
            end else begin
                if(~interupt) begin
                  //handle INTERRUPT FLAG (7,6,5 are dont cares):
                  IF_R[3] <= transfer_complete;
                  // IF_R[1] <= |(STAT_R[6:3]);
                  IF_R[1] <= hidden_stat;

                  if(IF_R[4] == 1'b0) begin
                      IF_R[4] <= joypad_press;
                  end else begin
                      IF_R[4] <= IF_R[4];
                  end

                  if(IF_R[2] == 1'b0) begin
                      IF_R[2] <= tima_overflow;
                  end else begin
                      IF_R[2] <= IF_R[2];
                  end

                  if(IF_R[0] == 1'b0) begin
                      IF_R[0] <= vblank_posedge;
                  end else begin
                      IF_R[0] <= IF_R[0];
                  end
                end else begin
                  IF_R <= IF_R;
                end
            end

            //APU-related writes
            if(within_range(cpu_addr_write, `NR10, `WAV_RAM_END) && cpu_wren) begin
                if(within_range(cpu_addr_write, `NR10, `NR14)) begin
                    APU_R.NR1x_R[cpu_addr_write - `NR10][7:0] <= cpu_IO_in_data; //TODO: wonder if this is okay
                end else if(within_range(cpu_addr_write, `NR21, `NR24)) begin
                    APU_R.NR2x_R[cpu_addr_write - `NR21][7:0] <= cpu_IO_in_data; //TODO: wonder if this is okay
                end else if(within_range(cpu_addr_write, `NR30, `NR34)) begin
                    APU_R.NR3x_R[cpu_addr_write - `NR30][7:0] <= cpu_IO_in_data; //TODO: wonder if this is okay
                end else if(within_range(cpu_addr_write, `NR41, `NR44)) begin
                    APU_R.NR4x_R[cpu_addr_write - `NR41][7:0] <= cpu_IO_in_data; //TODO: wonder if this is okay
                end else if(within_range(cpu_addr_write, `WAV_RAM_START, `WAV_RAM_END)) begin
                    APU_R.WAV_RAM_R[cpu_addr_write - `WAV_RAM_START][7:0] <= cpu_IO_in_data; //TODO: wonder if this is okay
                end else if(cpu_addr_write == `NR50) begin
                    APU_R.NR50_R <= cpu_IO_in_data;
                end else if(cpu_addr_write == `NR51) begin
                    APU_R.NR51_R <= cpu_IO_in_data;
                end else if(cpu_addr_write == `NR52) begin
                    NR52_R[7] <= cpu_IO_in_data[7]; //cpu can only write to 7th bit
                end
            end else begin
                APU_R <= APU_R;
                NR52_R[7] <= NR52_R[7];
            end

            NR52_R[3:0] <= NR52_R; //this is read only, always gets populated by APU


            //DMA transfer write
            if(cpu_addr_write == `DMA && cpu_wren) begin
                DMA_R <= cpu_IO_in_data;
                if(~start_dma) begin
                    start_dma <= 1'b1;
                end
            end else begin
                DMA_R <= DMA_R;
                start_dma <= 1'b0;
            end


            //PPU-related writes
            if((within_range(cpu_addr_write, `LCDC, `WX) && cpu_wren)) begin
                debug_skip_ppu <= 1'b1;
                if(cpu_addr_write == `LCDC) begin
                    LCDC_R <= cpu_IO_in_data;//NOTE: stat is handled by ppu write
                end else if(cpu_addr_write == `SCY) begin
                    PPU_R.SCY_R <= cpu_IO_in_data;
                end else if(cpu_addr_write == `SCX) begin
                    PPU_R.SCX_R <= cpu_IO_in_data;
                end else if(cpu_addr_write == `LY) begin
                    PPU_R.LY_R <= cpu_IO_in_data;
                end else if(cpu_addr_write == `LYC) begin
                    PPU_R.LYC_R <= cpu_IO_in_data;
                end else if(cpu_addr_write == `WX) begin
                    PPU_R.WX_R <= cpu_IO_in_data;
                end else if(cpu_addr_write == `WY) begin
                    PPU_R.WY_R <= cpu_IO_in_data;
                end else if(cpu_addr_write == `BGP) begin
                    PPU_R.BGP_R <= cpu_IO_in_data;
                end else if(cpu_addr_write == `OBP0) begin
                    PPU_R.OBP0_R <= cpu_IO_in_data;
                end else if(cpu_addr_write == `OBP1) begin
                    PPU_R.OBP1_R <= cpu_IO_in_data;
                end
            end else begin
                debug_skip_ppu <= 1'b0;
                LCDC_R <= LCDC_R;
                PPU_R <= PPU_R;
            end
            PPU_R.LY_R <= (LCDC_R[7]) ? ppu_LY : 8'd0; // ***
            if(cpu_addr_write == `STAT && cpu_wren) begin
                STAT_R[1:0] <= (LCDC_R[7]) ? ppu_mode : 2'b0;
                STAT_R[2] <= (PPU_R.LY_R == PPU_R.LYC_R);
                STAT_R[7:3] <= {1'b1,cpu_IO_in_data[6:3]};
            end else begin
                STAT_R[1:0] <= (LCDC_R[7]) ? ppu_mode : 2'b0;
                STAT_R[2] <= (PPU_R.LY_R == PPU_R.LYC_R);
                STAT_R[7:3] <= {1'b1,STAT_R[6:3]};
            end


            if(cpu_addr_write == `IE && cpu_wren) begin
                IE_R <= cpu_IO_in_data;
            end else begin
                IE_R <= IE_R;
            end

            if(cpu_addr_write == `BOOT_ROM && cpu_wren) begin
                BOOT_ROM_EN_R <= cpu_IO_in_data;
            end else begin
                BOOT_ROM_EN_R <= BOOT_ROM_EN_R;
            end
        end
    end

endmodule: IO_handler


