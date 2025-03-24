module ChipInterfaceVGA
    (input logic CLOCK_50,
    input logic [3:0] KEY,
    input logic [17:0] SW,
    output logic [17:0]LEDR,
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3,
    HEX4, HEX5, HEX6, HEX7,
    output logic [7:0] VGA_R, VGA_G, VGA_B,
    output logic VGA_BLANK_N, VGA_CLK, VGA_SYNC_N,
    output logic VGA_VS, VGA_HS);
    
   
    logic HS, VS, blank, reset, reset_sync, reset_sync1;
    assign reset = ~KEY[0];
    assign LEDR = {'0, VGA_R};
    always_ff @(posedge CLOCK_50) begin
        reset_sync <= reset;
        reset_sync1 <= reset_sync;
    end

    logic [8:0] row;
    logic [9:0] col;

    // instantiate vga module
    vga v1(.CLOCK_50, .row, .col, .HS(VGA_HS), .VS(VGA_VS), .blank, .reset());
    // Connect VGA active low signals
    assign VGA_BLANK_N = ~blank;
    assign VGA_SYNC_N = 1'b0;
    assign VGA_CLK = ~CLOCK_50;

    assign VGA_R = 8'h00;
    assign VGA_G = 8'hFF;
    assign VGA_B = 8'h00;

    logic [23:0] vga_color;
    assign vga_color = {VGA_R, VGA_G, VGA_B};


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

endmodule: ChipInterfaceVGA
