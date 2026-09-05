# Arduino Script for `ai-8x-0to3v3`

## Installation
Upload this script to an Arduino board using the Arduino IDE. Ensure the correct board and port are selected in the IDE before uploading.

---

## Functionality

### Overview
This script enables an Arduino to communicate with a Raspberry Pi (or another serial-enabled device) to read analog input values from up to 8 analog pins (A0-A7). The Arduino initializes, receives settings, and processes commands to read and send analog input values.

---

### Initialization Process
1. **Initial State (`initStatus = 0`)**
   The Arduino starts in this state, waiting for the `serveID` message from the Raspberry Pi. Upon receiving it, the Arduino generates or retrieves a unique ID, sends it to the Raspberry Pi, and transitions to `initStatus = 1`.

2. **Waiting for Initialization Start (`initStatus = 1`)**
   The Arduino waits for the `initStart` message. Once received, it transitions to `initStatus = 2`.

3. **Receiving Settings (`initStatus = 2`)**
   The Arduino expects settings in the format `Index,Value` (e.g., `0,1`). These settings are validated and stored in the `settings[]` array. If the `initEnd` message is received, it transitions to `initStatus = 3`.

4. **Finalizing Initialization (`initStatus = 3`)**
   The Arduino checks if all settings are valid (non-zero). If valid, it calculates a checksum and sends it to the Raspberry Pi. If no settings are required, it sends `noSettings`. It then transitions to `initStatus = 4` and configures the specified analog input pins (A0-A7) based on the settings.

5. **Normal Operation (`initStatus = 4`)**
   The Arduino enters its operational loop, where it processes commands to read analog inputs.

---

### Key Functions

#### `measure()`
- **Purpose**: Reads analog input values from specified pins.
- **Input Format**: A single integer representing the analog input index (0-7).
- **Behavior**:
  - Reads the analog value from the specified pin (A0-A7).
  - Sends the measured value to the Raspberry Pi.
  - If the index is invalid, it triggers `errorStatus()`.

#### `controll()`
- not in use!
- **Purpose**: Placeholder for controlling outputs (not implemented in this script).
- **Input Format**: `Index,State` (e.g., `0,1`).
- **Behavior**:
  - Currently a placeholder. If implemented, it would control outputs based on received commands.

#### `errorStatus()`
- **Purpose**: Handles errors by stopping code execution and ensuring a safe state.
- **Behavior**:
  - Sets `ERROR = true`, stopping the main loop.
  - Turns off all outputs (if any) and activates the built-in LED for error indication.

#### `startInit()`
- **Purpose**: Handles the initial `serveID` message and resets the Microcontroller.
- **Behavior**:
  - Generates or retrieves a unique ID from EEPROM.
  - Sends the ID to the Raspberry Pi and resets the `settings[]` array and `checksum`.
  - calls `errorStatus()` and sets `ERROR = false` immediately afterwards
  - resets `checksum` and `settings`. Sets `initStatus = 1` to restart the code

---
