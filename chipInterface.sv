//`default_nettype none

module chipInterface(
    input logic CLOCK_50,
    input logic CLOCK_25,
    input logic [3:0] KEY,
    input logic [35:0] GPIO_INPUT,
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
	logic CPU_CLOCK;


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
    assign HEX0 = 7'h0;
    assign HEX1 = 7'h0;
    assign HEX2 = 7'h0;
    assign HEX3 = 7'h0;
    assign HEX4 = 7'h0;
    assign HEX5 = 7'h0;
    assign HEX6 = 7'h0;
    assign HEX7 = 7'h0;

    assign VGA_R = 8'd1;
    assign VGA_G = 8'd1;
    assign VGA_B = 8'd1;

    assign VGA_BLANK_N = 1'b1;
    assign VGA_CLK = CLOCK_50;
    assign VGA_SYNC_N = 1'b1;
    assign VGA_VS = 1'b1;
    assign VGA_HS = 1'b1;

    assign LEDR[7:0] = GPIO_INPUT[7:0];
    assign LEDR[17:8] = '0;
    assign LEDG = frame_pixel_valid;



    always_ff @(posedge CLOCK_50) begin
        rst <= unsync_reset;
    end

    gameboy dut (.clk (CLOCK_50),
                 .clk2(CLOCK_25),
                 .*);



endmodule: chipInterface
