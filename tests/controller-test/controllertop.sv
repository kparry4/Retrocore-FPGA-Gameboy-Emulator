module controllertop(
	output logic [8:0] LEDG,
	input logic [35:0] GPIO
);
	assign LEDG[0] = GPIO[0];
	assign LEDG[1] = GPIO[1];
	assign LEDG[2] = GPIO[2];
	assign LEDG[3] = GPIO[3];
	assign LEDG[4] = GPIO[4];
	assign LEDG[5] = GPIO[5];
	assign LEDG[6] = GPIO[6];
	assign LEDG[7] = GPIO[7];

endmodule