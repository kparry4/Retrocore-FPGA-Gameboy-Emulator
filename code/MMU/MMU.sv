`default_netttype none
`include "RegisterPkg.pkg"
`include "addresses.svh"

function logic within_range(input logic [15:0] value, input logic [15:0] min, input logic [15:0] max);
    return (value >= min) && (value <= max);
endfunction    

module MMU (input logic CLK_4MHZ, // 5 Mhz?
            input logic rst,


            input logic [15:0] cpu_addr
            input logic        cpu_wren,
            input logic [15:0] cpu_in_data,
            
            input logic [15:0]  ppu_addr1,
            input logic [15:0]  ppu_addr2,

            input logic [1:0]   ppu_mode,

            input logic [1:0]   ppu_stat,

            input logic         joystick_select,
            input logic         joystick_start,
            
            input logic         joystick_dpad_up,
            input logic         joystick_dpad_down,
            input logic         joystick_dpad_left,  
            input logic         joystick_dpad_right,

            input logic         joystick_a_button,
            input logic         joystick_b_button,  


            output logic [15:0] cpu_out_data,
            output logic        cpu_data_valid,

            output logic [15:0] ppu1_out_data,
            output logic [15:0] ppu2_out_data,

            output logic        ppu_data_valid);
    
    localparam integer NUM_ROM_BANKS = 2

    //////////////////////////////////////////////////
    //------------  IO REGISTERS  --------------------
    //////////////////////////////////////////////////

    //---JOYPAD Register 
    logic [7:0] JOYPAD_R;

    //---APU Registers
    logic[7:0] NR52_R; //mixed r/w register
    APU_DATA APU_R;

    //---PPU Registers
    logic[7:0] LCDC_R;
    logic[7:0] STAT_R; //mixed r/w register
    PPU_DATA PPU_R;
    
    //---TIMER and CONTROL Registers  
    logic[7:0] DIV_R; // (FF04)
    logic[7:0] TIMA_R;  // (FF05)
    logic[7:0] TMA_R;  // (FF06)
    logic[7:0] TAC_R; // (FF07)
    
    //---INTERRUPT Registers  
    logic [7:0] IF_R; //interrupt flag
    logic [7:0] IE_R: //interrupt enable

    //---BOOT ROM Enable/Disable Register  
    logic [7:0] BOOT_ROM_EN_R;'


    ///////////////////////////////////////////
    //      MISC SIGNALS
    ///////////////////////////////////////////

    logic start_dma;
    logic halted;

    logic[7:0] memory_out_cpu_data;
    logic[7:0] IO_out_cpu_data;

    ///////////////////////////////////////////
    //      MEMORY DECLARATIONS
    ///////////////////////////////////////////  

    always_comb begin
        if(within_range(cpu_addr, `IO_START, `IO_END)) begin
            cpu_out_data = IO_out_cpu_data;
        end else begin
            cpu_out_data = memory_out_cpu_data;
        end
    end  


    IO_handler io_registers  (.clock(CLK_4MHZ),
                              .cpu_addr
                              .cpu_wren,
                              .cpu_in_data,
                              .cpu_out_data(IO_out_cpu_data)
                              .JOYPAD_R,
                              .APU_R,
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
    MM_handler memory_units  (.clock(CLK_4MHZ), 
                              .reset, 
                              .cpu_addr,
                              .ppu_addr1,
                              .ppu_addr2, 
                              .ppu_mode,
                              .DMA_R(DMA_R),
                              .start_dma,
                              .cpu_out_data(memory_out_cpu_data),
                              .ppu_out_data1,
                              .ppu_out_data2,
                              .cpu_data_valid(memory_cpu_valid),
                              .ppu_data_valid(ppu_data_valid));
endmodule: MMU

