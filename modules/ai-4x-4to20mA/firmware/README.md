# Arduino Script for `ai-4x-4to20mA`

## Installation

Upload this script to an Arduino board using the Arduino IDE.

Before compiling, install the required **Adafruit INA219** library and ensure that the correct board and serial port are selected in the Arduino IDE.

The following libraries are used:

- `SPI.h`
- `EEPROM.h`
- `Wire.h`
- `Adafruit_INA219.h`

---

## Functionality

### Overview

This script enables the `ai-4x-4to20mA` measurement card to communicate with a Raspberry Pi or another serial-enabled device.

The card provides four analog current input channels for sensors with a **4–20 mA output signal**.

Each channel is measured using a separate INA219 current sensor. The Arduino reads the current, averages multiple measurements and sends the result to the Raspberry Pi via USB serial communication.

The measured current is transmitted as an integer value in **microamperes (µA)**.

Conversion from the measured current to the physical sensor value is performed externally, for example in Node-RED on the Raspberry Pi.

---

### Channel Assignment

| Measurement Index | Housing Channel | INA219 Address |
|---|---:|---:|
| `0` | Channel 1 | `0x40` |
| `1` | Channel 2 | `0x41` |
| `2` | Channel 3 | `0x45` |
| `3` | Channel 4 | `0x44` |

Channels 3 and 4 are intentionally swapped in software to match the physical channel labels on the housing.

---

### Initialization Process

1. **Initial State (`initStatus = 0`)**  
   The Arduino starts in this state and waits for the `serveID` message from the Raspberry Pi.

   When the message is received, the Arduino generates or retrieves its unique ID from EEPROM and sends it to the Raspberry Pi.

   The ID begins with:

   ```text
   ai-4x-4to20mA_
   ```

2. **Waiting for Initialization Start (`initStatus = 1`)**  
   The Arduino waits for the `initStart` message.

   Once received, it changes to `initStatus = 2`.

3. **Configuration State (`initStatus = 2`)**  
   The card does not require configurable settings.

   The Arduino therefore waits for the `initEnd` message.

4. **Initialization Completion (`initStatus = 3`)**  
   Because no settings are required, the Arduino sends:

   ```text
   noSettings
   ```

   The I²C interface is then initialized and all four INA219 devices are checked.

   Expected INA219 addresses:

   ```text
   0x40
   0x41
   0x44
   0x45
   ```

   If one of the devices cannot be found, the card enters the error state.

5. **Normal Operation (`initStatus = 4`)**  
   The card is ready for measurement requests.

   The `measure()` function continuously waits for a channel index from the Raspberry Pi.

---

### Key Functions

#### `measure()`

Reads a requested measurement channel and sends the measured current back over the serial interface.

Expected input:

```text
0
1
2
3
```

Channel mapping:

```text
0 -> Channel 1
1 -> Channel 2
2 -> Channel 3
3 -> Channel 4
```

The returned value is an integer in **microamperes (µA)**.

Example:

```text
4280
```

corresponds to:

```text
4.280 mA
```

Another example:

```text
12000
```

corresponds to:

```text
12.000 mA
```

An invalid channel index causes an error and stops normal operation.

---

#### `readCurrent_uA()`

Reads the current value from the selected INA219.

For every requested measurement, the function takes **10 individual samples**.

The samples are averaged to reduce measurement noise.

The INA219 returns the measured current in milliamperes. The function converts this result to microamperes:

```text
µA = mA × 1000
```

Negative INA219 readings are converted to positive values before transmission.

Examples:

```text
-4.28 mA -> 4280 µA
12.00 mA -> 12000 µA
20.00 mA -> 20000 µA
```

The Arduino therefore only transmits the measured current. It does not convert the signal into a sensor-specific physical quantity.

---

#### `controll()`

This function is part of the common FOSSDAQ base code.

It is not used by the `ai-4x-4to20mA` card because this module only reads input signals and does not control outputs.

---

#### `errorStatus()`

Activates the global error state.

When an error occurs:

- normal operation is stopped
- the built-in Arduino LED is switched on
- no outputs need to be placed into a safe state because the card only reads inputs

The card can be reinitialized by sending `serveID`.

---

#### `startInit()`

Handles the initialization request from the Raspberry Pi.

When the Arduino receives:

```text
serveID
```

the function retrieves the device-specific ID from EEPROM.

If no ID exists yet, a random ID is generated and stored in EEPROM.

The complete ID consists of the card type followed by the device-specific number.

Example:

```text
ai-4x-4to20mA_12345
```

This allows multiple measurement cards of the same type to be distinguished by the Raspberry Pi.

---

## Measurement Principle

Each input channel is connected to an INA219 current measurement IC.

The measurement chain is:

```text
4–20 mA sensor
      ↓
INA219
      ↓
Arduino Nano R4
      ↓
USB serial communication
      ↓
Raspberry Pi / Node-RED
      ↓
Conversion to physical sensor value
```

The Arduino does not apply a sensor-specific conversion.

Instead, it returns the measured current directly in microamperes.

For example:

```text
4000  -> 4.000 mA
12000 -> 12.000 mA
20000 -> 20.000 mA
```

The conversion from the 4–20 mA signal to values such as flow rate, pressure, temperature or another physical quantity is performed in Node-RED according to the characteristics of the connected sensor.

---

## Serial Communication

The serial interface operates at:

```text
9600 baud
```

Typical initialization sequence:

```text
serveID
```

Arduino response:

```text
ai-4x-4to20mA_<ID>
```

Then:

```text
initStart
initEnd
```

Arduino response:

```text
noSettings
```

After initialization, a measurement can be requested by sending the channel index.

Example:

```text
0
```

Possible response:

```text
9764
```

This corresponds to a measured current of:

```text
9.764 mA
```

---

## Error Handling

The card enters the error state when, for example:

- an invalid measurement index is received
- one of the INA219 devices cannot be detected
- an `ERROR` message is received from Node-RED

Possible initialization errors include:

```text
ERROR: INA219 channel 0 not found
ERROR: INA219 channel 1 not found
ERROR: INA219 address 0x44 not found
ERROR: INA219 address 0x45 not found
```

An invalid measurement index produces:

```text
ERROR: invalid index
```

When the error state is active, the built-in Arduino LED remains switched on.