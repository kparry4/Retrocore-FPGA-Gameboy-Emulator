//`default_nettype none
//
`define WIDTH 160
`define HEIGHT 144
`define GET_FRAME_ADDR(row, col) (`WIDTH*row + col)

 function logic[15:0] GET_FRAME_ADDR(input logic[15:0] row, input logic[15:0] col);
	  return `WIDTH*row + col;
 endfunction

module chipInterface(
    input logic CLOCK_50, //8Mhz
    input logic CLOCK2_50, //4Mhz
	input logic CLOCK3_50, //gameboy:dut|50 Mhz
    input logic [3:0] KEY,
    input logic [35:0] GPIO,
    input logic [17:0] SW,
    output logic [17:0]LEDR,
    output logic [8:0] LEDG,
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3,
    HEX4, HEX5, HEX6, HEX7,
    output logic [7:0] VGA_R, VGA_G, VGA_B,
    output logic VGA_BLANK_N, VGA_CLK, VGA_SYNC_N,
    output logic VGA_VS, VGA_HS);

    //inputs into gameboy
    logic rst, unsync_reset;
	 logic unsync_key;//clk_key, unsync_key;
	 logic vga_clock;
    assign unsync_reset = ~KEY[2] || SW[0];
	 assign unsync_key = ~KEY[3] || SW[1];
	 
	 logic [31:0] instr_counter, time_ticks;
	 logic stop_collecting;
	 
	 localparam integer clock_freq = 8_000_000;
    localparam integer DIV_TICK_COUNT = clock_freq/1024; // (an 256hz clock)


    logic joypad_select;
    logic joypad_start;
    logic joypad_dpad_up;
    logic joypad_dpad_down;
    logic joypad_dpad_left;
    logic joypad_dpad_right;
    logic joypad_a_button;
    logic joypad_b_button;
	 
	 assign joypad_select =     ~GPIO[3];
	 assign joypad_start =      ~GPIO[4];
	 assign joypad_dpad_up =    ~GPIO[1];
	 assign joypad_dpad_down =  ~GPIO[5];
	 assign joypad_dpad_left =  ~GPIO[2];
	 assign joypad_dpad_right = ~GPIO[0];
	 assign joypad_a_button =   ~GPIO[6];
	 assign joypad_b_button =   ~GPIO[7];


    //outputs from gameboy
    logic [1:0] frame_pixel;
    logic frame_pixel_valid;
	 logic[7:0] LCDC_R;
	 logic[7:0] ppu_LY;
	 logic [15:0] pc, npc;
	 logic [1:0] ppu_mode;
	 logic vga_wren;
	 logic done;


    assign LEDR[7:0] = GPIO[7:0];
    assign LEDR[16:8] = '0;
    assign LEDG[0] = frame_pixel_valid;
	 assign LEDG[1] = rst;
	 assign LEDG[2] = stop_collecting;
	 assign LEDG[8:3] = '0;
	 assign LEDR[17] = rst;

	 assign vga_clock = CLOCK3_50;

    always_ff @(posedge CLOCK3_50) begin
        rst <= unsync_reset;
		  //clk_key <= unsync_key;
		  if(rst) begin
			stop_collecting <= 1'b0;
		  end else begin
			if(instr_counter > 32'd10_000) begin //614440 FOR DR MARIO FRAME
				stop_collecting <= 1'b1;
			end else begin
				stop_collecting <= stop_collecting;
			end
		  
		  end
    end

    logic HS, VS, blank;

    logic [8:0] vga_row;
    logic [9:0] vga_col;
    integer pixel_count;

    integer r, c;


    logic [23:0] vga_color, vga_color_pixel;
    logic [15:0] frame_buffer_pixel; //NOTE THAT THIS IS 2 BITS WIDE ACTUALLY BC NO COLOUR

    vga #(20) v1(.CLOCK_50(vga_clock), .row(vga_row), .col(vga_col), .HS(VGA_HS), .VS(VGA_VS), .blank, .reset());
    // Connect VGA active low signals
    assign VGA_BLANK_N = ~blank;
    assign VGA_SYNC_N = 1'b0;
    assign VGA_CLK = ~vga_clock;

    assign VGA_R = vga_color[23:16];
    assign VGA_G = vga_color[15:8];
    assign VGA_B = vga_color[7:0];

	 assign r = pixel_count / `WIDTH;
    assign c = pixel_count % `WIDTH;

    always_comb begin
        if(vga_row < `HEIGHT*3 & vga_col  < `WIDTH*3) begin
            vga_color = vga_color_pixel;
        end else begin
            vga_color = 24'hFF_00_00;
        end
	 end


	  always_comb begin
       case (frame_buffer_pixel)
              2'b11: vga_color_pixel = {8'd0,8'd0,8'd0};
              2'b10: vga_color_pixel = {8'd85,8'd85,8'd85};
              2'b01: vga_color_pixel = {8'd170,8'd170,8'd170};
              2'b00: vga_color_pixel = {8'd255,8'd255,8'd255};
				  default: vga_color_pixel = 24'h00_FF_00;
        endcase
    end

	 logic ppu_clk=0;
	 logic fake_clock=0;
	 logic ppu_fake_clk=0;

	  always_ff @(posedge CLOCK_50) begin
		 ppu_clk <= ~ppu_clk;
		 
		 if(time_ticks == DIV_TICK_COUNT - 1) begin
			  time_ticks <= '0;
			  fake_clock <= ~fake_clock;
		 end else begin
			  time_ticks <= time_ticks + 1;
			  fake_clock <= fake_clock;
		 end
	 end
		 
		 
		always_ff @(posedge fake_clock) begin
			ppu_fake_clk <= ~ppu_fake_clk;
		end
 
	  
	  
	/*
						 .joypad_select(joypad_select),
					 .joypad_start(joypad_start),
					 .joypad_dpad_up(joypad_dpad_up),
					 .joypad_dpad_down(joypad_dpad_down),
					 .joypad_dpad_left(joypad_dpad_left),
					 .joypad_dpad_right(joypad_dpad_right),
					 .joypad_a_button(joypad_a_button),
					 .joypad_b_button(joypad_b_button),
	*/
    gameboy dut (.clk (CLOCK_50), //8Mhz
                .clk2(ppu_clk), //4Mhz
					 .rst,
					 .joypad_select,
					 .joypad_start,
					 .joypad_dpad_up,
					 .joypad_dpad_down,
					 .joypad_dpad_left,
					 .joypad_dpad_right,
					 .joypad_a_button,
					 .joypad_b_button,
					 .frame_pixel,
					 .frame_pixel_valid,
					 .LCDC_R,
					 .ppu_mode,
			 		 .done,
					 .instr_counter,
					 .pc,
					 .ppu_LY);


     FRAME_BUFFER frame ( .rdaddress( GET_FRAME_ADDR(vga_row / 3, vga_col / 3) ),
                         .rdclock(CLOCK3_50), //50 Mhz
                         .q(frame_buffer_pixel),

                         .wraddress( GET_FRAME_ADDR(r, c) ),
                         .wrclock(ppu_clk), //4 Mhz
                         .wren(vga_wren),
                         .data(frame_pixel));

    SevenSegmentDisplayWithHex hi (
            .BCD7(4'b0),
            .BCD6(4'b0),
            .BCD5(ppu_LY[7:4]),
            .BCD4(ppu_LY[3:0]),
				
            .BCD3(pc[15:12]),
            .BCD2(pc[11:8]),
            .BCD1(pc[7:4]),
            .BCD0(pc[3:0]),
            .HEX7, .HEX6, .HEX5, .HEX4, .HEX3, .HEX2, .HEX1, .HEX0);

    always_ff @(posedge ppu_clk) begin
        if(rst) begin
            pixel_count <= 0;
				vga_wren <= '0;
        end else begin
            if(rst | pixel_count >= `WIDTH*`HEIGHT | ~LCDC_R[7] | ppu_mode==2'b1) begin
                pixel_count <= '0;
					 vga_wren <= '0;
            end else if(frame_pixel_valid) begin
                if(r < `HEIGHT) begin
                    pixel_count <= pixel_count + 1;
						  vga_wren <= '1;
                end else begin
						  vga_wren <= '0;
					 end
            end
        end
    end



endmodule: chipInterface

