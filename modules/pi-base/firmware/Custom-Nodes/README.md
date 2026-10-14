# Custom-Nodes/

This is a Node-RED node package (npm name `fossdaq`) providing four custom
nodes used to talk to Arduino-based sensor/actuator boards over a serial
connection:

- **`fossdaq-init`** – configuration node. Opens the serial port, runs the
  handshake with the board, applies user-chosen settings (e.g. pin modes),
  and stores per-channel config (formulas, value types) for the other nodes.
- **`fossdaq-input`** – reads sensor channels from an initialized board.
- **`fossdaq-output`** – writes actuator channels on an initialized board.
- **`fossdaq-broadcast-error`** – single-input, no-output action node. On
  every incoming message it sends `ERROR\n` to *every* currently open Arduino
  connection — the same broadcast that `fossdaq-init`/`-input`/`-output`
  trigger automatically on a severe error. Use it to trigger that same
  "notify every board" behavior explicitly from within a flow (e.g. an
  emergency-stop button or a watchdog).

During installation (`install.sh` in the parent `firmware/` directory), this
whole folder is copied into the Node-RED user's `~/.node-red/custom-nodes/fossdaq`
and installed with `npm install <path>`, which registers the nodes declared
in `package.json` so they show up in the Node-RED palette.

## Files

| File | Purpose | What you can edit |
|---|---|---|
| **`fossdaq-config.js`** | **The board catalog.** Defines every known board/channel type as a plain JS object keyed by the board's serial-ID prefix (the non-numeric part of the ID the Arduino returns, e.g. `"do-PWM-1to6x"`, `"ao-1to3x-0to10V"`, `"ai-8x-0to3v3"`). Each entry describes whether it's a `sensor` or `actuator` board, its configurable `settings` (shown during the init handshake), and its fixed `sensors`/`actuators` channel lists. | **This is where you add a new Arduino/board type.** Copy an existing entry as a template and add a new key (matching the ID prefix your `find_arduino.sh`/sketch reports), then define its `kind`, `settings` (if the board has a handshake-configurable pin mode) or a static `actuators`/`sensors` list. See inline comments in the file for the exact shape (`index`, `label`, `options` with `value`/`valueType`/`min`/`max` for actuators; `index`/`formula` for sensors). |
| `port-manager.js` | Runtime connection manager, one entry per serial port path. Tracks the open `SerialPort`, whether the handshake completed (`ready`), and per-channel config set by `fossdaq-init` and read by the input/output nodes. Also implements `writeAndWaitForLine()` for sequential sensor polling. | Not normally edited by users — this is shared plumbing used by all three node files. Only touch it if you need to change connection/queueing behavior itself. |
| `formula.js` | Safely compiles a user-entered math formula string (e.g. `"5*(S+5)^3"`, where `S` is the raw sensor value) into a JS function, using a character/identifier whitelist instead of `eval`. | `ALLOWED_FUNCS` — add a `Math.*` function name here if you want it usable in sensor formulas from the dashboard/editor (e.g. add `'hypot'` to allow `hypot(...)` in a formula). |
| `fossdaq-init.js` | Node-RED runtime code for the `fossdaq-init` node: opens the port via `port-manager.js`, runs the handshake against the board definition from `fossdaq-config.js`, derives actuator/sensor channel configs (`deriveActuatorConfig`, `deriveSensorConfig`), and marks the port ready. | Edit only if you need to change handshake *logic* (not board definitions — those go in `fossdaq-config.js`). |
| `fossdaq-init.html` | Node-RED editor UI (sidebar form) for `fossdaq-init`, plus registration of the `fossdaq-serial-port` config node (holds the serial path) and the `fossdaq-init` node type itself. | Edit to change what's shown/editable in the Node-RED editor for this node (labels, help text, form fields). |
| `fossdaq-input.js` | Runtime code for `fossdaq-input`: for each configured sensor row, sends a query and awaits the response (sequentially, via `port-manager.writeAndWaitForLine`), applies the row's formula, and sends one message per output. | Edit only for changes to how sensor reads are triggered/processed. |
| `fossdaq-input.html` | Node-RED editor UI for `fossdaq-input` (lets the user pick which sensor channels to read and in what order/labels). | Edit to change the editor UI for this node. |
| `fossdaq-output.js` | Runtime code for `fossdaq-output`: for each configured actuator row, resolves the value (either fixed in the editor, or from `msg.payload` in "dynamic"/`fromMsg` mode) and writes it to the board. | Edit only for changes to how actuator writes are triggered/processed. |
| `fossdaq-output.html` | Node-RED editor UI for `fossdaq-output` (lets the user pick which actuator channels to control, and fixed values vs. dynamic `msg.payload` mode). | Edit to change the editor UI for this node. |
| `fossdaq-broadcast-error.js` | Runtime code for `fossdaq-broadcast-error`: on every incoming message, calls `portManager.broadcastError()` to send `ERROR\n` to every currently open serial connection. | Edit only if you need to change what the broadcast action does. |
| `fossdaq-broadcast-error.html` | Node-RED editor UI for `fossdaq-broadcast-error` (single-input, zero-output node with just a `name` field). | Edit to change the editor UI/help text for this node. |
| `package.json` | npm package manifest. The `"node-red"` field is what tells Node-RED which files implement which node types (`fossdaq-init`, `fossdaq-input`, `fossdaq-output`, `fossdaq-broadcast-error`). Declares the `serialport` dependency. | Bump `version`/`description` as needed. **If you add a brand-new node file** (not just a new board in `fossdaq-config.js`), register it under `"node-red".nodes` here too. |

## Adding a new Arduino / board type (most common change)

1. Flash your Arduino with a sketch that responds to the `serveID` command
   over serial with an identity string ending in digits, e.g. `MySensor007`.
2. Add the non-numeric prefix (`"MySensor"`) to `KNOWN_IDS` in
   `../find_arduino.sh` so the board gets detected and symlinked.
3. Add a new entry to the object in **`fossdaq-config.js`**, keyed by that
   same prefix, e.g.:
   ```js
   "MySensor": {
       kind: "sensor",
       settings: [],
       sensors: [
           { index: 0, formula: "S" },
           { index: 1, formula: "S / 10" },
       ],
   },
   ```
   For an actuator board, use `kind: "actuator"` and either a static
   `actuators` list or `settings` + `actuatorsFromSettings: true` if the pin
   mode is chosen during the handshake (see the `"do-PWM-1to6x"` entry for an
   example of the latter, where each of the 6 outputs can be set to off/PWM/
   digital during the handshake).
4. Redeploy the `fossdaq-init` node in Node-RED (or restart Node-RED) so the
   new board definition is picked up.

No changes to `fossdaq-init.js`, `port-manager.js`, or the `.html` editor
files are needed just to add a board — they read board definitions from
`fossdaq-config.js` generically.
