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
                if (done) done();
                return;
            }

            const channelConfig = portManager.getChannelConfig(node.portPath);

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
                            continue;
                        }
                        value = msg.payload;
                    } else {
                        value = row.value;
                    }

                    if (typeof value !== "boolean" && chCfg && (chCfg.min !== undefined || chCfg.max !== undefined)) {
                        const min = chCfg.min !== undefined ? chCfg.min : -Infinity;
                        const max = chCfg.max !== undefined ? chCfg.max : Infinity;
                        if (value < min || value > max) {
                            node.error(`Value ${value} for channel ${row.index} is outside the allowed range [${min}, ${max}]`, msg);
                            continue;
                        }
                    }

                    const wireValue = typeof value === "boolean" ? (value ? 1 : 0) : value;
                    await portManager.write(node.portPath, `${row.index},${wireValue}\n`);
                    send({ ...msg, payload: value, topic: String(row.index) });
                }
                node.status({ fill: "green", shape: "dot", text: "ok" });
                if (done) done();
            } catch (err) {
                node.error("Write error: " + err.message, msg);
                node.status({ fill: "red", shape: "ring", text: "write error" });
                if (done) done(err);
            }
        });
    }

    RED.nodes.registerType("fossdaq-output", FossdaqOutputNode);
};
