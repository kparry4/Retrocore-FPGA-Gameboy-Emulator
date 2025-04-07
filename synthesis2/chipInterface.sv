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
	input logic CLOCK3_50, //50 Mhz
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

    logic [8:0] vga_row;
    logic [9:0] vga_col;
    integer pixel_count;

    integer r, c;


    vga v1(.CLOCK_50(CLOCK3_50), .row(vga_row), .col(vga_col), .HS(VGA_HS), .VS(VGA_VS), .blank, .reset());
    // Connect VGA active low signals
    assign VGA_BLANK_N = ~blank;
    assign VGA_SYNC_N = 1'b0;
    assign VGA_CLK = ~CLOCK3_50;

    assign VGA_R = vga_color[23:16];
    assign VGA_G = vga_color[15:8];
    assign VGA_B = vga_color[7:0];

    logic [23:0] vga_color, vga_color_pixel;
    logic [15:0] frame_buffer_pixel; //NOTE THAT THIS IS 2 BITS WIDE ACTUALLY BC NO COLOUR
	
	 assign r = pixel_count / `WIDTH;
    assign c = pixel_count % `WIDTH;

    always_comb begin
        if(vga_row < `HEIGHT & vga_col  < `WIDTH) begin
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




    gameboy dut (.clk (CLOCK_50), //8Mhz
                .clk2(CLOCK2_50), //4Mhz
                .*);


     FRAME_BUFFER frame ( .rdaddress( GET_FRAME_ADDR(vga_row, vga_col) ),
                         .rdclock(CLOCK3_50), //50 Mhz
                         .q(frame_buffer_pixel),
                         .wraddress( GET_FRAME_ADDR(r, c) ),
                         .wrclock(CLOCK2_50), //4 Mhz
                         .wren(frame_pixel_valid),
                         .data(frame_pixel));

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
        end else begin
            if(rst | pixel_count >= `WIDTH*`HEIGHT) begin
                pixel_count <= '0;
            end else if(frame_pixel_valid) begin
                if(r < `HEIGHT) begin
                    pixel_count <= pixel_count + 1;
                end
            end
        end
    end



endmodule: chipInterface
