module.exports = function(RED) {
    const portManager = require('./port-manager.js');

    // Single-input, no-output node: on every incoming msg it simply calls
    // portManager.broadcastError(), i.e. sends "ERROR\n" to every currently
    // open Arduino connection - the same broadcast that fossdaq-init/-input/
    // -output trigger automatically on a severe (red) error. This node lets
    // that same state be triggered explicitly from within a flow (e.g. from
    // an emergency-stop button, a watchdog, or custom logic that detects a
    // problem the fossdaq nodes themselves wouldn't catch).
    function FossdaqBroadcastErrorNode(config) {
        RED.nodes.createNode(this, config);
        const node = this;

        node.on('input', function(msg, send, done) {
            portManager.broadcastError();
            node.status({ fill: "red", shape: "dot", text: "broadcast sent" });
            if (done) done();
        });
    }

    RED.nodes.registerType("fossdaq-broadcast-error", FossdaqBroadcastErrorNode);
};
