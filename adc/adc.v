// =============================================================================
//  ADC Test — VSDSquadron FM Kit
//
//  ADS1015DGC 12-bit ADC on PMOD (I2C, addr 0x48)
//  PMOD mapping: SDA = pmod2 (pin 42), SCL = pmod4 (pin 44), RDY = pmod6 (pin 46)
//
//  Reads AIN0 in single-shot mode, displays level on 4 LEDs.
//  More voltage → more LEDs lit. Updates every ~500 ms.
// =============================================================================

module adc (
    output wire led0, led1, led2, led3,
    inout  wire pmod2,          // ADC SDA
    output wire pmod4,          // ADC SCL
    input  wire pmod6           // ADC READY
);

    // -------------------------------------------------------------------------
    //  12 MHz internal oscillator
    // -------------------------------------------------------------------------
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b10")) osc (
        .CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk)
    );

    // -------------------------------------------------------------------------
    //  Bidirectional SDA via SB_IO (open-drain with internal pullup)
    // -------------------------------------------------------------------------
    wire sda_in;
    wire sda_pull;

    SB_IO #(
        .PIN_TYPE(6'b101001),
        .PULLUP(1'b1)
    ) sda_io (
        .PACKAGE_PIN(pmod2),
        .OUTPUT_ENABLE(sda_pull),
        .D_OUT_0(1'b0),
        .D_IN_0(sda_in)
    );

    // -------------------------------------------------------------------------
    //  I2C master (read/write capable)
    // -------------------------------------------------------------------------
    reg        go    = 0;
    reg  [2:0] cmd   = 0;
    reg  [7:0] wdata = 0;
    wire [7:0] rdata;
    wire       i2c_busy;
    wire       scl_out;
    wire       sda_pull_w;

    i2c_rw i2c (
        .clk(clk), .go(go), .cmd(cmd), .wdata(wdata),
        .rdata(rdata), .busy(i2c_busy),
        .scl(scl_out), .sda_pull(sda_pull_w), .sda_in(sda_in)
    );

    assign pmod4    = scl_out;
    assign sda_pull = sda_pull_w;

    // -------------------------------------------------------------------------
    //  I2C command constants
    // -------------------------------------------------------------------------
    localparam CMD_START    = 3'd1,
               CMD_SEND     = 3'd2,
               CMD_RECV_ACK = 3'd3,
               CMD_RECV_NAK = 3'd4,
               CMD_STOP     = 3'd5;

    // ADS1015 I2C address (ADDR→GND): 0x48 → write=0x90, read=0x91
    // Config: OS=1, MUX=AIN0/GND, PGA=±4.096V, single-shot, 1600SPS
    //         = 0xC383

    // -------------------------------------------------------------------------
    //  State machine
    // -------------------------------------------------------------------------
    reg [23:0] delay     = 24'd6_000_000;  // 500 ms power-up delay
    reg [4:0]  step      = 0;
    reg        wait_go   = 0;              // one-cycle gap after go
    reg [7:0]  msb       = 0;
    reg [11:0] adc_val   = 0;

    always @(posedge clk) begin
        go <= 0;

        if (delay != 0) begin
            delay <= delay - 1;
        end else if (wait_go) begin
            wait_go <= 0;
        end else if (i2c_busy) begin
            // waiting for I2C command to finish
        end else begin
            case (step)
            // -- Write config register --
            // START → 0x90 → 0x01 → 0xC3 → 0x83 → STOP
             0: begin cmd<=CMD_START;    go<=1; wait_go<=1; step<= 1; end
             1: begin cmd<=CMD_SEND; wdata<=8'h90; go<=1; wait_go<=1; step<= 2; end
             2: begin cmd<=CMD_SEND; wdata<=8'h01; go<=1; wait_go<=1; step<= 3; end
             3: begin cmd<=CMD_SEND; wdata<=8'hC3; go<=1; wait_go<=1; step<= 4; end
             4: begin cmd<=CMD_SEND; wdata<=8'h83; go<=1; wait_go<=1; step<= 5; end
             5: begin cmd<=CMD_STOP;               go<=1; wait_go<=1; step<= 6; end

            // -- Wait for conversion (~2 ms) --
             6: begin delay <= 24'd24_000; step <= 7; end

            // -- Set pointer to conversion register --
            // START → 0x90 → 0x00 → STOP
             7: begin cmd<=CMD_START;    go<=1; wait_go<=1; step<= 8; end
             8: begin cmd<=CMD_SEND; wdata<=8'h90; go<=1; wait_go<=1; step<= 9; end
             9: begin cmd<=CMD_SEND; wdata<=8'h00; go<=1; wait_go<=1; step<=10; end
            10: begin cmd<=CMD_STOP;               go<=1; wait_go<=1; step<=11; end

            // -- Read 2 bytes --
            // START → 0x91 → recv MSB (ACK) → recv LSB (NACK) → STOP
            11: begin cmd<=CMD_START;    go<=1; wait_go<=1; step<=12; end
            12: begin cmd<=CMD_SEND; wdata<=8'h91; go<=1; wait_go<=1; step<=13; end
            13: begin cmd<=CMD_RECV_ACK; go<=1; wait_go<=1; step<=14; end
            14: begin msb<=rdata; cmd<=CMD_RECV_NAK; go<=1; wait_go<=1; step<=15; end
            15: begin adc_val<={msb, rdata[7:4]}; cmd<=CMD_STOP; go<=1; wait_go<=1; step<=16; end

            // -- Wait 500 ms, repeat --
            16: begin delay <= 24'd6_000_000; step <= 0; end

            default: step <= 0;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    //  LEDs — level bar based on ADC value (active-low)
    //  PGA=±4.096V, single-ended: 3.3V ≈ 1650 counts
    //  Thresholds at 25/50/75/95% of 3.3V range:
    //    ≥ 412  (~0.8V)  → 1 LED
    //    ≥ 824  (~1.6V)  → 2 LEDs
    //    ≥ 1236 (~2.5V)  → 3 LEDs
    //    ≥ 1550 (~3.1V)  → 4 LEDs
    // -------------------------------------------------------------------------
    assign led0 = ~(adc_val >= 12'd412);
    assign led1 = ~(adc_val >= 12'd824);
    assign led2 = ~(adc_val >= 12'd1236);
    assign led3 = ~(adc_val >= 12'd1550);

endmodule
