// =============================================================================
//  OLED Display Test — VSDSquadron FM Kit
//
//  0.91" SSD1306 WHITE OLED, 128x32, I2C (SCL=36, SDA=37, addr 0x3C)
//
//  Animation sequence:
//    1. Thick horizontal stripes         (1 second)
//    2. Inverted stripes                 (1 second)
//    3. "VSD" text (4× scaled 5x7 font) (holds forever)
// =============================================================================

module oled (
    output scl,
    output sda
);

    // -------------------------------------------------------------------------
    //  24 MHz internal oscillator
    // -------------------------------------------------------------------------
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b01")) osc (
        .CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk)
    );

    // -------------------------------------------------------------------------
    //  I2C master
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
    //  Power-up delay (~500 ms)
    // -------------------------------------------------------------------------
    reg [23:0] pwr_delay = 24'd12_000_000;

    // -------------------------------------------------------------------------
    //  Phase & timing
    // -------------------------------------------------------------------------
    reg [1:0]  phase    = 0;            // 0=stripe, 1=inv stripe, 2=VSD
    reg [24:0] wait_cnt = 0;            // 1-second wait between phases

    // -------------------------------------------------------------------------
    //  "VSD" font — 5x7 pixel, column-encoded (bit 0 = top row)
    //  Scaled 4× to 20x28 pixels, centred on 128-column display
    //
    //  Layout:  V @ cols 26-45 | gap | S @ cols 54-73 | gap | D @ cols 82-101
    // -------------------------------------------------------------------------
    reg [6:0] font_col;                 // 7-bit font column data

    always @(*) begin
        font_col = 7'd0;
        if (col >= 7'd26 && col <= 7'd45)
            case ((col - 7'd26) >> 2)           // V
                3'd0: font_col = 7'h0F;
                3'd1: font_col = 7'h30;
                3'd2: font_col = 7'h40;
                3'd3: font_col = 7'h30;
                3'd4: font_col = 7'h0F;
                default: font_col = 7'd0;
            endcase
        else if (col >= 7'd54 && col <= 7'd73)
            case ((col - 7'd54) >> 2)           // S
                3'd0: font_col = 7'h26;
                3'd1: font_col = 7'h49;
                3'd2: font_col = 7'h49;
                3'd3: font_col = 7'h49;
                3'd4: font_col = 7'h32;
                default: font_col = 7'd0;
            endcase
        else if (col >= 7'd82 && col <= 7'd101)
            case ((col - 7'd82) >> 2)           // D
                3'd0: font_col = 7'h7F;
                3'd1: font_col = 7'h41;
                3'd2: font_col = 7'h41;
                3'd3: font_col = 7'h41;
                3'd4: font_col = 7'h3E;
                default: font_col = 7'd0;
            endcase
    end

    // 4× vertical scale: map font rows to page bytes (2 rows padding top/bottom)
    reg [7:0] vsd_byte;
    always @(*) begin
        case (page)
            2'd0: vsd_byte = (font_col[0] ? 8'h3C : 8'h00)
                            | (font_col[1] ? 8'hC0 : 8'h00);
            2'd1: vsd_byte = (font_col[1] ? 8'h03 : 8'h00)
                            | (font_col[2] ? 8'h3C : 8'h00)
                            | (font_col[3] ? 8'hC0 : 8'h00);
            2'd2: vsd_byte = (font_col[3] ? 8'h03 : 8'h00)
                            | (font_col[4] ? 8'h3C : 8'h00)
                            | (font_col[5] ? 8'hC0 : 8'h00);
            2'd3: vsd_byte = (font_col[5] ? 8'h03 : 8'h00)
                            | (font_col[6] ? 8'h3C : 8'h00);
        endcase
    end

    // Pixel data for current phase
    wire [7:0] pixel_data = (phase == 2'd0) ? (page[0] ? 8'h00 : 8'hFF) :  // stripes
                            (phase == 2'd1) ? (page[0] ? 8'hFF : 8'h00) :  // inverted
                            vsd_byte;                                        // VSD

    // -------------------------------------------------------------------------
    //  State machine
    // -------------------------------------------------------------------------
    localparam T = 10;

    reg [12:0] delay = 0;
    reg [5:0]  step  = 0;
    reg [6:0]  col   = 0;
    reg [1:0]  page  = 0;

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
                // ---- SSD1306 init (128x32, Adafruit-compatible) ----
                 0: begin i2c_data<=8'hAE; i2c_dcn<=0; i2c_start<=1; step<= 1; delay<=T; end
                 1: begin i2c_data<=8'hD5; i2c_dcn<=0; i2c_start<=1; step<= 2; delay<=T; end
                 2: begin i2c_data<=8'h80; i2c_dcn<=0; i2c_start<=1; step<= 3; delay<=T; end
                 3: begin i2c_data<=8'hA8; i2c_dcn<=0; i2c_start<=1; step<= 4; delay<=T; end
                 4: begin i2c_data<=8'h1F; i2c_dcn<=0; i2c_start<=1; step<= 5; delay<=T; end
                 5: begin i2c_data<=8'hD3; i2c_dcn<=0; i2c_start<=1; step<= 6; delay<=T; end
                 6: begin i2c_data<=8'h00; i2c_dcn<=0; i2c_start<=1; step<= 7; delay<=T; end
                 7: begin i2c_data<=8'h40; i2c_dcn<=0; i2c_start<=1; step<= 8; delay<=T; end
                 8: begin i2c_data<=8'h8D; i2c_dcn<=0; i2c_start<=1; step<= 9; delay<=T; end
                 9: begin i2c_data<=8'h14; i2c_dcn<=0; i2c_start<=1; step<=10; delay<=T; end
                10: begin i2c_data<=8'h20; i2c_dcn<=0; i2c_start<=1; step<=11; delay<=T; end
                11: begin i2c_data<=8'h02; i2c_dcn<=0; i2c_start<=1; step<=12; delay<=T; end
                12: begin i2c_data<=8'hA1; i2c_dcn<=0; i2c_start<=1; step<=13; delay<=T; end
                13: begin i2c_data<=8'hC8; i2c_dcn<=0; i2c_start<=1; step<=14; delay<=T; end
                14: begin i2c_data<=8'hDA; i2c_dcn<=0; i2c_start<=1; step<=15; delay<=T; end
                15: begin i2c_data<=8'h02; i2c_dcn<=0; i2c_start<=1; step<=16; delay<=T; end
                16: begin i2c_data<=8'h81; i2c_dcn<=0; i2c_start<=1; step<=17; delay<=T; end
                17: begin i2c_data<=8'h8F; i2c_dcn<=0; i2c_start<=1; step<=18; delay<=T; end
                18: begin i2c_data<=8'hD9; i2c_dcn<=0; i2c_start<=1; step<=19; delay<=T; end
                19: begin i2c_data<=8'hF1; i2c_dcn<=0; i2c_start<=1; step<=20; delay<=T; end
                20: begin i2c_data<=8'hDB; i2c_dcn<=0; i2c_start<=1; step<=21; delay<=T; end
                21: begin i2c_data<=8'h40; i2c_dcn<=0; i2c_start<=1; step<=22; delay<=T; end
                22: begin i2c_data<=8'hA4; i2c_dcn<=0; i2c_start<=1; step<=23; delay<=T; end
                23: begin i2c_data<=8'hA6; i2c_dcn<=0; i2c_start<=1; step<=24; delay<=T; end
                24: begin i2c_data<=8'h2E; i2c_dcn<=0; i2c_start<=1; step<=25; delay<=T; end
                25: begin i2c_data<=8'hAF; i2c_dcn<=0; i2c_start<=1; step<=26; delay<=T; end

                // ---- Set page & column ----
                26: begin
                    i2c_data <= 8'hB0 | {6'b0, page};
                    i2c_dcn <= 0; i2c_start <= 1; step <= 27; delay <= T;
                end
                27: begin i2c_data<=8'h00; i2c_dcn<=0; i2c_start<=1; step<=28; delay<=T; end
                28: begin i2c_data<=8'h10; i2c_dcn<=0; i2c_start<=1; step<=29; delay<=T; end

                // ---- Stream 128 bytes ----
                29: begin
                    i2c_data  <= pixel_data;
                    i2c_dcn   <= 1;
                    i2c_start <= 1;
                    delay     <= T;
                    col       <= col + 1'b1;
                    if (col == 7'd127) begin
                        col <= 0;
                        if (page == 2'd3) begin
                            page <= 0;
                            if (phase == 2'd2)
                                step <= 31;     // VSD done → idle
                            else
                                step <= 30;     // → wait between phases
                        end else begin
                            page <= page + 1'b1;
                            step <= 26;
                        end
                    end
                end

                // ---- 1-second wait, then advance phase ----
                30: begin
                    if (wait_cnt == 25'd23_999_999) begin
                        wait_cnt <= 0;
                        phase    <= phase + 1'b1;
                        step     <= 26;
                    end else begin
                        wait_cnt <= wait_cnt + 1'b1;
                    end
                end

                // ---- Done — hold VSD on screen ----
                31: begin /* idle */ end

                default: step <= 0;
                endcase
            end
        end
    end

endmodule
