// =============================================================================
//  RGB LED Test — VSDSquadron FM Kit
//
//  Cycles through 7 colors using the iCE40 built-in RGB LED driver.
//  Each color is displayed for ~1 second.
//
//  Colors: Red → Green → Blue → Yellow → Cyan → Magenta → White → (repeat)
// =============================================================================

module rgb_led (
    output wire rgb_red,
    output wire rgb_green,
    output wire rgb_blue
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
    //  ~1 second timer → 3-bit color selector (0–6, 7 colors)
    // -------------------------------------------------------------------------
    reg [23:0] prescaler = 0;
    reg [2:0]  color     = 0;

    always @(posedge clk) begin
        if (prescaler == 24'd11_999_999) begin  // 12M cycles = 1 second
            prescaler <= 0;
            color     <= (color == 3'd6) ? 3'd0 : color + 1'b1;
        end else begin
            prescaler <= prescaler + 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    //  Color decode — which LEDs to light for each color
    //          R G B
    //  0: Red  1 0 0
    //  1: Grn  0 1 0
    //  2: Blu  0 0 1
    //  3: Yel  1 1 0
    //  4: Cyn  0 1 1
    //  5: Mag  1 0 1
    //  6: Wht  1 1 1
    // -------------------------------------------------------------------------
    reg red_on, green_on, blue_on;

    always @(*) begin
        case (color)
            3'd0: {red_on, green_on, blue_on} = 3'b100;  // Red
            3'd1: {red_on, green_on, blue_on} = 3'b010;  // Green
            3'd2: {red_on, green_on, blue_on} = 3'b001;  // Blue
            3'd3: {red_on, green_on, blue_on} = 3'b110;  // Yellow
            3'd4: {red_on, green_on, blue_on} = 3'b011;  // Cyan
            3'd5: {red_on, green_on, blue_on} = 3'b101;  // Magenta
            3'd6: {red_on, green_on, blue_on} = 3'b111;  // White
            default: {red_on, green_on, blue_on} = 3'b000;
        endcase
    end

    // -------------------------------------------------------------------------
    //  iCE40 RGB LED driver (hard IP block)
    // -------------------------------------------------------------------------
    SB_RGBA_DRV RGB_DRIVER (
        .RGBLEDEN (1'b1),
        .RGB0PWM  (green_on),
        .RGB1PWM  (blue_on),
        .RGB2PWM  (red_on),
        .CURREN   (1'b1),
        .RGB0     (rgb_green),
        .RGB1     (rgb_blue),
        .RGB2     (rgb_red)
    );
    defparam RGB_DRIVER.RGB0_CURRENT = "0b000001";
    defparam RGB_DRIVER.RGB1_CURRENT = "0b000001";
    defparam RGB_DRIVER.RGB2_CURRENT = "0b000001";

endmodule
