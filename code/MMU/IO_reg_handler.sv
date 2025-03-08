`default_nettype none



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

                  input logic stop_inst_hit,

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
    logic[10:0] TMA_TICK_COUNT; 

    logic vblank_handler_called;
    assign vblank_handler_called = 1'b0;

    logic joystick_press;
    assign joystick_press = |({joypad_select, joypad_start, joypad_b_button, joypad_a_button}
                              || {joystick_dpad_down, joystick_dpad_up, joystick_dpad_left, joystick_dpad_right});

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

        if(reset) begin
            halted <= 1'b0;
            JOYPAD_R <= '0;
            APU_R <= '0;
            PPU_R <= '0;
            DIV_R <= '0;
            TIMA_R <= '0;
            TMA_R <= '0;
            TAC_R <= '0;
            IF_R <= '0;
            IE_R <= '0;
            DMA_R <= '0;
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
            
            //I couldnt think of an elegant way, apologies     
            JOYPAD_R <= JOYPAD_R;
            APU_R <= APU_R;
            PPU_R.LCDC_R <= '0;
            PPU_R.LCDC_R <= PPU_R.LCDC_R;  //ewwww
            PPU_R.STAT_R <= PPU_R.STAT_R; 
            PPU_R.SCY_R  <= PPU_R.SCY_R;  
            PPU_R.SCX_R  <= PPU_R.SCX_R;  
            PPU_R.LY_R   <= PPU_R.LY_R;   
            PPU_R.LYC_R  <= PPU_R.LYC_R;  
            PPU_R.BGP_R  <= PPU_R.BGP_R;  
            PPU_R.OBP0_R <= PPU_R.OBP0_R; 
            PPU_R.OBP1_R <= PPU_R.OBP1_R; 
            PPU_R.WY_R   <= PPU_R.WY_R;   
            PPU_R.WX_R   <= PPU_R.WX_R; 
            DIV_R         <= DIV_R;
            TIMA_R        <= TIMA_R;
            TMA_R         <= TMA_R;
            TAC_R         <= TAC_R;
            IF_R          <= IF_R;
            IE_R          <= IE_R;
            DMA_R         <= DMA_R;
            BOOT_ROM_EN_R <= BOOT_ROM_EN_R;         
        end else begin
            halted <= 1'b0;
            
            //HANDLE joypad:
            if(cpu_wren == JOYPAD) begin
                //7,6,5 are empty
                JOYPAD_R[5:4] <= cpu_data[1:0]; //double check this
            end

            //HANDLE DIV: Divider
            if(cpu_addr == DIV && cpu_wren) begin
                DIV_R <= 8'd0;
            end else begin
                //based on speed switch (tbd, this can increment double speed)
                if(div_counter == DIV_TICK_COUNT - 1) begin
                    div_counter <= '0;
                    DIV_R <= 8'd0;
                end else begin
                    div_counter <= div_counter + 1;
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
            if(tima_div_counter == TMA_TICK_COUNT - 1) begin
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
                IF[2] <= 1'b0;
            end

            //HANDLE TAC: timer control
            if(cpu_addr == TIMA && cpu_wren) begin
                TIMER_CTRL_R <= cpu_data;
            end else begin
                TIMER_CTRL_R <= TIMER_CTRL_R;
            end


 
            //handle INTERRUPT FLAG (7,6,5 are dont cares):
            IF[4] <= joypad_edge; //TODO: joypad edgeeeeee
            IF[3] <= 1'b0; //wserial control (not implented)
            IF[1] <= STAT; 
            IF[0] <= vblank && vblank_handler_called;         


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
                    APU_R.NR52_R <= cpu_data;
                end
            end else begin
                APU_R <= APU_R;
            end


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
                    PPU_DATA.LCDC_R <= cpu_data;
                end else if(cpu_addr == STAT) begin
                    PPU_DATA.STAT_R <= cpu_data;
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
                PPU_DATA <= PPU_DATA;
            end



            if(cpu_addr == INTERRUPT_EN) begin
                IE_R <= cpu_data
            end else begin
                IE_R <= IE_R;
            end
        end
    end

endmodule: IO_handler


