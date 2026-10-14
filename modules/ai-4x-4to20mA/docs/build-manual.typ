// FOSSDAQ — ai-4x-4to20mA: Build Manual
// Save as ai-4x-4to20mA/docs/build-manual.typ.
// The separate style file belongs in ai-4x-4to20mA/docs/fossdaq-style.typ.
// Images belong in ai-4x-4to20mA/images/.
// From the module directory:
// typst compile --root . docs/build-manual.typ docs/build-manual.pdf

#import "fossdaq-style.typ": *

#show: doc => setup-doc(doc, doc-title: "ai-4x-4to20mA — Build Manual")

#doc-cover(
  "ai-4x-4to20mA",
  [Build Manual \ 4-channel 4–20 mA current input card on TS-35 DIN rail],
  (
    ("Project:", "FOSSDAQ"),
    ("Module:", "ai-4x-4to20mA"),
    ("Author:", "Sergej Tsoy"),
    ("Supervision:", "Prof. Dr. Peter Stein, HTWG Konstanz"),
    ("Hardware version:", "v1.0 (October 2026)"),
  ),
)

#outline(title: "Contents", indent: 1.5em, depth: 2)

= Basic data

#doc-intro[
The `ai-4x-4to20mA` card measures the loop current of up to *four* 4–20 mA
sensors. Four INA219 modules communicate with an Arduino Nano R4 over I²C.
The controller sends the measured current in integer microamperes to a
Raspberry Pi via USB. The Raspberry Pi / Node-RED performs the sensor-specific
conversion, for example from current to flow in l/min.
]

#spec-table(
  ([Property], [Value]),
  [Function], [4 analog current inputs for 4–20 mA loops],
  [Controller], [Arduino Nano R4],
  [Acquisition], [4 INA219 modules; one shunt per sensor loop],
  [Interface], [I²C on A4 / SDA and A5 / SCL; addresses 0x40, 0x41, 0x44, 0x45],
  [Bus supply], [24 V DC; common ground; input and pass-through],
  [Sensor supply], [Shared adjustable LM2596S output; 5 V shown in the schematic; verify the exact sensor rating],
  [INA219 logic supply], [Nano R4 5 V pin; common GND],
  [Transfer], [Integer current in µA; USB serial at 9600 baud],
  [Example], [12.00 mA is transmitted as 12000],
  [Mounting], [Printed enclosure for a TS-35 DIN rail],
  [Isolation], [No galvanic isolation between channels, sensors and controller],
)

#info-box(title: "Module supply")[
  The converter output is adjustable between *5 V and 21 V* for this build.
  The assembled prototype operates at 5 V according to the builder's test.
  Select the output voltage according to the connected sensors and verify
  it with a multimeter before connection. The converter supplies the sensor
  L+ rail and Nano VIN. Connect INA219 VCC to the Nano's regulated 5 V rail.
]

#pagebreak()
= Components

Parts required for one card. See `../bom/BOM.csv` for the complete bill of
materials, including all individual wire lengths, order codes and product
links. Wire lengths are combined below for the build manual.

#spec-table(
  ([Qty], [Part], [Order code], [Supplier], [Purpose]),
  [1], [Arduino Nano R4], [ARD NANO R4], [Reichelt], [I²C acquisition and USB serial communication],
  [2], [Double-sided perfboard, 80 × 20 mm, 2.54 mm pitch], [LR-DS-28], [Reichelt], [Sensor terminal carrier and cut strip for the bus terminal],
  [1], [JOY-IT LM2596S DC/DC step-down converter with display], [DEBO DCDC DOWN 5], [Reichelt], [Adjustable module supply],
  [4], [INA219 current-sensor breakout], [DEBO SENS POWER], [Reichelt], [One current measurement per sensor loop],
  [4], [6-pole spring terminal, 5 mm pitch], [AST 025-06], [Reichelt], [Sensor terminals],
  [1], [4-pole spring terminal, 5 mm pitch], [AST 025-04], [Reichelt], [24 V bus input and pass-through],
  [1], [USB-A to USB-C data cable, 2 m], [EAN 5705730336140], [Reichelt], [Data link and Nano power supply],
  [$approx$ 6 m], [H05V-K stranded wire: 4 m at 0.75 mm² and 2 m at 0.5 mm²; red, orange, black, blue, brown, green and purple], [See BOM.csv], [Conrad], [Power and I²C wiring; individual colors, lengths and EANs listed in BOM.csv],
  [1 set], [Self-tapping PA Phillips head screws: 4 × M1.2 × 6 mm and 24 × M2.3 × 6 mm], [B0G6SWF81Z], [Amazon], [Fasten electronics and lid],
  [min. 150 g], [PLA / PETG filament], [-], [free choice], [Printed enclosure parts],
)

Tools: soldering iron, solder, fine saw, side cutter, wire stripper,
multimeter and suitable screwdrivers. Deburr cut perfboard edges and printed
parts. A current-limited DC supply and a suitable loop-current source or
compatible sensor are needed for commissioning.

#pagebreak()
= Circuit

== Schematic

The card consists of a 24 V bus terminal, an LM2596S converter, an Arduino
Nano R4, four INA219 modules and four sensor terminals. The sensor currents
are measured in the return paths. Controller, converter and INA219 logic
grounds share a common reference. Editable circuit sources are in
`hardware/kicad/ai-4x-4to20mA.kicad_sch`.

#figure(
  image("../images/schematic-ai-4x-4to20mA.jpeg", width: 100%, height: 100mm, fit: "contain"),
  caption: [Schematic of the ai-4x-4to20mA card.],
)

#spec-table(
  ([Section], [Function]),
  [Bus terminal J1 / J2], [Receives 24 V and GND; passes both rails to the next module],
  [DC/DC converter U1], [Supplies the sensor L+ rail and Nano VIN],
  [INA219 IC1–IC4], [Measure each loop return current across an individual shunt; communicate over I²C],
  [Nano R4 A1], [Averages current readings and returns µA on request over USB],
  [Sensor terminals J3–J6], [Connect L+ to the converter rail and L− to the assigned INA219 VIN−],
)

#info-box(title: "Shunt polarity in the supplied schematic")[
  The schematic connects each INA219 *VIN+ to common GND* and *VIN− to the
  sensor L− return*. Normal loop current therefore produces a negative signed
  reading. The supplied firmware averages ten samples and sends the absolute
  value in µA. This documents the supplied polarity; the absolute value alone
  cannot detect reverse current or incorrect loop wiring. Never bridge the
  sensor L− directly to GND: that would bypass its measuring shunt.
]

#pagebreak()
== Current budget

The converter feeds the sensor loops and the Nano VIN input. The Nano's 5 V rail supplies the INA219 logic.

#spec-table(
  ([Item], [Current / check]),
  [Four sensor loops], [16–80 mA at nominal 4–20 mA per loop],
  [Four INA219 ICs], [Up to approximately 4 mA combined IC supply current; breakout components add load],
  [Nano R4 and converter display], [Determine actual consumption for the operating configuration],
  [Converter and Nano regulator], [Check the specific module rating, voltage, wiring and temperature under load],
)

The loop current and electronics consumption are different budget items.
For a VIN-powered Nano, convert its input power to converter output current
at the selected voltage; do not simply add a 5 V current figure at another
voltage. For USB power, include the Nano and INA219 logic in the USB budget.
Allow for sensor fault/overrange current according to the sensor datasheet.
No continuous 2 A rating is assumed for an unidentified LM2596S breakout.

#pagebreak()
= Sensor connections and conversion

== Terminal allocation

Each 6-pole terminal is assigned to *one* loop. The schematic uses poles
1–2; poles 3–6 have no sensor connection shown. Check the physical orientation
against the schematic and enclosure labels before connecting a sensor.
The photos show two rows of terminals; do not infer pole numbering from
left-to-right order in a photograph.

#spec-table(
  ([Terminal pole], [Function]),
  [1], [L−: sensor return to the individual INA219 VIN−; not a direct GND connection],
  [2], [L+: sensor supply from the converter],
  [3–6], [Unused in the supplied schematic],
)

Connect each sensor terminal to the INA219 module assigned below.
Use the same channel numbers for the enclosure labels.

#spec-table(
  ([Housing channel], [USB index], [Terminal / mating part], [INA219], [I²C address]),
  [1], [0], [J3 / J7], [IC1 / ina0], [0x40],
  [2], [1], [J4 / J8], [IC2 / ina1], [0x41],
  [3], [2], [J6 / J10], [IC4 / ina3], [0x45],
  [4], [3], [J5 / J9], [IC3 / ina2], [0x44],
)

== AS007 vortex sensor / 4–20 mA conversion

The autosen AS007 provides a 4–20 mA flow output. Connect sensor pin 1
(L+) to the terminal's L+ supply and pin 4 (OUT1, flow) to its L− measuring
return. The optional temperature output on pin 2 is not used here.
The supplied circuit illustration labels its example sensors AS010; the
conversion below applies specifically to the AS007.

#spec-table(
  ([Property], [Value]),
  [Sensor], [autosen AS007, DN10, G3/4A],
  [Flow measuring range], [1.8–32 l/min],
  [Flow output], [4–20 mA; sensor pin 4 / OUT1],
  [Firmware acquisition], [10 samples per request, with 5 ms delay per sample],
  [Transmitted value], [Integer current in µA: `x = round(abs(mean(I_mA)) * 1000)`],
  [Water conversion], [`Q_l_min = 2 * (I_mA - 4)`],
  [Pi / Node-RED conversion], [`Q_l_min = (x - 4000) / 500`],
)

For water, the 4–20 mA output corresponds to a 0–32 l/min analog scale.
The lower specified measuring limit is 1.8 l/min; it is not the 4 mA
scaling endpoint. With a received value of 12000 µA:

$ I = 12000 / 1000 = 12 "mA" $
$ Q = 2 times (12 - 4) = 16 "l/min" $

For glycol mixtures with kinematic viscosity `u` above 1.8 cSt and below
14 cSt, the manufacturer gives the corrected AS007 relationship:

`Q_l_min = (x - 4000) / 500 - 0.40 * u + 0.40`

The corresponding response threshold is `Q_min = u + 0.8` in l/min.
Use the viscosity for the actual mixture and temperature. Below the
response threshold, the stated measurement accuracy does not apply.

Source: #link("https://media.autosen.com/Shopsystem/Assets/en/AS006-AS011_manual.pdf")[autosen AS006–AS011 operating instructions].

#pagebreak()
= Enclosure and 3D printing

The enclosure contains the terminal carriers, four INA219 modules, controller and converter.
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

The main body holds the terminal carriers, four INA219 modules, the LM2596S converter and the Arduino Nano R4. The printed part has openings for the 24 V bus terminal, the four sensor terminals and the USB-C connector. The DIN-rail latch pin is inserted into the main body and secures the module to the rail.

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

The pin is a separately printed springy element of the same DIN-rail latch type as the pi-base pin. Pushing the enclosure onto the rail makes it snap in; to release it, pull the pin back with a flat screwdriver or similar tool.

#figure(
  image("../images/pin.png", width: 70%, fit: "contain"),
  caption: [DIN-rail latch pin],
)

#pagebreak()
== 3D printing

The print process follows the same approach as the pi-base module. The temperatures below are starting values; adjust them to the filament manufacturer and printer. 

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
  image("../images/perfboard-80x20-raw.jpg", width: 80%, height: 35mm, fit: "contain"),
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
  image("../images/bus-terminal-board-cut.jpg", width: 80%, height: 35mm, fit: "contain"),
  caption: [Marked cuts for the bus-terminal carrier.],
)
#figure(
  image("../images/bus-terminal-solder-side.png", width: 55%, height: 55mm, fit: "contain"),
  caption: [Bus terminal with pass-through bridges, solder side.],
)

#pagebreak()
= Sensor terminal carrier board

The carriers hold four 6-pole terminals; one terminal is assigned to each
sensor loop. Use the carrier positions shown in the enclosure and photographs.

#tip-box(title: "Allow clearance for the enclosure wall")[
  Leave approximately 2 mm between the terminal bodies and the carrier board
  where the enclosure design requires it. Test the fit before completing the
  solder joints: the enclosure wall must fit into this gap.
]

+ *Place the four terminals.* Maintain the required orientation and spacing.
+ *Solder from the rear.* Keep the four individual L− terminals separate.
+ *Bridge the sensor supply rail.* Join only the four pole-2 L+ connections
  to the converter output. Pole-1 L− connections must not be bridged together
  or connected directly to common GND.
+ *Prepare four return wires.* Connect each pole-1 L− to VIN− of its assigned
  INA219. Connect each INA219 VIN+ to common GND as in the supplied schematic.
+ *Prepare the logic connections.* Connect VCC and GND of the four INA219
  modules to the Nano's 5 V and common GND; share SDA and SCL separately.
+ *Check the completed board.* Verify the supply rail, isolated loop returns
  and individual shunt paths before inserting the carriers.

#figure(
  image("../images/sensor-terminals-supply-rails.jpeg", width: 85%, height: 100mm, fit: "contain"),
  caption: [Sensor-terminal carrier: shared L+ supply and separate shunt return wiring.],
)

#pagebreak()
= Arduino Nano R4 wiring

Connect the four INA219 modules in parallel on the Nano R4's primary I²C
bus. Their addresses must be distinct. Configure the breakout address jumpers
with power off; check the actual board's jumper layout before soldering.

#spec-table(
  ([INA219 module], [Address], [A0], [A1]),
  [IC1], [0x40], [GND], [GND],
  [IC2], [0x41], [VCC], [GND],
  [IC3], [0x44], [GND], [VCC],
  [IC4], [0x45], [VCC], [VCC],
)

#spec-table(
  ([Pin / connection], [Purpose]),
  [A4 / SDA], [Common INA219 SDA; brown in the schematic],
  [A5 / SCL], [Common INA219 SCL; green in the schematic],
  [5 V], [Regulated supply to all INA219 VCC pins; violet in the schematic],
  [GND0, GND1], [Common converter, INA219 logic and measuring-return reference],
  [VIN], [Supply from the converter; 5–21 V adjustment range for this build],
  [USB-C], [Serial link to the Pi; USB can power the Nano when VIN is disconnected],
)

#figure(
  image("../images/nano-pins.jpeg", width: 65%, height: 100mm, fit: "contain"),
  caption: [Prototype wiring at the Arduino Nano R4 headers; insulated soldered connections.],
)

Match connections to the printed pin labels rather than wire color alone.
Use A4/A5 for this 5 V I²C wiring; the Nano R4's Qwiic interface is a separate
3.3 V interface. Keep SDA/SCL wiring short and check the combined pull-ups
when using several breakout boards. Verify all four I²C addresses before sensor testing.

#pagebreak()
= Mechanical assembly and converter setup

+ *Deburr the enclosure.* Check the carrier slots and terminal openings.
+ *Mount the converter and four INA219 modules.* Use the printed supports
  and appropriate screws. Keep the potentiometer accessible; avoid contact
  between the modules, solder joints and unrelated wiring.
+ *Connect the converter input.* Connect VIN+ to the 24 V bus and VIN− to
  common 0 V, observing polarity.
+ *Set the supply voltage.* Disconnect sensors and Nano VIN. Power the
  converter from a current-limited supply and verify its output with a
  multimeter. Set the output between 5 V and 21 V according to the connected
  sensors. Switch power off before completing the wiring.
+ *Connect the Nano and INA219 supplies.* Apply the selected Nano power
  arrangement. Connect the INA219 VCC pins only to Nano 5 V and their GND
  pins to common GND. Configure the four unique I²C addresses.
+ *Insert the terminal carriers.* Check the terminal-to-board wall clearance.
+ *Connect the loops.* Route L+ from the converter to every sensor terminal.
  Route each L− individually through its assigned INA219 shunt to common GND,
  observing the VIN− / VIN+ polarity of the supplied schematic.
+ *Route and insulate the wires.* Use heat-shrink tubing on soldered joints;
  prevent strain at the Nano headers and avoid pinching wires under the lid.
+ *Install the cover and latch pin.* Check DIN-rail attachment and release.

#figure(
  image("../images/all-connections.jpeg", width: 65%, height: 115mm, fit: "contain"),
  caption: [Prototype with the Nano header wiring and insulated shared logic connections accessible.],
)
#figure(
  image("../images/assembled-open-top.jpeg", width: 60%, height: 115mm, fit: "contain"),
  caption: [Assembled ai-4x-4to20mA prototype with the cover removed.],
)

#pagebreak()
= Checks before commissioning

USB messages are newline-terminated at 9600 baud. Initialize with `serveID`,
`initStart`, then `initEnd`; the card reports its ID and `noSettings`. After
INA219 setup, request index `0`–`3` for one integer current value. The ID prefix
is `ai-4x-4to20mA_`; a missing INA219 causes an error state.

+ *Inspect the wiring and solder joints.* Check polarity, unintended bridges,
  exposed conductors and strain on the headers.
+ *Check continuity with power off.* Confirm bus poles 1/3 are joined for
  24 V and poles 2/4 for 0 V, with no short between the rails. Check common
  ground and sensor L+ distribution. Each L− must reach GND only through
  its own shunt. A 0.1 Ω shunt can trigger a continuity beeper; visually inspect
  the path rather than relying on the beeper to exclude a bypass.
+ *Verify the supply arrangement.* Check the selected sensor voltage against
  the exact sensor specification and confirm the selected converter output
  between 5 V and 21 V.
+ *Check INA219 logic.* Confirm approximately 5 V at VCC, correct GND and
  four distinct I²C addresses: 0x40, 0x41, 0x44 and 0x45.
+ *Test the converter without sensors.* Confirm the selected voltage remains
  stable under the intended load and check component temperatures.
+ *Test one loop.* Connect a compatible two-wire sensor or loop-current test
  arrangement, with polarity checked. Verify 4, 12 and 20 mA against a reference
  meter; expected USB replies are approximately 4000, 12000 and 20000 µA.
+ *Test acquisition over USB.* Upload the matching firmware with
  `Adafruit_INA219` installed. Complete `serveID`, `initStart`, `initEnd`, then
  request indexes 0–3. Check missing-device errors and channel responses.
+ *Check Pi-side conversion.* For the AS007 with water, a received value of
  12000 corresponds to 16 l/min using `(x - 4000) / 500`.
+ *Repeat for all channels.* Confirm enclosure channels 1–4 correspond to
  addresses 0x40, 0x41, 0x45 and 0x44 in that order. Test one loop at a time
  and verify that other channels remain independent.
+ *Check the mechanics.* Verify terminal retention, USB clearance, cover fit
  and secure DIN-rail mounting.

#pagebreak()
= Finished module
The connector labels can be printed from the file `../docs/connector_labels.pdf`. 

To attach them to the enclosure, first cover both sides of the printed paper with clear adhesive tape. This helps protect the labels from water and dirt. Then attach the labels to the measurement module using double-sided adhesive tape.

The following three images show the finished enclosure and label positions.
Use L+ and L− labels for every channel according to the connection table. Use 24 V / 0 V labels for the bus input and pass-through.
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
  caption: [Side view with the four L+ / L− sensor connections.],
)


// Sensor conversion reference:
// https://media.autosen.com/Shopsystem/Assets/en/AS006-AS011_manual.pdf
