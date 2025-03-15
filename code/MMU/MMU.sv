`default_nettype none
`include "RegisterPkg.pkg"
`include "addresses.svh"
`include "select.svh"



function logic within_range(input logic [15:0] value, input logic [15:0] min, input logic [15:0] max);
    return (value >= min) && (value <= max);
endfunction   

function logic is_even(input logic [15:0] address);
    return address[0] == 1'b0;
endfunction    


module MMU (input logic CLK_4MHZ, // 5 Mhz?
            input logic rst,


            input logic [15:0] cpu_addr,
            input logic        cpu_wren,
            input logic [15:0] cpu_in_data,
            input logic        stop_inst_hit,

            input logic [15:0]  ppu_addr1,
            input logic [15:0]  ppu_addr2,

            input logic [1:0]   ppu_mode,
            input logic         hblank,
            input logic         vblank,

            input logic         joypad_select,
            input logic         joypad_start,
            
            input logic         joypad_dpad_up,
            input logic         joypad_dpad_down,
            input logic         joypad_dpad_left,  
            input logic         joypad_dpad_right,

            input logic         joypad_a_button,
            input logic         joypad_b_button,  


            output logic [15:0] cpu_out_data,
            output logic        cpu_data_valid,

            output logic [15:0] ppu_out_data1,
            output logic [15:0] ppu_out_data2,

            output logic        ppu_data_valid,
            
            output logic        restart_after_stop);
    
    localparam integer NUM_ROM_BANKS = 2;

    //////////////////////////////////////////////////
    //------------  IO REGISTERS  --------------------
    //////////////////////////////////////////////////

    //---JOYPAD Register 
    logic [7:0] JOYPAD_R;
    logic [7:0] JOYPAD_OUTPUT;
    

    //---APU Registers
    logic[7:0] NR52_R; //mixed r/w register
    APU_DATA APU_R;

    //----------INPUT from the APU
    logic[3:0] APU_NR52_bits;
    assign APU_NR52_bits = 4'b0000;    

    //---PPU Registers
    logic[7:0] LCDC_R;
    logic[7:0] STAT_R; //mixed r/w register
    PPU_DATA PPU_R;

    //---DMA Register 
    logic[7:0] DMA_R;

    
    //---TIMER and CONTROL Registers  
    logic[7:0] DIV_R; // (FF04)
    logic[7:0] TIMA_R;  // (FF05)
    logic[7:0] TMA_R;  // (FF06)
    logic[7:0] TAC_R; // (FF07)
    
    //---INTERRUPT Registers  
    logic [7:0] IF_R; //interrupt flag
    logic [7:0] IE_R; //interrupt enable

    //---BOOT ROM Enable/Disable Register  
    logic [7:0] BOOT_ROM_EN_R;


    ///////////////////////////////////////////
    //      MISC SIGNALS
    ///////////////////////////////////////////

    logic start_dma;
    logic halted;

    logic[15:0] memory_out_cpu_data;
    logic[15:0] IO_out_cpu_data;

    ///////////////////////////////////////////
    //      MEMORY DECLARATIONS
    ///////////////////////////////////////////  

    always_comb begin
        if(within_range(cpu_addr, `IO_START, `IO_END)) begin
            /* even case: {8'd0, IO_data}
               odd case: {IO_data, 8'd0}  */            
            if(is_even(cpu_addr)) begin
                cpu_out_data = {8'd0, IO_out_cpu_data};
            end else begin
                cpu_out_data = {IO_out_cpu_data, 8'd0};
            end
        end else begin
            cpu_out_data = memory_out_cpu_data;
        end
    end  


    IO_handler io_registers  (.clock(CLK_4MHZ),
                              .reset(rst),
                              .vblank,
                              .cpu_addr,
                              .cpu_wren,
                              .cpu_in_data,
                              .joypad_select,
                              .joypad_start,
                              .joypad_dpad_up,
                              .joypad_dpad_down,
                              .joypad_dpad_left,  
                              .joypad_dpad_right,
                              .joypad_a_button,
                              .joypad_b_button, 
                              .APU_NR52_bits, 
                              .ppu_mode,
                              .stop_inst_hit,
                              .cpu_out_data(IO_out_cpu_data),
                              .restart_after_stop,
                              .halted,
                              .JOYPAD_R,
                              .JOYPAD_OUTPUT,
                              .NR52_R,
                              .APU_R,
                              .LCDC_R,
                              .STAT_R,
                              .PPU_R,
                              .DIV_R,// (FF04)
                              .TIMA_R,  // (FF05)
                              .TMA_R,  // (FF06)
                              .TAC_R, // (FF07)
                              .IF_R, //interrupt flag
                              .IE_R, //interrupt enable
                              .DMA_R,
                              .BOOT_ROM_EN_R,
                              .start_dma);

    
    //TODO: sanity check hwo dma data is passed, do i need antoher register
    BRAM_handler memory_units (.clock(CLK_4MHZ), 
                              .reset(rst), 
                              .cpu_addr,
                              .cpu_wren,
                              .cpu_in_data,
                              .ppu_addr1,
                              .ppu_addr2, 
                              .ppu_mode,
                              .DMA_R(DMA_R),
                              .start_dma,
                              .cpu_out_data(memory_out_cpu_data),
                              .ppu_out_data1,
                              .ppu_out_data2,
                              .cpu_data_valid(cpu_data_valid),
                              .ppu_data_valid(ppu_data_valid));
endmodule: MMU

