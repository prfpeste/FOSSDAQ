# ai-4x-tck

4-channel Type-K thermocouple input module for the FOSSDAQ system.

This module is designed for Type-K thermocouples with a measurement range of −40 to 200 °C. Each input has its own AD8495 thermocouple amplifier. The module is based on an Arduino Nano 33 BLE Rev2 and communicates with the Raspberry Pi via USB.

## Status

- Development status: prototype
- Hardware version: v1.0
- Firmware status: v1.0
- Last updated: September 20, 2026

## Purpose

The `ai-4x-tck` module is the temperature measurement card of the FOSSDAQ system. It is intended for simple and low-cost acquisition of temperatures with Type-K thermocouples in educational and laboratory setups.

## Features

- 4 thermocouple input channels for Type-K thermocouples
- One dedicated AD8495 thermocouple amplifier per channel
- Measurement range: −40 to 200 °C
- Based on Arduino Nano 33 BLE Rev2 (3.3 V logic)
- 12-bit ADC, amplifier outputs connected to analog pins A1, A3, A5 and A7
- Type-K thermocouples are passive sensors, no sensor supply required
- Local 5 V generation from shared 24 V DC bus
- USB connection to Raspberry Pi for data only
- 3D-printed enclosure for TS-35 DIN rail mounting
- Plug-and-socket connectors for the thermocouples on the front of the enclosure
- Spring terminal for 24 V bus input and pass-through to the next card

## Directory structure

- `hardware/` – CAD files (FreeCAD), exported print files
- `firmware/` – microcontroller code for this module
- `docs/` – build manual, BOM, technical documentation, test instructions
- `images/` – photos, renders and schematic

**BOM** stands for **Bill of Materials** and refers to the module's parts list.

## Build and assembly

1. Print the enclosure parts.
2. Prepare the perfboard strip for the 24 V bus terminal.
3. Assemble the 24 V input and pass-through terminal block.
4. Install the DC/DC converter and set its output to 5.0 V.
5. Install the four AD8495 amplifiers and the Arduino Nano.
6. Connect the 5 V supply, common ground and the amplifier outputs (A1, A3, A5, A7).
7. Install the four thermocouple plug/socket connections and connect them to IN+ / IN− of the amplifiers.
8. Perform the checks described in `docs/`.
9. Close the enclosure and connect the module to the Raspberry Pi via USB.

## Interfaces

### Power
- Bus input: nominal 24 V DC
- Converter input range: 10–35 V DC (LM2596S module)
- Local logic/amplifier supply: 5 V generated locally (adjusted to 5.0 V)
- Sensor supply: not required (Type-K thermocouples are passive)
- Shared system ground: yes
- Galvanic isolation: no

### Data
- Interface to host: USB 2.0
- Connector: Micro-USB-B on Arduino Nano 33 BLE Rev2
- USB used as: data path only

### Signals
- Channel count: 4
- Input pins: A1, A3, A5, A7 (outputs of AD8495 1–4)
- Signal range: −40 to 200 °C (Type-K thermocouples)
- Typical sensor type: Type-K thermocouples (e.g. PEAKTECH TF-50)
- Note: the analog inputs of the Nano 33 BLE Rev2 operate at 3.3 V and are not 5 V tolerant

### Mechanics
- Mounting: TS-35 DIN rail
- Enclosure: 3D-printed
- Front connections: Type-K thermocouple plug/socket connectors
- Bus connection: spring terminal block (24 V input/pass-through)

## Main components

- Arduino Nano 33 BLE Rev2
- 4 × AD8495 thermocouple amplifier (DEBO AMP THERMO2)
- DEBO DCDC DOWN 5 DC/DC converter module (LM2596S)
- 4 × Type-K thermocouple plug/socket pair
- 4 × Type-K thermocouple
- AST 025-04 spring terminal block for 24 V bus input/pass-through
- Double-sided perfboard
- 3D-printed enclosure parts

## Files

Important project files for this module include:
- FreeCAD files for enclosure (`AI-Gehaeuse_Thermoelement_v1.FCStd`), cover (`AI-Deckel_v1.FCStd`) and DIN rail mounting part (`AI_Slate.FCStd`)
- Schematic of the thermocouple input card
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
