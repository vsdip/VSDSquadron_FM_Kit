# 7-Segment Display Diagnostic

This folder currently contains a diagnostic build, not a working `00` to `99`
counter.

Board testing showed that the documented 7-segment mapping in this repo does
not match the observed hardware behavior.

Observed with the current board/constraint setup:

**Documented `seg_a` / pin 32:** physical `A`  
**Documented `seg_b` / pin 31:** physical `E`  
**Documented `seg_c` / pin 28:** physical `D`  
**Documented `seg_d` / pin 27:** decimal point (`DP`)  
**Documented `seg_e` / pin 26:** physical `C`  
**Documented `seg_f` / pin 25:** no visible output  
**Documented `seg_g` / pin 23:** no visible output

**Digits:** pins `34` and `35` appear to behave as active-low digit enables.

**Current behavior:** both digits are enabled and the confirmed visible outputs
above are stepped one at a time every 0.5 seconds with an `off` gap between
them.

Use this only for hardware verification until the real board schematic or
correct segment pinout is available.

CHANGE - 7-Segment (2-digit) Segment pins: 32, 31, 28, 27, 26, 25, 23; dig0/tens=35, dig1/ones=34. Active-low segments and digits. The seven_seg demo remaps the board/ribbon segment order to logical A-G. DP not connected.

