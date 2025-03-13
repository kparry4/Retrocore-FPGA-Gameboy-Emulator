`default_nettype none
`include "RegisterPkg.pkg"
`include "addresses.svh"


module MMU_TB();
            
            
            logic CLK_4MHZ;
            logic rst;


            logic [15:0] cpu_addr;
            logic        cpu_wren;
            logic [15:0] cpu_in_data;
            
            logic [15:0]  ppu_addr1;
            logic [15:0]  ppu_addr2;

            logic [1:0]   ppu_mode;

            logic hblank;
            logic vblank;

            logic         joypad_select;
            logic         joypad_start;
            
            logic         joypad_dpad_up;
            logic         joypad_dpad_down;
            logic         joypad_dpad_left;  
            logic         joypad_dpad_right;

            logic         joypad_a_button;
            logic         joypad_b_button;  


            logic [15:0] cpu_out_data;
            logic        cpu_data_valid;

            logic [15:0] ppu_out_data1, ppu_out_data2;
            logic        ppu_data_valid;

            logic        restart_after_stop;

            logic        stop_inst_hit;

    MMU dut (.*);

    initial begin
        CLK_4MHZ = 1'b0;
        forever #5 CLK_4MHZ = ~CLK_4MHZ;
    end


    initial begin
        #10000;
        $finish;
    end



endmodule