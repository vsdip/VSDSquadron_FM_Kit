# ==============================================================================
#  VSDSquadron FM Kit - Shared Build Rules
#  Toolchain: Yosys + nextpnr-ice40 + IceStorm
#  Target:    Lattice iCE40 UP5K (SG48)
#
#  Usage: Each project Makefile sets TOP and VERILOG_FILES, then includes this.
# ==============================================================================

# --- FPGA defaults (can be overridden per-project) ---
BOARD_FREQ   ?= 12
FPGA_VARIANT ?= up5k
FPGA_PACKAGE ?= sg48

# --- Paths ---
# Locate this Makefile's directory (= repo root) regardless of where make runs
ROOT_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
PCF_FILE ?= $(ROOT_DIR)VSDSquadronFM.pcf

# ==============================================================================
#  Build targets
# ==============================================================================

build:
	@echo "=== Synthesising $(TOP) ==="
	yosys -q -p "synth_ice40 -abc9 -device u -dsp -top $(TOP) -json $(TOP).json" $(VERILOG_FILES)
	@echo "=== Place & Route ==="
	nextpnr-ice40 --force --json $(TOP).json --pcf $(PCF_FILE) \
		--asc $(TOP).asc --freq $(BOARD_FREQ) --$(FPGA_VARIANT) \
		--package $(FPGA_PACKAGE) --opt-timing -q
	@echo "=== Timing Analysis ==="
	icetime -p $(PCF_FILE) -P $(FPGA_PACKAGE) -r $(TOP).timings \
		-d $(FPGA_VARIANT) -t $(TOP).asc
	@echo "=== Packing Bitstream ==="
	icepack -s $(TOP).asc $(TOP).bin
	@echo "=== Done! Flash with: make flash ==="

flash:
	iceprog $(TOP).bin

clean:
	rm -f $(TOP).json $(TOP).asc $(TOP).bin $(TOP).timings $(TOP).blif

.PHONY: build flash clean
