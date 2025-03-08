`default_netttype none
`include "RegisterPkg.pkg"
`include "addresses.svh"


module MMU_TB();
            
            
            logic CLK_4MHZ;
            logic rst;


            logic [15:0] cpu_addr
            logic        cpu_wren;
            logic [15:0] cpu_in_data;
            
            logic [15:0]  ppu_addr1;
            logic [15:0]  ppu_addr2;

            logic [1:0]   ppu_mode;

            logic         joystick_select;
            logic         joystick_start;
            
            logic         joystick_dpad_up;
            logic         joystick_dpad_down;
            logic         joystick_dpad_left;  
            logic         joystick_dpad_right;

            logic         joystick_a_button;
            logic         joystick_b_button;  


            logic [15:0] cpu_out_data;
            logic        cpu_data_valid;

            logic [15:0] ppu1_out_data;
            logic        ppu2_out_data;

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