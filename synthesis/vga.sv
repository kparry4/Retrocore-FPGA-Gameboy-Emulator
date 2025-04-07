`default_nettype none

module vga
(input logic CLOCK_50, reset,
output logic HS, VS, blank,
output logic [8:0] row,
output logic [9:0] col);

logic clear_hs_ct, clear_vs_ct, two_clocks, start_col, start_row;
 logic [10:0] hs_num_clk;
 logic [19:0] vs_num_clk;



 // counter to keep track of num clock period elapsed
 Counter #(11) hs_ct (.en(1'b1), .clear(reset), .load(clear_hs_ct), .D(11'd0),
 .up(1'b1), .clock(CLOCK_50), .Q(hs_num_clk));

 Counter #(20) vs_ct(.en(1'b1), .clear(reset), .load(clear_vs_ct), .D(20'd0),
 .up(1'b1), .clock(CLOCK_50), .Q(vs_num_clk));


 // Send clear signal to counter every sync pulse period
 MagComp #(11) HS_num_clock (.A(hs_num_clk), .B(11'd1599),
 .AeqB(clear_hs_ct));
 MagComp #(20) VS_num_clock (.A(vs_num_clk), .B(20'd833599),
 .AeqB(clear_vs_ct));

 // row counter
 // increment on each clear
 logic start_row_clr, start_col_clr, load_row, load_col;
 assign start_row_clr = ~start_row;
 assign start_col_clr = ~start_col;
 assign load_row = ~VS;
 assign load_col = ~HS;
 Counter #(9) row_ct(.en(clear_hs_ct), .clear(start_row_clr), .up(1'b1),
 .load(load_row), .D(9'd0), .clock(CLOCK_50), .Q(row));
 // col counter
 // increament every two clock
 Counter #(10) col_ct(.en(two_clocks), .clear(start_col_clr), .up(1'b1),
 .load(load_col), .D(10'd0), .clock(CLOCK_50), .Q(col));

 assign two_clocks = hs_num_clk[0];

 // HS/VS window check
 range_check #(11) hs_period(.val(hs_num_clk),
 .low(11'd192),
 .high(11'd1599),
 .is_between(HS));

 range_check #(20) vs_period(.val(vs_num_clk),
 .low(20'd3200),
 .high(20'd833599),
 .is_between(VS));

 // Tdisp window check
 range_check #(11) tdisphs_period(.val(hs_num_clk),
 .low(11'd288),
 .high(11'd1567),
 .is_between(start_col));

 range_check #(20) tdispvs_period(.val(vs_num_clk),
 .low(20'd49600),
 .high(20'd817599),
 .is_between(start_row));


 assign blank = ~(start_col & start_row);

 endmodule: vga

// check if low <= val <= high
module range_check
#(parameter WIDTH = 8)
(input logic [WIDTH-1:0] val, low, high,
output logic is_between);

assign is_between = (val <= high) & (val >= low);

endmodule: range_check

// check if low <= val <= low + delta
module offset_check
#(parameter WIDTH = 8)
(input logic [WIDTH-1:0] val, low, delta,
output logic is_between);

assign is_between = (val >= low) & (val <= low + delta);

endmodule: offset_check

// Counter with two direction of counting
// clear > load > enable > counting

module MagComp
#(parameter WIDTH = 8)
(input logic [WIDTH-1:0] A, B,
output logic AltB, AeqB, AgtB);

assign AltB = (A < B);
assign AeqB = (A == B);
assign AgtB = (A > B);

endmodule: MagComp
