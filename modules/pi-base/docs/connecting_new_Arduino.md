# Connecting Raspberry Pi / Node-RED with Arduino

This guide describes how to establish a connection between a Raspberry Pi running Node-RED and an Arduino.

## 1. Flash the Arduino

1. Connect the Arduino to your computer via USB.
2. Open the Arduino IDE.
3. Open the sketch (code) that should be flashed onto the Arduino.
4. Select the correct board and port under **Tools**.
5. Click **Upload** to flash the code onto the Arduino.

## 2. Retrieve the Arduino's identifier
This step is necessary, if you intend to use more than one of the same kind of module.

1. Open the **Serial Monitor** in the Arduino IDE.
2. Make sure the baud rate is set to **9600**.
3. Send the message `serveID` to the Arduino.
4. The Arduino will respond with its identifier. It consists of the type of module (e.g. ai-8x-0to3v3) and a serial number (e.g. 3845) connected by an underscore.
5. **Save/note down this identifier** — the serial number will always stay the same for this specific Arduino. If the Arduino is flashed with another FOSSDAQ sketch, only the module identifier will change. The serial number will stay the same. 
6. It is recommended to physically label the Arduino with this identifier, so it can be easily identified later (e.g. when using multiple Arduinos).

## 2. Integration into Node-RED

To integrate the Arduino into Node-RED, simply connect the Arduino to the Raspberry PI via an USB cable. Drag a `FOSSDAQ init Node` into the flow. Double click the node. Add a port and select the module you want. 

`FOSSDAQ init` will show you all the possible settings for this specific module. 
