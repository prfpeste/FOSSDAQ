module.exports = function(RED) {
    const portManager = require('./port-manager.js');
    const { compileFormula } = require('./formula.js');

    function FossdaqInputNode(config) {
        RED.nodes.createNode(this, config);
        const node = this;

        node.portConfigNode = RED.nodes.getNode(config.port);
        // rows: [{ index: <sensorIndex>, label: <string> }, ...] - order =
        // query order = order of the node outputs (rows[i] -> output i)
        node.rows = Array.isArray(config.rows) ? config.rows : [];
        node._formulaCache = new Map(); // "index:formulaString" -> compiled fn

        if (!node.portConfigNode || !node.portConfigNode.path) {
            node.status({ fill: "red", shape: "ring", text: "no port configured" });
            return;
        }

        node.portPath = node.portConfigNode.path;
        node.status({ fill: "grey", shape: "ring", text: "waiting for init node" });

        function getCompiledFormula(index, formulaStr) {
            const key = index + ":" + formulaStr;
            if (!node._formulaCache.has(key)) {
                node._formulaCache.set(key, compileFormula(formulaStr));
            }
            return node._formulaCache.get(key);
        }

        node.on('input', async function(msg, send, done) {
            send = send || function() { node.send.apply(node, arguments); };

            if (node.rows.length === 0) {
                node.error("No sensor channels configured", msg);
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
            // One array slot per configured channel/output - send() with an
            // array sends outputs[i] to node output i (Node-RED's standard
            // behavior for nodes with multiple outputs). Channels where an
            // error occurs stay null (= no msg on this output for this run).
            const outputs = new Array(node.rows.length).fill(null);

            try {
                // Sequential: the next query only starts AFTER the response to
                // the previous one, since the Arduino sends back exactly one
                // line per request.
                for (let i = 0; i < node.rows.length; i++) {
                    const row = node.rows[i];
                    const line = await portManager.writeAndWaitForLine(node.portPath, `${row.index}\n`);

                    const raw = parseFloat(line);
                    if (isNaN(raw)) {
                        node.error(`Unexpected response for channel ${row.index}: "${line}"`, msg);
                        continue;
                    }

                    const chCfg = channelConfig.sensors[row.index];
                    if (!chCfg) {
                        node.error(`Sensor channel ${row.index} is not available (disabled or not configured in the fossdaq-init node)`, msg);
                        continue;
                    }
                    const formulaStr = chCfg.formula || "S";

                    let value;
                    try {
                        value = getCompiledFormula(row.index, formulaStr)(raw);
                    } catch (formulaErr) {
                        node.error(`Formula error for channel ${row.index}: ${formulaErr.message}`, msg);
                        value = raw;
                    }

                    outputs[i] = {
                        ...msg,
                        payload: value,
                        raw: raw,
                        topic: String(row.index)
                    };
                }
                send(outputs);
                node.status({ fill: "green", shape: "dot", text: "ok" });
                if (done) done();
            } catch (err) {
                send(outputs);
                node.error("Error during sensor query: " + err.message, msg);
                node.status({ fill: "red", shape: "ring", text: "read error" });
                if (done) done(err);
            }
        });
    }

    RED.nodes.registerType("fossdaq-input", FossdaqInputNode);
};
