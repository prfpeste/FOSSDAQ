
# Arduino PWM Control Script

## Installation
Upload this script to an Arduino board using the Arduino IDE. Ensure the correct board and port are selected in the IDE before uploading.

---

## Functionality

### Overview
This script enables an Arduino to communicate with a Raspberry Pi (or another serial-enabled device) to control PWM or digital outputs. The Arduino initializes, receives settings, and processes commands to control outputs or read inputs.

---

### Initialization Process
1. **Initial State (`initStatus = 0`)**
   The Arduino starts in this state, waiting for the `serveID` message from the Raspberry Pi. Upon receiving it, the Arduino generates or retrieves a unique ID, sends it plus the       card specific identification string (e.g. do-PWM-1to6x) to the Raspberry Pi, and transitions to `initStatus = 1`.

2. **Waiting for Initialization Start (`initStatus = 1`)**
   The Arduino waits for the `initStart` message. Once received, it transitions to `initStatus = 2`.

3. **Receiving Settings (`initStatus = 2`)**
   The Arduino expects settings in the format `Index,Value` (e.g., `0,1`). These settings are validated and stored in the `settings[]` array. If the `initEnd` message is received, it transitions to `initStatus = 3`.

4. **Finalizing Initialization (`initStatus = 3`)**
   The Arduino checks if all settings are valid (non-zero). If valid, it calculates a checksum and sends it to the Raspberry Pi. If no settings are required, it sends `noSettings`. It then transitions to `initStatus = 4` and executes card-specific setup code.

5. **Normal Operation (`initStatus = 4`)**
   The Arduino enters its operational loop, where it processes commands to control outputs or read inputs.

---

### Key Functions

#### `controll()`
- **Purpose**: Controls outputs based on received commands.
- **Input Format**: `Index,State` (e.g., `0,1`).
- **Behavior**:
  - Validates the index and state.
  - Calls `digitalOutPWM()` to set the output to the desired state (PWM or digital).
  - If the index or state is invalid, it triggers `errorStatus()`.

#### `measure()`
- not in use!
- **Purpose**: Reads input values from sensors.
- **Input Format**: A single integer representing the sensor index.
- **Behavior**:
  - Reads the specified input and sends its value to the Raspberry Pi.
  - If the index is invalid, it triggers `errorStatus()`.

#### `errorStatus()`
- **Purpose**: Handles errors by stopping code execution and ensuring a safe state.
- **Behavior**:
  - Sets `ERROR = true`, stopping the main loop.
  - Turns off all outputs and activates the built-in LED for error indication.

#### `digitalOutPWM()`
- **Purpose**: Controls PWM or digital outputs based on settings.
- **Parameters**:
  - `OutPin`: The pin to control.
  - `command`: The desired state (0-255 for PWM, 0 or 1 for digital).
  - `controllIndex`: The index of the output in the `settings[]` array.
- **Behavior**:
  - If the setting for the index is `2` (PWM), it writes the command as an analog value.
  - If the setting for the index is `3` (digital), it sets the pin to `HIGH` or `LOW`.
  - If the command is invalid, it triggers `errorStatus()`.

#### `startInit()`
- **Purpose**: Handles the initial `serveID` message and resets the Microcontroller.
- **Behavior**:
  - Generates or retrieves a unique ID from EEPROM.
  - Sends the ID to the Raspberry Pi and resets the `settings[]` array and `checksum`.
  - calls `errorStatus()` and sets `ERROR = false` immediately afterwards
  - resets `checksum` and `settings`. Sets `initStatus = 1` to restart the code

---
