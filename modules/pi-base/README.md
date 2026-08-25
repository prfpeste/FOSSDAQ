# pi-base

Central Raspberry Pi rail module for the FOSSDAQ system.

This module hosts the Raspberry Pi 5 as the central unit of the system, provides integration on a TS-35 DIN rail, converts the shared 24 V bus to 5 V locally, and serves as the data hub for connected measurement cards via USB.

## Status

- Development status: prototype
- Hardware version: v1.0
- Firmware version: v1.0
- Last updated: August 25, 2026

## Purpose

The `pi-base` module is the central master unit of the FOSSDAQ platform. It is intended for educational and laboratory use and provides the mechanical, electrical, and communication backbone for modular measurement cards.

## Features

- Raspberry Pi 5 based central unit
- Mounting on TS-35 DIN rail
- Local 5 V generation from shared 24 V DC bus
- 3D-printed enclosure with side cover and rail latch
- Front access to USB and Ethernet ports
- Active cooling via Raspberry Pi active cooler
- Designed for open-source reproduction and modification

## Directory structure

- `hardware/` – KiCad files, CAD files, exported manufacturing files
- `firmware/` – optional scripts or module-specific setup files
- `docs/` – build notes, technical documentation, test instructions
- `bom/` – parts list for the module
- `images/` – photos and renders

**BOM** stands for **Bill of Materials** and refers to the module's parts list.

## Build and assembly

1. Print the enclosure parts.
2. Assemble the DIN rail latch and side cover.
3. Install the Raspberry Pi 5 and active cooler.
4. Build the 24 V input and pass-through terminal assembly.
5. Connect the 24 V input to the REG5V5A step-down converter.
6. Feed the generated 5 V to the Raspberry Pi.
7. Close the enclosure and perform the checks described in `docs/`.
8. follow the instructions in `docs/how_to_setup.md`.

## Interfaces

### Power
- Bus input: 24 V DC ± 5 %
- Local logic voltage: 5 V generated locally from the 24 V bus
- Shared system ground: yes

### Data
- Host system: Raspberry Pi 5
- USB used as: data connection to measurement cards
- Ethernet: available on front side
- USB power distribution to cards: not intended

### Mechanics
- Mounting: TS-35 DIN rail
- Enclosure: 3D-printed
- Cooling: active CPU cooler, enclosure ventilation openings

## Main components

- Raspberry Pi 5 (1 GB RAM minimum, 2 GB RAM recommended)
- Official Raspberry Pi active cooler
- Optional RTC battery
- REG5V5A DC/DC converter module
- AST 025-04 spring terminal block for 24 V input and pass-through
- 3D-printed enclosure parts

## Files

Important project files for this module include:
- FreeCAD files for enclosure, cover, DIN rail latch, and assembly
- 3MF export files for printing
- KiCad schematic page for the 24 V supply concept
- Module-specific BOM and build documentation

## Intended use and limitations

This module is intended for supervised educational and laboratory environments. The design prioritizes simplicity, low cost, accessibility, and ease of reproduction over maximum ruggedness. Additional protection, isolation, or EMC measures may be required for use in industrial or electrically harsh environments.

## Contributors

- Jürgen Altemeier
- Patrick Uitz
- Alexander Gschlecht

## License

Hardware design files in this module are licensed under **CERN-OHL-W-2.0**.  
Firmware and software are licensed under **GPL-3.0-or-later**.  
Documentation is licensed under **CC-BY-SA-4.0**.

See the repository root license files for details.
