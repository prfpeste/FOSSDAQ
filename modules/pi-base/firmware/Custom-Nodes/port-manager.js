// A "manager" per port path: the map holds exactly ONE connection for
// each physical port (e.g. '/dev/arduino/boardB1234').
//
// Ownership model:
//   - open()  may only be called by the init node (fossdaq-init), once
//             on deploy. Establishes the connection.
//   - get()   is used by command nodes to use the existing connection.
//             Does NOT build anything new - if the port has not been
//             initialized yet, it returns undefined.
//   - close() may only be called by the init node (on node 'close',
//             i.e. redeploy/delete). Closes the connection permanently.
//
// Channel config:
//   - The init node (fossdaq-init) configures scale/offset per channel
//     (sensors) resp. valueType (actuators) and stores it here via
//     setChannelConfig() once the board reports "ready". Sensor/actuator
//     nodes read this via getChannelConfig() - they don't know about each
//     other and only need the values at runtime.
//
// Sequential write+wait (sensors):
//   - writeAndWaitForLine() writes once and resolves the returned promise
//     with the NEXT line received from the Arduino. The sensor node is
//     responsible for awaiting the previous promise before querying the
//     next channel (=> sequential).

const { SerialPort, ReadlineParser } = require('serialport');
const EventEmitter = require('events');

const connections = new Map();   // path -> { serial, parser, emitter, ready, pending }
const channelConfigs = new Map(); // path -> { sensors: {idx:{scale,offset}}, actuators: {idx:{valueType}} }

function open(path, baudRate = 9600) {
    if (connections.has(path)) {
        // Connection already exists (e.g. due to a quick redeploy) - reuse it
        return connections.get(path);
    }

    const emitter = new EventEmitter();
    const conn = { serial: null, parser: null, emitter, ready: false, pending: [], intentionalClose: false };

    // Native-USB boards (e.g. Arduino Nano R4 / Uno R4 - Renesas RA4M1) do a
    // FULL USB disconnect + re-enumeration on every reset, including the
    // reset that simply opening the port can trigger. That means the file
    // descriptor we just opened can die within milliseconds, well before
    // any handshake happens, and no amount of retrying at the application
    // layer helps because the connection itself is gone. Boards with a
    // separate USB-serial bridge chip (Uno/Mega) never do this - their USB
    // link to the host stays up across a sketch reset.
    //
    // To handle both transparently, this reopens the same path automatically
    // whenever the connection closes unexpectedly (not via close() below),
    // and re-emits 'open' so the init node's handshake restarts cleanly
    // against the fresh connection.
    const MAX_RECONNECT_ATTEMPTS = 10;
    const RECONNECT_DELAY_MS = 500;
    let reconnectAttempts = 0;

    function attemptOpen() {
        const serial = new SerialPort({ path, baudRate }, (err) => {
            if (err) {
                if (conn.intentionalClose) return;
                if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
                    emitter.emit('error', new Error(`Could not open ${path} after ${reconnectAttempts} attempts: ${err.message}`));
                    return;
                }
                reconnectAttempts++;
                setTimeout(attemptOpen, RECONNECT_DELAY_MS);
                return;
            }

            reconnectAttempts = 0;
            conn.serial = serial;
            conn.parser = serial.pipe(new ReadlineParser({ delimiter: '\n' }));
            conn.parser.on('data', (line) => emitter.emit('line', line.trim()));
            serial.on('error', (err2) => emitter.emit('error', err2));

            serial.on('close', () => {
                if (conn.intentionalClose) return; // close() below was called deliberately
                if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
                    emitter.emit('error', new Error(`Port ${path} closed unexpectedly and gave up reconnecting after ${MAX_RECONNECT_ATTEMPTS} attempts`));
                    return;
                }
                reconnectAttempts++;
                setTimeout(attemptOpen, RECONNECT_DELAY_MS);
            });

            emitter.emit('open');
        });
    }

    attemptOpen();

    // Dedicated consumer for writeAndWaitForLine(): every incoming line is
    // passed to the oldest open "pending" request (FIFO). Runs independently
    // of the handshake listener in fossdaq-init.js, which also listens for
    // 'line' - EventEmitter allows multiple listeners.
    emitter.on('line', (line) => {
        if (conn.pending.length > 0) {
            const entry = conn.pending.shift();
            entry.resolve(line);
        }
    });

    connections.set(path, conn);
    return conn;
}

function get(path) {
    return connections.get(path); // undefined if not yet opened
}

function close(path) {
    const conn = connections.get(path);
    if (conn) {
        conn.intentionalClose = true; // suppress the auto-reconnect above
        conn.pending.forEach(entry => entry.reject(new Error('Port was closed')));
        if (conn.serial && conn.serial.isOpen) conn.serial.close();
    }
    connections.delete(path);
    channelConfigs.delete(path);
}

function markReady(path) {
    const conn = connections.get(path);
    if (conn) conn.ready = true;
}

function isReady(path) {
    const conn = connections.get(path);
    return !!(conn && conn.ready);
}

function write(path, data) {
    const conn = connections.get(path);
    if (!conn || !conn.serial || !conn.serial.isOpen) {
        return Promise.reject(new Error(`Port ${path} is not open - is the init node deployed?`));
    }
    return new Promise((resolve, reject) => {
        conn.serial.write(data, (err) => err ? reject(err) : resolve());
    });
}

// Broadcasts "ERROR\n" to every currently open connection (every physical
// Arduino board), regardless of its port path or ready state. Intended to
// be called whenever a severe, flow-halting error occurs on any single
// board (write error, connection error, handshake failure, an Arduino
// itself reporting an error line, ...) - the other boards should be able
// to react (e.g. go to a safe state) even though the problem happened on
// a different port. Best-effort / fire-and-forget: write failures on
// individual (already broken) connections are ignored here, since there
// is nothing more we could do about them at this point.
function broadcastError() {
    connections.forEach((conn) => {
        if (conn && conn.serial && conn.serial.isOpen) {
            conn.serial.write("ERROR\n", () => {});
        }
    });
}

// Writes `data` and resolves the promise with the next line received from
// the Arduino (raw, trimmed string). For sequential sensor queries: the
// caller MUST wait for the promise before querying the next channel,
// otherwise responses get mixed up.
function writeAndWaitForLine(path, data, timeoutMs = 3000) {
    const conn = connections.get(path);
    if (!conn || !conn.serial || !conn.serial.isOpen) {
        return Promise.reject(new Error(`Port ${path} is not open - is the init node deployed?`));
    }
    return new Promise((resolve, reject) => {
        const entry = {
            resolve: (line) => { clearTimeout(timer); resolve(line); },
            reject:  (err)  => { clearTimeout(timer); reject(err); },
        };
        const timer = setTimeout(() => {
            const idx = conn.pending.indexOf(entry);
            if (idx >= 0) conn.pending.splice(idx, 1);
            reject(new Error(`Timeout: no response received from ${path}`));
        }, timeoutMs);

        conn.pending.push(entry);

        conn.serial.write(data, (err) => {
            if (err) {
                const idx = conn.pending.indexOf(entry);
                if (idx >= 0) conn.pending.splice(idx, 1);
                clearTimeout(timer);
                reject(err);
            }
        });
    });
}

function setChannelConfig(path, cfg) {
    channelConfigs.set(path, {
        sensors: (cfg && cfg.sensors) || {},
        actuators: (cfg && cfg.actuators) || {},
    });
}

function getChannelConfig(path) {
    return channelConfigs.get(path) || { sensors: {}, actuators: {} };
}

module.exports = {
    open, get, close, markReady, isReady, write,
    writeAndWaitForLine, setChannelConfig, getChannelConfig, broadcastError,
};
