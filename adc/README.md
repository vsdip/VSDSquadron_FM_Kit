# ADC Test

Reads ADS1015DGC 12-bit ADC on PMOD header via I2C.
Displays voltage level on 4 LEDs as a bar indicator.

- **Channel:** AIN0 (single-ended vs GND)
- **Range:** 0–3.3 V (PGA ±4.096 V)
- **Rate:** Single-shot, updates every ~500 ms
- **Display:** LED level bar — more voltage, more LEDs lit

**PMOD Pins:** SDA = pmod2 (pin 42), SCL = pmod4 (pin 44), RDY = pmod6 (pin 46)
**I2C Address:** 0x48 (ADDR to GND)
