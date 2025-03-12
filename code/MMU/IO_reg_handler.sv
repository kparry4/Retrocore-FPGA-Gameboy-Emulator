`default_nettype none
`include "RegisterPkg.pkg"
`include "addresses.svh"

module IO_handler(input logic clock, 
                  input logic reset,

                  input logic vblank,


                  input logic [15:0] cpu_addr
                  input logic        cpu_wren,

                  input logic [15:0] cpu_in_data,

                  input logic         joystick_select,
                  input logic         joystick_start,
                
                  input logic         joystick_dpad_up,
                  input logic         joystick_dpad_down,
                  input logic         joystick_dpad_left,  
                  input logic         joystick_dpad_right,


                  input logic [3:0] APU_NR52,
                  input logic [1:0]   ppu_stat

                  input logic stop_inst_hit,

                  output logic [7:0] cpu_out_data,
                  
                  output logic restart_after_stop,
                  output logic halted,


                  output logic [7:0] JOYPAD_OUTPUT,
                  
                  
                  
                  output APU_DATA APU_R,
                  output PPU_DATA PPU_R,
                  
                  output logic[7:0] DIV_,// (FF04)
                  output logic[7:0] TIMA_R,  // (FF05)
                  output logic[7:0] TMA_R,  // (FF06)
                  output logic[7:0] TAC_R, // (FF07)

                  output logic [7:0] IF_R, //interrupt flag
                  output logic [7:0] IE_R, //interrupt enable

                  output logic [7:0] DMA_R,
                  output logic [7:0] BOOT_ROM_EN_R,
                  
                  output logic start_dma);
         
    localparam interger clock_freq = 4_000_000;
    localparam integer DIV_TICK_COUNT = clock_freq/16384; //should be 244
    logic[10:0] tma_ticks, divider_ticks; 

    logic vblank_sync;

    assign vblank_handler_called = ~vlbank_sync && vblank;

    logic joystick_press;
    assign joystick_press = |({joypad_select, joypad_start, joypad_b_button, joypad_a_button}
                              || {joystick_dpad_down, joystick_dpad_up, joystick_dpad_left, joystick_dpad_right});

    always_comb begin
        casez(cpu_selected_addr)
        `JOYP:           cpu_out_data = JOYPAD_OUTPUT;
        `SERIAL_TRANS_D: cpu_out_data = 16'hFF;//dont think we need this
        `SERIAL_TRANS_C: cpu_out_data = 16'hFF;//dont think we need this
        `DIV:            cpu_out_data = DIV_R;
        `TIMA:           cpu_out_data = TIMA_R;
        `TMA:            cpu_out_data = TMA_R;
        `TAC:            cpu_out_data = TAC_R;
        `INTERRUPT_FLAG: cpu_out_data = IF_R;

        `NR10,          
        `NR11,          
        `NR12,          
        `NR13,          
        `NR14:           cpu_out_data = APU_R.NR1x_R[cpu_addr - `NR10][7:0];
        
        `NR21,          
        `NR22,           
        `NR23,           
        `NR24:           cpu_out_data = APU_R.NR2x_R[cpu_addr - `NR20][7:0];
        
        `NR30,           
        `NR31,           
        `NR32,           
        `NR33,           
        `NR34:           cpu_out_data = APU_R.NR3x_R[cpu_addr - `NR30][7:0];
        
        `NR41,           
        `NR42,           
        `NR43,           
        `NR44:           cpu_out_data = APU_R.NR4x_R[cpu_addr - `NR40][7:0];    
        
        `NR50:           cpu_out_data = APU_R.NR51;
        `NR51:           cpu_out_data = APU_R.NR52;
        `NR52:           cpu_out_data = NR52_R;
        
        
        16'hFF3?:        cpu_out_data = WAV_RAM_R[cpu_addr - WAV_RAM_START][7:0];
        
        
        `LCDC:           cpu_out_data = LCDC_R;
        `STAT:           cpu_out_data = STAT_R;
        `SCY:            cpu_out_data = PPU_DATA.SCY_R;
        `SCX:            cpu_out_data = PPU_DATA.SCX_R;
        `LY:             cpu_out_data = PPU_DATA.LY_R;
        `LYC:            cpu_out_data = PPU_DATA.LYC;
        `DMA:            cpu_out_data = DMA_R;
        `BGP:            cpu_out_data = PPU_DATA.BGP_R;
        `OBP0:            cpu_out_data = PPU_DATA.OBP0_R;
        `OBP1:            cpu_out_data = PPU_DATA.OBP1_R;
        `WY:            cpu_out_data = PPU_DATA.WY_R;
        `WX:            cpu_out_data = PPU_DATA.WX_R;

        `INTERRUPT_EN:        
        endcase
    end
    
    
    always_comb begin
        case(TAC_R[1:0])
        2'b00: TMA_TICK_COUNT = 1024;
        2'b01: TMA_TICK_COUNT = 16;
        2'b10: TMA_TICK_COUNT = 64;
        2'b11: TMA_TICK_COUNT = 256;
        default: TMA_TICK_COUNT = 0; //HOPEFULLY unreachable
        endcase
    end

    always_comb begin
        casex(JOYPAD_R[5:4])
        2'bx0: JOYPAD_OUTPUT = {joypad_select, joypad_start, joypad_b_button, joypad_a_button};
        2'b0x: JOYPAD_OUTPUT = {joystick_dpad_down, joystick_dpad_up, joystick_dpad_left, joystick_dpad_right};
        default: JOYPAD_OUTPUT = '0; //unreachable?
        endcase
    end

    always_ff@(posedge clock) begin

        vblank_sync <= vblank;
        

        if(reset) begin
            halted     <= 1'b0;
            JOYPAD_R   <= '0;
            APU_NR52   <= '0;
            APU_R      <= '0;
            PPU_R_LCDC <= '0;
            PPU_R_STAT <= 8'h80; //1 in MSB for dmg mode
            PPU_R      <= '0;
            DIV_R      <= '0;
            TIMA_R     <= '0;
            TMA_R      <= '0;
            TAC_R      <= '0;
            IF_R       <= '0;
            IE_R       <= '0;
            DMA_R      <= '0;
            BOOT_ROM_EN_R <= 1'b1;

        end else if(stop_inst_hit || halted) begin
            //if stop instruction, FREEZE everything, turn off LCDC
            //keep it this way until a joystick press 

            if(joystick_press) begin
                halted <= 1'b0;
            end
            else begin
                halted <= 1'b1;
            end
            
            LCDC_R        <= 1'b0; 
            JOYPAD_R      <= JOYPAD_R;
            NR52_R        <= NR52_R; //apu register
            APU_R         <= APU_R; //apu regisTERS
            LCDC_R        <= LCDC_R; //ppu register
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
            
            //HANDLE joypad:
            if(cpu_wren && cpu_addr == JOYPAD) begin
                //7,6,5 are empty
                JOYPAD_R[5:4] <= cpu_data[1:0]; //double check this
            end

            //HANDLE DIV: Divider
            if(cpu_addr == DIV && cpu_wren) begin
                DIV_R <= 8'd0;
            end else begin
                //based on speed switch (tbd, this can increment double speed)
                if(div_counter == DIV_TICK_COUNT - 1) begin
                    divider_ticks <= '0;
                    DIV_R <= 8'd0;
                end else begin
                    divider_ticks <= divider_ticks + 1;
                    DIV_R <= DIV_R:
                end
            end

            //HANDLE TMA: timer modulo
            if(cpu_addr == TMA && cpu_wren) begin
                TIMER_MODULO_R <= cpu_data;
            end else begin
                TIMER_MODULO_R <= TIMER_MODULO_R;
            end

            //HANDLE TIMA: Timer Counter
            if(tma_ticks == TMA_TICK_COUNT - 1 && TIMER_CTRL_R[2]) begin
                if(TIMER_COUNTER_R == 8'hFF) begin
                    TIMER_COUNTER_R <= TIMER_MODULO_R;
                    IF[2] <= 1'b1; //interrupt requested
                end else if(TIMER_CTRL_R[2]) begin
                    TIMER_COUNTER_R <= TIMER_COUNTER_R + 8'h1;
                    IF[2] <= 1'b0;
                end else begin
                    TIMER_COUNTER_R <= TIMER_COUNTER_R;
                    IF[2] <= 1'b0;
                end         
            end else begin
                TIMER_COUNTER_R <= TIMER_COUNTER_R;
                tma_ticks <= tma_ticks + 1'b1;
                IF[2] <= 1'b0;
            end

            //HANDLE TAC: timer control
            if(cpu_addr == TIMA && cpu_wren) begin
                TIMER_CTRL_R <= cpu_data;
            end else begin
                TIMER_CTRL_R <= TIMER_CTRL_R;
            end


            //handle INTERRUPT FLAG (7,6,5 are dont cares):
            IF[4] <= joypad_press; 
            //note that IF[2] is handled in time section
            IF[3] <= 1'b0; //wserial control (not implented)
            IF[1] <= |(STAT[6:3]); 
            IF[0] <= vblank_handler_called;         

            //APU-related writes
            if(within_range(cpu_addr, NR10, WAV_RAM_END) && cpu_wren) begin
                if(within_range(cpu_addr, NR10, NR14)) begin
                    APU_R.NR1x_R[cpu_addr - NR10][7:0] <= cpu_data; //TODO: wonder if this is okay 
                end else if(within_range(cpu_addr, NR21, NR24)) begin
                    APU_R.NR2x_R[cpu_addr - NR21][7:0] <= cpu_data; //TODO: wonder if this is okay 
                end else if(within_range(cpu_addr, NR31, NR34)) begin
                    APU_R.NR3x_R[cpu_addr - NR31][7:0] <= cpu_data; //TODO: wonder if this is okay 
                end else if(within_range(cpu_addr, NR41, NR44)) begin
                    APU_R.NR4x_R[cpu_addr - NR41][7:0] <= cpu_data; //TODO: wonder if this is okay 
                end else if(within_range(cpu_addr, WAV_RAM_START, WAV_RAM_END)) begin
                    APU_R.WAV_RAM_R[cpu_addr - WAV_RAM_START][7:0] <= cpu_data; //TODO: wonder if this is okay 
                end else if(cpu_addr == NR50) begin
                    APU_R.NR50_R <= cpu_data;
                end else if(cpu_addr == NR51) begin
                    APU_R.NR51_R <= cpu_data;
                end else if(cpu_addr == NR52) begin
                    NR52_R[7] <= cpu_data[7]; //cpu can only write to 7th bit
                end
            end else begin
                APU_R <= APU_R;
                NR52_R[7] <= NR52_R[7];
            end

            NR52_R[3:0] <= NR52_R; //this is read only, always gets populated by APU


            //DMA transfer write
            if(cpu_addr == DMA && cpu_wren) begin
                DMA_R <= cpu_data;
                if(~start_dma) begin
                    start_dma <= 1'b1;
                end
            end else begin
                DMA_R <= DMA_R;
                start_dma <= 1'b0;
            end      


            //PPU-related writes
            if((within_range(cpu_addr, LCDC, OBP1_R) && cpu_wren)) begin           
                if(cpu_addr == LCDC) begin
                    LCDC_R <= cpu_data;
                    //NOTE: stat is handled by ppu write
                end else if(cpu_addr == SCY && cpu_wren) begin
                    PPU_DATA.SCY_R <= cpu_data;
                end else if(cpu_addr == SCX && cpu_wren) begin
                    PPU_DATA.SCX_R <= cpu_data;
                end else if(cpu_addr == LY && cpu_wren) begin
                    PPU_DATA.LY_R <= cpu_data;
                end else if(cpu_addr == LYC && cpu_wren) begin
                    PPU_DATA.LYC_R <= cpu_data;
                end else if(cpu_addr == WX) begin
                    PPU_DATA.WX_R <= cpu_data;
                end else if(cpu_addr == WY) begin
                    PPU_DATA.WY_R <= cpu_data;
                end else if(cpu_addr == BGP) begin
                    PPU_DATA.BGP_R <= cpu_data;
                end else if(cpu_addr == OBP0) begin
                    PPU_DATA.OBP0_R <= cpu_data;
                end else if(cpu_addr == OBP1) begin
                    PPU_DATA.OBP1_R <= cpu_data;
                end
            end else begin
                LCDC_R <= LCDC_R;
                PPU_DATA <= PPU_DATA;
            end

            STAT_R[1:0] <= ppu_mode;
            STAT_R[2] <= (PPU_DATA.LY_R == PPU_DATA.LYC_R); 
            STAT_R[3] <= (ppu_mode == 2'd0);
            STAT_R[4] <= (ppu_mode == 2'd1);
            STAT_R[5] <= (ppu_mode == 2'd2);
            STAT_R[6] <= (PPU_DATA.LY_R == PPU_DATA.LYC_R); 




            if(cpu_addr == INTERRUPT_EN && cpu_wren) begin
                IE_R <= cpu_data
            end else begin
                IE_R <= IE_R;
            end

            if(cpu_addr == BOOT_ROM && cpu_wren) begin
                BOOT_ROM_EN_R <= cpu_data
            end else begin
                BOOT_ROM_EN_R <= BOOT_ROM_EN_R;
            end            
        end
    end

endmodule: IO_handler


