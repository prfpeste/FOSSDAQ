# buildinginstructions do-PWM-1to6x

## cutting PCBs to size

Make sure that the copper side faces down and that the copper lines are directed in the direction of the blue arrow in the upper left corner.
The PCBs can be cut with a regular metal saw. It is recommended to deburr the freshly cut edges.

<img src="../images/PCB_cutout_1.png" alt="PCB 1" width="700" />
The measurements are: 
- a -> 39 holes
- b -> 26 holes
- c -> 19 holes
- d -> 4 holes
- e -> 14 holes
- f -> 7 holes

<img src="../images/PCB_cutout_2.png" alt="PCB 2" width="700" />
The measurements are:
- g -> 11 holes
- h -> 39 holes


## Description of used symbols
|symbol|description|
|---|---|
|<img src="../images/pin.png" alt="" width="160" />|jumper pin|
|<img src="../images/wire_down.png" alt="" width="160" />|wire exiting underneath the PCB|
|<img src="../images/wire_up.png" alt="" width="160" />|wire exiting on top of the PCB|
|<img src="../images/resistor.png" alt="" width="160" />|electrical resistor (10 kOhm)|
|<img src="../images/diode.png" alt="" width="160" />|diode (Taiwan Semiconductor Company - 1N5819)|
|<img src="../images/transistor.png" alt="" width="160" />|transistor; arrows pointing in the direction of the writing on the transistor (STMicroelectronics - TIP41C)|
|<img src="../images/mosfet.png" alt="" width="160" />|mosfet; arrows pointing in the direction of the writing on the mosfet (infineon - IRLZ 44N)|
|red lines| cut the copper strips with a sharp knife|

## Assembly

Make sure that the copper side faces down and that the copper lines are directed in the direction of the blue arrow in the upper left corner.

<img src="../images/PCB_6x.png" alt="Assembled PCB" width="700" />

It is recommended to insert all the jumper pins first. Do not solder them immediately.

Take the second PCB and align it on top of the first PCB as shown.

All the jumper pins should now be placed through both PCBs. Completely solder two jumper pins to mechanically connect the two PCBs and prevent the other jumper pins from falling out.

<img src="../images/connection_PCB_1_2.png" alt="" width="700" />

- 1 -> PCB 1
- 2 -> PCB2
- 3 -> copper lines
- 4 -> metal part of jumper pins
- 5 -> plastic part of jumper pins
