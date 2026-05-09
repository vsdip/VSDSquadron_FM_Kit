// =============================================================================
//  7-Segment Display Counter — VSDSquadron FM Kit
//
//  Counts 00 -> 99 and wraps.
//
//  Confirmed polarity:
//      Segment ON = 0
//      Digit ON   = 0
//
//  Confirmed physical mapping:
//      Verilog seg_a -> physical C
//      Verilog seg_b -> physical G
//      Verilog seg_c -> physical D
//      Verilog seg_d -> physical E
//      Verilog seg_e -> physical A
//      Verilog seg_f -> physical B
//      Verilog seg_g -> physical F
// =============================================================================

module seven_seg (
    output wire seg_a,
    output wire seg_b,
    output wire seg_c,
    output wire seg_d,
    output wire seg_e,
    output wire seg_f,
    output wire seg_g,
    output wire dig0,      // tens / left digit
    output wire dig1       // ones / right digit
);

    // -------------------------------------------------------------------------
    // Internal 12 MHz oscillator
    // -------------------------------------------------------------------------
    wire clk;

    SB_HFOSC #(
        .CLKHF_DIV("0b10")      // 12 MHz
    ) osc (
        .CLKHFPU(1'b1),
        .CLKHFEN(1'b1),
        .CLKHF(clk)
    );

    // -------------------------------------------------------------------------
    // 0.5 second counter
    // -------------------------------------------------------------------------
    reg [22:0] half_sec = 23'd0;
    reg [3:0]  ones     = 4'd0;
    reg [3:0]  tens     = 4'd0;

    always @(posedge clk) begin
        if (half_sec == 23'd5_999_999) begin
            half_sec <= 23'd0;

            if (ones == 4'd9) begin
                ones <= 4'd0;

                if (tens == 4'd9)
                    tens <= 4'd0;
                else
                    tens <= tens + 4'd1;

            end else begin
                ones <= ones + 4'd1;
            end

        end else begin
            half_sec <= half_sec + 23'd1;
        end
    end

    // -------------------------------------------------------------------------
    // Digit multiplexer
    // 1 ms per digit, about 500 Hz full refresh
    // -------------------------------------------------------------------------
    reg [13:0] mux_cnt = 14'd0;
    reg        sel     = 1'b0;      // 0 = tens, 1 = ones

    always @(posedge clk) begin
        if (mux_cnt == 14'd11_999) begin
            mux_cnt <= 14'd0;
            sel     <= ~sel;
        end else begin
            mux_cnt <= mux_cnt + 14'd1;
        end
    end

    // -------------------------------------------------------------------------
    // BCD to physical 7-segment decoder
    //
    // physical_on = {A, B, C, D, E, F, G}
    // 1 = segment should be ON logically
    // -------------------------------------------------------------------------
    wire [3:0] digit;
    reg  [6:0] physical_on;

    assign digit = sel ? ones : tens;

    always @(*) begin
        case (digit)
            4'd0: physical_on = 7'b1111110;   // A B C D E F
            4'd1: physical_on = 7'b0110000;   // B C
            4'd2: physical_on = 7'b1101101;   // A B D E G
            4'd3: physical_on = 7'b1111001;   // A B C D G
            4'd4: physical_on = 7'b0110011;   // B C F G
            4'd5: physical_on = 7'b1011011;   // A C D F G
            4'd6: physical_on = 7'b1011111;   // A C D E F G
            4'd7: physical_on = 7'b1110000;   // A B C
            4'd8: physical_on = 7'b1111111;   // A B C D E F G
            4'd9: physical_on = 7'b1111011;   // A B C D F G
            default: physical_on = 7'b0000000;
        endcase
    end

    // -------------------------------------------------------------------------
    // Remap physical segments to actual Verilog outputs
    //
    // physical_on[6] = A
    // physical_on[5] = B
    // physical_on[4] = C
    // physical_on[3] = D
    // physical_on[2] = E
    // physical_on[1] = F
    // physical_on[0] = G
    //
    // Confirmed wiring:
    // Verilog seg_a controls physical C
    // Verilog seg_b controls physical G
    // Verilog seg_c controls physical D
    // Verilog seg_d controls physical E
    // Verilog seg_e controls physical A
    // Verilog seg_f controls physical B
    // Verilog seg_g controls physical F
    //
    // Active-low output:
    // output = 0 means ON
    // -------------------------------------------------------------------------

    assign seg_a = ~physical_on[4];   // physical C
    assign seg_b = ~physical_on[0];   // physical G
    assign seg_c = ~physical_on[3];   // physical D
    assign seg_d = ~physical_on[2];   // physical E
    assign seg_e = ~physical_on[6];   // physical A
    assign seg_f = ~physical_on[5];   // physical B
    assign seg_g = ~physical_on[1];   // physical F

    // -------------------------------------------------------------------------
    // Digit enables
    // Active-low: 0 = digit ON
    //
    // Use Gerber-corrected PCF:
    // dig0 -> FM35 / left / tens
    // dig1 -> FM34 / right / ones
    // -------------------------------------------------------------------------
    assign dig0 =  sel;     // sel=0 -> tens ON
    assign dig1 = ~sel;     // sel=1 -> ones ON

endmodule
