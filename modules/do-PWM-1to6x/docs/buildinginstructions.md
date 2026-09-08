# buildinginstructions do-PWM-1to6x

## cutting PCBs to size

> IMPORTANT:  
> Make sure that the copper side of the larger PCB faces down and that the copper lines are directed in the direction of the blue arrow in the upper left corner.
> The copper lines of the larger PCB always face down, until written otherwise!

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

<img src="../images/terminal_24V_cutout.png" alt="24 V terminal cutout" width="300" />

## Description of used symbols
|symbol|description|
|---|---|
|<img src="../images/pin.png" alt="" width="160" />|jumper pin|
|<img src="../images/wire_down.png" alt="" width="160" />|wire exiting underneath the PCB (approximately 20 cm)|
|<img src="../images/wire_up.png" alt="" width="160" />|wire exiting on top of the PCB (approximately 20 cm)|
|<img src="../images/resistor.png" alt="" width="160" />|electrical resistor (10 kOhm)|
|<img src="../images/diode.png" alt="" width="160" />|diode (Taiwan Semiconductor Company - 1N5819)|
|<img src="../images/transistor.png" alt="" width="160" />|transistor; arrows pointing in the direction of the writing on the transistor (STMicroelectronics - TIP41C)|
|<img src="../images/mosfet.png" alt="" width="160" />|mosfet; arrows pointing in the direction of the writing on the mosfet (infineon - IRLZ 44N)|
|red lines| cut the copper strips with a sharp knife|
|large white dots|soldering points|
|small white dots|open PCB holes|

## Modulation of transistor
To manufacture the main PCB, the right legs of the transistors must be bent outward as shown in Figure below.

For this, the leg should be bent to the right directly below the edge (A), where the leg becomes thicker. Approximately three to five millimeters further down (B), the leg should then be bent to the left again. The leg does not need to fit into the PCB's hole grid on the first attempt. The end of the leg (C) can simply be pulled down or pushed up. This adjusts the distance between the legs, making it smaller or larger.

It is important that, in the end, all legs are more or less parallel to each other and that there is one row on the PCB free between the right and middle legs.

<img src="../images/transistor_modulation.png" alt="Modulation of transistor" width="400" />

## PCB assembly

> IMPORTANT:  
> Make sure that the copper side of the larger PCB faces down and that the copper lines are directed in the direction of the blue arrow in the upper left corner.
> The copper lines of the larger PCB always face down, until written otherwise!

<img src="../images/PCB_6x.png" alt="Assembled PCB" width="700" />

If fewer than six outputs are required, consider the following alternatives (greyed-out sections are for reference only and do not require soldering).

- [5x](../images/PCB_5x.png)
- [4x](../images/PCB_4x.png)
- [3x](../images/PCB_3x.png)
- [2x](../images/PCB_2x.png)
- [1x](../images/PCB_1x.png)

It is recommended to insert all the jumper pins first. Do not solder them immediately.

Take the second PCB and align it on top of the first PCB as shown.

All the jumper pins should now be placed through both PCBs. Completely solder two jumper pins to mechanically connect the two PCBs and prevent the other jumper pins from falling out.

<img src="../images/connection_PCB_1_2.png" alt="" width="700" />

- 1 -> PCB 1
- 2 -> PCB2
- 3 -> copper lines
- 4 -> metal part of jumper pins
- 5 -> plastic part of jumper pins

> IMPORTANT:  
> Now, flip the PCB to the opposite side from its current position.

<img src="../images/assemble_inv.png" alt="" width="700" />

Solder the DIL-14 socket as depicted in the image above. Insert the 74HCT14TI chip into the socket, ensuring the notch is oriented upward.

> IMPORTANT:  
> Now, flip the PCB to the opposite side from its current position.

After assembling all components as previously described and connecting both PCBs, your setup should resemble the following, excluding the six wires and the cut copper traces. Add them.

All wires are described in the image below. You can either tag them now with a small sticky note or refer back to the image later to identify their connections.
<img src="../images/PCB_1_2_w_inv.png" alt="" width="700" />


## Terminals
> IMPORTANT:  
> The terminal pins do not fit into the PCB holes. Carefully file the diameter down slightly.

### 24 V terminal

<img src="../images/Terminal_24V.png" alt="" width="300" />  

The image above shows the placement of the 4-pole spring-loaded terminal on the previously cut PCB. The orange circles indicate the terminal pins, and the arrows denote the direction of the terminal ports.
Connect the pins with wires short wires. Add one pair of long wires (approximately 20 cm) for one pair of pins. It is recommended to use red for 24 V and black for GND. See the image below for clarity.

<img src="../images/Terminal_24V_real.jpeg" alt="" width="300" />


### Output terminal
