## Available modules

- `pi-base` – central Raspberry Pi carrier and rail module
- `ai-8x-0to3v3` – 8-channel analog input card for 5 V sensors with 0–3.3 V output
- `ai-8x-5V` – 8-channel analog input card for 5 V sensors with 0–5 V output
- `ai-4x-tck` – 4-channel Type-K thermocouple input card (one AD8495 amplifier per channel)
- `ao-3x-0to10V` – 3-channel analog output card with 0–10 V output (12-bit DAC)
- `do-6x-PWM` – 6-channel digital output card with PWM or on/off switching per channel (up to 20 V)
- `I2C-6x-mux` – 6-channel I²C sensor interface card with I²C multiplexer

The Arduino-based cards are powered from the shared 24 V DC bus, communicate with the Raspberry Pi via USB and are mounted on a TS-35 DIN rail. Each module folder contains its own `docs/` (build instructions and BOM), `firmware/` and `images/`.


## License

Hardware files in this module are licensed under CERN-OHL-W-2.0.  
Firmware/software is licensed under GPL-3.0.  
Documentation is licensed under CC-BY-SA-4.0.
