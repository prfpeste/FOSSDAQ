# ai-8x-0to3v3

8-channel analog input module for the FOSSDAQ system.

This module is designed for sensors with 5 V supply and analog output signals in the range of 0–3.3 V. It is based on an Arduino Nano and communicates with the Raspberry Pi via USB.

## Status

- Development status: prototype
- Hardware version: v1.0
- Firmware status: defined separately
- Last updated: June 19, 2026

## Purpose

The `ai-8x-0to3v3` module is the first fully developed analog measurement card of the FOSSDAQ system. It is intended for simple and low-cost acquisition of analog sensor signals in educational and laboratory setups.

## Features

- 8 analog input channels
- Designed for 5 V powered sensors with 0–3.3 V signal output
- Based on Arduino Nano 33 BLE Rev2 or Arduino Nano R4
- 12-bit ADC via analog pins A0–A7
- Local 5 V generation from shared 24 V DC bus
- USB connection to Raspberry Pi for data only
- 3D-printed enclosure for TS-35 DIN rail mounting
- Spring terminal connections for sensor wiring

## Directory structure

- `hardware/` – KiCad files, CAD files, exported manufacturing files
- `firmware/` – microcontroller code for this module
- `docs/` – build notes, technical documentation, test instructions
- `bom/` – parts list for the module
- `images/` – photos and renders

**BOM** stands for **Bill of Materials** and refers to the module's parts list.

## Build and assembly

1. Print the enclosure parts.
2. Prepare the perfboard sections.
3. Assemble the 24 V input and pass-through terminal block.
4. Build the sensor terminal carrier board.
5. Solder the required connections to the Arduino Nano.
6. Connect the LM2596S power converter.
7. Install the electronics into the enclosure.
8. Connect the module to the Raspberry Pi via USB.
9. Perform the checks described in `docs/`.

## Interfaces

### Power
- Bus input: nominal 24 V DC
- Converter input range: 10–35 V DC (LM2596S module)
- Local logic/sensor supply: 5 V generated locally
- Shared system ground: yes
- Galvanic isolation: no

### Data
- Interface to host: USB 2.0
- Connector: Micro-USB-B on Arduino Nano 33 BLE Rev2
- USB used as: data path only

### Signals
- Channel count: 8
- Input pins: A0–A7
- Signal range: 0–3.3 V
- Typical sensor type: pressure or flow sensors with active 5 V supply

### Mechanics
- Mounting: TS-35 DIN rail
- Enclosure: 3D-printed
- Front connections: spring terminal blocks

## Main components

- Arduino Nano 33 BLE Rev2
- Optional alternative: Arduino Nano R4
- LM2596S DC/DC converter module
- AST 025-06 spring terminal blocks for sensor connections
- AST 025-04 spring terminal blocks for 24 V bus input/pass-through
- Double-sided perfboard
- 3D-printed enclosure parts

## Files

Important project files for this module include:
- FreeCAD files for enclosure, cover, DIN rail latch, and assembly
- KiCad schematic page for the analog input card
- BOM for components and wiring
- Build and test documentation

## Intended use and limitations

This module is intended for educational, demonstrator, and laboratory use in controlled environments. The design prioritizes simplicity, low cost, and ease of reproduction over maximum electrical robustness. The module uses a shared ground and does not include galvanic isolation. Additional protection, filtering, and EMC measures may be required for use in harsher environments or outside supervised lab settings.

## Contributors

- Jürgen Altemeier
- Patrick Uitz

## License

Hardware design files in this module are licensed under **CERN-OHL-W-2.0**.  
Firmware and software are licensed under **GPL-3.0-or-later**.  
Documentation is licensed under **CC-BY-SA-4.0**.

See the repository root license files for details.
