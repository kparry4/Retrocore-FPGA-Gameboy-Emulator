`default_nettype none
`include "RegisterPkg.pkg"
`include "addresses.svh"
`include "select.svh"

module MMU_TB();
                
    logic clock;
    logic cpu_clock;
    logic reset;

    logic [15:0] cpu_addr;
    logic        cpu_wren;
    logic [15:0] cpu_in_data;
    
    logic [15:0]  ppu_addr1;
    logic [15:0]  ppu_addr2;

    logic [1:0]   ppu_mode;

    logic [3:0]  APU_NR52;

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

    MMU dut ( .CLK_4MHZ(clock), .rst(reset), .*);

    //////////////////////////
    //  tb signals to help me out

    logic[7:0] joystick_control;

    assign joypad_select     = joystick_control[0];
    assign joypad_start      = joystick_control[1];
    assign joypad_dpad_up    = joystick_control[2];
    assign joypad_dpad_down  = joystick_control[3];
    assign joypad_dpad_left  = joystick_control[4];  
    assign joypad_dpad_right = joystick_control[5];
    assign joypad_a_button   = joystick_control[6];
    assign joypad_b_button   = joystick_control[7];    

    assign hblank = (ppu_mode == 2'b00);
    assign vblank = (ppu_mode == 2'b01);

    assign joystick_control = 8'd0;




    /**
    
    Things to test:

    DURING ppu mode 0, then 1, then 2, then 3:

    DO DMA in each mode

    cpu addr
        -ROM 0-1 (read)
        -VRAM    (read/write)
        -EXRAM (read/write)
        -WRAM (read/write)
        -OAM (read/write)
        -HRAM (read/write)

        -EACH I/O register    
    **/

    task stopInstruction();
        stop_inst_hit <= 1'b1;
    endtask

    task do_cpu_read(input logic[15:0] address);
        cpu_addr <= address;
        cpu_wren <= 1'b0;
        @(posedge cpu_clock);
    endtask
    
    task do_cpu_write(input logic[15:0] address, input logic[15:0] data);
        cpu_addr <= address;
        cpu_wren <= 1'b1;
        cpu_in_data <= data;    
        @(posedge cpu_clock);
        cpu_wren <= 1'b0;
        @(posedge cpu_clock);
    endtask

    task init_ppu_address();
        ppu_addr1 <= `VRAM_START;
        ppu_addr2 <= `VRAM_START + 16'h1;
    endtask


    task read_with_ppu_address(input logic[15:0] addr1, input logic[15:0] addr2);
        ppu_addr1 <= addr1;
        ppu_addr2 <= addr2;
        @(posedge cpu_clock);
    endtask    

    task set_ppu_mode(input logic[1:0] new_mode);
        ppu_mode <= new_mode;
        @(posedge cpu_clock);
    endtask    


    /*
    even case: {8'd0, IO_data}
    odd case: {IO_data, 8'd0}
    */
    task write_IO(input logic [15:0] IO_address, input logic [7:0] IO_data);
        $display("writing to io %h...\n", IO_address);

        if(IO_address[0] == 1'b0) begin
            // cpu_addr <= IO_address;
            // cpu_wren <= 1'b1;
            // cpu_in_data <= {IO_data, 8'd0};    
            // @(posedge cpu_clock);            
            do_cpu_write(IO_address, {8'd0, IO_data});
        end else begin
            // cpu_addr <= IO_address;
            // cpu_wren <= 1'b1;
            // cpu_in_data <= {8'd0, IO_data};    
            // @(posedge cpu_clock);            
            do_cpu_write(IO_address, {IO_data, 8'd0});
        end
    endtask

    task dump_NR52(input logic[3:0] bits);
        APU_NR52 = bits;
    endtask


    task write_TAC(input logic enable, input logic[1:0] clock_select);    
        write_IO(`TAC, {5'b0, enable, clock_select});
    endtask


    task do_reset();
        reset <= 1'b1;
        init_ppu_address();
        dump_NR52(4'b0000);
        stop_inst_hit <= 1'b0;
        cpu_addr <= `ROM_0_START;
        @(posedge clock);
        @(posedge clock);
        reset <= 1'b0;
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);            
        @(posedge clock);    
    endtask


    task clock_cycles(int num_cycles);
        for(int i = 0; i < num_cycles; i++) begin
            @(posedge clock);
        end
    endtask


    initial begin
        clock = 1'b0;
        forever #5 clock = ~clock; 
    end

    logic odd;

    always_ff @(posedge clock) begin
        if(reset) begin
            cpu_clock <= 1'b0;
        end else begin
            cpu_clock <= ~cpu_clock;
        end
    end


    initial begin
        if ($test$plusargs("BASIC_BRAM")) begin
        $display({"\n",
                    "-----------------------------------------------------------\n",
                    " <Started> Basic Send/Recv Test\n",
                    "-----------------------------------------------------------",
                    "\n"});

            $display("---------STARTING WITH PPU MODE 0-----------------");

            for(int pmode = 0; pmode < 4; pmode++) begin


                
                do_reset();
                set_ppu_mode(pmode);
                //-----------ROM 0-------------
                for(int i = 0; i < 40; i++) begin
                    do_cpu_read(`ROM_0_START + i);
                end
                for(int i = 0; i < 20; i++) begin
                    do_cpu_read(`ROM_0_END - i);
                end        

                for(int i = 0; i < 10; i++) begin
                    do_cpu_read(`ROM_1_START + i);
                end
                for(int i = 0; i < 20; i++) begin
                    do_cpu_read(`ROM_1_END - i);
                end               

                //-----------VRAM-------------
                for(int i = 0; i < 10; i++) begin
                    do_cpu_write(`VRAM_START + i, 16'hDEAD + i);
                    do_cpu_read(`VRAM_START + i);
                end  
                for(int i = 0; i < 10; i++) begin
                    do_cpu_write(`VRAM_END - i, 16'hBEEF + i);
                    do_cpu_read(`VRAM_END - i);
                end   
                    
                //-----------EXRAM-------------
                for(int i = 0; i < 10; i++) begin
                    do_cpu_write(`EXRAM_START + i, 16'hAAAA + i);
                    do_cpu_read(`EXRAM_START + i);
                end  
                for(int i = 0; i < 10; i++) begin
                    do_cpu_write(`EXRAM_END - i, 16'hBBBB + i);
                    do_cpu_read(`EXRAM_END - i);
                end   
                    

                //-----------WRAM-------------
                for(int i = 0; i < 10; i++) begin
                    do_cpu_write(`WRAM_START + i, 16'hCCCC + i);
                    do_cpu_read(`WRAM_START + i);
                end  
                for(int i = 0; i < 10; i++) begin
                    do_cpu_write(`WRAM_END - i, 16'hDDDD + i);
                    do_cpu_read(`WRAM_END - i);
                end          


                //-----------OAM-------------
                for(int i = 0; i < 159; i++) begin
                    do_cpu_write(`OAM_START + i, 16'hEEEE + i);
                    do_cpu_read(`OAM_START + i);
                end  
                // for(int i = 0; i < 10; i++) begin
                //     do_cpu_write(`OAM_END - i, 16'hABAB + i);
                //     do_cpu_read(`OAM_END - i);
                // end    

                //-----------HRAM-------------
                for(int i = 0; i < 16; i++) begin
                    do_cpu_write(`HRAM_START + i, 16'hFEFE + i);
                    do_cpu_read(`HRAM_START + i);
                end                          
                            

                for(int i = 0; i < 20; i++) begin
                    read_with_ppu_address(`VRAM_START + i, `VRAM_END - i);
                end

                for(int i = 0; i < 159; i++) begin
                    read_with_ppu_address(`OAM_START + i, `OAM_START + i + 1);
                end                
                

                // for(int i = 0; i < 40; i++) begin
                //     do_cpu_write(`WRAM_START + i, 16'h0 + i);
                //     do_cpu_write(`EXRAM_START + i, 16'h10 + i);
                // end   
                // for(int i = 0; i < 40; i++) begin
                //     do_cpu_read(`WRAM_START + i);
                //     do_cpu_read(`EXRAM_START + i);
                // end      

                // for(int i = 0; i < 5; i++) begin
                //     do_cpu_write(`HRAM_START + i, 16'h20 + i);
                //     do_cpu_read(`HRAM_START + i);
                // end              

            end
        end
        else if ($test$plusargs("BASIC_TIMER")) begin

            set_ppu_mode(2'b00);
            do_reset();
            
            /**TIMER
                --> check divider register
                --> set timer modulo (tma) to each value, tima should reset to this when overflow
                --> set timer control (tac) to each value
                --> check that timer counter (tima) works
            **/

            for(int timer_clock_select = 0; timer_clock_select < 4; timer_clock_select++) begin
                do_cpu_read(`ROM_0_START);
                @(posedge cpu_clock);
                @(posedge cpu_clock);
                @(posedge cpu_clock);
                write_TAC(1'b1, timer_clock_select);
                @(posedge cpu_clock);
                $display("changing tac to %d \n", timer_clock_select);
                
                for(int timer_modulo = 5; timer_modulo < 30; timer_modulo+=10) begin
                    @(posedge cpu_clock);
                    write_IO(`TMA, timer_modulo);
                    @(posedge cpu_clock);
                    $display("changing tma to %d \n", timer_modulo);
                    clock_cycles(3000);
                    $display("finished clockc cylces, moving on\n");
                    @(posedge cpu_clock);
                end

                clock_cycles(4);
                write_IO(`DIV, 16'h1); //this should clear divider
                clock_cycles(20);
                do_cpu_read(`TAC);
                clock_cycles(4);
                do_cpu_read(`DIV);
                clock_cycles(4);
                do_cpu_read(`TIMA);
                clock_cycles(4);
                do_cpu_read(`TMA);
                clock_cycles(4);
                clock_cycles(5);
                write_IO(`IF, 8'b0);
                clock_cycles(15);


                do_reset();
            end
        end
            else if ($test$plusargs("BASIC_APU")) begin
                /**AUDIO
                --> provide NR52 with different values
                --> all nrxx read/writes
                **/
                do_reset();
                dump_NR52(4'b0000);
                write_IO(`NR52, 8'b1111_0000);

                write_IO(`NR10, 8'hAA); 
                write_IO(`NR11, 8'hAB); 
                write_IO(`NR12, 8'hAC); 
                write_IO(`NR13, 8'hAD); 
                write_IO(`NR14, 8'hAE); 

                write_IO(`NR21, 8'hBA); 
                write_IO(`NR22, 8'hBB); 
                write_IO(`NR23, 8'hBC); 
                write_IO(`NR24, 8'hBD); 

                write_IO(`NR30, 8'hCA); 
                write_IO(`NR31, 8'hCB); 
                write_IO(`NR32, 8'hCC); 
                write_IO(`NR33, 8'hCD); 
                write_IO(`NR34, 8'hCE); 

                write_IO(`NR41, 8'hDA); 
                write_IO(`NR42, 8'hDB); 
                write_IO(`NR43, 8'hDC); 
                write_IO(`NR44, 8'hDD); 

                for(int i = 0; i < 15; i++) begin
                    write_IO(`WAV_RAM_START + i, 8'hE0 + i);
                end

                write_IO(`NR50, 8'hFA); 
                write_IO(`NR51, 8'hFB); 
                write_IO(`NR52, 8'hFC);

                write_IO(`NR52, 8'd0);

                clock_cycles(30);  

                do_cpu_read(`NR52);

                do_cpu_read(`NR10); 
                do_cpu_read(`NR11); 
                do_cpu_read(`NR12); 
                do_cpu_read(`NR13); 
                do_cpu_read(`NR14); 

                do_cpu_read(`NR21); 
                do_cpu_read(`NR22); 
                do_cpu_read(`NR23); 
                do_cpu_read(`NR24); 

                do_cpu_read(`NR30); 
                do_cpu_read(`NR31); 
                do_cpu_read(`NR32); 
                do_cpu_read(`NR33); 
                do_cpu_read(`NR34); 

                do_cpu_read(`NR41); 
                do_cpu_read(`NR42); 
                do_cpu_read(`NR43); 
                do_cpu_read(`NR44); 

                for(int i = 0; i < 15; i++) begin
                    do_cpu_read(`WAV_RAM_START+i);
                end

                do_cpu_read(`NR50); 
                do_cpu_read(`NR51); 
                do_cpu_read(`NR52);
            end
            else if($test$plusargs("BASIC_PPU")) begin
                /**PPU
                    --> LCDC
                    --> check if STAT makes sense
                    --> all ppu read/writes
                **/

                do_reset();
                for(int i = 0; i < 4; i++) begin
                    set_ppu_mode(i);
                    write_IO(`LCDC, 8'hAA);
                    write_IO(`STAT, 8'hAB); //this should do nothing
                    write_IO(`SCY,  8'hAC); 
                    write_IO(`SCX,  8'hAD); 
                    write_IO(`LY,   8'hAE);  
                    write_IO(`LYC,  8'hAF); 
                    // write_IO(`DMA, 8'hAB); 
                    write_IO(`BGP,  8'hBA); 
                    write_IO(`OBP0, 8'hBB);
                    write_IO(`OBP1, 8'hBC);
                    write_IO(`WY,   8'hBD);  
                    write_IO(`WX,   8'hBE);
                    clock_cycles(10);  

                    write_IO(`LY,   8'hFE);  
                    write_IO(`LYC,  8'hFE); 

                    clock_cycles(5);
                    write_IO(`LYC,  8'hFF); 

                    write_IO(`IF, 8'd0);

                    clock_cycles(30); 
                    
                    do_cpu_read(`LCDC);
                    do_cpu_read(`STAT);
                    do_cpu_read(`SCY); 
                    do_cpu_read(`SCX); 
                    do_cpu_read(`LY);  
                    do_cpu_read(`LYC); 
                    // do_cpu_read(`DMA); 
                    do_cpu_read(`BGP); 
                    do_cpu_read(`OBP0);
                    do_cpu_read(`OBP1);
                    do_cpu_read(`WY);  
                    do_cpu_read(`WX); 



                end
            




            
            
            /**JOYPAD
                --> should give masked bits on right signal
            **/

            /**IF
                --> set bits if vblank, lcdc (stat), timer, joypad happen
                --> clear once cpu requests clear **/
            /**IE
                --> just an enable the cpu writes to**/

            /**SERIAL transfer 
                --> should do nothing**/

            /*DMA (later)*/

            $finish;

        end else begin
            $display("No test selected.");
            #100
            $finish;
        end
        $finish;
    end



endmodule