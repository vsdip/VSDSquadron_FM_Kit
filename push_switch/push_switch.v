// =============================================================================
//  Push Switch Test — VSDSquadron FM Kit
//
//  4 push switches, each controlling one LED.
//  Press a switch → corresponding LED lights up.
//
//  NOTE: Switches are active-high (pressed = HIGH).
//        LEDs are active-low (LOW = ON).
//        So we invert: led = ~sw.
// =============================================================================

module push_switch (
    // LEDs (active-low)
    output wire led0,       // LED 1
    output wire led1,       // LED 2
    output wire led2,       // LED 3
    output wire led3,       // LED 4
    // Switches (active-high)
    input  wire sw0,        // Switch 1
    input  wire sw1,        // Switch 2
    input  wire sw2,        // Switch 3
    input  wire sw3         // Switch 4
);

    // Invert: switch HIGH (pressed) → LED LOW (on)
    assign led0 = ~sw0;
    assign led1 = ~sw1;
    assign led2 = ~sw2;
    assign led3 = ~sw3;

endmodule
