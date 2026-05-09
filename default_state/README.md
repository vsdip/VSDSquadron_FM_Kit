# Default Clean State

Flashed after all tests to leave the board in a quiet state.

All LEDs, buzzer, servo, 7-segment, RGB LED, and OLED display are turned OFF.
The OLED receives a Display OFF (0xAE) command via I2C to ensure it goes dark.
