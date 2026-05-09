// =============================================================================
//  I2C Master — read/write, open-drain SDA
//
//  Commands: START(1), SEND(2), RECV_ACK(3), RECV_NACK(4), STOP(5)
//  SDA is open-drain: sda_pull=1 drives low, sda_pull=0 releases (pullup)
//  SCL is push-pull (single master, no clock stretching)
// =============================================================================

module i2c_rw (
    input        clk,
    input        go,            // pulse to begin command
    input  [2:0] cmd,
    input  [7:0] wdata,         // byte to send (SEND cmd)
    output reg [7:0] rdata = 0, // byte received (RECV cmds)
    output reg   busy = 0,
    output reg   scl  = 1,
    output reg   sda_pull = 0,  // 1=drive low, 0=release
    input        sda_in
);

    localparam T = 30;          // quarter-period (~100 kHz at 12 MHz)

    reg [5:0] dly  = 0;
    reg [3:0] bcnt = 0;
    reg [7:0] sr   = 0;
    reg       nack = 0;
    reg [2:0] st   = 0;
    reg [2:0] ph   = 0;

    localparam S_IDLE=0, S_START=1, S_SEND=2, S_RECV=3, S_STOP=4;

    always @(posedge clk) begin
        if (dly != 0) begin
            dly <= dly - 1;
        end else begin
            case (st)

            S_IDLE: begin
                if (go) begin
                    busy <= 1;
                    ph   <= 0;
                    case (cmd)
                        3'd1: st <= S_START;
                        3'd2: begin st <= S_SEND; sr <= wdata; bcnt <= 0; end
                        3'd3: begin st <= S_RECV; bcnt <= 0; nack <= 0; rdata <= 0; end
                        3'd4: begin st <= S_RECV; bcnt <= 0; nack <= 1; rdata <= 0; end
                        3'd5: st <= S_STOP;
                        default: busy <= 0;
                    endcase
                end
            end

            // START: SDA↓ while SCL high, then SCL↓
            S_START: case (ph)
                0: begin sda_pull<=0; scl<=1; dly<=T; ph<=1; end
                1: begin sda_pull<=1; dly<=T; ph<=2; end
                2: begin scl<=0; dly<=T; ph<=3; end
                3: begin st<=S_IDLE; busy<=0; end
            endcase

            // SEND: 8 bits MSB-first, then read ACK
            S_SEND: case (ph)
                0: begin sda_pull <= ~sr[7]; scl<=0; dly<=T; ph<=1; end
                1: begin scl<=1; dly<=T; ph<=2; end
                2: begin scl<=0; sr<={sr[6:0],1'b0};
                    if (bcnt==4'd7) begin dly<=T; ph<=3; end
                    else begin bcnt<=bcnt+1; dly<=T; ph<=0; end
                end
                // ACK clock
                3: begin sda_pull<=0; dly<=T; ph<=4; end    // release SDA
                4: begin scl<=1; dly<=T; ph<=5; end
                5: begin scl<=0; dly<=T; ph<=6; end
                6: begin st<=S_IDLE; busy<=0; end
            endcase

            // RECV: 8 bits MSB-first, then send ACK/NACK
            S_RECV: case (ph)
                0: begin sda_pull<=0; scl<=0; dly<=T; ph<=1; end  // release SDA
                1: begin scl<=1; dly<=T; ph<=2; end
                2: begin rdata<={rdata[6:0], sda_in}; scl<=0;
                    if (bcnt==4'd7) begin dly<=T; ph<=3; end
                    else begin bcnt<=bcnt+1; dly<=T; ph<=0; end
                end
                // ACK/NACK
                3: begin sda_pull <= ~nack; dly<=T; ph<=4; end  // ACK=pull low, NACK=release
                4: begin scl<=1; dly<=T; ph<=5; end
                5: begin scl<=0; dly<=T; ph<=6; end
                6: begin sda_pull<=0; st<=S_IDLE; busy<=0; end
            endcase

            // STOP: SDA↑ while SCL high
            S_STOP: case (ph)
                0: begin sda_pull<=1; scl<=0; dly<=T; ph<=1; end
                1: begin scl<=1; dly<=T; ph<=2; end
                2: begin sda_pull<=0; dly<=T; ph<=3; end
                3: begin st<=S_IDLE; busy<=0; end
            endcase

            endcase
        end
    end

endmodule
