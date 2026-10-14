# di-4x-5V

4-channel digital input module for the FOSSDAQ system.

This module is designed for sensors with digital pulse output signals up to 5 V. It is based on an Arduino Nano R4 and communicates with the Raspberry Pi via USB.

## Status

- Development status: prototype
- Hardware version: v1.0
- Firmware status: defined separately
- Last updated: October 3, 2026

## Purpose

The `di-4x-5V` module is a digital input measurement card for the FOSSDAQ system.

It is intended for the acquisition of pulse and frequency signals from digital sensors, such as Hall-effect flow sensors. Each sensor connection provides terminals for supply voltage, ground, and signal.

The Arduino Nano R4 detects the incoming pulses and transfers the measured values to the Raspberry Pi. Further processing and conversion into physical quantities, such as flow rate, can be performed on the Raspberry Pi.

## Features

- 4 digital input channels
- Designed for digital pulse signals up to 5 V
- Suitable for sensors with TTL-compatible output signals
- Based on Arduino Nano R4
- Digital input pins D2, D3, D8, and D12
- Sensor supply provided by an adjustable DC/DC converter
- Shared 24 V DC bus input and pass-through
- USB connection to Raspberry Pi
- 3D-printed enclosure for TS-35 DIN rail mounting
- Spring terminal connections for sensor wiring
- Sensor conversion can be handled externally on the Raspberry Pi

## Directory structure

- `hardware/` – KiCad, FreeCAD, and 3D-print files
- `firmware/` – Arduino firmware for the module
- `docs/` – technical documentation, connector labels, and additional documentation
- `bom/` – Bill of Materials for the module
- `images/` – photos and images of the assembled module

**BOM** stands for **Bill of Materials** and refers to the module's parts list.

## Build and assembly

1. Print the required enclosure parts.
2. Prepare the perfboard sections.
3. Assemble the 24 V input and pass-through terminal block.
4. Assemble the sensor terminal connections.
5. Connect the digital signal lines to pins D2, D3, D8, and D12 of the Arduino Nano R4.
6. Connect the sensor supply and ground lines.
7. Install and configure the LM2596S DC/DC converter.
8. Install the electronics into the enclosure.
9. Attach the connector labels as described in `docs/`.
10. Connect the module to the Raspberry Pi via USB.
11. Perform the required functional checks before connecting sensors.

## Interfaces

### Power

- Bus input: nominal 24 V DC
- DC/DC converter: LM2596S step-down converter
- Converter output: adjustable
- Arduino supply: via VIN
- Maximum converter output when supplying the Arduino Nano R4: 21 V
- Shared system ground: yes
- Galvanic isolation: no

The DC/DC converter supplies both the Arduino Nano R4 and the connected sensors. The converter output voltage must therefore be selected according to the requirements of the connected sensors and must not exceed the allowable input voltage of the Arduino Nano R4.

### Data

- Interface to host: USB
- Connector: USB-C on Arduino Nano R4
- Host system: Raspberry Pi
- Data processing: serial communication between Arduino and Raspberry Pi

### Signals

- Channel count: 4
- Input pins: D2, D3, D8, and D12
- Signal type: digital pulse / frequency signal
- Maximum signal level: 5 V
- Typical sensor connection:
  - supply voltage
  - ground
  - signal
- Typical sensor type: Hall-effect flow sensors and other sensors with digital pulse output

The module transfers the measured pulse or frequency values without applying a sensor-specific conversion. Conversion into physical quantities can therefore be configured separately on the Raspberry Pi for different sensor types.

### Mechanics

- Mounting: TS-35 DIN rail
- Enclosure: 3D-printed
- Rail mount: external slate
- Front connections: spring terminal blocks

## Main components

- Arduino Nano R4
- LM2596S DC/DC step-down converter with display
- AST 025-06 spring terminal blocks for sensor connections
- AST 025-04 spring terminal block for 24 V bus input and pass-through
- Double-sided perfboard
- USB-A to USB-C data cable
- 3D-printed enclosure parts

## Files

Important project files for this module include:

- FreeCAD files for the enclosure components and assembly
- STL files for universal 3D printing
- 3MF files prepared for slicers such as Bambu Studio and PrusaSlicer
- KiCad project and schematic files
- Arduino firmware
- Human-readable and machine-readable BOM
- Connector labels
- Photos and documentation of the assembled module

## Intended use and limitations

This module is intended for educational, demonstrator, and laboratory use in controlled environments.

The design prioritizes simplicity, low cost, modularity, and ease of reproduction. The module uses a shared ground and does not include galvanic isolation.

Only digital input signals within the supported voltage range may be connected to the Arduino inputs. The sensor supply voltage and the sensor output signal voltage must be considered separately. A sensor may require a supply voltage above 5 V while still providing a digital signal compatible with the 5 V input of the module.

Additional protection, filtering, and EMC measures may be required for use in harsher environments or outside supervised laboratory setups.

## Contributors

- Sergej Tsoy

## License

Hardware design files in this module are licensed under **CERN-OHL-W-2.0**.  
Firmware and software are licensed under **GPL-3.0-or-later**.  
Documentation is licensed under **CC-BY-SA-4.0**.

See the repository root license files for details.