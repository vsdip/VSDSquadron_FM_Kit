// =============================================================================
//  Servo Motor Test — VSDSquadron FM Kit  (360° continuous rotation)
//
//  For a 360° servo (SG90 continuous):
//    Pulse 1.0 ms = full speed clockwise
//    Pulse 1.5 ms = stopped
//    Pulse 2.0 ms = full speed counter-clockwise
//
//  Cycle: CW 3 s → Stop 1 s → CCW 3 s → Stop 1 s → repeat
// =============================================================================

module servo (
    output wire servo          // PWM output to servo signal wire
);

    // -------------------------------------------------------------------------
    //  Internal 12 MHz oscillator
    // -------------------------------------------------------------------------
    wire clk;
    SB_HFOSC #(
        .CLKHF_DIV("0b10")
    ) osc (
        .CLKHFPU(1'b1),
        .CLKHFEN(1'b1),
        .CLKHF(clk)
    );

    // -------------------------------------------------------------------------
    //  50 Hz PWM (20 ms = 240 000 cycles at 12 MHz)
    // -------------------------------------------------------------------------
    localparam PWM_PERIOD  = 18'd239_999;
    localparam PULSE_CW    = 15'd12_000;    // 1.0 ms → clockwise
    localparam PULSE_STOP  = 15'd18_000;    // 1.5 ms → stopped
    localparam PULSE_CCW   = 15'd24_000;    // 2.0 ms → counter-clockwise

    // State durations in PWM cycles (50 Hz → 50 cycles = 1 second)
    localparam DUR_SPIN = 8'd150;           // 3 seconds
    localparam DUR_STOP = 8'd50;            // 1 second

    reg [17:0] pwm_cnt = 0;                 // PWM period counter
    reg [7:0]  dur_cnt = 0;                 // duration counter (PWM cycles)
    reg [1:0]  phase   = 0;                 // 0=CW, 1=stop, 2=CCW, 3=stop
    reg [14:0] pulse_width = PULSE_CW;

    always @(posedge clk) begin
        if (pwm_cnt == PWM_PERIOD) begin
            pwm_cnt <= 0;
            dur_cnt <= dur_cnt + 1'b1;

            case (phase)
                2'd0: begin                         // Clockwise
                    pulse_width <= PULSE_CW;
                    if (dur_cnt == DUR_SPIN) begin dur_cnt <= 0; phase <= 1; end
                end
                2'd1: begin                         // Stop
                    pulse_width <= PULSE_STOP;
                    if (dur_cnt == DUR_STOP) begin dur_cnt <= 0; phase <= 2; end
                end
                2'd2: begin                         // Counter-clockwise
                    pulse_width <= PULSE_CCW;
                    if (dur_cnt == DUR_SPIN) begin dur_cnt <= 0; phase <= 3; end
                end
                2'd3: begin                         // Stop
                    pulse_width <= PULSE_STOP;
                    if (dur_cnt == DUR_STOP) begin dur_cnt <= 0; phase <= 0; end
                end
            endcase
        end else begin
            pwm_cnt <= pwm_cnt + 1'b1;
        end
    end

    assign servo = (pwm_cnt < {3'b0, pulse_width}) ? 1'b1 : 1'b0;

endmodule
