`timescale 1ns/1ps
`default_nettype none 

////////////////////////////////////////////////////////////////////////////////
//   I2C Format:
//   START   |  ADDRESS+R/W  |  ACK  |  DATA BYTE  |  ACK  | ... |  STOP
////////////////////////////////////////////////////////////////////////////////

/*
        Left Line In                        000_0000_0_1001_0111
        Right Line In                       000_0001_0_1001_0111        
        Left Headphone Out                  000_0010_0_0111_1001
        Right Headphone Out                 000_0011_0_0111_1001
        Analogue Audio Path Control         000_0100_0_0001_0101
        Digital Audio Path Control          000_0101_0_0000_0000
        Power Down Control                  000_0110_0_0000_0000
        Digital Audio Interface Format      000_0111_0_0100_0010
        Sampling Control                    000_1000_0_0001_1001
        Active Control                      000_1001_0_0000_0001
*/


////////////////////////////////////////////////////////////////////////////////
// Updated I2C Master Design
// - This version adds a clock divider (I2C_DIV) so that SCL/SDA transitions 
//   occur at a controlled (slower) rate.
// - The FSM now only updates when a “tick” occurs (i.e. when the delay counter 
//   has reached its terminal count).
// - Duplicate copies have been removed so that only one complete design is shown.
////////////////////////////////////////////////////////////////////////////////

module sound_check_top (
    input  logic CLOCK_50,
    input  logic [3:0] KEY,
    output logic [17:0] LEDR,
    output logic I2C_SCLK,
    inout  wire  I2C_SDAT
);
    wire config_done_internal;
    assign LEDR[0] = ~config_done_internal;
    
    wm8731_configurator u_config (
        .clk(CLOCK_50),
        .rst_n(~KEY[0]),
        .config_done(config_done_internal),
        .i2c_scl(I2C_SCLK),
        .i2c_sda(I2C_SDAT)
    );
endmodule

////////////////////////////////////////////////////////////////////////////////
// WM8731 Configurator
// Drives a sequence of 11 commands (including a reset) to configure the WM8731.
////////////////////////////////////////////////////////////////////////////////
module wm8731_configurator (
    input  logic        clk,
    input  logic        rst_n,
    output logic        config_done,
    output logic        i2c_scl,
    inout  wire         i2c_sda
);

    localparam int NUM_REGISTERS = 11;

    // Register Command Definitions (WM8731 register map)
    localparam logic [15:0] REG_RESET              = 16'h1E00; // Reset CODEC
    localparam logic [15:0] REG_LEFT_LINE_IN       = 16'h0017; // Left line in: 0dB, no mute
    localparam logic [15:0] REG_RIGHT_LINE_IN      = 16'h0217; // Right line in: 0dB, no mute
    localparam logic [15:0] REG_LEFT_HP_OUT        = 16'h0497; // Left headphone out
    localparam logic [15:0] REG_RIGHT_HP_OUT       = 16'h0697; // Right headphone out
    localparam logic [15:0] REG_ANALOG_AUDIO_PATH  = 16'h0800; // Analog audio path control
    localparam logic [15:0] REG_DIGITAL_AUDIO_PATH = 16'h0A00; // Digital audio path control
    localparam logic [15:0] REG_POWER_DOWN         = 16'h0C00; // Power down control (all on)
    localparam logic [15:0] REG_DIGITAL_AUDIO_IF   = 16'h0E51; // Digital audio interface format
    localparam logic [15:0] REG_SAMPLING_CTRL      = 16'h0100; // Sampling control
    localparam logic [15:0] REG_ACTIVE_CTRL        = 16'h1201; // Activate interface

    localparam logic [7:0] I2C_ADDR                = 8'h34;    // I2C address

    // Internal signals
    logic [3:0]  reg_index;      // We need 4 bits to index 11 registers (0–10)
    logic [15:0] command_word;
    logic        transfer_enable;
    logic        transfer_done;

    // State machine for sequencing the I2C transactions.
    typedef enum logic [1:0] {
        S_IDLE,
        S_START,
        S_WAIT_DONE,
        S_FINISH
    } state_t;
    state_t state;

    // Instantiate the I2C master.
    // The 24‐bit data is formed by concatenating the 8‐bit I2C address with the 16–bit command word.
    i2c_master #(.I2C_DIV(100)) u_i2c (
        .clk(clk),
        .rst_n(rst_n),
        .enable(transfer_enable),
        .data({I2C_ADDR, command_word}),
        .done(transfer_done),
        .scl(i2c_scl),
        .sda(i2c_sda)
    );
    
    // Update the command word at the end of each transaction.
    // On reset the first command is REG_RESET.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            command_word <= REG_RESET;
        else if (transfer_done) begin
            case (reg_index)
                4'd0:  command_word <= REG_RESET;
                4'd1:  command_word <= REG_LEFT_LINE_IN;
                4'd2:  command_word <= REG_RIGHT_LINE_IN;
                4'd3:  command_word <= REG_LEFT_HP_OUT;
                4'd4:  command_word <= REG_RIGHT_HP_OUT;
                4'd5:  command_word <= REG_ANALOG_AUDIO_PATH;
                4'd6:  command_word <= REG_DIGITAL_AUDIO_PATH;
                4'd7:  command_word <= REG_POWER_DOWN;
                4'd8:  command_word <= REG_DIGITAL_AUDIO_IF;
                4'd9:  command_word <= REG_SAMPLING_CTRL;
                4'd10: command_word <= REG_ACTIVE_CTRL;
                default: command_word <= REG_RESET;
            endcase
        end
    end

    // State machine to pulse the I2C master enable and step through the register commands.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= S_IDLE;
            reg_index        <= 4'd0;
            transfer_enable  <= 1'b0;
            config_done      <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    transfer_enable <= 1'b1; // Pulse enable to start a transaction
                    state <= S_START;
                end
                S_START: begin
                    transfer_enable <= 1'b0; // Disable enable (the I2C master samples the enable edge)
                    state <= S_WAIT_DONE;
                end
                S_WAIT_DONE: begin
                    if (transfer_done) begin
                        if (reg_index == NUM_REGISTERS - 1) begin
                            config_done <= 1'b1;
                            state <= S_FINISH;
                        end else begin
                            reg_index <= reg_index + 1;
                            state <= S_IDLE;
                        end
                    end
                end
                S_FINISH: begin
                    config_done <= 1'b1; // Remain done once finished.
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

////////////////////////////////////////////////////////////////////////////////
// I2C Master 
// This module implements a bit‐banged I2C transaction following the code logic
// provided. It shifts out 24–bit data (8–bit address + 16–bit command) and
// then reads three ACK bits. Timing is controlled by a divider parameter.
////////////////////////////////////////////////////////////////////////////////
module i2c_master #(
    parameter I2C_DIV = 100
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic [23:0] data,   // 24-bit data: 8-bit address concatenated with 16-bit command word
    output logic        done,
    output logic        scl,
    inout  wire         sda
);

    // Internal registers and signals.
    reg [23:0] data_reg;
    logic [4:0] current_bit_index;
    logic [6:0] sclk_divider;
    logic       clock_en;
    // Internal register to control the SDA line.
    reg         sda_reg;  
    logic [2:0] acks;
    
    // Compute mid-clock count (here we take half the divider)
    localparam integer MIDLOW_COUNT = (I2C_DIV >> 1) - 1;
    wire midlow = (sclk_divider == MIDLOW_COUNT);

    // I2C master state machine (using enable as a start pulse)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_divider     <= 7'd0;
            current_bit_index<= 5'd29;  
            clock_en         <= 1'b0;
            sda_reg          <= 1'b1;         // Release SDA (assume external pull-up)
            acks             <= 3'b111;
            data_reg         <= 24'd0;
        end else begin
            if (enable) begin
                // On the rising edge of enable, load new data and start the transaction.
                sclk_divider     <= 7'd0;
                current_bit_index<= 5'd0;
                clock_en         <= 1'b0;
                sda_reg          <= 1'b1;
                acks             <= 3'b111;
                data_reg         <= data;
            end else begin
                if (sclk_divider == I2C_DIV - 1) begin
                    sclk_divider <= 7'd0;
                    if (current_bit_index != 5'd29)
                        current_bit_index <= current_bit_index + 1;
                    // Sample ACK bits at the appropriate bit indices.
                    case (current_bit_index)
                        5'd0:  clock_en <= 1'b1;
                        5'd9:  acks[0] <= sda;  // Sample the physical SDA value here.
                        5'd18: acks[1] <= sda;
                        5'd27: acks[2] <= sda;
                        5'd28: clock_en <= 1'b0;
                        default: ;
                    endcase
                end else begin
                    sclk_divider <= sclk_divider + 1;
                end
                
                if (midlow) begin
                    // Drive SDA according to the current_bit_index.
                    case (current_bit_index)
                        5'd0:  sda_reg <= 1'b0;            // START condition: pull SDA low.
                        5'd1:  sda_reg <= data_reg[23];
                        5'd2:  sda_reg <= data_reg[22];
                        5'd3:  sda_reg <= data_reg[21];
                        5'd4:  sda_reg <= data_reg[20];
                        5'd5:  sda_reg <= data_reg[19];
                        5'd6:  sda_reg <= data_reg[18];
                        5'd7:  sda_reg <= data_reg[17];
                        5'd8:  sda_reg <= data_reg[16];
                        5'd9:  sda_reg <= 1'b1;            // Release SDA for ACK.
                        5'd10: sda_reg <= data_reg[15];
                        5'd11: sda_reg <= data_reg[14];
                        5'd12: sda_reg <= data_reg[13];
                        5'd13: sda_reg <= data_reg[12];
                        5'd14: sda_reg <= data_reg[11];
                        5'd15: sda_reg <= data_reg[10];
                        5'd16: sda_reg <= data_reg[9];
                        5'd17: sda_reg <= data_reg[8];
                        5'd18: sda_reg <= 1'b1;            // Release SDA for ACK.
                        5'd19: sda_reg <= data_reg[7];
                        5'd20: sda_reg <= data_reg[6];
                        5'd21: sda_reg <= data_reg[5];
                        5'd22: sda_reg <= data_reg[4];
                        5'd23: sda_reg <= data_reg[3];
                        5'd24: sda_reg <= data_reg[2];
                        5'd25: sda_reg <= data_reg[1];
                        5'd26: sda_reg <= data_reg[0];
                        5'd27: sda_reg <= 1'b1;            // Release SDA for ACK.
                        5'd28: sda_reg <= 1'b0;            // STOP condition: pull SDA low.
                        5'd29: sda_reg <= 1'b1;            // Release SDA.
                        default: sda_reg <= 1'b1;
                    endcase
                end
            end
        end
    end

    // Generate the I2C clock.
    assign scl = (!clock_en) || sclk_divider[6];
    // When sda_reg is 1, release SDA (drive high impedance 1'bz); when 0, drive it low.
    assign sda = (sda_reg) ? 1'bz : 1'b0;
    // The transaction is done when current_bit_index reaches 5'd29.
    assign done = (current_bit_index == 5'd29);

endmodule

module tb_wm8731_configurator;

  // Clock and reset signals.
  logic clk;
  logic rst_n;

  // Outputs from the UUT.
  logic config_done;
  logic i2c_scl;
  wire i2c_sda; // inout port

  // Instantiate the wm8731_configurator module.
  wm8731_configurator uut (
    .clk(clk),
    .rst_n(rst_n),
    .config_done(config_done),
    .i2c_scl(i2c_scl),
    .i2c_sda(i2c_sda)
  );

  // Clock generation: 50MHz (20 ns period)
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  // Reset generation: hold reset low for 100 ns.
  initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
  end

  // Dump waveforms and finish simulation after a set time.
  initial begin
    wait (config_done);
    #200;
    $finish;
  end

  // Monitor key signals.
  initial begin
    $monitor("Time=%0t | rst_n=%b | config_done=%b | i2c_scl=%b | i2c_sda=%b", 
             $time, rst_n, config_done, i2c_scl, i2c_sda);
  end

endmodule
