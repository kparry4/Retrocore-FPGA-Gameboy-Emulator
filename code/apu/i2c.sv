module I2C_Master (
    input  logic        clk,         // System clock
    input  logic        rst_n,       // Active-low reset
    input  logic        start,       // Start transaction signal
    input  logic [6:0]  slave_addr,  // 7-bit slave address
    input  logic [7:0]  reg_addr,    // Register address inside the slave
    input  logic [7:0]  data_in,     // Data to be written
    output logic        done,        // Transaction complete
    output logic        ack_error,   // Non-acknowledge detected
    inout  logic        sda,         // I2C data (bidirectional)
    output logic        scl          // I2C clock
);

  // Define state machine states
  typedef enum logic [3:0] {
    IDLE,
    START_COND,
    SEND_SLAVE_ADDR,
    SEND_REG_ADDR,
    SEND_DATA,
    WAIT_ACK,
    STOP_COND
  } state_t;
  
  state_t state, next_state;

  // Counters for bits within a byte and a simple clock divider for scl
  logic [2:0] bit_cnt;
  logic [7:0] clk_div;
  logic scl_int;

  // SDA internal driver and direction control (1: drive low; Z: released)
  logic sda_out;
  logic sda_oe;  // Output enable: when 1, drive sda_out; when 0, tri-state

  // Drive the bidirectional SDA line
  assign sda = sda_oe ? sda_out : 1'bz;

  // Generate SCL by dividing the system clock (adjust divisor as needed)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      clk_div <= 8'd0;
    else
      clk_div <= clk_div + 1;
  end
  // Example: use a bit of the counter for SCL (ensure proper duty cycle)
  assign scl_int = clk_div[7];
  assign scl = scl_int;

  // Main state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      bit_cnt <= 3'd0;
    end else if (scl_int) begin  // update on SCL rising edge (example)
      state <= next_state;
      // Use bit_cnt to count bits when sending a byte
      if (state != IDLE)
        bit_cnt <= bit_cnt + 1;
      else
        bit_cnt <= 3'd0;
    end
  end

  // Next state logic (simplified, not cycle-accurate)
  always_comb begin
    next_state = state;
    sda_out  = 1'b1;
    sda_oe   = 1'b0;  // by default, release SDA
    done     = 1'b0;
    ack_error = 1'b0;
    
    case (state)
      IDLE: begin
        if (start)
          next_state = START_COND;
      end

      START_COND: begin
        // Generate a start: SDA goes low while SCL is high.
        sda_oe  = 1'b1;
        sda_out = 1'b0;
        if (bit_cnt == 3'd0)
          next_state = SEND_SLAVE_ADDR;
      end

      SEND_SLAVE_ADDR: begin
        // Drive SDA with the slave address (MSB first) and a write bit (0)
        sda_oe = 1'b1;
        sda_out = (bit_cnt < 7) ? slave_addr[6 - bit_cnt] : 1'b0;
        if (bit_cnt == 3'd7)
          next_state = WAIT_ACK;
      end

      SEND_REG_ADDR: begin
        sda_oe = 1'b1;
        sda_out = reg_addr[7 - bit_cnt];
        if (bit_cnt == 3'd7)
          next_state = WAIT_ACK;
      end

      SEND_DATA: begin
        sda_oe = 1'b1;
        sda_out = data_in[7 - bit_cnt];
        if (bit_cnt == 3'd7)
          next_state = WAIT_ACK;
      end

      WAIT_ACK: begin
        // Release SDA for ACK from slave
        sda_oe = 1'b0;  // tri-state, so slave can drive ACK (expected 0)
        if (bit_cnt == 3'd7) begin
          if (sda !== 1'b0)  // simple check for ACK (could be refined)
            ack_error = 1'b1;
          // Decide next state based on current transaction phase.
          // For example, after sending slave address, move to send register address.
          // Here we assume one transaction that sends all bytes.
          if (state == SEND_SLAVE_ADDR)
            next_state = SEND_REG_ADDR;
          else if (state == SEND_REG_ADDR)
            next_state = SEND_DATA;
          else if (state == SEND_DATA)
            next_state = STOP_COND;
        end
      end

      STOP_COND: begin
        // Generate a stop condition: SDA goes high while SCL is high.
        sda_oe  = 1'b1;
        sda_out = 1'b0;  // Ensure low then release
        next_state = IDLE;
        done = 1'b1;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
