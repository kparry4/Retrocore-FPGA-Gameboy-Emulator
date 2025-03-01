module controllertop(
	output logic [8:0] LEDG,
	input logic [3:0] KEY
);
	assign LEDG[0] = KEY[0];
	assign LEDG[1] = KEY[1];
	assign LEDG[2] = KEY[2];
	assign LEDG[3] = KEY[3];

endmodule