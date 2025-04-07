`default_nettype none

// Given 8 binary represented hex, output 8 corresponding 
// display vector for LED
module SevenSegmentDisplayWithHex

  (input logic [3:0] BCD7, BCD6, BCD5, BCD4, BCD3, BCD2, BCD1, BCD0,
   output logic [6:0] HEX7, HEX6, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0);

  logic [6:0] num0, num1, num2, num3, num4, num5, num6, num7;

  BCDtoSevenSegment g1(.segment(num0), .BCD(BCD0));
  BCDtoSevenSegment g2(.segment(num1), .BCD(BCD1));
  BCDtoSevenSegment g3(.segment(num2), .BCD(BCD2));
  BCDtoSevenSegment g4(.segment(num3), .BCD(BCD3));
  BCDtoSevenSegment g5(.segment(num4), .BCD(BCD4));
  BCDtoSevenSegment g6(.segment(num5), .BCD(BCD5));
  BCDtoSevenSegment g7(.segment(num6), .BCD(BCD6));
  BCDtoSevenSegment g8(.segment(num7), .BCD(BCD7));

  assign HEX0 = ~num0;
  assign HEX1 = ~num1;
  assign HEX2 = ~num2;
  assign HEX3 = ~num3;
  assign HEX4 = ~num4;
  assign HEX5 = ~num5;
  assign HEX6 = ~num6;
  assign HEX7 = ~num7;
 
endmodule: SevenSegmentDisplayWithHex


// Convert binary code into the LED display vectors as hex values
module BCDtoSevenSegment
  (input logic [3:0] BCD,
  output logic [6:0] segment);

  always_comb
    case(BCD)
      4'b0000: segment = 7'b011_1111;
      4'b0001: segment = 7'b000_0110;    
      4'b0010: segment = 7'b101_1011;
      4'b0011: segment = 7'b100_1111;
      4'b0100: segment = 7'b110_0110;
      4'b0101: segment = 7'b110_1101;
      4'b0110: segment = 7'b111_1101;
      4'b0111: segment = 7'b000_0111;
      4'b1000: segment = 7'b111_1111;
      4'b1001: segment = 7'b110_1111;
      4'ha: segment = 7'b111_0111;
      4'hb: segment = 7'b111_1100;
      4'hc: segment = 7'b011_1001;
      4'hd: segment = 7'b101_1110;
      4'he: segment = 7'b111_1001;
      4'hf: segment = 7'b111_0001;
    endcase


endmodule: BCDtoSevenSegment
