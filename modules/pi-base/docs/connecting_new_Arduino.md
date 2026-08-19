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
6. It is recommended to physically label the Arduino with this ID, so it can be identified easily later (e.g. when using multiple Arduinos).

## 3. Integration into Node-RED

The following steps show how to integrate the Arduino into Node-RED.

### Step 1 — Add the Serial Request node

![Step 1](https://github.com/prfpeste/FOSSDAQ/blob/Alexander_Gschlecht_Test/modules/pi-base/images/NodeRed_Arduino_1.png)

Scroll through the palette until you find the `serial request` node. Click and hold it, then drag it into the flow (1.a).

### Step 2 — Open the node configuration

![Step 2](https://github.com/prfpeste/FOSSDAQ/blob/Alexander_Gschlecht_Test/modules/pi-base/images/NodeRed_Arduino_2.png)

Double-click the node icon to open its configuration window (2.a).

### Step 3 — Create a new serial port configuration

![Step 3](https://github.com/prfpeste/FOSSDAQ/blob/Alexander_Gschlecht_Test/modules/pi-base/images/NodeRed_Arduino_3.png)

Click the plus icon in the panel on the right to create a new serial port configuration (3.a).

### Step 4 — Configure the serial connection

![Step 4](https://github.com/prfpeste/FOSSDAQ/blob/Alexander_Gschlecht_Test/modules/pi-base/images/NodeRed_Arduino_4.png)

Give the Arduino a custom name (4.a). If left empty, the value from 4.b will be used as the name instead.

Set the serial port in 4.b. The port always starts with `bin/arduino/`, followed by the ID you noted down earlier. The value shown in the image is just an example.

Set the baud rate to `9600` (4.c).

Click **Add** to save the configuration (4.d).

### Step 5 — Select the configured Arduino

![Step 5](https://github.com/prfpeste/FOSSDAQ/blob/Alexander_Gschlecht_Test/modules/pi-base/images/NodeRed_Arduino_5.png)

Select the Arduino you just configured from the dropdown menu (5.a).

Click **Done** to finish (5.b).
