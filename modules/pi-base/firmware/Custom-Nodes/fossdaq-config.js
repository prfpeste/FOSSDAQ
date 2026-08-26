module.exports = {
    // --- Actuator board: 6 outputs whose mode (PWM/digital/off) is
    // configured during the handshake. actuatorsFromSettings: true means
    // that the value type (int/boolean) of the fossdaq-output node is NOT
    // configured separately, but is derived automatically from the mode
    // chosen here - PWM out => int (0-255), digital out => boolean,
    // off => channel is not available to the output node.
    // Settings index === actuator index.
    "do-PWM-1to6x": {
        kind: "actuator",
        actuatorsFromSettings: true,
        settings: [
            {
                index: 0,
                label: "Output 1",
                options: [
                    { value: 3, label: "off", valueType: null },
                    { value: 1, label: "PWM out (0-255)", valueType: "int", min: 0, max: 255 },
                    { value: 2, label: "digital out (on/off)", valueType: "boolean" },
                ]
            },
            {
                index: 1,
                label: "Output 2",
                options: [
                    { value: 3, label: "off", valueType: null },
                    { value: 1, label: "PWM out (0-255)", valueType: "int", min: 0, max: 255 },
                    { value: 2, label: "digital out (on/off)", valueType: "boolean" },
                ]
            },
            {
                index: 2,
                label: "Output 3",
                options: [
                    { value: 3, label: "off", valueType: null },
                    { value: 1, label: "PWM out (0-255)", valueType: "int", min: 0, max: 255 },
                    { value: 2, label: "digital out (on/off)", valueType: "boolean" },
                ]
            },
            {
                index: 3,
                label: "Output 4",
                options: [
                    { value: 3, label: "off", valueType: null },
                    { value: 1, label: "PWM out (0-255)", valueType: "int", min: 0, max: 255 },
                    { value: 2, label: "digital out (on/off)", valueType: "boolean" },
                ]
            },
            {
                index: 4,
                label: "Output 5",
                options: [
                    { value: 3, label: "off", valueType: null },
                    { value: 1, label: "PWM out (0-255)", valueType: "int", min: 0, max: 255 },
                    { value: 2, label: "digital out (on/off)", valueType: "boolean" },
                ]
            },
            {
                index: 5,
                label: "Output 6",
                options: [
                    { value: 3, label: "off", valueType: null },
                    { value: 1, label: "PWM out (0-255)", valueType: "int", min: 0, max: 255 },
                    { value: 2, label: "digital out (on/off)", valueType: "boolean" },
                ]
            },
        ],
    },

    // --- Actuator board without selectable pin mode: fixed, static actuators.
    "ao-1to3x-0to10V": {
        kind: "actuator",
        actuatorsFromSettings: true,
        settings: [{
                index: 0,
                label: "Output 1",
                options: [
                    { value: 1, label: "off", valueType: null},
                    { value: 2, label: "on", valueType: "int", min: 0, max: 10000 },
                ]
            },
            {
                index: 1,
                label: "Output 2",
                options: [
                    { value: 1, label: "off", valueType: null},
                    { value: 2, label: "on", valueType: "int", min: 0, max: 10000 },
                ]
            },
            {
                index: 2,
                label: "Output 3",
                options: [
                    { value: 1, label: "off", valueType: null},
                    { value: 2, label: "on", valueType: "int", min: 0, max: 10000 },
                ]
            }
        ],   // no settings -> node sends initEnd immediately, expects 'noSettings'
    },

    // --- Example sensor board: no settings, two sensor channels. No own
    // `label` -> default display name is simply "Sensor <index>", unless
    // the user assigns a custom name in fossdaq-init.
    "ttyACM": {
        kind: "sensor",
        settings: [],
        sensors: [
            { index: 0, formula: "S" },
            { index: 1, formula: "S" },
        ],
    },
    // add more board types...
};
