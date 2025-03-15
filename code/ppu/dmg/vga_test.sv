`timescale 1ns/1ps
`default_nettype none

module top_de2_115 (
  input  logic         CLOCK_50,
  input  logic [3:0]   KEY,
  output logic [3:0]   VGA_R,
  output logic [3:0]   VGA_G,
  output logic [3:0]   VGA_B,
  output logic         VGA_HS,
  output logic         VGA_VS,
  output logic [7:0]   LED
);
  logic reset;
  assign reset = ~KEY[0];

  logic [23:0] vga_color;
  logic hsync, vsync;

  vga_test vga_inst (
    .clk(CLOCK_50),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .vga_color(vga_color)
  );

  assign VGA_HS = hsync;
  assign VGA_VS = vsync;
  assign VGA_R = vga_color[23:20];
  assign VGA_G = vga_color[15:12];
  assign VGA_B = vga_color[7:4];
  assign LED = {hsync, vsync, 6'b0};
endmodule

module vga_test (
  input  logic clk,
  input  logic reset,
  output logic hsync,
  output logic vsync,
  output logic [23:0] vga_color
);
  localparam int H_ACTIVE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48;
  localparam int H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
  localparam int V_ACTIVE = 480, V_FRONT = 10, V_SYNC = 2, V_BACK = 33;
  localparam int V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;
  
  logic [9:0] h_count, v_count;
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      h_count <= 0;
      v_count <= 0;
    end else begin
      if (h_count == H_TOTAL - 1) begin
        h_count <= 0;
        if (v_count == V_TOTAL - 1)
          v_count <= 0;
        else
          v_count <= v_count + 1;
      end else begin
        h_count <= h_count + 1;
      end
    end
  end
  
  assign hsync = ~((h_count >= (H_ACTIVE + H_FRONT)) && (h_count < (H_ACTIVE + H_FRONT + H_SYNC)));
  assign vsync = ~((v_count >= (V_ACTIVE + V_FRONT)) && (v_count < (V_ACTIVE + V_FRONT + V_SYNC)));
  
  assign vga_color = (v_count < V_ACTIVE/2) ? 24'hFFFFFF : 24'h000000;
endmodule
