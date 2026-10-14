module.exports = function(RED) {
    const portManager = require('./port-manager.js');

    function FossdaqOutputNode(config) {
        RED.nodes.createNode(this, config);
        const node = this;

        node.portConfigNode = RED.nodes.getNode(config.port);
        // rows: [{ index: <actuatorIndex>, value: <int|boolean>, fromMsg: <bool> }, ...]
        // fromMsg === true -> there can only be ONE row (already enforced in
        // the editor); the value then does not come from row.value, but from
        // msg.payload of each incoming message.
        node.rows = Array.isArray(config.rows) ? config.rows : [];

        if (!node.portConfigNode || !node.portConfigNode.path) {
            node.status({ fill: "red", shape: "ring", text: "no port configured" });
            return;
        }

        node.portPath = node.portConfigNode.path;
        node.status({ fill: "grey", shape: "ring", text: "waiting for init node" });

        node.on('input', async function(msg, send, done) {
            send = send || function() { node.send.apply(node, arguments); };

            if (node.rows.length === 0) {
                node.error("No actuator channels configured", msg);
                if (done) done();
                return;
            }

            if (!portManager.isReady(node.portPath)) {
                node.error("Port is not ready yet (init node not finished or not deployed)", msg);
                node.status({ fill: "red", shape: "ring", text: "port not ready" });
                portManager.broadcastError();
                if (done) done();
                return;
            }

            const channelConfig = portManager.getChannelConfig(node.portPath);

            let anyClipped = false;
            let anyError = false;

            try {
                for (const row of node.rows) {
                    const chCfg = channelConfig.actuators[row.index];

                    // Dynamic mode: the value to set comes from msg.payload
                    // instead of a row.value fixed in the editor. Since in
                    // dynamic mode there is always exactly one row,
                    // msg.payload is directly the setpoint for this single
                    // channel.
                    let value;
                    if (row.fromMsg) {
                        if (msg.payload === undefined || msg.payload === null) {
                            node.error(`Dynamic channel ${row.index}: msg.payload is missing`, msg);
                            anyError = true;
                            continue;
                        }
                        value = msg.payload;
                    } else {
                        value = row.value;
                    }

                    if (row.fromMsg && chCfg && chCfg.valueType === "boolean" && typeof value !== "boolean") {
                        if (value === 1 || value === "1" || value === "true") {
                            value = true;
                        } else if (value === 0 || value === "0" || value === "false") {
                            value = false;
                        } else {
                            node.error(`Dynamic channel ${row.index}: msg.payload must be true/false or 1/0, got ${JSON.stringify(value)}`, msg);
                            anyError = true;
                            continue;
                        }
                    }

                    let clipped = false;
                    if (row.fromMsg && typeof value !== "boolean" && chCfg && (chCfg.min !== undefined || chCfg.max !== undefined)) {
                        const min = chCfg.min !== undefined ? chCfg.min : -Infinity;
                        const max = chCfg.max !== undefined ? chCfg.max : Infinity;
                        if (value < min) {
                            node.warn(`Dynamic channel ${row.index}: value ${value} is below the allowed range [${min}, ${max}], clipped to ${min}`, msg);
                            value = min;
                            clipped = true;
                        } else if (value > max) {
                            node.warn(`Dynamic channel ${row.index}: value ${value} is above the allowed range [${min}, ${max}], clipped to ${max}`, msg);
                            value = max;
                            clipped = true;
                        }
                        if (clipped) anyClipped = true;
                    }

                    const wireValue = typeof value === "boolean" ? (value ? 1 : 0) : value;
                    await portManager.write(node.portPath, `${row.index},${wireValue}\n`);
                    send({ ...msg, payload: value, topic: String(row.index) });
                }
                if (anyError) {
                    node.status({ fill: "red", shape: "ring", text: "invalid value(s), see debug/error" });
                    portManager.broadcastError();
                } else if (anyClipped) {
                    node.status({ fill: "yellow", shape: "dot", text: "clipped to range" });
                } else {
                    node.status({ fill: "green", shape: "dot", text: "ok" });
                }
                if (done) done();
            } catch (err) {
                node.error("Write error: " + err.message, msg);
                node.status({ fill: "red", shape: "ring", text: "write error" });
                portManager.broadcastError();
                if (done) done(err);
            }
        });
    }

    RED.nodes.registerType("fossdaq-output", FossdaqOutputNode);
};
