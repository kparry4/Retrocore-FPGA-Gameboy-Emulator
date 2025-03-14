`timescale 1ns/1ps
//---------------------------------------------------------------------
// Top-level module: AudioCodecSystem
//---------------------------------------------------------------------
module AudioCodecSystem(
    input  logic         CLOCK_50,      // 50 MHz system clock
    input  logic [1:0]   BTN,           // BTN[0]: Reset; BTN[1]: (unused or user-defined)
    input  logic         AUD_BCLK,      // Bit clock from the codec
    input  logic         AUD_LRCLK,     // Left/Right clock (for ADC/DAC)
    input  logic         AUD_ADCDAT,    // Serial ADC data from the codec

    output logic         AUD_XCK,       // Codec master clock output
    output logic         I2C_SCLK,      // I2C clock output for codec configuration
    output logic [7:0]   GPIO,          // Debug/general-purpose outputs
    output logic [1:0]   LEDG,          // LED indicators (e.g., one shows configuration complete)

    inout  logic         I2C_SDAT       // Bidirectional I2C data line
);

    // Generate auxiliary clocks using a PLL (ClockGenerator)
    logic aux_clk;
    ClockGenerator clk_pll (
        .inclk0(CLOCK_50),
        .c0(AUD_XCK),
        .c1(aux_clk)
    );

    // Instantiate the codec configuration module (I2C based)
    CodecI2CConfig codec_config (
        .MCLK(aux_clk),
        .RESET(BTN[0]),
        .CONFIG_DONE(LEDG[0]),
        .SCL(I2C_SCLK),
        .SDA(I2C_SDAT)
    );

    // Instantiate the I2S interface module.
    // In this example the I2S_Interface passes through the serial audio signals
    // to debug outputs. In a complete design, you would convert between parallel
    // and serial formats.
    I2S_Interface i2s_if (
        .BCLK(AUD_BCLK),
        .LRCLK(AUD_LRCLK),
        .ADCDAT(AUD_ADCDAT),
        .debug(GPIO[3]),
        .d_BCLK(GPIO[0]),
        .d_LRCLK(GPIO[1]),
        .d_ADCDAT(GPIO[2])
    );

endmodule

//---------------------------------------------------------------------
// Clock Generator Module (formerly "pll")
//---------------------------------------------------------------------
module ClockGenerator (
    input  logic inclk0,
    output logic c0,  // e.g., Codec master clock (AUD_XCK)
    output logic c1   // Auxiliary clock (used for I2C configuration)
);
    // For simulation: pass through inclk0 for c0
    assign c0 = inclk0;

    // Simple divider for c1 (divide by 4 for example)
    logic [1:0] div;
    always_ff @(posedge inclk0) begin
       div <= div + 1;
    end
    assign c1 = div[1];
endmodule

//---------------------------------------------------------------------
// Codec I2C Configuration Module (formerly "WM8731")
// This module configures the WM8731 codec using an I2C write sequence.
//---------------------------------------------------------------------
module CodecI2CConfig (
    input  logic MCLK,      // Auxiliary clock (e.g., 12.5 MHz)
    input  logic RESET,     // Active-low reset
    output logic CONFIG_DONE, // High when configuration is complete
    output logic SCL,       // I2C clock output
    inout  logic SDA        // I2C data (bidirectional)
);
    // Define configuration states
    typedef enum logic [2:0] {
      CONFIG_RESET,
      CONFIG_LEFT_LINE_IN,
      CONFIG_RIGHT_LINE_IN,
      CONFIG_LEFT_HEAD_OUT,
      CONFIG_DONE_STATE
    } config_state_t;

    config_state_t state;
    logic           start_i2c;        // Signal to start an I2C transaction
    logic           transaction_done; // Indicates one transaction is finished
    logic [15:0]    config_value;     // The configuration value to send

    // Instantiate the I2C controller
    I2C_Controller i2c_ctrl (
       .clk(MCLK),
       .rst_n(RESET),
       .start(start_i2c),
       .slave_addr(7'b0011010), // WM8731 slave address
       .reg_addr(8'h00),        // For simplicity, reg_addr is fixed here
       .data_in(config_value[7:0]),
       .done(transaction_done),
       .ack_error(),
       .sda(SDA),
       .scl(SCL)
    );

    // Configuration ROM: assign register value for each state.
    always_comb begin
      case (state)
         CONFIG_RESET:         config_value = 16'h1E00; // Reset the codec
         CONFIG_LEFT_LINE_IN:  config_value = 16'h0017; // Left Line In configuration
         CONFIG_RIGHT_LINE_IN: config_value = 16'h0217; // Right Line In configuration
         CONFIG_LEFT_HEAD_OUT: config_value = 16'h0497; // Left Headphone Out configuration
         default:              config_value = 16'h0000;
      endcase
    end

    // Simple state machine for configuration
    always_ff @(posedge MCLK or negedge RESET) begin
       if (!RESET) begin
           state <= CONFIG_RESET;
           start_i2c <= 1'b0;
           CONFIG_DONE <= 1'b0;
       end else begin
           if (state != CONFIG_DONE_STATE) begin
               if (!start_i2c)
                   start_i2c <= 1'b1;  // Trigger the I2C transaction
               else if (transaction_done) begin
                   start_i2c <= 1'b0;
                   case (state)
                       CONFIG_RESET:         state <= CONFIG_LEFT_LINE_IN;
                       CONFIG_LEFT_LINE_IN:  state <= CONFIG_RIGHT_LINE_IN;
                       CONFIG_RIGHT_LINE_IN: state <= CONFIG_LEFT_HEAD_OUT;
                       CONFIG_LEFT_HEAD_OUT: state <= CONFIG_DONE_STATE;
                       default:              state <= CONFIG_DONE_STATE;
                   endcase
               end
           end else begin
              CONFIG_DONE <= 1'b1;
           end
       end
    end

endmodule

//---------------------------------------------------------------------
// I2C Controller Module (formerly "I2C_Master")
// Implements a simple write-only I2C transaction.
//---------------------------------------------------------------------
module I2C_Controller (
    input  logic         clk,        // System clock (e.g., MCLK)
    input  logic         rst_n,      // Active-low reset
    input  logic         start,      // Assert to start transaction
    input  logic [6:0]   slave_addr, // 7-bit slave address
    input  logic [7:0]   reg_addr,   // Register address (not used in this simple example)
    input  logic [7:0]   data_in,    // Data byte to write
    output logic         done,       // One-cycle pulse when transaction is finished
    output logic         ack_error,  // Assert if a NACK is detected
    inout  logic         sda,        // Bidirectional I2C data
    output logic         scl         // I2C clock
);

    // State machine definitions
    typedef enum logic [3:0] {
      IDLE,
      START_CONDITION,
      SEND_SLAVE,
      WAIT_ACK1,
      SEND_REG,
      WAIT_ACK2,
      SEND_DATA,
      WAIT_ACK3,
      STOP_CONDITION
    } state_t;
    state_t state, next_state;

    logic [3:0] bit_cnt;
    // Internal signals for SDA control (simulate open-drain)
    logic sda_out;
    logic sda_oe;  // When 1, drive SDA; otherwise, tri-state

    assign sda = sda_oe ? sda_out : 1'bz;

    // Simple SCL generator using a clock divider (adjust division as needed)
    logic [7:0] clk_div;
    always_ff @(posedge clk or negedge rst_n) begin
       if (!rst_n)
          clk_div <= 8'd0;
       else
          clk_div <= clk_div + 1;
    end
    assign scl = clk_div[7];

    // State machine for I2C transaction
    always_ff @(posedge clk or negedge rst_n) begin
       if (!rst_n) begin
          state   <= IDLE;
          bit_cnt <= 4'd0;
          done    <= 1'b0;
          ack_error <= 1'b0;
       end else begin
          state <= next_state;
          if (state == SEND_SLAVE || state == SEND_REG || state == SEND_DATA)
              bit_cnt <= bit_cnt + 1;
          else
              bit_cnt <= 4'd0;
       end
    end

    always_comb begin
        next_state = state;
        sda_out = 1'b1;
        sda_oe  = 1'b0;
        done    = 1'b0;
        ack_error = 1'b0;

        case (state)
            IDLE: begin
                if (start)
                    next_state = START_CONDITION;
            end
            START_CONDITION: begin
                // Generate start condition: while SCL is high, pull SDA low.
                sda_oe  = 1'b1;
                sda_out = 1'b0;
                if (bit_cnt == 4'd0)
                    next_state = SEND_SLAVE;
            end
            SEND_SLAVE: begin
                sda_oe  = 1'b1;
                // Send 7-bit slave address (MSB first) then write bit (0)
                if (bit_cnt < 4'd7)
                    sda_out = slave_addr[6 - bit_cnt];
                else
                    sda_out = 1'b0; // Write bit = 0
                if (bit_cnt == 4'd7)
                    next_state = WAIT_ACK1;
            end
            WAIT_ACK1: begin
                sda_oe = 1'b0; // Release SDA for ACK from slave
                next_state = SEND_REG;
            end
            SEND_REG: begin
                sda_oe = 1'b1;
                sda_out = reg_addr[7 - bit_cnt];
                if (bit_cnt == 4'd7)
                    next_state = WAIT_ACK2;
            end
            WAIT_ACK2: begin
                sda_oe = 1'b0;
                next_state = SEND_DATA;
            end
            SEND_DATA: begin
                sda_oe = 1'b1;
                sda_out = data_in[7 - bit_cnt];
                if (bit_cnt == 4'd7)
                    next_state = WAIT_ACK3;
            end
            WAIT_ACK3: begin
                sda_oe = 1'b0;
                next_state = STOP_CONDITION;
            end
            STOP_CONDITION: begin
                // Generate stop condition: while SCL is high, release SDA (goes high via pull-up)
                sda_oe  = 1'b1;
                sda_out = 1'b0; // Drive low then release
                next_state = IDLE;
                done = 1'b1;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule

//---------------------------------------------------------------------
// I2S Interface Module (formerly "I2S_Driver")
// This simple I2S interface passes the serial audio signals through for debugging.
//---------------------------------------------------------------------
module I2S_Interface(
    input  logic BCLK,
    input  logic LRCLK,
    input  logic ADCDAT,
    output logic debug,
    output logic d_BCLK,
    output logic d_LRCLK,
    output logic d_ADCDAT
);
    assign debug    = ADCDAT;
    assign d_BCLK   = BCLK;
    assign d_LRCLK  = LRCLK;
    assign d_ADCDAT = ADCDAT;
endmodule
