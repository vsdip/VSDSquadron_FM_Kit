// =============================================================================
//  Toggle Switch Test — VSDSquadron FM Kit
//
//  Two toggle switches (default OFF, active-high):
//    Toggle 1 (pin 4) → Buzzer:  continuous 1 kHz tone (on/off)
//    Toggle 2 (pin 6) → Servo:   360° CW/stop/CCW/stop cycle
// =============================================================================

module toggle_switch (
    input  wire sw_tog0,    // Toggle switch 1 → buzzer enable
    input  wire sw_tog1,    // Toggle switch 2 → servo enable
    output wire buzzer,     // Buzzer output
    output wire servo       // Servo PWM output
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

    // =========================================================================
    //  BUZZER — constant 1 kHz tone, gated by toggle switch
    //  12 MHz / 12 000 = 1 kHz → toggle every 6000 cycles
    // =========================================================================
    reg [12:0] tone_cnt = 0;
    reg        tone     = 0;

    always @(posedge clk) begin
        if (tone_cnt == 13'd5999) begin
            tone_cnt <= 0;
            tone     <= ~tone;
        end else
            tone_cnt <= tone_cnt + 1'b1;
    end

    // Switch ON → tone plays, Switch OFF → silent
    assign buzzer = sw_tog0 & tone;

    // =========================================================================
    //  SERVO — 360° continuous rotation, CW/stop/CCW/stop cycle
    // =========================================================================
    localparam PWM_PERIOD  = 18'd239_999;
    localparam PULSE_CW    = 15'd12_000;    // 1.0 ms → clockwise
    localparam PULSE_STOP  = 15'd18_000;    // 1.5 ms → stopped
    localparam PULSE_CCW   = 15'd24_000;    // 2.0 ms → counter-clockwise
    localparam DUR_SPIN    = 8'd150;        // 3 seconds (150 PWM cycles)
    localparam DUR_PAUSE   = 8'd50;         // 1 second  (50 PWM cycles)

    reg [17:0] pwm_cnt     = 0;
    reg [7:0]  dur_cnt     = 0;
    reg [1:0]  phase       = 0;
    reg [14:0] pulse_width = PULSE_CW;

    always @(posedge clk) begin
        if (pwm_cnt == PWM_PERIOD) begin
            pwm_cnt <= 0;
            if (sw_tog1) begin
                dur_cnt <= dur_cnt + 1'b1;
                case (phase)
                    2'd0: begin
                        pulse_width <= PULSE_CW;
                        if (dur_cnt == DUR_SPIN) begin dur_cnt <= 0; phase <= 1; end
                    end
                    2'd1: begin
                        pulse_width <= PULSE_STOP;
                        if (dur_cnt == DUR_PAUSE) begin dur_cnt <= 0; phase <= 2; end
                    end
                    2'd2: begin
                        pulse_width <= PULSE_CCW;
                        if (dur_cnt == DUR_SPIN) begin dur_cnt <= 0; phase <= 3; end
                    end
                    2'd3: begin
                        pulse_width <= PULSE_STOP;
                        if (dur_cnt == DUR_PAUSE) begin dur_cnt <= 0; phase <= 0; end
                    end
                endcase
            end
        end else begin
            pwm_cnt <= pwm_cnt + 1'b1;
        end
    end

    assign servo = sw_tog1 ? (pwm_cnt < {3'b0, pulse_width}) : 1'b0;

endmodule
