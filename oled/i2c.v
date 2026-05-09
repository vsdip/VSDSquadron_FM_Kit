// =============================================================================
//  I2C Master — write-only, for SSD1306 OLED
//  Adapted from the proven VSDSquadron FM OLED reference design.
//
//  Transaction: START → 0x78 (slave addr) → control byte → data → STOP
//  Control byte: 0x00 for command, 0x40 for display data
// =============================================================================

module i2c_master (
    input        clk,
    input        start,         // pulse to begin transaction
    input        DCn,           // 0 = command, 1 = data
    input  [7:0] Data,          // byte to transmit
    output reg   busy = 0,
    output reg   scl  = 1,
    output reg   sda  = 1
);

    localparam IDLE  = 0, START = 1, ADDR = 2;
    localparam CBYTE = 3, DATA  = 4, STOP = 5;
    localparam T_WAIT = 50;                     // ~2 µs at 24 MHz ≈ 250 kHz I2C

    reg        DCn_r  = 0;
    reg [2:0]  state  = IDLE;
    reg [3:0]  i      = 0;                      // bit index
    reg [3:0]  step   = 0;                      // sub-state
    reg [12:0] delay  = 1;                      // 1 = ready (not waiting)
    reg [7:0]  slave  = 8'h78;                  // 0x3C << 1
    reg [7:0]  cbyte  = 8'h00;                  // control: command
    reg [7:0]  dbyte  = 8'h40;                  // control: data
    reg [7:0]  data_r = 0;

    always @(posedge clk) begin
        if (delay != 1) begin
            delay <= delay - 1;
        end else begin
            case (state)

            IDLE: begin
                scl <= 1;
                sda <= 1;
                if (start) begin
                    DCn_r  <= DCn;
                    data_r <= Data;
                    busy   <= 1;
                    state  <= START;
                    step   <= 0;
                end
            end

            START: begin
                case (step)
                    0: begin sda <= 0; delay <= T_WAIT; step <= 1; end
                    1: begin scl <= 0; state <= ADDR; step <= 0; end
                endcase
            end

            ADDR: begin
                case (step)
                    0: begin
                        if (i < 8) begin
                            scl <= 0; step <= 1;
                        end else begin
                            scl <= 0; sda <= 0;
                            delay <= T_WAIT; i <= i + 1; step <= 2;
                        end
                    end
                    1: begin
                        sda <= slave[7-i];
                        delay <= T_WAIT - 1; i <= i + 1; step <= 2;
                    end
                    2: begin
                        if (i < 9) begin
                            scl <= 1; delay <= T_WAIT; step <= 0;
                        end else begin
                            scl <= 1; delay <= T_WAIT; step <= 3;
                        end
                    end
                    3: begin scl <= 0; sda <= 0; delay <= T_WAIT; step <= 4; end
                    4: begin step <= 0; i <= 0; state <= CBYTE; end
                endcase
            end

            CBYTE: begin
                case (step)
                    0: begin
                        if (i < 8) begin
                            scl <= 0; step <= 1;
                        end else begin
                            scl <= 0; sda <= 0;
                            delay <= T_WAIT; i <= i + 1; step <= 2;
                        end
                    end
                    1: begin
                        sda <= DCn_r ? dbyte[7-i] : cbyte[7-i];
                        delay <= T_WAIT - 1; i <= i + 1; step <= 2;
                    end
                    2: begin
                        if (i < 9) begin
                            scl <= 1; delay <= T_WAIT; step <= 0;
                        end else begin
                            scl <= 1; delay <= T_WAIT; step <= 3;
                        end
                    end
                    3: begin scl <= 0; sda <= 0; delay <= T_WAIT; step <= 4; end
                    4: begin step <= 0; i <= 0; state <= DATA; end
                endcase
            end

            DATA: begin
                case (step)
                    0: begin
                        if (i < 8) begin
                            scl <= 0; step <= 1;
                        end else begin
                            scl <= 0; sda <= 0;
                            delay <= T_WAIT; i <= i + 1; step <= 2;
                        end
                    end
                    1: begin
                        sda <= data_r[7-i];
                        delay <= T_WAIT - 1; i <= i + 1; step <= 2;
                    end
                    2: begin
                        if (i < 9) begin
                            scl <= 1; delay <= T_WAIT; step <= 0;
                        end else begin
                            scl <= 1; delay <= T_WAIT; step <= 3;
                        end
                    end
                    3: begin scl <= 0; sda <= 0; delay <= T_WAIT; step <= 4; end
                    4: begin step <= 0; i <= 0; state <= STOP; end
                endcase
            end

            STOP: begin
                case (step)
                    0: begin scl <= 1; sda <= 0; delay <= T_WAIT; step <= 1; end
                    1: begin state <= IDLE; busy <= 0; step <= 0; end
                endcase
            end

            endcase
        end
    end

endmodule
