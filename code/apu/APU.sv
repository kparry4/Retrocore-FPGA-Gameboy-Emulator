//`default_nettype none
`include "RegisterPkg.svh"

/*
        typedef struct packed {

            //----Global Control
            logic[7:0] NR51_R; //Sound panning (FF25)
            logic[7:0] NR50_R; //Master Volume, Vin panning(FF24)

            logic [0:4][7:0]  NR1x_R; //TODO: this might be cursed
            logic [0:3][7:0]  NR2x_R; //TODO: this might be cursed
            logic [0:4][7:0]  NR3x_R; //TODO: this might be cursed
            logic [0:15][7:0] WAV_RAM_R;
            logic [0:3][7:0]  NR4x_R; //TODO: this might be cursed
        } APU_DATA;


*/

module APU (input logic CLK_4MHZ, // 5 Mhz?
            input logic reset,
            input APU_DATA  APU_R,
            input logic[7:0] NR52_R,
            output logic[3:0] APU_NR52_bits);

            logic[3:0] CHANNEL_1; //pwm with sweep
            logic[3:0] CHANNEL_2; //pwm
            logic[3:0] CHANNEL_3; //wave
            logic[3:0] CHANNEL_4; //pseudorandom

            logic ch1on, ch2on, ch3on, ch4on;

            assign APU_NR52_bits = {ch4on, ch3on, ch2on, ch1on};

            logic ch3_dac_on;
            logic rst;
            assign rst = (reset || NR52_R[7]);

            PWM_CHANNEL   ch1  (.CLK_4MHZ,
                                .rst(rst),
                                .is_ch1(1'b1),
                                .NR0(APU_R.NR1x_R[0]),
                                .NR1(APU_R.NR1x_R[1]),
                                .NR2(APU_R.NR1x_R[2]),
                                .NR3(APU_R.NR1x_R[3]),
                                .NR4(APU_R.NR1x_R[4]),
                                .on(ch1on),
                                .CH_VALUE(CHANNEL_1));

            PWM_CHANNEL   ch2  (.CLK_4MHZ,
                                .rst,
                                .is_ch1(1'b0),
                                .NR0('X),
                                .NR1(APU_R.NR2x_R[1]),
                                .NR2(APU_R.NR2x_R[2]),
                                .NR3(APU_R.NR2x_R[3]),
                                .NR4(APU_R.NR2x_R[4]),
                                .on(ch2on),
                                .CH_VALUE(CHANNEL_2));

            WAVE_CHANNEL  ch3  (.CLK_4MHZ,
                                .rst,
                                .NR30(APU_R.NR3x_R[0]),
                                .NR31(APU_R.NR3x_R[1]),
                                .NR32(APU_R.NR3x_R[2]),
                                .NR33(APU_R.NR3x_R[3]),
                                .NR34(APU_R.NR3x_R[4]),
                                .WAV_RAM_R(APU_R.WAV_RAM_R),
                                .CH_VALUE(CHANNEL_3),
                                .on(ch3on),
                                .DAC_ON(ch3_dac_on));

            NOISE_CHANNEL ch4  (.CLK_4MHZ,
                                .rst,
                                .NR41(APU_R.NR4x_R[1]),
                                .NR42(APU_R.NR4x_R[2]),
                                .NR43(APU_R.NR4x_R[3]),
                                .NR44(APU_R.NR4x_R[4]),
                                .on(ch4on),
                                .CH_VALUE(CHANNEL_4));

endmodule: APU


module PWM_CHANNEL (input logic CLK_4MHZ, // 5 Mhz?
                    input logic rst,
                    input logic is_ch1,
                    input logic[7:0] NR0,
                    input logic[7:0] NR1,
                    input logic[7:0] NR2,
                    input logic[7:0] NR3,
                    input logic[7:0] NR4,
                    output logic on,
                    output logic[3:0] CH_VALUE);


    enum logic[1:0] {OFF, ON} state;
    logic trigger;
    assign trigger = NR4[7];
    assign on = (state == ON);

    localparam integer clock_freq = 4_000_000;
    localparam integer SWEEP_TICK_COUNT = clock_freq/128; //128 hz tick for sweep pace decrement
    localparam integer ENVELOPE_TICK_COUNT = clock_freq/64; //64hz tick for envelope updates
    localparam integer LENGTH_TICK_COUNT = clock_freq/256; //256hz tick for length handling

    logic[31:0] period_ticks, sweep_ticks, length_ticks, envelope_ticks, duty_cycle_ON_ticks;

    logic [10:0] period_value;
    logic[31:0] PERIOD_TICK_COUNT;
    assign PERIOD_TICK_COUNT = clock_freq / (131072 / (2048 - period_value));


    //CHANNEL 1SWEEP HANDLING (dictated by NR10)
    logic [3:0] sweep_pace, pace;
    logic       sweep_direction;
    logic [2:0] sweep_step;
    logic       sweep_enable;
    assign sweep_enable = (sweep_pace > 0);

    //CHANNEL 1 length timer/duty cycle (dictated by NR11)
    logic [5:0] length_timer;
    logic [11:0] duty_cycle;
    always_comb begin
        case(duty_cycle)
            2'b00: duty_cycle_ON_ticks = PERIOD_TICK_COUNT/8;   //12.5%
            2'b01: duty_cycle_ON_ticks = PERIOD_TICK_COUNT/4;   //25%
            2'b10: duty_cycle_ON_ticks = PERIOD_TICK_COUNT/2;   //50%
            2'b11: duty_cycle_ON_ticks = PERIOD_TICK_COUNT*3/4; //75%
        endcase
    end

    //CHANNEL 1 volume/envelope (dictated by NR12)
    logic [3:0] volume; //0 - 15. the amplitude.
    logic       envelope_direction;
    logic [2:0] envelope_sweep_pace, envelope_pace;


    //TONE frequency is calculated via 131072 / (2048 - value)
    //note that their internal timer register is (2048-N)*4 reset value, but I think this is internal and does not impact the RESULTING tone freq, which is what we want

    always_ff @(posedge CLK_4MHZ) begin
        if(rst) begin
                    state <= OFF;
                    period_ticks   <= '0;
                    length_ticks   <= '0;
                    envelope_ticks <= '0;
                    CH_VALUE <= '0;
                    length_timer  <= '0;
                    volume        <= '0;
                    pace          <= '0;
                    envelope_pace <= '0;
                    period_value  <= '0;
                    sweep_pace          <= '0;
                    envelope_sweep_pace <= '0;
                    envelope_direction  <= '0;
                    sweep_direction     <= '0;
        end
        else if(state == OFF && trigger) begin

            state <= ON;

            //set from NR10 (sweep)
            if(is_ch1) begin
                sweep_pace      <=  NR0[6:4];
                sweep_direction <=  NR0[3] ? -1 : 1; //1 means sub, 0 means add
                sweep_step      <=  NR0[2:0];
            end else begin
                sweep_pace      <=  'X;
                sweep_direction <=  'X;
                sweep_step      <=  'X;
            end

            //set from NRx1 (length + pwm duty)
            length_timer <= NR1[5:0];
            duty_cycle   <= NR1[7:6];


            //set from NRx2 ()
            volume              <= NR2[7:4];
            envelope_direction  <= NR2[3] ? 1 : -1; //the fuck. 1 is addition, 0 is sub
            envelope_sweep_pace <= NR2[2:0];

            //set from NR13, NR14
            period_value <= {NR3[2:0], NR4[3]};
        end else begin
                if(state == OFF) begin
                    state <= state;

                    period_ticks   <= '0;
                    length_ticks   <= '0;
                    envelope_ticks <= '0;

                    CH_VALUE <= '0;

                    length_timer  <= '0;
                    volume        <= '0;
                    pace          <= '0;
                    envelope_pace <= '0;
                    period_value  <= '0;

                    sweep_pace          <= '0;
                    envelope_sweep_pace <= '0;
                    envelope_direction  <= '0;
                    sweep_direction     <= '0;

                end else
                if (state == ON) begin

                    //if timer runs out, turn channel off
                    if(length_timer == '0) begin
                        state <= OFF;
                    end else begin
                        state <= state;
                    end

                    //final output
                    if(period_ticks <= duty_cycle_ON_ticks) begin
                        CH_VALUE <= volume;
                    end else begin
                        CH_VALUE <= '0;
                    end

                    //maintain trigger-inited values:
                    sweep_pace          <= sweep_pace;
                    envelope_sweep_pace <= envelope_sweep_pace;
                    envelope_direction  <= envelope_direction;
                    sweep_direction     <= sweep_direction;

                    //handle period
                    if(period_ticks == PERIOD_TICK_COUNT) begin
                        period_ticks <= 32'd0;
                    end else begin
                        period_ticks <= period_ticks + 32'd1;
                    end

                    //handle length timer
                    if(length_ticks == LENGTH_TICK_COUNT) begin
                        length_ticks <= 32'd0;
                        length_timer <= length_timer - 5'd1;
                    end else begin
                        length_ticks <= length_ticks + 32'd1;
                        length_timer <= length_timer;
                    end

                    //handle envelope (volume over time, alters volume, aka amplitude)
                    if(envelope_ticks == ENVELOPE_TICK_COUNT) begin
                        envelope_ticks <= 32'd0;
                        if(envelope_pace == envelope_sweep_pace) begin
                            envelope_pace <= 3'd0;
                            volume <= volume + envelope_direction;
                        end else begin
                            envelope_pace <= envelope_pace + 3'd1;
                            volume <= volume;
                        end
                    end else begin
                        envelope_ticks <= envelope_ticks + 32'd1;
                        envelope_pace <= envelope_pace;
                        volume <= volume;
                    end

                    //handle sweep (frequency over time, alters period)
                    if(is_ch1) begin
                        if(sweep_ticks == SWEEP_TICK_COUNT) begin
                            sweep_ticks <= 32'd0;
                            if(pace == sweep_pace) begin
                                pace <= 3'd0;
                                if(period_value + period_value/(32'd1 << sweep_step) > 11'h7FF) begin
                                    state <= OFF;
                                end else begin
                                    period_value <= period_value + period_value/(32'd1 << sweep_step);
                                end
                            end
                            else begin
                                pace <= pace + 3'd1;
                                period_value <= period_value;
                            end
                        end else begin
                            sweep_ticks <= sweep_ticks + 32'd1;
                            pace <= pace;
                            period_value <= period_value;
                        end
                    end
                end
            end
        end

endmodule: PWM_CHANNEL



module WAVE_CHANNEL (input logic CLK_4MHZ, // 5 Mhz?
                    input logic rst,
                    input logic[7:0] NR30,
                    input logic[7:0] NR31,
                    input logic[7:0] NR32,
                    input logic[7:0] NR33,
                    input logic[7:0] NR34,
                    input logic[0:15][7:0] WAV_RAM_R,
                    output logic on,
                    output logic[3:0] CH_VALUE,
                    output logic      DAC_ON);

    enum logic[1:0] {OFF, ON} state;

    logic trigger;
    assign trigger = NR34[7];
    assign on = (state == ON);

    assign DAC_ON = NR30[7];

    localparam integer clock_freq = 4_000_000;
    localparam integer LENGTH_TICK_COUNT = clock_freq/256; //256hz tick for length handling

    logic[31:0] period_ticks, length_ticks;


    logic [1:0] output_level;
    logic [7:0] length_timer;
    logic [10:0] period_value;

    logic [4:0] WAVERAM_index; //0 to 32, although there are 16 entries in wave ram

    logic[31:0] PERIOD_TICK_COUNT;
    assign PERIOD_TICK_COUNT = clock_freq / (65536 / (2048 - period_value));

    logic [7:0] waveram_value;
    always_comb begin
        if(WAVERAM_index[0]) begin
            //odd number (upper nibble)
            waveram_value = WAV_RAM_R[WAVERAM_index >> 1][7:4];
        end else begin
            //even number (lower nibble)
            waveram_value = WAV_RAM_R[WAVERAM_index >> 1][3:0];
        end
    end

    always_comb begin
        case(output_level)
        2'b00: CH_VALUE = '0; //mute
        2'b01: CH_VALUE = waveram_value; //100% volume
        2'b10: CH_VALUE = waveram_value >> 1; //50% volume
        2'b11: CH_VALUE = waveram_value >> 2; //25% volume
        endcase
    end

    always_ff@(posedge CLK_4MHZ) begin
        if(rst) begin
            state <= OFF;
            period_ticks  <= '0;
            length_ticks  <= '0;
            output_level  <= '0;
            period_value  <= '0;
            length_timer  <= '0;
            WAVERAM_index <= '0;
        end
        else if(state == OFF && trigger) begin
            period_value <= {NR34[2:0], NR33[7:0]};
            length_timer <= NR31;
            output_level <= NR32[6:5];
            WAVERAM_index <= 4'd0;
        end
        else begin
            if(state == OFF) begin
                period_ticks  <= '0;
                length_ticks  <= '0;
                output_level  <= '0;
                period_value  <= '0;
                length_timer  <= '0;
                WAVERAM_index <= '0;
            end
            else if(state == ON)begin
                    period_value <= period_value;

                    //turn off channel if timer runs out or dac turns off
                    if(~DAC_ON || length_timer == '0) begin
                        state <= OFF;
                    end else begin
                        state <= state;
                    end

                    //maintain trigger-inited value
                    output_level <= output_level;

                    //handle period
                    if(period_ticks == PERIOD_TICK_COUNT) begin
                        period_ticks <= 32'd0;
                        WAVERAM_index <= WAVERAM_index + 5'd1; //note that this wraps around and its fine
                    end else begin
                        period_ticks <= period_ticks + 32'd1;
                        WAVERAM_index <= WAVERAM_index;
                    end

                    //handle length timer
                    if(length_ticks == LENGTH_TICK_COUNT) begin
                        length_ticks <= 32'd0;
                        length_timer <= length_timer - 5'd1;
                    end else begin
                        length_ticks <= length_ticks + 32'd1;
                        length_timer <= length_timer;
                    end
            end
        end
    end

endmodule: WAVE_CHANNEL


module NOISE_CHANNEL(input logic CLK_4MHZ, // 5 Mhz?
                    input logic rst,
                    input logic[7:0] NR41,
                    input logic[7:0] NR42,
                    input logic[7:0] NR43,
                    input logic[7:0] NR44,
                    output logic on,
                    output logic[3:0] CH_VALUE);

    enum logic[1:0] {OFF, ON} state;

    logic trigger;
    assign trigger = NR44[7];
    assign on = (state == ON);

    localparam integer clock_freq = 4_000_000;
    localparam integer LENGTH_TICK_COUNT = clock_freq/256; //256hz tick for length handling
    localparam integer ENVELOPE_TICK_COUNT = clock_freq/64; //64hz tick for envelope updates

    logic[31:0] period_ticks, length_ticks, envelope_ticks, clock_shift_ticks;

    //dictated by NR41
    logic[7:0] length_timer;

    //volume/envelope, dictated by NR42 (functions like pwm channel)
    logic [3:0] volume; //0 - 15. the amplitude.
    logic       envelope_direction;
    logic [2:0] envelope_sweep_pace, envelope_pace;

    //NR43 handles freq and randomness
    logic [3:0] clock_shift;
    logic LFSR_width; //choose 15 or 7 feedback register
    logic [2:0] clock_divider; //how frequently lfsr updates

    logic[31:0] PERIOD_TICK_COUNT;
    assign PERIOD_TICK_COUNT = clock_freq / (262144 / (clock_divider * (32'd1 << clock_shift)));

    logic [15:0] lfsr;
    logic shift;


    lfsr_shifter random ( .clock(CLK_4MHZ),
                          .shift_en(state == ON && shift),
                          .reset(rst),
                          .bit7(LFSR_width),
                          .lfsr);

    assign CH_VALUE = lfsr[0] * volume;

    always_ff@(posedge CLK_4MHZ) begin
        if(rst) begin
            state <= OFF;
            period_ticks   <= '0;
            envelope_ticks <= '0;
            length_ticks   <= '0;

            length_timer  <= '0;
            volume        <= '0;
            envelope_pace <= '0;
            shift <= '0;

            clock_shift <=  '0;
            LFSR_width  <=  '0;
            clock_shift <=  '0;
        end
        else if(state == OFF && trigger) begin

            state <= ON;
            period_ticks   <= '0;
            envelope_ticks <= '0;
            length_ticks   <= '0;

            length_timer  <= NR41;

            //set from NR42
            volume              <= NR42[7:4];
            envelope_direction  <= NR42[3] ? 1 : -1; //the fuck. 1 is addition, 0 is sub
            envelope_sweep_pace <= NR42[2:0];

            shift <= '0;

            //set from NR43
            clock_shift <= NR43[7:4];
            LFSR_width <= NR43[3];
            clock_shift <= NR43[2:0];

        end else begin
            if(state == OFF) begin

            state <= OFF;
            period_ticks   <= '0;
            envelope_ticks <= '0;
            length_ticks   <= '0;
            length_timer  <= '0;

            //set from NR42
            volume              <='0;
            envelope_direction  <='0;
            envelope_sweep_pace <='0;

            shift <='0;
            clock_shift <='0;
            LFSR_width  <='0;
            clock_shift <='0;

            end else if(state == ON) begin


                //maintain trigger inited values
                clock_shift <=  clock_shift;
                LFSR_width  <=  LFSR_width;
                clock_shift <=  clock_shift;

                //handle envelope (volume over time, alters volume, aka amplitude)
                if(envelope_ticks == ENVELOPE_TICK_COUNT - 1) begin
                    envelope_ticks <= 32'd0;
                    if(envelope_pace == envelope_sweep_pace) begin
                        envelope_pace <= 3'd0;
                        volume <= volume + envelope_direction;
                    end else begin
                        envelope_pace <= envelope_pace + 3'd1;
                        volume <= volume;
                    end
                end else begin
                    envelope_ticks <= envelope_ticks + 32'd1;
                    envelope_pace <= envelope_pace;
                    volume <= volume;
                end

                //handle period
                if(period_ticks == PERIOD_TICK_COUNT - 1) begin
                    period_ticks <= 32'd0;
                end else begin
                    period_ticks <= period_ticks + 32'd1;
                end

                //handle length timer
                if(length_ticks == LENGTH_TICK_COUNT - 1) begin
                    length_ticks <= 32'd0;
                    length_timer <= length_timer - 5'd1;
                    shift <= 1'b1;
                end else begin
                    length_ticks <= length_ticks + 32'd1;
                    length_timer <= length_timer;
                    shift <= 1'b0;
                end


            end
        end
    end

endmodule: NOISE_CHANNEL




module lfsr_shifter(input logic clock,
                    input logic shift_en,
                    input logic reset,
                    input logic bit7,
                    output logic[15:0] lfsr);

    logic lfsr_bit7, lfsr_bit15;
    assign lfsr_bit15 = lfsr[0]^lfsr[1];
    assign lfsr_bit7 = lfsr[0]^lfsr[1];

    always_ff@(posedge clock) begin
        if(reset) begin
            lfsr <= '0;
        end else begin
                //right shift LFSR
                if(shift_en) begin
                    if(~bit7) begin
                        lfsr[15] <= lfsr_bit15;
                        lfsr[14:0] <= lfsr[15:1]; //shift everythiing right by 1
                    end else begin
                        lfsr[15] <= lfsr_bit15;
                        lfsr[14:8] <= lfsr[15:9];
                        lfsr[7] <= lfsr_bit7;
                        lfsr[6:0] <= lfsr[7:1];
                    end
                end else begin
                    lfsr <= lfsr;
                end
        end
    end
endmodule: lfsr_shifter


