module.exports = function(RED) {
    const { SerialPort } = require('serialport');
    const boardConfig = require('./fossdaq-config.js');
    const portManager = require('./port-manager.js');
    const { compileFormula } = require('./formula.js');

    function extractFullId(path) {
        const match = path.match(/([A-Za-z]+\d+)$/);
        return match ? match[1] : null;
    }

    function extractPrefix(fullId) {
        if (!fullId) return null;
        return fullId.replace(/\d+$/, '');
    }

    // Derives the actuator channel config (value type per index):
    // - actuatorsFromSettings: from the pin mode option (PWM/digital/off)
    //   chosen during the handshake - no separate configuration needed.
    // - otherwise: from the static `actuators` list in the board entry.
    // name: user-defined name (if assigned), otherwise the board default
    // label, otherwise simply "Actuator <index>".
    function deriveActuatorConfig(cfgEntry, settingValues, actuatorNames) {
        const actuatorConfig = {};
        if (cfgEntry.actuatorsFromSettings) {
            (cfgEntry.settings || []).forEach(s => {
                const chosen = settingValues[s.index];
                const opt = (s.options || []).find(o => o.value === chosen);
                if (opt && opt.valueType) {
                    const name = (actuatorNames && actuatorNames[s.index]) || s.label || `Actuator ${s.index}`;
                    actuatorConfig[s.index] = { valueType: opt.valueType, min: opt.min, max: opt.max, name };
                }
                // valueType === null (e.g. "off") -> channel stays unconfigured,
                // the output node can then not address it.
            });
        } else {
            (cfgEntry.actuators || []).forEach(a => {
                const name = (actuatorNames && actuatorNames[a.index]) || a.label || `Actuator ${a.index}`;
                actuatorConfig[a.index] = { valueType: a.valueType, min: a.min, max: a.max, name };
            });
        }
        return actuatorConfig;
    }

    // Derives the sensor channel config (formula + name per index):
    // formula/name from the node instance config (if customized by the
    // user), otherwise the default formula from the board entry. The
    // default name is simply numbered ("Sensor <index>"), unless the user
    // assigned a custom name. Compiled immediately to catch formula errors
    // already at the ready event instead of only on the first sensor read.
    // Channels the user has disabled (enabled === false) do NOT appear in
    // the result - the sensor node can then not query them.
    function deriveSensorConfig(cfgEntry, node, savedFormulas) {
        const sensorConfig = {};
        (cfgEntry.sensors || []).forEach(s => {
            const saved = savedFormulas && savedFormulas[s.index];
            const enabled = saved && saved.enabled !== undefined ? saved.enabled : true;
            if (!enabled) return;

            const formula = (saved && saved.formula) || s.formula || "S";
            const name = (saved && saved.name && saved.name.trim()) || s.label || `Sensor ${s.index}`;
            try {
                compileFormula(formula); // validation only
                sensorConfig[s.index] = { formula, name };
            } catch (err) {
                node.error(`Invalid formula for sensor channel ${s.index} ("${name}"): ${err.message}`);
                sensorConfig[s.index] = { formula: "S", name };
            }
        });
        return sensorConfig;
    }

    // --- HTTP endpoints for the editor ---

    RED.httpAdmin.get('/fossdaq/ports', RED.auth.needsPermission('fossdaq-init.read'), function(req, res) {
        SerialPort.list().then(ports => {
            res.json(ports);
        }).catch(err => {
            RED.log.error("Failed to list serial ports: " + err.message);
            res.json([]);
        });
    });

    // Full board entry (kind, settings, sensors, actuators, ...) - every
    // node type pulls out of it whatever it needs.
    RED.httpAdmin.get('/fossdaq/board/:prefix', RED.auth.needsPermission('fossdaq-init.read'), function(req, res) {
        const entry = boardConfig[req.params.prefix];
        res.json(entry || { kind: null, settings: [], sensors: [], actuators: [] });
    });

    // --- Config node: represents a single serial port, reusable across nodes ---
    function FossdaqSerialPortNode(config) {
        RED.nodes.createNode(this, config);
        this.path = config.path;
    }
    RED.nodes.registerType("fossdaq-serial-port", FossdaqSerialPortNode);

    // --- Init node: establishes the connection (once) and does the handshake ---
    function FossdaqInitNode(config) {
        RED.nodes.createNode(this, config);
        const node = this;

        const portConfigNode = RED.nodes.getNode(config.port);
        if (!portConfigNode || !portConfigNode.path) {
            node.error("No serial port configured");
            node.status({ fill: "red", shape: "ring", text: "no port configured" });
            return;
        }

        node.portPath = portConfigNode.path;
        node.settingValues = config.settingValues || {};
        // Only overridden per instance for sensor boards:
        // { "<index>": { formula: "S", enabled: true, name: "" } }
        node.sensorFormulas = config.sensorFormulas || {};
        // Only assigned per instance for actuator boards:
        // { "<index>": "custom name" }
        node.actuatorNames = config.actuatorNames || {};

        node.expectedFullId = extractFullId(node.portPath);
        node.prefix = extractPrefix(node.expectedFullId);
        node.cfgEntry = boardConfig[node.prefix];
        node.ready = false;

        if (!node.cfgEntry) {
            node.error("No config found for board type: " + node.prefix);
            node.status({ fill: "red", shape: "ring", text: "unknown board type" });
            return;
        }

        function publishReady() {
            node.ready = true;
            portManager.markReady(node.portPath);

            const channelConfig = { sensors: {}, actuators: {} };
            if (node.cfgEntry.kind === "sensor") {
                channelConfig.sensors = deriveSensorConfig(node.cfgEntry, node, node.sensorFormulas);
            } else if (node.cfgEntry.kind === "actuator") {
                channelConfig.actuators = deriveActuatorConfig(node.cfgEntry, node.settingValues, node.actuatorNames);
            }
            portManager.setChannelConfig(node.portPath, channelConfig);

            node.status({ fill: "green", shape: "dot", text: "ready" });
            node.send({ payload: true, topic: "ready" });
        }

        node.status({ fill: "yellow", shape: "ring", text: "connecting..." });

        // The connection is established HERE, once - sensor/actuator nodes
        // only access it later via portManager.get(path).
        const conn = portManager.open(node.portPath, 9600);

        conn.emitter.on('open', () => {
            node.status({ fill: "yellow", shape: "ring", text: "requesting ID" });
            portManager.write(node.portPath, "serveID\n").catch(err => {
                node.error("Write error: " + err.message);
            });
        });

        conn.emitter.on('error', (err) => {
            node.error("Connection error: " + err.message);
            node.status({ fill: "red", shape: "ring", text: "error" });
        });

        conn.emitter.on('line', (line) => {
            if (line.startsWith("ERROR:")) {
                node.error("Arduino reported: " + line);
                node.status({ fill: "red", shape: "ring", text: "error" });
                return;
            }

            if (!node.idVerified && line.startsWith("ID")) {
                const receivedFullId = line.substring(2);
                if (receivedFullId !== node.expectedFullId) {
                    node.error(`ID mismatch: expected ${node.expectedFullId}, got ${receivedFullId}`);
                    node.status({ fill: "red", shape: "ring", text: "ID mismatch" });
                    return;
                }
                node.idVerified = true;
                node.status({ fill: "yellow", shape: "ring", text: "starting init" });

                portManager.write(node.portPath, "initStart\n");

                let expectedChecksum = 0;
                node.cfgEntry.settings.forEach(s => {
                    const value = node.settingValues[s.index];
                    portManager.write(node.portPath, `${s.index},${value}\n`);
                    expectedChecksum += value;
                });
                node.expectedChecksum = expectedChecksum;

                portManager.write(node.portPath, "initEnd\n");
                node.status({ fill: "yellow", shape: "ring", text: "awaiting confirmation" });
                return;
            }

            if (node.idVerified && !node.ready) {
                if (line === "noSettings") {
                    if (node.cfgEntry.settings.length > 0) {
                        node.error("Arduino reported 'noSettings' but settings were expected");
                        node.status({ fill: "red", shape: "ring", text: "checksum error" });
                        return;
                    }
                    publishReady();
                    return;
                }

                if (/^\d+$/.test(line)) {
                    const receivedChecksum = parseInt(line, 10);
                    if (receivedChecksum !== node.expectedChecksum) {
                        node.error(`Checksum mismatch: expected ${node.expectedChecksum}, got ${receivedChecksum}`);
                        node.status({ fill: "red", shape: "ring", text: "checksum error" });
                        return;
                    }
                    publishReady();
                    return;
                }
            }
        });

        // Only the init node closes the connection again - sensor/actuator
        // nodes never call close().
        node.on('close', function(done) {
            portManager.close(node.portPath);
            done();
        });
    }

    RED.nodes.registerType("fossdaq-init", FossdaqInitNode);
};
