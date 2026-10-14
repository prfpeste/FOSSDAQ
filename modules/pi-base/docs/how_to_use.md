# FOSSDAQ Usage Guide

## Flashing the Arduino

Upload the specific script for your module to an Arduino board using the [Arduino IDE](https://www.arduino.cc/en/software). Ensure the correct board and port are selected in the IDE before uploading.

If you have **two or more** units of the same module, follow these steps. Otherwise, they are recommended but not mandatory:

1. Open the **Serial Monitor** under **Tools** or by pressing `Ctrl+Shift+M`.
2. Set the baud rate to **9600**.
3. Type `serveID` and press **Enter**.
4. Record the returned string (e.g., `ai-8x-0to3v3`). It is recommended to label it on the device for future reference.

---

## Connecting Modules to Node-RED

1. Connect your module to the Raspberry Pi using a USB cable.
2. Open **Node-RED** and drag the `FOSSDAQ - init` node into your flow.
3. Double-click the node and click the **+** button on the right side of **Add new fossdaq-serial-port...**.
4. Select your module from the dropdown menu. It will appear as `/dev/arduino/module_id`, where `module_id` is the ID you recorded earlier.
5. Optionally, assign a custom name for the port.
6. The newly created port is automatically selected after clicking **Add**.
7. The `FOSSDAQ - init` node will automatically retrieve the available settings for the module. Adjust the settings as needed.

The port remains consistent even if the module is connected to a different USB port. For simplicity, the terms **module** and **port** are used interchangeably in this guide.

**Note:** Each module must have exactly one `FOSSDAQ - init` node. Without it, the module cannot be used.

---

## Using Modules in Node-RED

Drag either the `FOSSDAQ - input` or `FOSSDAQ - output` node into your flow. Double-click the node and select the desired module. The node will display all available actions based on the configured settings. Disabled ports will not appear in the selection.

---

## `FOSSDAQ - broadcast - error`

This function forces all connected modules into an **error mode**, placing them in a safe state (e.g., turning off all outputs). The modules remain in this state until the Node-RED flow is restarted. **No manual restart (unplugging/replugging) of the Arduinos is required.**
