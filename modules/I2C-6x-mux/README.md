# i2c-4x-mux

4-channel I²C sensor interface module with TCA9548A multiplexer for the FOSSDAQ system.

This module is designed for up to four BME280 sensors (temperature, relative humidity and air pressure) with digital I²C interface. It is based on an Arduino Nano 33 BLE Rev2 and communicates with the Raspberry Pi via USB.

## Status

- Development status: prototype
- Hardware version: v1.0
- Firmware status: defined separately
- Last updated: September 20, 2026

## Purpose

The `i2c-4x-mux` module is the I²C sensor card of the FOSSDAQ system. It is intended for simple and low-cost acquisition of digital I²C sensor data in educational and laboratory setups. The TCA9548A multiplexer provides separate I²C channels, so that several identical sensors can be operated on one card.

## Features

- 4 independent I²C sensor connections via TCA9548A multiplexer
- Designed for 4 × BME280 (temperature, relative humidity, air pressure)
- Digital I²C interface, no analog signal path
- Based on Arduino Nano 33 BLE Rev2
- 24 spring terminal positions (4 × 6-pole); 16 used for four sensors (VCC, GND, SCL, SDA per sensor), remaining positions available for additional I²C sensors
- Local 5 V generation from shared 24 V DC bus, shared 5 V sensor supply
- USB connection to Raspberry Pi for data only
- 3D-printed enclosure for TS-35 DIN rail mounting
- Spring terminal for 24 V bus input and pass-through to the next card

## Directory structure

- `hardware/` – CAD files (FreeCAD), exported print files (3MF/STL)
- `firmware/` – microcontroller code for this module
- `docs/` – build manual, BOM, technical documentation, test instructions
- `images/` – photos, renders and schematic

**BOM** stands for **Bill of Materials** and refers to the module's parts list.

## Build and assembly

1. Print the enclosure parts.
2. Prepare the perfboard sections.
3. Assemble the 24 V input and pass-through terminal block.
4. Build the sensor terminal carrier board (four 6-pole terminals, 2 mm gap to the board).
5. Solder the required connections to the Arduino Nano.
6. Connect the DC/DC converter and set its output to 5.0 V.
7. Install the electronics (Nano, TCA9548A, DC/DC converter) into the enclosure and wire the sensor terminals.
8. Connect the module to the Raspberry Pi via USB.
9. Perform the checks described in `docs/`.

## Interfaces

### Power
- Bus input: nominal 24 V DC
- Converter input range: 10–35 V DC (LM2596S module)
- Local logic/sensor supply: 5 V generated locally (adjusted to 5.0 V)
- Shared system ground: yes
- Galvanic isolation: no

### Data
- Interface to host: USB 2.0
- Connector: Micro-USB-B on Arduino Nano 33 BLE Rev2
- USB used as: data path only

### Signals
- Channel count: 4 (via TCA9548A)
- Interface: digital I²C (SDA/SCL); the sensor values are not connected to the analog inputs of the Arduino
- Terminal signals per sensor: VCC, GND, SCL, SDA
- Typical sensor type: BME280 (temperature, relative humidity, air pressure)

### Mechanics
- Mounting: TS-35 DIN rail
- Enclosure: 3D-printed
- Front connections: spring terminal blocks
- Bus connection: spring terminal block (24 V input/pass-through)

## Main components

- Arduino Nano 33 BLE Rev2
- TCA9548A I²C multiplexer (DEBO I2C-MULTI)
- 4 × BME280 I²C sensor (DEBO BME280)
- DEBO DCDC DOWN 5 DC/DC converter module (LM2596S)
- AST 025-06 spring terminal blocks for sensor connections
- AST 025-04 spring terminal block for 24 V bus input/pass-through
- Double-sided perfboard
- 3D-printed enclosure parts

## Files

Important project files for this module include:
- FreeCAD files for enclosure with DIN rail recess (`AI-Gehaeuse+Slate.FCStd`), cover (`AI-Deckel_v2.FCStd`) and DIN rail latch pin (`AI-Stift.FCStd`)
- Schematic of the I²C multiplexer card
- BOM for components and wiring
- Build and test documentation

## Intended use and limitations

This module is intended for educational, demonstrator, and laboratory use in controlled environments. The design prioritizes simplicity, low cost, and ease of reproduction over maximum electrical robustness. The module uses a shared ground and does not include galvanic isolation. Additional protection, filtering, and EMC measures may be required for use in harsher environments or outside supervised lab settings.

## Contributors

- Philip Hauser
- Vincent Böhmer
- Supervision: Prof. Dr. Peter Stein, HTWG Konstanz

## License

Hardware design files in this module are licensed under **CERN-OHL-W-2.0**.  
Firmware and software are licensed under **GPL-3.0-or-later**.  
Documentation is licensed under **CC-BY-SA-4.0**.

See the repository root license files for details.
