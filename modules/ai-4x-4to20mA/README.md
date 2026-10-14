# ai-4x-4to20mA

4-channel analog current input module for the FOSSDAQ system.

This module is designed for sensors with 4–20 mA current output signals. It is based on an Arduino Nano R4 and four INA219 current measurement modules and communicates with the Raspberry Pi via USB.

## Status

- Development status: prototype
- Hardware version: v1.0
- Firmware status: defined separately
- Last updated: October 3, 2026

## Purpose

The `ai-4x-4to20mA` module is an analog current input measurement card for the FOSSDAQ system.

It is intended for the acquisition of standard 4–20 mA sensor signals, such as those commonly used by industrial flow, pressure, level, and other process sensors.

Each input channel uses an INA219 current measurement module to measure the sensor current. The Arduino Nano R4 communicates with the INA219 modules via I2C and transfers the measured values to the Raspberry Pi via USB.

Sensor-specific conversion from the measured 4–20 mA signal into physical quantities, such as flow rate, pressure, or level, can be performed on the Raspberry Pi.

## Features

- 4 analog current input channels
- Designed for 4–20 mA sensor signals
- 4 independent INA219 current measurement modules
- Based on Arduino Nano R4
- I2C communication between Arduino Nano R4 and INA219 modules
- Sensor supply provided by an adjustable DC/DC converter
- Shared 24 V DC bus input and pass-through
- USB connection to Raspberry Pi
- 3D-printed enclosure for TS-35 DIN rail mounting
- Spring terminal connections for sensor wiring
- Sensor-specific conversion can be handled externally on the Raspberry Pi

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
4. Assemble the four sensor terminal connections.
5. Install the four INA219 current measurement modules.
6. Connect the INA219 modules to the Arduino Nano R4 via I2C.
7. Configure the individual I2C addresses of the INA219 modules.
8. Connect the sensor supply and ground lines.
9. Install and configure the LM2596S DC/DC converter.
10. Install the electronics into the enclosure.
11. Attach the connector labels as described in `docs/`.
12. Connect the module to the Raspberry Pi via USB.
13. Perform the required functional checks before connecting sensors.

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
- Internal measurement interface: I2C

### Signals

- Channel count: 4
- Signal type: analog current signal
- Input range: 4–20 mA
- Measurement device: INA219
- Number of INA219 modules: 4
- Communication with Arduino: I2C
- Typical sensor connection:
  - supply voltage
  - current signal / current loop
  - ground, depending on sensor configuration
- Typical sensor types:
  - flow sensors
  - pressure sensors
  - level sensors
  - other sensors with 4–20 mA output

The module measures the current signal using the INA219 modules. Sensor-specific conversion of the measured 4–20 mA value into a physical quantity is not fixed by the measurement card and can therefore be configured separately on the Raspberry Pi for different sensor types and measurement ranges.

### Mechanics

- Mounting: TS-35 DIN rail
- Enclosure: 3D-printed
- Rail mount: external slate
- Front connections: spring terminal blocks

## Main components

- Arduino Nano R4
- 4 × INA219 current measurement modules
- LM2596S DC/DC step-down converter with display
- Spring terminal blocks for sensor connections
- Spring terminal block for 24 V bus input and pass-through
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

Only sensors and current signals compatible with the electrical limits of the module may be connected. The sensor supply voltage must be selected according to the requirements of the connected sensors while also remaining within the allowable supply voltage range of the Arduino Nano R4.

The 4–20 mA input represents the electrical measurement signal only. The relationship between current and the corresponding physical quantity depends on the connected sensor and must be configured separately in the data processing system.

Additional protection, filtering, and EMC measures may be required for use in harsher environments or outside supervised laboratory setups.

## Contributors

- Sergej Tsoy

## License

Hardware design files in this module are licensed under **CERN-OHL-W-2.0**.  
Firmware and software are licensed under **GPL-3.0-or-later**.  
Documentation is licensed under **CC-BY-SA-4.0**.

See the repository root license files for details.