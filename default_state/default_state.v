// =============================================================================
//  Default Clean State — VSDSquadron FM Kit
//
//  Flashed after all tests to leave the board in a quiet state:
//    - All 4 LEDs OFF (active-low, so driven HIGH)
//    - Buzzer OFF
//    - Servo signal LOW (no PWM)
//    - 7-segment display OFF (all segments LOW, digits disabled)
//    - OLED display OFF (sends 0xAE via I2C, then idles)
//    - RGB LED OFF (SB_RGBA_DRV disabled)
// =============================================================================

module default_state (
    output wire led0, led1, led2, led3,
    output wire buzzer,
    output wire servo,
    output wire seg_a, seg_b, seg_c, seg_d,
    output wire seg_e, seg_f, seg_g,
    output wire dig0, dig1,
    output       scl,
    output       sda
);

    // -------------------------------------------------------------------------
    //  24 MHz internal oscillator (needed for I2C to turn off OLED)
    // -------------------------------------------------------------------------
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b01")) osc (
        .CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk)
    );

    // -------------------------------------------------------------------------
    //  Static outputs — everything OFF
    // -------------------------------------------------------------------------
    assign led0   = 1'b1;      // active-low: HIGH = OFF
    assign led1   = 1'b1;
    assign led2   = 1'b1;
    assign led3   = 1'b1;
    assign buzzer = 1'b0;
    assign servo  = 1'b0;
    assign seg_a  = 1'b0;
    assign seg_b  = 1'b0;
    assign seg_c  = 1'b0;
    assign seg_d  = 1'b0;
    assign seg_e  = 1'b0;
    assign seg_f  = 1'b0;
    assign seg_g  = 1'b0;
    assign dig0   = 1'b0;
    assign dig1   = 1'b0;

    // -------------------------------------------------------------------------
    //  RGB LED — explicitly OFF via SB_RGBA_DRV
    // -------------------------------------------------------------------------
    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"),
        .RGB1_CURRENT("0b000001"),
        .RGB2_CURRENT("0b000001")
    ) RGB_DRIVER (
        .CURREN(1'b1),
        .RGBLEDEN(1'b0),          // disabled
        .RGB0PWM(1'b0),
        .RGB1PWM(1'b0),
        .RGB2PWM(1'b0),
        .RGB0(),
        .RGB1(),
        .RGB2()
    );

    // -------------------------------------------------------------------------
    //  I2C master — used to send Display OFF (0xAE) to OLED
    // -------------------------------------------------------------------------
    wire       i2c_busy;
    reg        i2c_start = 0;
    reg        i2c_dcn   = 0;
    reg  [7:0] i2c_data  = 0;

    i2c_master i2c (
        .clk(clk), .start(i2c_start), .DCn(i2c_dcn),
        .Data(i2c_data), .busy(i2c_busy), .scl(scl), .sda(sda)
    );

    // -------------------------------------------------------------------------
    //  Power-up delay (~500 ms) then send Display OFF command
    // -------------------------------------------------------------------------
    localparam T = 10;
    reg [23:0] pwr_delay = 24'd12_000_000;
    reg [12:0] delay     = 0;
    reg [2:0]  step      = 0;

    always @(posedge clk) begin
        if (pwr_delay != 0) begin
            pwr_delay <= pwr_delay - 1;
            i2c_start <= 0;
            step      <= 0;
        end else begin
            i2c_start <= 0;

            if (delay != 0) begin
                delay <= delay - 1;
            end else if (i2c_busy) begin
                delay <= T;
            end else begin
                case (step)
                    // Send Display OFF command (0xAE)
                    0: begin i2c_data<=8'hAE; i2c_dcn<=0; i2c_start<=1; step<=1; delay<=T; end
                    // Done — idle forever
                    1: begin /* idle */ end
                    default: step <= 0;
                endcase
            end
        end
    end

endmodule
