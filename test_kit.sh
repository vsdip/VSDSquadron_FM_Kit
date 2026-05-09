#!/bin/bash
# ==============================================================================
#  VSDSquadron FM Kit — Board Test Script
#  Builds and flashes each test, waits for user confirmation between tests.
# ==============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
TOTAL=9

bold="\033[1m"
yellow="\033[33m"
cyan="\033[36m"
reset="\033[0m"

flash_test() {
    local dir="$1"
    local name="$2"
    local expect="$3"

    echo ""
    echo -e "${bold}${cyan}===== TEST: $name =====${reset}"
    echo -e "${yellow}Building...${reset}"
    make -C "$SCRIPT_DIR/$dir" clean build

    echo -e "${yellow}Flashing...${reset}"
    sudo make -C "$SCRIPT_DIR/$dir" flash

    echo ""
    echo -e "${bold}EXPECTED:${reset} $expect"
    echo ""
    read -rp "Did it pass? [Y/n] " answer
    if [[ "$answer" =~ ^[Nn] ]]; then
        echo -e "  ❌ $name — FAILED"
    else
        echo -e "  ✅ $name — PASSED"
        PASS=$((PASS + 1))
    fi
}

echo -e "${bold}=====================================${reset}"
echo -e "${bold}  VSDSquadron FM Kit — Board Tester${reset}"
echo -e "${bold}=====================================${reset}"
echo ""
echo "This script will flash 9 tests one by one."
echo "Make sure the board is connected via USB."
echo ""
read -rp "Press ENTER to start... "

# --- Test 1: LED Counter ---
flash_test "led_counter" "LED Counter" \
    "4 LEDs count up in binary (0-15), each step ~0.5 seconds."

# --- Test 2: Buzzer ---
flash_test "buzzer" "Buzzer" \
    "Buzzer plays a continuous 1 kHz tone."

# --- Test 3: Push Switches ---
flash_test "push_switch" "Push Switches" \
    "Press each of the 4 switches — its paired LED should light up."

# --- Test 4: RGB LED ---
flash_test "rgb_led" "RGB LED" \
    "RGB LED cycles: Red → Green → Blue → Yellow → Cyan → Magenta → White (1s each)."

# --- Test 5: Servo Motor ---
flash_test "servo" "Servo Motor (360°)" \
    "Servo spins CW 3s → stop 1s → CCW 3s → stop 1s, repeating."

# --- Test 6: Toggle Switches ---
flash_test "toggle_switch" "Toggle Switches" \
    "Toggle SW1 (pin 4) → buzzer ON/OFF. Toggle SW2 (pin 6) → servo CW/stop/CCW."

# --- Test 7: 7-Segment Display ---
flash_test "seven_seg" "7-Segment Display" \
    "2-digit display counts 00 → 99, incrementing every 0.5 seconds."

# --- Test 8: OLED Display ---
flash_test "oled" "OLED Display" \
    "OLED shows thick stripes (1s) → inverted stripes (1s) → \"VSD\" text (holds)."

# --- Test 9: ADC ---
flash_test "adc" "ADC (ADS1015)" \
    "LEDs show level bar from AIN0 reading. Vary input voltage — more LEDs = higher voltage."

# --- Summary ---
echo ""
echo -e "${bold}=====================================${reset}"
echo -e "${bold}  Results: $PASS / $TOTAL passed${reset}"
echo -e "${bold}=====================================${reset}"

# --- Flash default clean state ---
echo ""
echo -e "${bold}${cyan}Flashing default clean state...${reset}"
make -C "$SCRIPT_DIR/default_state" clean build
sudo make -C "$SCRIPT_DIR/default_state" flash
echo -e "${bold}Board is now in default clean state (all outputs OFF).${reset}"
