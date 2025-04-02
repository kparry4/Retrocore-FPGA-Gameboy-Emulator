//`default_nettype none

module chipInterface(
    input logic CLOCK_50,
    input logic CLOCK2_50,
	input logic CLOCK3_50,
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
    assign unsync_reset = ~KEY[0];
    logic [7:0] LY;


    logic joypad_select;
    logic joypad_start;
    logic joypad_dpad_up;
    logic joypad_dpad_down;
    logic joypad_dpad_left;
    logic joypad_dpad_right;
    logic joypad_a_button;
    logic joypad_b_button;


    //outputs from gameboy
    logic [1:0] frame_pixel;
    logic frame_pixel_valid;


    //misc assigns
    assign LY = 8'd01;

    //chip interface assigns

//    assign VGA_R = 8'd1;
//    assign VGA_G = 8'd1;
//    assign VGA_B = 8'd1;
//
//    assign VGA_BLANK_N = 1'b1;
//    assign VGA_CLK = CLOCK_50;
//    assign VGA_SYNC_N = 1'b1;
//    assign VGA_VS = 1'b1;
//    assign VGA_HS = 1'b1;
//
    assign LEDR[7:0] = GPIO[7:0];
    assign LEDR[17:8] = '0;
    assign LEDG = frame_pixel_valid;



    always_ff @(posedge CLOCK3_50) begin
        rst <= unsync_reset;
    end

    logic HS, VS, blank;

    logic [8:0] row;
    logic [9:0] col;
    localparam WIDTH  = 160;
    localparam HEIGHT = 144;
    integer pixel_count;

    reg[1:0] frame_buffer [0:HEIGHT-1][0:WIDTH-1];
    integer r, c;

    // instantiate vga module
    vga v1(.CLOCK_50(CLOCK3_50), .row, .col, .HS(VGA_HS), .VS(VGA_VS), .blank, .reset());
    // Connect VGA active low signals
    assign VGA_BLANK_N = ~blank;
    assign VGA_SYNC_N = 1'b0;
    assign VGA_CLK = ~CLOCK3_50;

    assign VGA_R = vga_color[23:16];
    assign VGA_G = vga_color[15:8];
    assign VGA_B = vga_color[7:0];

    logic [23:0] vga_color;
    //assign vga_color = {VGA_R, VGA_G, VGA_B};
    //
    //
    always_comb begin
        if(row < 144 & col < 160) begin
            vga_color = frame_buffer[row][col];
        end else begin
            vga_color = 24'hFFF_FFF_FFF;
        end
    end

    /*
	 always_comb begin

         if(~GPIO[0]) begin
		    vga_color = {8'hEC, 8'hCB, 8'hD9};
	     end
	     else if(~GPIO[1]) begin
		    vga_color = {8'hE1, 8'hEF, 8'hF6};
	     end
	     else if(~GPIO[2]) begin
	 		vga_color = {8'h97, 8'hD2, 8'hFB};
	     end
	     else if(~GPIO[3]) begin
	 		vga_color = {8'h83, 8'hBC, 8'hFF};
	     end
	     else if(~GPIO[4]) begin
	 		vga_color = {8'h80, 8'hFF, 8'hE8};
	     end
	     else if(~GPIO[5]) begin
	 		vga_color = {8'hFF, 8'hC8, 8'hFB};
	     end
	     else if(~GPIO[6]) begin
	 		vga_color = {8'hFF, 8'h92, 8'hC2};
	     end
	     else if(~GPIO[7]) begin
	    	vga_color = {8'h88, 8'h84, 8'hFF};
	     end
	     else begin
		    vga_color = {8'hFF, 8'hEE, 8'hF2};
	     end
fdfdfff
     end
    */

    gameboy dut (.clk (CLOCK_50),
                 .clk2(CLOCK2_50),
                 .*);

 	SevenSegmentDisplayWithHex hi (
				.BCD7('0),
				.BCD6('0),
                .BCD5(vga_color[23:20]),
				.BCD4(vga_color[19:16]),
				.BCD3(vga_color[15:12]),
				.BCD2(vga_color[11:8]),
				.BCD1(vga_color[7:4]),
				.BCD0(vga_color[3:0]),
                .HEX7, .HEX6, .HEX5, .HEX4, .HEX3, .HEX2, .HEX1, .HEX0);

    always_ff @(posedge CLOCK2_50) begin
        if(rst) begin
            pixel_count <= 0;
            for(int i = 0; i < HEIGHT; i++) begin
                for(int j = 0; j < WIDTH; j++) begin
                    frame_buffer[i][j] <= '0;
                end
            end
        end else begin
            if(rst | pixel_count >= WIDTH*HEIGHT) begin
                pixel_count <= '0;
            end else if(frame_pixel_valid) begin
                r = pixel_count / WIDTH;
                c = pixel_count % WIDTH;
                if(r < HEIGHT) begin
                    frame_buffer[r][c] <= frame_pixel;
                    pixel_count <= pixel_count + 1;
                end
            end
        end
    end



endmodule: chipInterface
