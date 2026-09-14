// ============================================================================
//  VSDSquadron FM Kit - Unified automatic peripheral demonstration
//
//  Target : Lattice iCE40UP5K-SG48
//  Clock  : internal 12 MHz oscillator
//
//  This is a single-file replacement for the individual projects in the
//  VSDSquadron_FM_Kit repository.  Flash this top module once; the following
//  functions then run continuously after power-up:
//
//    - 4-bit LED counter and ADC level bar
//    - push-switch indication
//    - 1 kHz buzzer
//    - RGB colour cycle
//    - 360-degree servo CW/STOP/CCW/STOP cycle
//    - 00-99 multiplexed seven-segment counter
//    - SSD1306 OLED startup, stripe animation, and VSD text
//    - ADS1015 ADC readout on PMOD
//
//  LED sharing policy:
//    * Pressing any push switch gives that switch priority on its LED.
//    * Otherwise the LEDs alternate automatically between the binary counter
//      and the ADC level bar.  Both engines continue to run all the time.
//    * Toggle 1 ON mutes the automatic buzzer; toggle 1 OFF is the default
//      automatic buzzer demonstration.
//    * Toggle 2 ON commands the servo to stop; toggle 2 OFF runs the cycle.
//
//  Use the existing VSDSquadronFM.pcf file.  Its signal names match this port
//  list exactly.
// ============================================================================

module unified_test_kit (
    output wire led0, led1, led2, led3,
    output wire buzzer,
    output wire servo,
    input  wire sw0, sw1, sw2, sw3,
    input  wire sw_tog0, sw_tog1,
    output wire rgb_red, rgb_green, rgb_blue,
    output wire sda, scl,
    output wire seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g,
    output wire dig0, dig1,
    inout  wire pmod2,
    output wire pmod4,
    input  wire pmod6
);

    // ------------------------------------------------------------------------
    // One oscillator shared by every synchronous function.
    // ------------------------------------------------------------------------
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b10")) osc (
        .CLKHFPU(1'b1),
        .CLKHFEN(1'b1),
        .CLKHF(clk)
    );

    // ========================================================================
    // Common demo timing: 0.5 s LED/7-segment update and 1 s RGB update.
    // ========================================================================
    reg [22:0] half_sec_cnt = 23'd0;
    reg [3:0]  led_count    = 4'd0;
    reg [3:0]  seven_ones   = 4'd0;
    reg [3:0]  seven_tens   = 4'd0;
    reg [2:0]  demo_second  = 3'd0;
    reg        one_sec_half = 1'b0;
    reg [2:0]  color        = 3'd0;

    always @(posedge clk) begin
        if (half_sec_cnt == 23'd5_999_999) begin
            half_sec_cnt <= 23'd0;
            led_count    <= led_count + 1'b1;

            if (seven_ones == 4'd9) begin
                seven_ones <= 4'd0;
                if (seven_tens == 4'd9)
                    seven_tens <= 4'd0;
                else
                    seven_tens <= seven_tens + 1'b1;
            end else begin
                seven_ones <= seven_ones + 1'b1;
            end

            if (one_sec_half) begin
                one_sec_half <= 1'b0;
                demo_second  <= demo_second + 1'b1;
                color        <= (color == 3'd6) ? 3'd0 : color + 1'b1;
            end else begin
                one_sec_half <= 1'b1;
            end
        end else begin
            half_sec_cnt <= half_sec_cnt + 1'b1;
        end
    end

    // ========================================================================
    // LEDs: push switch override, otherwise counter/ADC alternating view.
    // Active-low LED outputs: zero lights an LED.
    // ========================================================================
    reg [11:0] adc_value = 12'd0;
    wire [3:0] adc_bar = {
        (adc_value >= 12'd1550),
        (adc_value >= 12'd1236),
        (adc_value >= 12'd824),
        (adc_value >= 12'd412)
    };
    wire any_push = sw0 | sw1 | sw2 | sw3;
    wire show_adc = demo_second[1];
    wire [3:0] led_view = any_push ? {sw3, sw2, sw1, sw0} :
                          (show_adc ? adc_bar : led_count);

    assign led0 = ~led_view[0];
    assign led1 = ~led_view[1];
    assign led2 = ~led_view[2];
    assign led3 = ~led_view[3];

    // ========================================================================
    // Buzzer: 1 kHz square wave, muted by toggle switch 1.
    // ========================================================================
    reg [12:0] tone_count = 13'd0;
    reg        tone       = 1'b0;

    always @(posedge clk) begin
        if (tone_count == 13'd5_999) begin
            tone_count <= 13'd0;
            tone       <= ~tone;
        end else begin
            tone_count <= tone_count + 1'b1;
        end
    end

    assign buzzer = tone & sw_tog0;

    // ========================================================================
    // RGB LED: red, green, blue, yellow, cyan, magenta, white.
    // The RGB pins are hard-IP outputs on the iCE40 and must use SB_RGBA_DRV.
    // ========================================================================
    reg rgb_red_on, rgb_green_on, rgb_blue_on;

    always @(*) begin
        case (color)
            3'd0: {rgb_red_on, rgb_green_on, rgb_blue_on} = 3'b100;
            3'd1: {rgb_red_on, rgb_green_on, rgb_blue_on} = 3'b010;
            3'd2: {rgb_red_on, rgb_green_on, rgb_blue_on} = 3'b001;
            3'd3: {rgb_red_on, rgb_green_on, rgb_blue_on} = 3'b110;
            3'd4: {rgb_red_on, rgb_green_on, rgb_blue_on} = 3'b011;
            3'd5: {rgb_red_on, rgb_green_on, rgb_blue_on} = 3'b101;
            3'd6: {rgb_red_on, rgb_green_on, rgb_blue_on} = 3'b111;
            default: {rgb_red_on, rgb_green_on, rgb_blue_on} = 3'b000;
        endcase
    end

    SB_RGBA_DRV RGB_DRIVER (
        .RGBLEDEN(1'b1),
        .RGB0PWM(rgb_green_on),
        .RGB1PWM(rgb_blue_on),
        .RGB2PWM(rgb_red_on),
        .CURREN(1'b1),
        .RGB0(rgb_green),
        .RGB1(rgb_blue),
        .RGB2(rgb_red)
    );
    defparam RGB_DRIVER.CURRENT_MODE = "0b1";
    defparam RGB_DRIVER.RGB0_CURRENT = "0b000001";
    defparam RGB_DRIVER.RGB1_CURRENT = "0b000001";
    defparam RGB_DRIVER.RGB2_CURRENT = "0b000001";

    // ========================================================================
    // Servo: 50 Hz, 1.0 ms CW, 1.5 ms stop, 2.0 ms CCW.
    // Toggle 2 ON forces the stop pulse; OFF runs the automatic cycle.
    // ========================================================================
    localparam [17:0] SERVO_PERIOD = 18'd239_999;
    localparam [14:0] SERVO_CW     = 15'd12_000;
    localparam [14:0] SERVO_STOP   = 15'd18_000;
    localparam [14:0] SERVO_CCW    = 15'd24_000;
    localparam [7:0]  SPIN_FRAMES  = 8'd150;
    localparam [7:0]  STOP_FRAMES  = 8'd50;

    reg [17:0] servo_count = 18'd0;
    reg [7:0]  servo_time  = 8'd0;
    reg [1:0]  servo_phase = 2'd0;
    reg [14:0] servo_width = SERVO_CW;
    wire [14:0] selected_servo_width = sw_tog1 ? servo_width : SERVO_STOP;

    always @(posedge clk) begin
        if (servo_count == SERVO_PERIOD) begin
            servo_count <= 18'd0;
            servo_time  <= servo_time + 1'b1;
            case (servo_phase)
                2'd0: begin
                    servo_width <= SERVO_CW;
                    if (servo_time == SPIN_FRAMES) begin
                        servo_time  <= 8'd0;
                        servo_phase <= 2'd1;
                    end
                end
                2'd1: begin
                    servo_width <= SERVO_STOP;
                    if (servo_time == STOP_FRAMES) begin
                        servo_time  <= 8'd0;
                        servo_phase <= 2'd2;
                    end
                end
                2'd2: begin
                    servo_width <= SERVO_CCW;
                    if (servo_time == SPIN_FRAMES) begin
                        servo_time  <= 8'd0;
                        servo_phase <= 2'd3;
                    end
                end
                default: begin
                    servo_width <= SERVO_STOP;
                    if (servo_time == STOP_FRAMES) begin
                        servo_time  <= 8'd0;
                        servo_phase <= 2'd0;
                    end
                end
            endcase
        end else begin
            servo_count <= servo_count + 1'b1;
        end
    end

    assign servo = servo_count < {3'b000, selected_servo_width};

    // ========================================================================
    // Two-digit seven-segment display.
    // Existing FM board mapping is retained:
    //   seg_a=C, seg_b=G, seg_c=D, seg_d=E, seg_e=A, seg_f=B, seg_g=F.
    // Segment and digit enables are active-low.
    // ========================================================================
    reg [13:0] mux_count = 14'd0;
    reg        mux_select = 1'b0;
    reg [6:0]  physical_on;
    wire [3:0] selected_digit = mux_select ? seven_ones : seven_tens;

    always @(posedge clk) begin
        if (mux_count == 14'd11_999) begin
            mux_count  <= 14'd0;
            mux_select <= ~mux_select;
        end else begin
            mux_count <= mux_count + 1'b1;
        end
    end

    always @(*) begin
        case (selected_digit)
            4'd0: physical_on = 7'b1111110;
            4'd1: physical_on = 7'b0110000;
            4'd2: physical_on = 7'b1101101;
            4'd3: physical_on = 7'b1111001;
            4'd4: physical_on = 7'b0110011;
            4'd5: physical_on = 7'b1011011;
            4'd6: physical_on = 7'b1011111;
            4'd7: physical_on = 7'b1110000;
            4'd8: physical_on = 7'b1111111;
            4'd9: physical_on = 7'b1111011;
            default: physical_on = 7'b0000000;
        endcase
    end

    assign seg_a = ~physical_on[4];
    assign seg_b = ~physical_on[0];
    assign seg_c = ~physical_on[3];
    assign seg_d = ~physical_on[2];
    assign seg_e = ~physical_on[6];
    assign seg_f = ~physical_on[5];
    assign seg_g = ~physical_on[1];
    assign dig0  = mux_select;
    assign dig1  = ~mux_select;

    // ========================================================================
    // OLED SSD1306 write-only I2C engine and display sequencer.
    // ========================================================================
    wire       oled_busy;
    reg        oled_start = 1'b0;
    reg        oled_dcn   = 1'b0;
    reg [7:0]  oled_data  = 8'd0;

    oled_i2c_writer oled_i2c (
        .clk(clk),
        .start(oled_start),
        .dcn(oled_dcn),
        .data_in(oled_data),
        .busy(oled_busy),
        .scl(scl),
        .sda(sda)
    );

    reg [22:0] oled_power_delay = 23'd5_999_999;
    reg [24:0] oled_wait        = 25'd0;
    reg [5:0]  oled_step        = 6'd0;
    reg [1:0]  oled_phase       = 2'd0;
    reg [6:0]  oled_col         = 7'd0;
    reg [1:0]  oled_page        = 2'd0;
    reg [12:0] oled_gap         = 13'd0;
    reg [6:0]  oled_font_col;
    reg [7:0]  oled_vsd_byte;

    always @(*) begin
        oled_font_col = 7'd0;
        if (oled_col >= 7'd26 && oled_col <= 7'd45) begin
            case ((oled_col - 7'd26) >> 2)
                3'd0: oled_font_col = 7'h0F;
                3'd1: oled_font_col = 7'h30;
                3'd2: oled_font_col = 7'h40;
                3'd3: oled_font_col = 7'h30;
                3'd4: oled_font_col = 7'h0F;
                default: oled_font_col = 7'd0;
            endcase
        end else if (oled_col >= 7'd54 && oled_col <= 7'd73) begin
            case ((oled_col - 7'd54) >> 2)
                3'd0: oled_font_col = 7'h26;
                3'd1: oled_font_col = 7'h49;
                3'd2: oled_font_col = 7'h49;
                3'd3: oled_font_col = 7'h49;
                3'd4: oled_font_col = 7'h32;
                default: oled_font_col = 7'd0;
            endcase
        end else if (oled_col >= 7'd82 && oled_col <= 7'd101) begin
            case ((oled_col - 7'd82) >> 2)
                3'd0: oled_font_col = 7'h7F;
                3'd1: oled_font_col = 7'h41;
                3'd2: oled_font_col = 7'h41;
                3'd3: oled_font_col = 7'h41;
                3'd4: oled_font_col = 7'h3E;
                default: oled_font_col = 7'd0;
            endcase
        end
    end

    always @(*) begin
        case (oled_page)
            2'd0: oled_vsd_byte = (oled_font_col[0] ? 8'h3C : 8'h00) |
                                  (oled_font_col[1] ? 8'hC0 : 8'h00);
            2'd1: oled_vsd_byte = (oled_font_col[1] ? 8'h03 : 8'h00) |
                                  (oled_font_col[2] ? 8'h3C : 8'h00) |
                                  (oled_font_col[3] ? 8'hC0 : 8'h00);
            2'd2: oled_vsd_byte = (oled_font_col[3] ? 8'h03 : 8'h00) |
                                  (oled_font_col[4] ? 8'h3C : 8'h00) |
                                  (oled_font_col[5] ? 8'hC0 : 8'h00);
            default: oled_vsd_byte = (oled_font_col[5] ? 8'h03 : 8'h00) |
                                     (oled_font_col[6] ? 8'h3C : 8'h00);
        endcase
    end

    wire [7:0] oled_pixel = (oled_phase == 2'd0) ?
                            (oled_page[0] ? 8'h00 : 8'hFF) :
                            (oled_phase == 2'd1) ?
                            (oled_page[0] ? 8'hFF : 8'h00) : oled_vsd_byte;

    always @(posedge clk) begin
        oled_start <= 1'b0;

        if (oled_power_delay != 0) begin
            oled_power_delay <= oled_power_delay - 1'b1;
            oled_step <= 6'd0;
        end else if (oled_gap != 0) begin
            oled_gap <= oled_gap - 1'b1;
        end else if (oled_busy) begin
            oled_gap <= 13'd10;
        end else begin
            case (oled_step)
                // SSD1306 initialization: 128x32, charge pump, display on.
                 0: begin oled_data<=8'hAE; oled_dcn<=0; oled_start<=1; oled_step<=1; oled_gap<=10; end
                 1: begin oled_data<=8'hD5; oled_dcn<=0; oled_start<=1; oled_step<=2; oled_gap<=10; end
                 2: begin oled_data<=8'h80; oled_dcn<=0; oled_start<=1; oled_step<=3; oled_gap<=10; end
                 3: begin oled_data<=8'hA8; oled_dcn<=0; oled_start<=1; oled_step<=4; oled_gap<=10; end
                 4: begin oled_data<=8'h1F; oled_dcn<=0; oled_start<=1; oled_step<=5; oled_gap<=10; end
                 5: begin oled_data<=8'hD3; oled_dcn<=0; oled_start<=1; oled_step<=6; oled_gap<=10; end
                 6: begin oled_data<=8'h00; oled_dcn<=0; oled_start<=1; oled_step<=7; oled_gap<=10; end
                 7: begin oled_data<=8'h40; oled_dcn<=0; oled_start<=1; oled_step<=8; oled_gap<=10; end
                 8: begin oled_data<=8'h8D; oled_dcn<=0; oled_start<=1; oled_step<=9; oled_gap<=10; end
                 9: begin oled_data<=8'h14; oled_dcn<=0; oled_start<=1; oled_step<=10; oled_gap<=10; end
                10: begin oled_data<=8'h20; oled_dcn<=0; oled_start<=1; oled_step<=11; oled_gap<=10; end
                11: begin oled_data<=8'h02; oled_dcn<=0; oled_start<=1; oled_step<=12; oled_gap<=10; end
                12: begin oled_data<=8'hA1; oled_dcn<=0; oled_start<=1; oled_step<=13; oled_gap<=10; end
                13: begin oled_data<=8'hC8; oled_dcn<=0; oled_start<=1; oled_step<=14; oled_gap<=10; end
                14: begin oled_data<=8'hDA; oled_dcn<=0; oled_start<=1; oled_step<=15; oled_gap<=10; end
                15: begin oled_data<=8'h02; oled_dcn<=0; oled_start<=1; oled_step<=16; oled_gap<=10; end
                16: begin oled_data<=8'h81; oled_dcn<=0; oled_start<=1; oled_step<=17; oled_gap<=10; end
                17: begin oled_data<=8'h8F; oled_dcn<=0; oled_start<=1; oled_step<=18; oled_gap<=10; end
                18: begin oled_data<=8'hD9; oled_dcn<=0; oled_start<=1; oled_step<=19; oled_gap<=10; end
                19: begin oled_data<=8'hF1; oled_dcn<=0; oled_start<=1; oled_step<=20; oled_gap<=10; end
                20: begin oled_data<=8'hDB; oled_dcn<=0; oled_start<=1; oled_step<=21; oled_gap<=10; end
                21: begin oled_data<=8'h40; oled_dcn<=0; oled_start<=1; oled_step<=22; oled_gap<=10; end
                22: begin oled_data<=8'hA4; oled_dcn<=0; oled_start<=1; oled_step<=23; oled_gap<=10; end
                23: begin oled_data<=8'hA6; oled_dcn<=0; oled_start<=1; oled_step<=24; oled_gap<=10; end
                24: begin oled_data<=8'h2E; oled_dcn<=0; oled_start<=1; oled_step<=25; oled_gap<=10; end
                25: begin oled_data<=8'hAF; oled_dcn<=0; oled_start<=1; oled_step<=26; oled_gap<=10; end

                // Set page and column address, then stream one page byte.
                26: begin oled_data<=8'hB0 | {6'd0,oled_page}; oled_dcn<=0; oled_start<=1; oled_step<=27; oled_gap<=10; end
                27: begin oled_data<=8'h00; oled_dcn<=0; oled_start<=1; oled_step<=28; oled_gap<=10; end
                28: begin oled_data<=8'h10; oled_dcn<=0; oled_start<=1; oled_step<=29; oled_gap<=10; end
                29: begin
                    oled_data  <= oled_pixel;
                    oled_dcn   <= 1'b1;
                    oled_start <= 1'b1;
                    oled_gap   <= 13'd10;
                    oled_col   <= oled_col + 1'b1;
                    if (oled_col == 7'd127) begin
                        oled_col <= 7'd0;
                        if (oled_page == 2'd3) begin
                            oled_page <= 2'd0;
                            if (oled_phase == 2'd2)
                                oled_step <= 6'd31;
                            else
                                oled_step <= 6'd30;
                        end else begin
                            oled_page <= oled_page + 1'b1;
                            oled_step <= 6'd26;
                        end
                    end
                end
                30: begin
                    if (oled_wait == 25'd11_999_999) begin
                        oled_wait  <= 25'd0;
                        oled_phase <= oled_phase + 1'b1;
                        oled_step  <= 6'd26;
                    end else begin
                        oled_wait <= oled_wait + 1'b1;
                    end
                end
                31: begin
                    // Hold the final VSD image.
                end
                default: oled_step <= 6'd0;
            endcase
        end
    end

    // ========================================================================
    // ADS1015 ADC on PMOD: SDA=pmod2, SCL=pmod4, RDY=pmod6.
    // The conversion engine runs independently of the LED display policy.
    // ========================================================================
    wire       adc_sda_in;
    wire       adc_sda_pull;
    wire       adc_busy;
    wire       adc_scl;
    wire [7:0] adc_read_data;
    reg        adc_go = 1'b0;
    reg [2:0]  adc_cmd = 3'd0;
    reg [7:0]  adc_write_data = 8'd0;
    reg [23:0] adc_delay = 24'd5_999_999;
    reg [4:0]  adc_step = 5'd0;
    reg        adc_wait_go = 1'b0;
    reg [7:0]  adc_msb = 8'd0;

    SB_IO #(
        .PIN_TYPE(6'b101001),
        .PULLUP(1'b1)
    ) ADC_SDA_IO (
        .PACKAGE_PIN(pmod2),
        .OUTPUT_ENABLE(adc_sda_pull),
        .D_OUT_0(1'b0),
        .D_IN_0(adc_sda_in)
    );

    assign pmod4 = adc_scl;

    adc_i2c_master adc_i2c (
        .clk(clk),
        .go(adc_go),
        .cmd(adc_cmd),
        .wdata(adc_write_data),
        .rdata(adc_read_data),
        .busy(adc_busy),
        .scl(adc_scl),
        .sda_pull(adc_sda_pull),
        .sda_in(adc_sda_in)
    );

    localparam [2:0] ADC_START = 3'd1;
    localparam [2:0] ADC_SEND  = 3'd2;
    localparam [2:0] ADC_RECV_ACK = 3'd3;
    localparam [2:0] ADC_RECV_NAK = 3'd4;
    localparam [2:0] ADC_STOP   = 3'd5;

    always @(posedge clk) begin
        adc_go <= 1'b0;
        if (adc_delay != 0) begin
            adc_delay <= adc_delay - 1'b1;
        end else if (adc_wait_go) begin
            adc_wait_go <= 1'b0;
        end else if (adc_busy) begin
            // The command engine owns the bus until busy goes low.
        end else begin
            case (adc_step)
                 0: begin adc_cmd<=ADC_START; adc_go<=1; adc_wait_go<=1; adc_step<=1; end
                 1: begin adc_cmd<=ADC_SEND; adc_write_data<=8'h90; adc_go<=1; adc_wait_go<=1; adc_step<=2; end
                 2: begin adc_cmd<=ADC_SEND; adc_write_data<=8'h01; adc_go<=1; adc_wait_go<=1; adc_step<=3; end
                 3: begin adc_cmd<=ADC_SEND; adc_write_data<=8'hC3; adc_go<=1; adc_wait_go<=1; adc_step<=4; end
                 4: begin adc_cmd<=ADC_SEND; adc_write_data<=8'h83; adc_go<=1; adc_wait_go<=1; adc_step<=5; end
                 5: begin adc_cmd<=ADC_STOP; adc_go<=1; adc_wait_go<=1; adc_step<=6; end
                 6: begin adc_delay<=24'd23_999; adc_step<=7; end
                 7: begin adc_cmd<=ADC_START; adc_go<=1; adc_wait_go<=1; adc_step<=8; end
                 8: begin adc_cmd<=ADC_SEND; adc_write_data<=8'h90; adc_go<=1; adc_wait_go<=1; adc_step<=9; end
                 9: begin adc_cmd<=ADC_SEND; adc_write_data<=8'h00; adc_go<=1; adc_wait_go<=1; adc_step<=10; end
                10: begin adc_cmd<=ADC_STOP; adc_go<=1; adc_wait_go<=1; adc_step<=11; end
                11: begin adc_cmd<=ADC_START; adc_go<=1; adc_wait_go<=1; adc_step<=12; end
                12: begin adc_cmd<=ADC_SEND; adc_write_data<=8'h91; adc_go<=1; adc_wait_go<=1; adc_step<=13; end
                13: begin adc_cmd<=ADC_RECV_ACK; adc_go<=1; adc_wait_go<=1; adc_step<=14; end
                14: begin adc_msb<=adc_read_data; adc_cmd<=ADC_RECV_NAK; adc_go<=1; adc_wait_go<=1; adc_step<=15; end
                15: begin adc_value<={adc_msb,adc_read_data[7:4]}; adc_cmd<=ADC_STOP; adc_go<=1; adc_wait_go<=1; adc_step<=16; end
                16: begin adc_delay<=24'd5_999_999; adc_step<=0; end
                default: adc_step <= 0;
            endcase
        end
    end

    // Keep the RDY input in the top-level interface for the documented PMOD
    // wiring.  The fixed conversion delay above also works with ADC modules
    // that do not route the ADS1015 ALERT/RDY signal.
    wire unused_adc_rdy = pmod6;

endmodule

// ============================================================================
// SSD1306 byte writer.  The OLED module has hardware pull-ups, so SDA is
// driven high/low directly as in the original repository OLED test.
// ============================================================================
module oled_i2c_writer (
    input        clk,
    input        start,
    input        dcn,
    input  [7:0] data_in,
    output reg   busy = 1'b0,
    output reg   scl  = 1'b1,
    output reg   sda  = 1'b1
);
    localparam [2:0] IDLE=0, START_BIT=1, ADDRESS=2,
                     CONTROL=3, DATA_BYTE=4, STOP_BIT=5;
    localparam [5:0] T_WAIT = 6'd30;
    reg [2:0] state = IDLE;
    reg [3:0] bit_index = 4'd0;
    reg [3:0] substep = 4'd0;
    reg [5:0] delay_count = 6'd1;
    reg       dcn_latched = 1'b0;
    reg [7:0] data_latched = 8'd0;
    reg [7:0] control_byte = 8'h00;
    reg [7:0] address_byte = 8'h78;

    always @(posedge clk) begin
        if (delay_count != 1) begin
            delay_count <= delay_count - 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    scl <= 1'b1;
                    sda <= 1'b1;
                    if (start) begin
                        dcn_latched  <= dcn;
                        data_latched <= data_in;
                        control_byte <= dcn ? 8'h40 : 8'h00;
                        busy         <= 1'b1;
                        state        <= START_BIT;
                        substep      <= 4'd0;
                    end
                end
                START_BIT: begin
                    case (substep)
                        0: begin sda<=0; delay_count<=T_WAIT; substep<=1; end
                        default: begin scl<=0; state<=ADDRESS; substep<=0; bit_index<=0; end
                    endcase
                end
                ADDRESS: begin
                    case (substep)
                        0: begin
                            if (bit_index < 8) begin scl<=0; substep<=1; end
                            else begin scl<=0; sda<=0; delay_count<=T_WAIT; bit_index<=bit_index+1; substep<=2; end
                        end
                        1: begin sda<=address_byte[7-bit_index]; delay_count<=T_WAIT-1; bit_index<=bit_index+1; substep<=2; end
                        2: begin
                            if (bit_index < 9) begin scl<=1; delay_count<=T_WAIT; substep<=0; end
                            else begin scl<=1; delay_count<=T_WAIT; substep<=3; end
                        end
                        3: begin scl<=0; sda<=0; delay_count<=T_WAIT; substep<=4; end
                        default: begin state<=CONTROL; substep<=0; bit_index<=0; end
                    endcase
                end
                CONTROL: begin
                    case (substep)
                        0: begin
                            if (bit_index < 8) begin scl<=0; substep<=1; end
                            else begin scl<=0; sda<=0; delay_count<=T_WAIT; bit_index<=bit_index+1; substep<=2; end
                        end
                        1: begin sda<=control_byte[7-bit_index]; delay_count<=T_WAIT-1; bit_index<=bit_index+1; substep<=2; end
                        2: begin
                            if (bit_index < 9) begin scl<=1; delay_count<=T_WAIT; substep<=0; end
                            else begin scl<=1; delay_count<=T_WAIT; substep<=3; end
                        end
                        3: begin scl<=0; sda<=0; delay_count<=T_WAIT; substep<=4; end
                        default: begin state<=DATA_BYTE; substep<=0; bit_index<=0; end
                    endcase
                end
                DATA_BYTE: begin
                    case (substep)
                        0: begin
                            if (bit_index < 8) begin scl<=0; substep<=1; end
                            else begin scl<=0; sda<=0; delay_count<=T_WAIT; bit_index<=bit_index+1; substep<=2; end
                        end
                        1: begin sda<=data_latched[7-bit_index]; delay_count<=T_WAIT-1; bit_index<=bit_index+1; substep<=2; end
                        2: begin
                            if (bit_index < 9) begin scl<=1; delay_count<=T_WAIT; substep<=0; end
                            else begin scl<=1; delay_count<=T_WAIT; substep<=3; end
                        end
                        3: begin scl<=0; sda<=0; delay_count<=T_WAIT; substep<=4; end
                        default: begin state<=STOP_BIT; substep<=0; end
                    endcase
                end
                default: begin
                    case (substep)
                        0: begin scl<=1; sda<=0; delay_count<=T_WAIT; substep<=1; end
                        default: begin sda<=1; state<=IDLE; busy<=0; substep<=0; end
                    endcase
                end
            endcase
        end
    end
endmodule

// ============================================================================
// Small command-driven I2C master for ADS1015.  SDA is open-drain and SCL is
// push-pull, matching the original ADC test in the repository.
// ============================================================================
module adc_i2c_master (
    input        clk,
    input        go,
    input  [2:0] cmd,
    input  [7:0] wdata,
    output reg [7:0] rdata = 8'd0,
    output reg   busy = 1'b0,
    output reg   scl = 1'b1,
    output reg   sda_pull = 1'b0,
    input        sda_in
);
    localparam [2:0] IDLE=0, START_CMD=1, SEND_CMD=2,
                     RECV_CMD=3, STOP_CMD=4;
    localparam [5:0] QUARTER = 6'd30;
    reg [2:0] state = IDLE;
    reg [2:0] phase = 3'd0;
    reg [5:0] delay_count = 6'd0;
    reg [3:0] bit_count = 4'd0;
    reg [7:0] shift_reg = 8'd0;
    reg       nack = 1'b0;

    always @(posedge clk) begin
        if (delay_count != 0) begin
            delay_count <= delay_count - 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    if (go) begin
                        busy  <= 1'b1;
                        phase <= 0;
                        case (cmd)
                            3'd1: state <= START_CMD;
                            3'd2: begin state<=SEND_CMD; shift_reg<=wdata; bit_count<=0; end
                            3'd3: begin state<=RECV_CMD; bit_count<=0; nack<=0; rdata<=0; end
                            3'd4: begin state<=RECV_CMD; bit_count<=0; nack<=1; rdata<=0; end
                            3'd5: state <= STOP_CMD;
                            default: busy <= 0;
                        endcase
                    end
                end
                START_CMD: begin
                    case (phase)
                        0: begin sda_pull<=0; scl<=1; delay_count<=QUARTER; phase<=1; end
                        1: begin sda_pull<=1; delay_count<=QUARTER; phase<=2; end
                        2: begin scl<=0; delay_count<=QUARTER; phase<=3; end
                        default: begin state<=IDLE; busy<=0; end
                    endcase
                end
                SEND_CMD: begin
                    case (phase)
                        0: begin sda_pull<=~shift_reg[7]; scl<=0; delay_count<=QUARTER; phase<=1; end
                        1: begin scl<=1; delay_count<=QUARTER; phase<=2; end
                        2: begin
                            scl<=0; shift_reg<={shift_reg[6:0],1'b0};
                            if (bit_count==7) begin delay_count<=QUARTER; phase<=3; end
                            else begin bit_count<=bit_count+1; delay_count<=QUARTER; phase<=0; end
                        end
                        3: begin sda_pull<=0; delay_count<=QUARTER; phase<=4; end
                        4: begin scl<=1; delay_count<=QUARTER; phase<=5; end
                        5: begin scl<=0; delay_count<=QUARTER; phase<=6; end
                        default: begin state<=IDLE; busy<=0; end
                    endcase
                end
                RECV_CMD: begin
                    case (phase)
                        0: begin sda_pull<=0; scl<=0; delay_count<=QUARTER; phase<=1; end
                        1: begin scl<=1; delay_count<=QUARTER; phase<=2; end
                        2: begin
                            rdata<={rdata[6:0],sda_in}; scl<=0;
                            if (bit_count==7) begin delay_count<=QUARTER; phase<=3; end
                            else begin bit_count<=bit_count+1; delay_count<=QUARTER; phase<=0; end
                        end
                        3: begin sda_pull<=~nack; delay_count<=QUARTER; phase<=4; end
                        4: begin scl<=1; delay_count<=QUARTER; phase<=5; end
                        5: begin scl<=0; delay_count<=QUARTER; phase<=6; end
                        default: begin sda_pull<=0; state<=IDLE; busy<=0; end
                    endcase
                end
                default: begin
                    case (phase)
                        0: begin sda_pull<=1; scl<=0; delay_count<=QUARTER; phase<=1; end
                        1: begin scl<=1; delay_count<=QUARTER; phase<=2; end
                        2: begin sda_pull<=0; delay_count<=QUARTER; phase<=3; end
                        default: begin state<=IDLE; busy<=0; end
                    endcase
                end
            endcase
        end
    end
endmodule
