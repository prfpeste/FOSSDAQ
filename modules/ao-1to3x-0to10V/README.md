# ao-1to3x-0to10V

1to3-channel analog output module for the FOSSDAQ system.

This module is designed for actors with 0to10 V supply. It is based on an Arduino Nano and communicates with the Raspberry Pi via USB.

## Status

- Development status: prototype
- Hardware version: v1.0
- Firmware version: v1.0
- Last updated: September 7th, 2026

## Purpose

The `ao-1to3x-0to10V` module is the first fully developed analog output card of the FOSSDAQ system. It is intended for simple and low-cost control of devices with an analog input in educational and laboratory setups.

## Features

- 1to3 analog output channels
- Designed for 0to10 V signal output
- Based on Arduino Nano R4
- 12-bit DAC via SPI
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
4. Build the PCBs and the terminal carrier board.
5. Solder the required connections to the Arduino Nano.
6. Connect the LM2596S power converter.
7. Install the electronics into the enclosure.
8. Connect the module to the Raspberry Pi via USB.
9. Perform the checks described in `docs/`.

## Interfaces

### Power
- Bus input: nominal 24 V DC
- Converter input range: 10–35 V DC (LM2596S module)
- Local logic/sensor supply: 10 V generated locally
- Shared system ground: yes
- Galvanic isolation: no

### Data
- Interface to host: USB 2.0
- Connector: USB-c on Arduino Nano R4
- USB used as: data path only

### Signals
- Channel count: 1to3
- Input pins: see documentation
- Signal range: 0to10 V

### Mechanics
- Mounting: TS-35 DIN rail
- Enclosure: 3D-printed
- Front connections: spring terminal blocks

## Main components

- Arduino Nano R4
- LM2596S DC/DC converter module
- AST 025-06 spring terminal blocks for sensor connections
- AST 025-04 spring terminal blocks for 24 V bus input/pass-through
- Double-sided perfboard
- self soldered PCB 
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

- Alexander Gschlecht

## License

Hardware design files in this module are licensed under **CERN-OHL-W-2.0**.  
Firmware and software are licensed under **GPL-3.0-or-later**.  
Documentation is licensed under **CC-BY-SA-4.0**.

See the repository root license files for details.
