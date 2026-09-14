# VSDSquadron FM Kit

Test and demo codes for the VSDSquadron FM Kit board, built around the Lattice iCE40 UP5K FPGA (SG48 package). Each folder contains a standalone test for one peripheral, written in minimal, well-commented Verilog targeted at learners.

## Toolchain Installation

Install the open-source iCE40 FPGA toolchain:

```bash
sudo apt-get install -y fpga-icestorm yosys nextpnr-ice40
```

This provides:
- **Yosys** — Verilog synthesis
- **nextpnr-ice40** — Place and route
- **IceStorm** — Bitstream packing (`icepack`) and flashing (`iceprog`)

## Board Peripherals

| Peripheral | Pins | Notes |
|---|---|---|
| 4 LEDs | 13, 18, 19, 21 | Active-low (0 = ON) |
| Buzzer | 2 | |
| 4 Push Switches | 9, 10, 11, 12 | Active-high (1 = pressed) |
| 2 Toggle Switches | 4, 6 | Active-high, default OFF |
| RGB LED | 39, 40, 41 | Directly connected to `SB_RGBA_DRV` hard IP |
| SG90 Servo (360°) | 3 | Continuous rotation, 50 Hz PWM |
| 0.91" OLED (SSD1306) | SDA=37, SCL=36 | 128x32, I2C, address 0x3C |
| 7-Segment (2-digit) | A=32 B=31 C=28 D=27 E=26 F=25 G=23, dig1=34 dig2=35 | Documented mapping only. Board test found mismatches: 32->A, 31->E, 28->D, 27->DP, 26->C, 25/23 no visible output. Verify hardware before using as numeric display. |
| PMOD Header (8-pin) | 38, 42, 43, 44, 45, 46, 47, 48 | General-purpose, active ADC connected on pmod2/4/6 |

**Common notes:**
- All designs use the internal 48 MHz oscillator (`SB_HFOSC`), divided down as needed — no external crystal required.
- The RGB LED uses the `SB_RGBA_DRV` hard IP primitive; its pins (39, 40, 41) cannot be directly driven as regular GPIO.
- The global pin constraint file `VSDSquadronFM.pcf` contains all pin assignments. Unmatched pin warnings during build are normal and harmless.
- Flashing requires `sudo` (for `iceprog` USB access).

## Tests

Each test lives in its own folder with a `Makefile` and `README.md`.

| # | Folder | Description |
|---|---|---|
| 1 | `led_counter/` | 4-bit binary counter on LEDs, 0.5s per step |
| 2 | `buzzer/` | Continuous 1 kHz tone |
| 3 | `push_switch/` | Each push switch lights its paired LED |
| 4 | `rgb_led/` | Cycles 7 colors: R, G, B, Y, C, M, W (1s each) |
| 5 | `servo/` | 360° servo: CW 3s, stop 1s, CCW 3s, stop 1s |
| 6 | `toggle_switch/` | SW1 toggles buzzer, SW2 toggles servo |
| 7 | `seven_seg/` | 2-digit counter 00–99, 0.5s per step |
| 8 | `oled/` | Stripe animation then "VSD" text on OLED |
| 9 | `adc/` | ADS1015 ADC on PMOD, voltage level shown on LEDs |
| — | `default_state/` | All outputs OFF (flashed after tests) |

### Build and flash a single test

```bash
cd led_counter
make clean build
sudo make flash
```

This works for any test folder. Each project's Makefile includes the shared build rules from the root `Makefile`.

### Run all tests

The `test_kit.sh` script builds, flashes, and walks through all 9 tests one by one, showing expected behaviour and asking for pass/fail confirmation. After all tests, it flashes the default clean state.

```bash
chmod +x test_kit.sh
sudo ./test_kit.sh
```

At the end, a summary shows how many tests passed out of 9 and the board is left in its default clean state.

## Unified Automatic Peripheral Demonstration

The unified Verilog design runs the following tests simultaneously:

* Servo CW, stop, and CCW cycle
* 7-segment display counter from 00 to 99
* OLED SSD1306 animation followed by “VSD” display
* RGB LED colour cycle
* 1 kHz buzzer
* Push-switch LED indication
* LED binary counter
* ADS1015 ADC level display
* Shared 12 MHz oscillator for lower LUT usage

### Toggle Switch Behaviour

* Toggle Switch 1 ON: Buzzer enabled
* Toggle Switch 1 OFF: Buzzer disabled
* Toggle Switch 2 ON: Servo motor runs automatically
* Toggle Switch 2 OFF: Servo motor stops

### Build and Flash

Copy `unified_test_kit.v` to the repository root and run:

```bash
make TOP=unified_test_kit VERILOG_FILES=unified_test_kit.v build
sudo make TOP=unified_test_kit flash
```

The design uses the existing `VSDSquadronFM.pcf` pin constraint file.

After flashing once, all tests start automatically whenever the board is powered through USB.

The source has passed static checks. Exact LUT usage must be verified using the Yosys and nextpnr toolchain. Confirm that the final build reports resource usage below the UP5K’s approximately 5.3K LUT capacity.

