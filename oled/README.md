# OLED Display Test

Drives a 0.91" SSD1306 OLED (128x32 pixels, white) over I2C.

Animation sequence:
1. Thick horizontal stripes (1 second)
2. Inverted stripes (1 second)
3. "VSD" text in large 4x scaled font (holds forever)

**Pins:** SDA = 37, SCL = 36 | **I2C address:** 0x3C

**Expected:** Stripe pattern alternates, then "VSD" appears and stays.
