// =============================================================================
//  Buzzer Test — VSDSquadron FM Kit
//
//  Generates a continuous 1 kHz tone.
//  Uses the iCE40 internal 12 MHz oscillator.
// =============================================================================

module buzzer (
    output wire buzzer      // Buzzer output (pin 2)
);

    // -------------------------------------------------------------------------
    //  Internal 12 MHz oscillator
    // -------------------------------------------------------------------------
    wire clk;
    SB_HFOSC #(
        .CLKHF_DIV("0b10")         // 48 MHz / 4 = 12 MHz
    ) osc (
        .CLKHFPU(1'b1),
        .CLKHFEN(1'b1),
        .CLKHF(clk)
    );

    // -------------------------------------------------------------------------
    //  1 kHz tone generator
    //  12 MHz / 12_000 = 1 kHz → toggle every 6000 cycles
    // -------------------------------------------------------------------------
    reg [12:0] tone_cnt = 0;
    reg        tone     = 0;

    always @(posedge clk) begin
        if (tone_cnt == 13'd5999) begin
            tone_cnt <= 0;
            tone     <= ~tone;
        end else begin
            tone_cnt <= tone_cnt + 1'b1;
        end
    end

    assign buzzer = tone;

endmodule
