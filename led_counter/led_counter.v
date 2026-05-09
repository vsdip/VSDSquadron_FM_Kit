// =============================================================================
//  4-Bit LED Counter — VSDSquadron FM Kit
//
//  Counts 0 to 15 in binary on 4 LEDs.
//  Each step lasts ~0.5 seconds (full cycle ≈ 8 seconds).
//  Uses the iCE40 internal 12 MHz oscillator — no external clock needed.
// =============================================================================

module led_counter (
    output wire led0,       // LED 1 — bit 0 (LSB)
    output wire led1,       // LED 2 — bit 1
    output wire led2,       // LED 3 — bit 2
    output wire led3        // LED 4 — bit 3 (MSB)
);

    // -------------------------------------------------------------------------
    //  Internal 12 MHz oscillator (iCE40 UP5K built-in)
    //  CLKHF_DIV = "0b10" divides 48 MHz base by 4 → 12 MHz
    // -------------------------------------------------------------------------
    wire clk;
    SB_HFOSC #(
        .CLKHF_DIV("0b10")
    ) osc (
        .CLKHFPU(1'b1),    // power-up the oscillator
        .CLKHFEN(1'b1),    // enable clock output
        .CLKHF(clk)        // 12 MHz clock out
    );

    // -------------------------------------------------------------------------
    //  Prescaler — divides 12 MHz down to 2 Hz (0.5 s per tick)
    //  12_000_000 / 2 = 6_000_000 cycles per half-second
    // -------------------------------------------------------------------------
    reg [22:0] prescaler = 0;       // 23-bit counter (holds up to 8_388_607)
    reg [3:0]  counter   = 0;       // 4-bit value shown on LEDs

    always @(posedge clk) begin
        if (prescaler == 23'd5_999_999) begin
            prescaler <= 0;
            counter   <= counter + 1'b1;    // wraps 15 → 0 automatically
        end else begin
            prescaler <= prescaler + 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    //  Drive each LED from one bit of the counter
    // -------------------------------------------------------------------------
    assign led0 = ~counter[0];
    assign led1 = ~counter[1];
    assign led2 = ~counter[2];
    assign led3 = ~counter[3];

endmodule
