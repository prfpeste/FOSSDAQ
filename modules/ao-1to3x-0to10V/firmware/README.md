# Arduino Script for `ao-1to3-x-0to10V`

## Installation
Upload this script to an Arduino board using the Arduino IDE. Ensure the correct board and port are selected in the IDE before uploading.

---

## Functionality

### Overview
This script enables an Arduino to communicate with a Raspberry Pi (or another serial-enabled device) to control DAC (Digital-to-Analog Converter) outputs. The Arduino initializes, receives settings, and processes commands to set specific voltage levels on designated DAC outputs.

---

### Initialization Process
1. **Initial State (`initStatus = 0`)**
   The Arduino starts in this state, waiting for the `serveID` message from the Raspberry Pi. Upon receiving it, the Arduino generates or retrieves a unique ID, sends it to the Raspberry Pi, and transitions to `initStatus = 1`.

2. **Waiting for Initialization Start (`initStatus = 1`)**
   The Arduino waits for the `initStart` message. Once received, it transitions to `initStatus = 2`.

3. **Receiving Settings (`initStatus = 2`)**
   The Arduino expects settings in the format `Index,Value` (e.g., `0,1`). These settings are validated and stored in the `settings[]` array. If the `initEnd` message is received, it transitions to `initStatus = 3`.

4. **Finalizing Initialization (`initStatus = 3`)**
   The Arduino checks if all settings are valid (non-zero). If valid, it calculates a checksum and sends it to the Raspberry Pi. If no settings are required, it sends `noSettings`. It then transitions to `initStatus = 4` and executes card-specific setup code:
   - Initializes SPI communication.
   - Configures pins based on settings.
   - Activates the DAC by setting the shutdown pin (`SHDN_PIN`) to `HIGH`.
   - Configures the `LDAC_PIN` to ensure immediate output.

5. **Normal Operation (`initStatus = 4`)**
   The Arduino enters its operational loop, where it processes commands to control DAC outputs.

---

### Key Functions

#### `writeToDAC(uint16_t value, int CS_PIN)`
- **Purpose**: Writes a 12-bit value to the DAC.
- **Parameters**:
  - `value`: The 12-bit value to write (0-4095).
  - `CS_PIN`: The chip select pin for the DAC (default: `2`).
- **Behavior**:
  - Masks the input value to 12 bits.
  - Constructs a command with configuration bits (buffer enabled, gain 1x, active).
  - Transfers the command and value to the DAC via SPI.

#### `controll()`
- **Purpose**: Controls DAC outputs based on received commands.
- **Input Format**: `Index,Voltage` (e.g., `0,5000`).
- **Behavior**:
  - Validates the index and voltage (0-10000 mV).
  - Converts the voltage to a 12-bit DAC value.
  - Calls `writeToDAC()` to set the specified voltage on the selected DAC output.
  - If the index or voltage is invalid, it triggers `errorStatus()`.

#### `measure()`
- **Purpose**: Placeholder for reading input values from sensors (not implemented in this script).
- **Input Format**: A single integer representing the sensor index.
- **Behavior**:
  - Currently a placeholder. If implemented, it would read the specified input and send its value to the Raspberry Pi.
  - If the index is invalid, it triggers `errorStatus()`.

#### `errorStatus()`
- **Purpose**: Handles errors by stopping code execution and ensuring a safe state.
- **Behavior**:
  - Sets `ERROR = true`, stopping the main loop.
  - Resets all DAC outputs to `0` to ensure a safe state.
  - Activates the built-in LED for error indication.
    
#### `startInit()`
- **Purpose**: Handles the initial `serveID` message and resets the Microcontroller.
- **Behavior**:
  - Generates or retrieves a unique ID from EEPROM.
  - Sends the ID to the Raspberry Pi and resets the `settings[]` array and `checksum`.
  - calls `errorStatus()` and sets `ERROR = false` immediately afterwards
  - resets `checksum` and `settings`. Sets `initStatus = 1` to restart the code

---
