# Connecting Raspberry Pi / Node-RED with Arduino

This guide describes how to establish a connection between a Raspberry Pi running Node-RED and an Arduino.

## 1. Flash the Arduino

1. Connect the Arduino to your computer via USB.
2. Open the Arduino IDE.
3. Open the sketch (code) that should be flashed onto the Arduino.
4. Select the correct board and port under **Tools**.
5. Click **Upload** to flash the code onto the Arduino.

## 2. Retrieve the Arduino's Serial ID

1. Open the **Serial Monitor** in the Arduino IDE.
2. Make sure the baud rate matches the one used in the sketch.
3. Send the message `serveID` to the Arduino.
4. The Arduino will respond with its ID.
5. **Save/note down this ID** — it always stays the same for this specific Arduino.
6. It is recommended to physically label the Arduino with this ID, so it can be easily identified later (e.g. when using multiple Arduinos).

## 3. Integration into Node-RED

The following steps show how to integrate the Arduino into Node-RED. Each image is explained below.

### Step 1

![Step 1](FOSSDAQ/modules/pi-base/images/NodeRed_Arduino_1.png)

*(Your description here)*

### Step 2

![Step 2](FOSSDAQ/modules/pi-base/images/NodeRed_Arduino_2.png)

*(Your description here)*

### Step 3

![Step 3](FOSSDAQ/modules/pi-base/images/NodeRed_Arduino_3.png)

*(Your description here)*

### Step 4

![Step 4](FOSSDAQ/modules/pi-base/images/NodeRed_Arduino_4.png)

*(Your description here)*

### Step 5

![Step 5](FOSSDAQ/modules/pi-base/images/NodeRed_Arduino_5.png)

*(Your description here)*
