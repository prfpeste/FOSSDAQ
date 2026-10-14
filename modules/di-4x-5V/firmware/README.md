# Arduino Script for `di-4x-5V`

## Installation
Upload this script to an Arduino Nano R4 using the Arduino IDE. Ensure the correct board and port are selected in the IDE before uploading.

---

## Functionality

### Overview
This script enables an Arduino Nano R4 to communicate with a Raspberry Pi (or another serial-enabled device) and measure frequency signals from up to 4 digital 5 V inputs.

The card is designed for sensors with a digital pulse output, such as Hall-effect flow sensors.

The Arduino counts the rising edges of the selected input during a measurement interval of approximately one second. The resulting frequency is transmitted to the Raspberry Pi as an integer in the format `Hz × 100`.

Sensor-specific conversion, for example from frequency to flow rate in l/min, is not performed by the Arduino. This conversion is performed later on the Raspberry Pi, for example using Node-RED.

---

### Channel Assignment

| Index | Channel | Arduino Input |
|---:|---:|---|
| 0 | Channel 1 | D2 |
| 1 | Channel 2 | D3 |
| 2 | Channel 3 | D8 |
| 3 | Channel 4 | D12 |

---

### Initialization Process

1. **Initial State (`initStatus = 0`)**  
   The Arduino starts in this state and waits for the `serveID` message from the Raspberry Pi. Upon receiving it, the Arduino generates or retrieves a unique ID, sends it to the Raspberry Pi, and transitions to `initStatus = 1`.

2. **Waiting for Initialization Start (`initStatus = 1`)**  
   The Arduino waits for the `initStart` message. Once received, it transitions to `initStatus = 2`.

3. **Initialization (`initStatus = 2`)**  
   This card does not require any settings. The Arduino waits for the `initEnd` message and then transitions to `initStatus = 3`.

4. **Finalizing Initialization (`initStatus = 3`)**  
   Since no settings are required, the Arduino sends `noSettings` to the Raspberry Pi.

   The four digital inputs are then configured and interrupts are attached to the rising edges of the input signals.

   The Arduino then transitions to `initStatus = 4`.

5. **Normal Operation (`initStatus = 4`)**  
   The Arduino enters normal operation and waits for measurement commands from the Raspberry Pi.

---

### Key Functions

#### `measure()`
- **Purpose**: Measures the frequency of a selected digital input.
- **Input Format**: A single integer from `0` to `3`.
- **Behavior**:
  - Selects the corresponding input channel.
  - Resets the pulse counter of the selected channel.
  - Counts rising signal edges during the measurement interval.
  - Calculates the signal frequency.
  - Multiplies the frequency by 100.
  - Sends the resulting integer value to the Raspberry Pi.
  - If the index is invalid, `errorStatus()` is called.

**Example:**

A measured frequency of:

`73.40 Hz`

is transmitted as:

`7340`

The Arduino does **not** convert this value into a physical quantity such as flow rate. Sensor-specific conversion is performed later on the Raspberry Pi, for example in Node-RED.

---

#### `measureFrequencyX100()`
- **Purpose**: Measures and calculates the frequency of the selected input signal.
- **Behavior**:
  - Resets the corresponding pulse counter.
  - Measures incoming rising edges for approximately 1000 ms.
  - Determines the actual elapsed measurement time using `micros()`.
  - Calculates the frequency in Hz.
  - Multiplies the frequency by 100.
  - Returns the result as an integer.

The frequency is calculated from the number of detected pulses and the actual measurement time:

`frequency = pulses / measurement time`

The result is scaled by 100 to allow two decimal places to be transmitted without sending a floating-point value.

---

#### `countPulse0()` – `countPulse3()`
- **Purpose**: Interrupt service routines for the four digital input channels.
- **Behavior**:
  - Each function is assigned to one digital input.
  - Every detected rising edge increments the corresponding pulse counter.

---

#### `controll()`
- **Not in use!**
- **Purpose**: Placeholder for controlling outputs.
- **Behavior**:
  - This card is an input-only card.
  - No outputs are controlled by the `di-4x-5V` card.

---

#### `errorStatus()`
- **Purpose**: Handles errors and stops normal operation.
- **Behavior**:
  - Sets `ERROR = true`.
  - Stops normal measurement operation.
  - Activates the built-in LED to indicate an error.
  - No outputs need to be switched to a safe state because the card only reads digital inputs.

---

#### `startInit()`
- **Purpose**: Handles the `serveID` message and restarts the initialization process.
- **Behavior**:
  - Generates or retrieves a unique card ID from EEPROM.
  - Uses the prefix `di-4x-5V_`.
  - Sends the complete ID to the Raspberry Pi.
  - Resets the settings array and checksum.
  - Resets the error state.
  - Sets `initStatus = 1`.

---

## Measurement Principle

Each sensor connected to the `di-4x-5V` card provides a digital pulse signal.

The Arduino detects the rising edges of this signal and determines its frequency over a measurement interval of approximately one second.

The measured frequency is multiplied by 100 and transmitted as an integer:

`Sensor signal → Pulse counting → Frequency [Hz] → ×100 → Raspberry Pi`

For example:

`73.40 Hz → 7340`

The Raspberry Pi or Node-RED can then apply the appropriate sensor-specific conversion:

`Frequency → Sensor-specific conversion → Physical unit`

For a flow sensor, the resulting physical unit can be `l/min`.

This separation allows different compatible 5 V pulse-output sensors to be used with the same measurement card without requiring sensor-specific conversion in the Arduino firmware.