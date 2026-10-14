// FOSSDAQ — di-4x-5V: Build Manual
// Save as di-4x-5V/docs/build-manual.typ.
// The separate style file belongs in di-4x-5V/docs/fossdaq-style.typ.
// Images belong in di-4x-5V/images/.
// From the module directory:
// typst compile --root . docs/build-manual.typ docs/build-manual.pdf

#import "fossdaq-style.typ": *

#show: doc => setup-doc(doc, doc-title: "di-4x-5V — Build Manual")

#doc-cover(
  "di-4x-5V",
  [Build Manual \ 4-channel digital pulse / frequency input card on TS-35 DIN rail],
  (
    ("Project:", "FOSSDAQ"),
    ("Module:", "di-4x-5V"),
    ("Author:", "Sergej Tsoy"),
    ("Supervision:", "Prof. Dr. Peter Stein, HTWG Konstanz"),
    ("Hardware version:", "v1.0 (October 2026)"),
  ),
)

#outline(title: "Contents", indent: 1.5em, depth: 2)

= Basic data

#doc-intro[
The `di-4x-5V` card measures pulse frequencies from up to *four* sensors.
It uses an Arduino Nano R4 with 5 V digital logic and sends the measured
frequencies to a Raspberry Pi via USB. The Raspberry Pi / Node-RED performs
the sensor-specific conversion, for example from frequency to flow in l/min.
]

#spec-table(
  ([Property], [Value]),
  [Function], [4 digital pulse / frequency inputs],
  [Controller], [Arduino Nano R4],
  [Input pins], [D2, D3, D8 and D12],
  [Signal], [Digital pulses between GND and 5 V],
  [Bus supply], [24 V DC; common ground],
  [Sensor supply], [Adjustable LM2596S output; maximum 21 V, subject to the sensor supply rating],
  [Transfer], [Frequency multiplied by 100; USB serial to the Raspberry Pi],
  [Example], [75.56 Hz is transmitted as 7556],
  [Mounting], [Printed enclosure for a TS-35 DIN rail],
  [Isolation], [No galvanic isolation between the sensors and the controller; common ground],
)

#warn-box(title: "Signal compatibility")[
  Only connect signals compatible with the Nano R4's 5 V digital inputs.
  A sensor supply rating alone does not establish signal compatibility.
  Do not connect 24 V signals directly to the input pins.
  
  The DC/DC converter supplies the sensors and the Arduino Nano R4's VIN pin.
The Nano R4 accepts a VIN supply of *up to 21 V*. If a sensor requires more
than 5 V, the converter output can be adjusted accordingly, to a *maximum
of 21 V*, provided the selected voltage is permitted for every connected sensor.
The digital signal inputs remain limited to 5 V.
]

#pagebreak()
= Components

Parts required for one card (see `../bom/` for the machine-readable bill of materials):

#spec-table(
  ([Qty], [Part], [Order code], [Supplier], [Purpose]),
  [1], [Arduino Nano R4], [ARD NANO R4], [Reichelt], [Pulse acquisition and USB serial communication],
  [2], [Double-sided perfboard, 80 × 20 mm, 2.54 mm pitch], [LR-DS-28], [Reichelt], [Sensor terminal carrier and a cut strip for the bus terminal],
  [4], [6-pole spring terminal AST 025-06], [AST 025-06], [Reichelt], [One sensor channel per terminal; three poles used per terminal in the schematic],
  [1], [4-pole spring terminal AST 025-04], [AST 025-04], [Reichelt], [24 V / GND input and pass-through],
  [1], [LM2596S DC/DC module with display], [LM2596S], [Reichelt], [Local sensor & Nano R4 supply],
  [1], [USB-A data cable with USB-C connector for the Nano R4], [-], [free choice], [Connection to the Raspberry Pi],
  [$approx$ 4 m], [stranded wire H05V-K 1 x 0.75 mm², red / black / green / gray], [-], [Conrad],
  [wire colors freely selectable; recommended as shown in the schematic], [$>= $ 12], [Screws M2.3 x 6mm & M1.2 x 6mm, self-tapping, PA Phillips Head], 
  [B0G6SWF81Z], [Amazon], [cover screws, thread directly into the printed plastic],
  [-], [PLA Filament, 1.75 mm], [-], [3D printing the enclosure and latch pin],[PETG as alternative],
)

Tools: soldering iron, solder, fine saw, side cutter, wire stripper,
multimeter and suitable screwdrivers. Deburr cut perfboard edges and printed parts.


#pagebreak()
= Circuit

== Schematic

The card consists of a 24 V bus terminal, an LM2596S converter, an Arduino
Nano R4 and four sensor terminals. The sensor ground and controller ground
share a common reference. Editable circuit sources belong in the module's
`hardware/kicad/` directory.

#figure(
  image("../images/schematic-di-4x-5V.jpeg", width: 100%, height: 132mm, fit: "contain"),
  caption: [Schematic of the di-4x-5V card],
)

#spec-table(
  ([Section], [Function]),
  [Bus terminal], [Receives 24 V and GND; passes both rails to the next module],
  [DC/DC converter], [Provides the common sensor and VIN supply; adjustable up to 21 V according to sensor requirements],
  [Nano R4], [Measures the four input frequencies and sends scaled values via USB],
  [Sensor terminals], [Provide supply, signal and ground connections for four sensors],
)

#pagebreak()
== Current budget

Arduino and sensors share the 5 V output of the LM2596S converter, so this module is the limiting element:
#spec-table(
  ([Item], [Current]),
  [LM2596S, 5 V output], [up to 2 A continuous],
  [Arduino Nano R4], [$approx$ 50 mA],
  [4 sensors at 10-30 mA each], [$approx$ 40-120 mA],
  [Total],[$approx$ 90-170 mA],
)

The total load of roughly 90–170 mA is well below the converter's 2 A rating. Check the datasheet of each sensor for its actual supply current and ensure the total does not exceed the converter's rating. Only power-hungry sensors drawing several hundred mA each may require a separate supply.

#pagebreak()
= Sensor connections and conversion

== Terminal allocation

Each 6-pole terminal is assigned to *one* channel. The schematic uses poles
1–3; poles 4–6 have no sensor connection shown. Check the physical orientation
against the schematic and the enclosure labels before connecting a sensor.

#spec-table(
  ([Terminal pole], [Function]),
  [1], [GND / 0 V],
  [2], [Sensor supply from the converter; +5 V shown in the schematic],
  [3], [Digital sensor signal],
  [4–6], [Unused in the supplied schematic],
)

The following connections are taken from the schematic. The order of
channels in the transmitted data must match the firmware and enclosure labels.

#spec-table(
  ([Schematic terminal], [Signal pin on Nano R4]),
  [J13], [D12],
  [J14], [D8],
  [J15], [D3],
  [J16], [D2],
)

== YF-S201 flow sensor

#spec-table(
  ([Property], [Value]),
  [Principle], [Hall-effect pulse output],
  [Connection on this card], [+5 V, digital signal, GND],
  [Nominal conversion factor], [7.5 Hz per l/min],
  [Sensor relationship], [`f_Hz = 7.5 * Q_l_min`],
  [Transmitted value], [`x = 100 * f_Hz`],
  [Pi / Node-RED conversion], [`Q_l_min = x / 750`],
)

For example, 75.56 Hz is transmitted as 7556:

$ Q = 7556 / 750 approx 10.07 "l/min" $

The factor 7.5 is the nominal YF-S201 conversion used here; verify it against
the exact sensor datasheet and calibrate if required. For another sensor,
change its conversion on the Pi while retaining the card's frequency scaling.



#pagebreak()
= Enclosure and 3D printing

The enclosure contains the terminal carriers, controller and converter.
The cover closes the side; a separate printed latch pin secures the card
to the DIN rail. Editable CAD files belong in `hardware/cad/`; print files
belong in `hardware/print/`.

#spec-table(
  ([Part], [FreeCAD file], [Function]),
  [Main body], [`enclosure_body+slate.FCStd`], [Holds the electronics and provides the terminal openings and DIN-rail mounting],
  [Lid], [`enclosure_lid.FCStd`], [Closes the enclosure and is fastened with screws],
  [Latch pin], [`enclosure_pin.FCStd`], [Locks the module onto the DIN rail],
)

== Main body

The main body holds the carrier board with the terminals, the LM2596S converter and the Arduino Nano R4. The printed part has openings for the 24 V bus terminal, the four sensor terminals and the USB-C connector. The DIN-rail latch pin is inserted into the main body and secures the module to the rail.

#figure(
  image("../images/enclosure-iso-open.png", width: 70%, fit: "contain"),
  caption: [Open main enclosure],
)

#pagebreak()
== Lid

The lid closes the enclosure and is fastened with four self-tapping screws.

#figure(
  image("../images/cover.png", width: 70%, fit: "contain"),
  caption: [Side cover],
)

== DIN-rail latch pin

The pin is identical design to the pi-base pin: a separately printed springy element. Pushing the enclosure onto the rail makes it snap in; to release it, pull the pin back with a flat screwdriver or similar tool.

#figure(
  image("../images/pin.png", width: 70%, fit: "contain"),
  caption: [DIN-rail latch pin],
)

#pagebreak()
== 3D printing

The print process is identical to the pi-base module. 

#spec-table(
  ([Parameter], [Value]),
  [Filament],[PLA or alternatively PETG],
  [Nozzle / bed (PLA)],[210 °C / 60 °C],
  [Nozzle / bed (PETG)],[230 °C / 80 °C],
  [Supports],[not required],
  [Attention],[thin walls of the slide-in slot - check the first layer carefully]
)


#pagebreak()
= 24 V bus terminal assembly

The bus input sits on a narrow strip cut from the 80 × 20 mm perfboard.
Two terminal poles receive 24 V and GND, and the second pair provides
pass-through for the next module. Bridge only matching supply potentials.

#figure(
  image("../images/perfboard-80x20-raw.jpeg", width: 80%, height: 35mm, fit: "contain"),
  caption: [Raw double-sided perfboard, 80 × 20 mm.],
)

+ *Cut and deburr the strip.* Use the marked cut lines as a guide and check
  the fit in the enclosure before soldering.
+ *Mount the 4-pole terminal.* Solder the AST 025-04 to the strip and connect
  the two 24 V poles to each other and the two ground poles to each other.
+ *Check continuity.* Verify the pass-through connections and confirm there
  is no short circuit between 24 V and GND.
+ *Install the carrier.* Slide the completed bus-terminal carrier into its guide.

#figure(
  image("../images/bus-terminal-board-cut.jpeg", width: 80%, height: 35mm, fit: "contain"),
  caption: [Marked cuts for the bus-terminal carrier.],
)
#figure(
  image("../images/bus-terminal-solder-side.png", width: 55%, height: 55mm, fit: "contain"),
  caption: [Bus terminal with pass-through bridges, solder side.],
)

#pagebreak()
= Sensor terminal carrier board

It carries the four
6-pole terminals; one terminal is assigned to each sensor channel.

#tip-box(title: "Allow clearance for the enclosure wall")[
  Leave approximately 2 mm between the terminal bodies and the carrier board
  where the enclosure design requires it. Test the fit before completing the
  solder joints: the enclosure wall must fit into this gap.
]

+ *Place the four terminals.* Maintain the required orientation and spacing.
+ *Solder from the rear.* Check that adjacent signal poles remain separate.
+ *Bridge the supply rails.* Join the four sensor-supply connections and the four
  GND connections. Follow the schematic rather than assuming wire colors.
+ *Prepare four signal wires.* Each sensor signal must have its own wire to
  the assigned Nano R4 pin.
+ *Check the completed board.* Verify every supply and signal connection
  with a multimeter before inserting the carrier.

#figure(
  image("../images/sensor-terminals-supply-rails.jpeg", width: 85%, height: 100mm, fit: "contain"),
  caption: [Rear of the sensor carrier with common supply rails and individual signal wires.],
)

#pagebreak()
= Arduino Nano R4 wiring

Connect the four signal wires to D2, D3, D8 and D12 according to the schematic.
All sensors and the controller need a common ground. The sensor rail comes
from the converter; do not route the combined sensor load through an Arduino
GPIO pin.

#spec-table(
  ([Pin / connection], [Purpose]),
  [D2, D3, D8, D12], [Four independent pulse inputs],
  [GND0, GND1], [Common reference for sensors, converter and controller],
  [VIN], [Supply from the DC/DC converter; specified VIN range 5–21 V],
  [USB-C], [Serial data link; can also supply the board through USB],
)

#figure(
  image("../images/nano-pins.jpeg", width: 65%, height: 100mm, fit: "contain"),
  caption: [Prototype wiring at the Arduino Nano R4 headers.],
)

The supplied photos document the assembled prototype. Verify pin labels
directly on the board and match each input to the channel order used by the
firmware.

#pagebreak()
= Mechanical assembly and converter setup

+ *Deburr the enclosure.* Check the carrier slots and terminal openings.
+ *Mount the converter.* Keep the adjustment potentiometer and USB connector
  accessible; prevent conductive parts from contacting unintended wiring.
+ *Connect the converter input.* Observe polarity at the 24 V bus terminal.
+ *Set the supply voltage.* With the sensors disconnected, adjust the converter
  output to the required supply voltage, verified by a multimeter. Use a setting
  within the Nano R4's 5–21 V VIN range and the permitted supply range of every
  connected sensor. Then switch the supply off.
+ *Connect the Nano R4 supply.* Connect the converter output to VIN and
  the common ground to GND.
+ *Insert the terminal carriers.* Ensure the enclosure wall fits into the
  terminal-to-board clearance.
+ *Connect and route the wires.* Keep signal and supply connections secure;
  avoid pinching wires when the cover is fitted.
+ *Install the cover and latch pin.* Check the DIN-rail attachment and release.

#figure(
  image("../images/all-connections.jpeg", width: 65%, fit: "contain"),
  caption: [All connections visible without the enclosure.],
)
#figure(
  image("../images/dcdc-setup.jpeg", width: 60%, fit: "contain"),
  caption: [Prototype with the LM2596S display showing approximately 5 V.],
)
#figure(
  image("../images/assembled-open-top.jpeg", width: 60%, fit: "contain"),
  caption: [Assembled di-4x-5V prototype with the cover removed.],
)

#pagebreak()
= Checks before commissioning

+ *Inspect the wiring and solder joints.* Check polarity, unintended bridges,
  exposed conductors and strain on the headers.
+ *Check continuity with power off.* Confirm the bus pass-through, common
  ground, sensor supply connections and the four individual signal paths.
+ *Verify the supply voltage.* Confirm the converter setting is within the
  permitted supply ranges of the Nano R4 and all connected sensors; maximum 21 V.
+ *Test the converter without sensors.* Use a current-limited supply and
  confirm the supply rail remains at the selected voltage under the intended load.
+ *Connect one compatible sensor.* Confirm correct supply polarity and
  that the digital signal remains within the input range.
+ *Test acquisition over USB.* Upload the matching firmware, initialize
  according to its serial protocol and confirm the assigned channel responds.
+ *Check Pi-side conversion.* For the YF-S201, a received value of 7556
  must yield approximately 10.07 l/min after division by 750.
+ *Repeat for all channels.* Match each physical connector to the enclosure
  label and the corresponding field in the received data.
+ *Check the mechanics.* Verify terminal retention, USB clearance, cover fit
  and secure DIN-rail mounting.
#pagebreak()
= Finished module
The connector labels can be printed from the file `../docs/connector-labels.pdf`. 

To attach them to the enclosure, first cover both sides of the printed paper with clear adhesive tape. This helps protect the labels from water and dirt. Then attach the labels to the measurement module using double-sided adhesive tape.

The following three images show where the labels should be placed on the enclosure.
#figure(
  image("../images/bottom-view-finished-module.jpeg", width: 85%, height: 95mm, fit: "contain"),
  caption: [Bottom view with ventilation grid.],
)

#figure(
  image("../images/top-view-finished-module.jpeg", width: 85%, height: 95mm, fit: "contain"),
  caption: [Top view with the 24 V bus terminal and the USB-C socket.],
)

#figure(
  image("../images/side-view-finished-module.jpeg", width: 85%, height: 95mm, fit: "contain"),
  caption: [Side view with the signal terminals.],
)

