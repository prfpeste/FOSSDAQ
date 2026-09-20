# I2C-6x-mux

## 0 - 3D-printing
You'll need to print the following components: 

|image|Name and Link|
|---|---|
|<img src="../images/" alt="" width="160" />|[Case](../hardware/)|
|<img src="../images/" alt="" width="160" />|[Lid](../hardware/)|
|<img src="../images/" alt="" width="160" />|[Mounting Plate Arduino](../hardware/)|
|<img src="../images/" alt="" width="160" />|[slate pin](../hardware/)|


 ## 1 - 24 V Terminal Assembly

### Materials

<table>
  <tr>
    <td rowspan="1">Pos</td>
    <td rowspan="1">Part</td>
    <td colspan="6">number of parts</td>
  </tr>

  <tr>
    <td rowspan="1">4</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/federkraftklemme_4-pol_0_08_-_1_mm_rm_5_0-72189">Spring-loaded terminal (4-pole)</td>
    <td colspan="6">1</td>
  </tr>
  <tr>
    <td rowspan="1">5</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/lochrasterplatine_doppelseitig_80_x_20_mm-319114">perforated circuit board (2.54 mm; 80 x 20 mm)</td>
    <td colspan="6">1</td>
  </tr>
  <tr>
    <td rowspan="1">7.1</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">red insulated copper stranded wire (≥ 0,5 mm²; ca. 20 cm each)</td>
    <td colspan="6">1</td>
  </tr>
  <tr>
    <td rowspan="1">7.2</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">red insulated copper stranded wire (≥ 0,5 mm²; ca. 5 cm each)</td>
    <td colspan="6">1</td>
  </tr>
  <tr>
    <td rowspan="1">7.3</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">black insulated copper stranded wire (≥ 0,5 mm²; ca. 20 cm each)</td>
    <td colspan="6">1</td>
  </tr>
  <tr>
    <td rowspan="1">7.4</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">black insulated copper stranded wire (≥ 0,5 mm²; ca. 5 cm each)</td>
    <td colspan="6">1</td>
  </tr>
  </tr>
</table>

### Tools

- soldering iron with solder
- metal saw
- vise (recommended)
- small side-cutting pliers
- small metal file

### 1.1 - Step 1: Pre-assembling Spring-loaded terminal (4-pole)

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|4|<a href="https://www.reichelt.de/de/de/shop/produkt/federkraftklemme_4-pol_0_08_-_1_mm_rm_5_0-72189">Spring-loaded terminal (4-pole)|1| |small metal file|
| | | | |vise (recommended)|

- The terminal pins are too large for the PCB holes.
- Carefully file down the edges of the pins until they fit into the holes of the perforated circuit board (80 x 20 mm) (BOM Pos 5).



### 1.2 - Step 2: cutting PCB to size

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|5|<a href="https://www.reichelt.de/de/de/shop/produkt/lochrasterplatine_doppelseitig_80_x_20_mm-319114">perforated circuit board (80 x 20 mm)|1|      |metal saw|
| | | | |vise (recommended)|

- Take one perforated circuit board (80 x 20 mm) (BOM Pos 5)
- cut it to size using a metal saw.
    - measurements are written down below.
    - dont use much force at the end of the cut. Otherwise the Strip-Grid PCB will break.
      
<img src="../images/terminal_24V_cutout.png" alt="" width="400" />

This PCB will form now on be referenced as 24 V Terminal PCB.



### 1.3 - Step 3: soldering Spring-loaded terminal (4-pole)

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|N/A|24 V Terminal PCB|1|      |soldering iron with solder|
|4|<a href="https://www.reichelt.de/de/de/shop/produkt/federkraftklemme_4-pol_0_08_-_1_mm_rm_5_0-72189">Spring-loaded terminal (4-pole)|1| ||

- Solder the 4-pole spring-loaded terminal (Pos 4) on the 24 V Terminal PCB as shown in the image below. 
  - Orange circles indicate the terminal pins.
  - The 4-pole spring-loaded terminal (Pos 4) is mounted on the side of the 24 V Terminal PCB facing towards you.
  - Arrows denote the direction of the spring loaded terminal ports.
      - The spring loaded terminal ports face down.

<img src="../images/Terminal_24V.png" alt="" width="400" />  



### 1.4 - Step 4: soldering insulated copper stranded wire to 24 V Terminal PCB

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|N/A|24 V Terminal PCB|1|      |soldering iron with solder|
|7.1|<a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">red insulated copper stranded wire (≥ 0,5 mm²; ca. 20 cm each)|1| ||
|7.2|<a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">red insulated copper stranded wire (≥ 0,5 mm²; ca. 5 cm each)|1| ||
|7.3|<a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">black insulated copper stranded wire (≥ 0,5 mm²; ca. 20 cm each)|1| ||
|7.4|<a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">black insulated copper stranded wire (≥ 0,5 mm²; ca. 5 cm each)|1| ||

- Connect both 24 V pins with one red insulated copper stranded wire (≥ 0,5 mm²; ca. 5 cm each) (BOM Pos 7.2).
- Connect both GND pins with one black insulated copper stranded wire (≥ 0,5 mm²; ca. 5 cm each) (BOM Pos 7.4).
- Ensure no connection exists between any 24 V pin and any GND pin.
- Connect one red insulated copper stranded wire (≥ 0,5 mm²; ca. 20 cm each) (BOM Pos 7.1) to one 24 V pin.
- Connect one black insulated copper stranded wire (≥ 0,5 mm²; ca. 20 cm each) (BOM Pos 7.3) to one GND pin.
- Refer to the image below for clarity.
<img src="../images/Terminal_24V_real.png" alt="" width="400" />



## 2 - Output Terminal Assembly

### Materials

<table>
  <tr>
    <td rowspan="1">Pos</td>
    <td rowspan="1">Part</td>
    <td colspan="6">number of parts</td>
  </tr>
  <tr>
    <td rowspan="1">3</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/federkraftklemme_6-pol_0_08_-_1_mm_rm_5_0-72191">Spring-loaded terminal (6-pole)</td>
    <td colspan="6">4</td>
  </tr>
  <tr>
    <td rowspan="1">5</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/lochrasterplatine_doppelseitig_80_x_20_mm-319114">perforated circuit board (80 x 20 mm)</td>
    <td colspan="6">1</td>
  </tr>
  <tr>
    <td rowspan="1">7.2</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">red insulated copper stranded wire (≥ 0,5 mm²; ca. 5 cm each)</td>
    <td colspan="6">5</td>
  </tr>
  <tr>
    <td rowspan="1">7.5</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">red insulated copper stranded wire (≥ 0,5 mm²; ca. 10 cm each)</td>
    <td colspan="6">1</td>
  </tr>
  <tr>
    <td rowspan="1">7.4</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">black insulated copper stranded wire (≥ 0,5 mm²; ca. 5 cm each)</td>
    <td colspan="6">5</td>
  </tr>
  <tr>
    <td rowspan="1">7.6</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">black insulated copper stranded wire (≥ 0,5 mm²; ca. 10 cm each)</td>
    <td colspan="6">1</td>
  </tr>
  <tr>
    <td rowspan="1">7.7</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">green insulated copper stranded wire (≥ 0,5 mm²; ca. 20 cm each)</td>
    <td colspan="6">6</td>
  </tr>
  <tr>
    <td rowspan="1">7.8</td>
    <td rowspan="1"><a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">blue insulated copper stranded wire (≥ 0,5 mm²; ca. 20 cm each)</td>
    <td colspan="6">6</td>
  </tr>
  </tr>
</table>


### Tools

- soldering iron with solder
- small side-cutting pliers
- small metal file
- vise (recommended)

### 2.1 - Step 1: Pre-assembling Spring-loaded terminal (6-pole)

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|3|<a href="https://www.reichelt.de/de/de/shop/produkt/federkraftklemme_6-pol_0_08_-_1_mm_rm_5_0-72191">Spring-loaded terminal (6-pole)|4| |small metal file|
| | | | |vise (recommended)|

- The terminal pins are too large for the PCB holes.
- Carefully file down the edges of the pins until they fit into the holes of the perforated circuit board (80 x 20 mm) (BOM Pos 5).



### 2.2 - Step 2: soldering Spring-loaded terminal (6-pole)

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|5|<a href="https://www.reichelt.de/de/de/shop/produkt/lochrasterplatine_doppelseitig_80_x_20_mm-319114">perforated circuit board (80 x 20 mm)|1|      |soldering iron with solder|
|3|<a href="https://www.reichelt.de/de/de/shop/produkt/federkraftklemme_6-pol_0_08_-_1_mm_rm_5_0-72191">Spring-loaded terminal (6-pole)|4| ||

- Solder the 6-pole spring-loaded terminal (Pos 3) on the perforated circuit board (80 x 20 mm) (BOM Pos 5) as shown in the image below. 
  - Orange circles indicate the terminal pins.
  - The 6-pole spring-loaded terminal (Pos 3) is mounted on the side of the perforated circuit board (80 x 20 mm) (BOM Pos 5) facing towards you.
  - Arrows denote the direction of the spring loaded terminal ports.
      - The spring loaded terminal ports face down.
  - leave a 2 mm gap between the 6-pole spring-loaded terminal (Pos 3) and the perforated circuit board (80 x 20 mm) (BOM Pos 5).
      - place the perforated circuit board (80 x 20 mm) (BOM Pos 5) in the case (0 - 3D-printing) and push the 6-pole spring-loaded terminal (Pos 3) in, until it touches the case.

<img src="../images/I2C_terminal.png" alt="" width="700" />  



### 2.3 - Step 3: soldering Vcc wires

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|N/A|Output Terminal PCB|1|      |soldering iron with solder|
|7.2|<a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">red insulated copper stranded wire (≥ 0,5 mm²; ca. 5 cm each)|5| ||

- Connect all six Vcc pins with five red insulated copper stranded wires (≥ 0,5 mm²; ca. 5 cm each) (BOM Pos 7.2).
- Ensure no connection exists between any Vcc pin and any GND pin.



### 2.4 - Step 4: soldering Vcc wire

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|N/A|Output Terminal PCB|1|      |soldering iron with solder|
|7.5|<a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">red insulated copper stranded wire (≥ 0,5 mm²; ca. 10 cm each)|1| ||

- Connect one Vcc pin to one red insulated copper stranded wire (≥ 0,5 mm²; ca. 10 cm each) (BOM Pos 7.5).
- Ensure no connection exists between any Vcc pin and any GND pin.



### 2.5 - Step 5: soldering GND wires

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|N/A|Output Terminal PCB|1|      |soldering iron with solder|
|7.4|<a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">black insulated copper stranded wire (≥ 0,5 mm²; ca. 5 cm each)|5| ||

- Connect all six GND pins with five black insulated copper stranded wires (≥ 0,5 mm²; ca. 5 cm each) (BOM Pos 7.4).
- Ensure no connection exists between any Vcc pin and any GND pin.



### 2.6 - Step 6: soldering GND wire

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|N/A|Output Terminal PCB|1|      |soldering iron with solder|
|7.6|<a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">black insulated copper stranded wire (≥ 0,5 mm²; ca. 10 cm each)|1| ||

- Connect one GND pin to one black insulated copper stranded wire (≥ 0,5 mm²; ca. 10 cm each) (BOM Pos 7.6).
- Ensure no connection exists between any Vcc pin and any GND pin.



### 2.7 - Step 7: soldering SCx wires

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|N/A|Output Terminal PCB|1|      |soldering iron with solder|
|7.7|<a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">green insulated copper stranded wire (≥ 0,5 mm²; ca. 20 cm each)|6| ||

- Connect all six SCx pins with six green insulated copper stranded wires (≥ 0,5 mm²; ca. 20 cm each) (BOM Pos 7.7).



### 2.8 - Step 8: soldering SDx wires

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|N/A|Output Terminal PCB|1|      |soldering iron with solder|
|7.8|<a href="https://www.reichelt.de/de/de/shop/produkt/kupferlitze_isoliert_10_m_4_x_0_50_mm_sw_gn_rt_bl-280308">blue insulated copper stranded wire (≥ 0,5 mm²; ca. 20 cm each)|6| ||

- Connect all six SDx pins with six blue insulated copper stranded wires (≥ 0,5 mm²; ca. 20 cm each) (BOM Pos 7.8).



### 2.9 - Step 9: twisting SCx and SDx pairs

|Pos in BOM|Part|Quantity||Tools|
|---|---|---|---|---|
|N/A|Output Terminal PCB|1|      ||


- Twist the wire pairs (e.g. SD0 and SC0).

## 3 setting DCDC converter voltage

### Materials 

<table>
  <tr>
    <td rowspan="1">Pos</td>
    <td rowspan="1">Part</td>
    <td colspan="6">number of parts</td>
  </tr>
  <tr>
    <td rowspan="1">2</td>
    <td rowspan="1"><a href="https://www.reichelt.com/de/en/shop/product/developer_boards_-_voltage_regulators_dc_dc_converters-333853#closemodal">DCDC converter (SBC-BUCK01)</td>
    <td colspan="6">1</td>
  </tr>
  </tr>
</table>

### Tools

- small flathead screwdriver.

  
### Steps

- Plug the DCDC converter (SBC-BUCK01) (BOM Pos 2) into the 24V power supply.
- Verify the Display shows 24 V.
- Press the button (S1) in the lower right corner.
- Use a small flathead screwdriver to turn the brass screw on top of the blue Voltage Adjustment box.
- Adjust until the display shows 5 V.
 
<img src="../images/DCDC.png" alt="" width="300" />  



## 4 connecting all components

![kiCAD](../images/kiCAD_I2C.png)

- Connect all assembled components as shown in the drawing above.
- Keep wires as short as possible to ensure they fit into the case.
