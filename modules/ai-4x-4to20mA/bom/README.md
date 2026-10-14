# Bill of Materials

This README contains the human-readable Bill of Materials (BOM) for the measurement module.

The table below lists the quantity, component, order code, and description. The component name links to the corresponding product or supplier page where available.

| Qty | Component | Order Code | Description |
|---:|---|---|---|
| 1 | [Arduino Nano R4](https://www.reichelt.de/de/de/shop/produkt/arduino_nano_r4_ra4m1_ohne_header-406592) | ARD NANO R4 | Microcontroller board |
| 2 | [Breadboard (perfboard), double-sided, 80 × 20 mm](https://www.reichelt.de/de/de/shop/produkt/lochrasterplatine_doppelseitig_80_x_20_mm-319114) | LR-DS-28 | One board used as sensor terminal carrier and one strip for the 24 V bus terminal |
| 1 | [DC/DC step-down converter LM2596S with display (JOY-IT)](https://www.reichelt.com/de/en/shop/product/developer_boards_-_voltage_regulators_dc_dc_converters-333853#closemodal) | DEBO DCDC DOWN 5 | Adjustable DC/DC step-down converter for the module power supply |
| 4 |[Developer boards - current sensor with breakout board, INA219](https://www.reichelt.com/de/en/shop/product/developer_boards_-_current_sensor_with_breakout_board_ina219-266047)| DEBO SENS POWER |INA219 chip can measure both the voltage and the DC power consumption via the I2C interface  |
| 4 | [Spring-loaded terminal, 6-pin, 5 mm pin spacing](https://www.reichelt.de/de/de/shop/produkt/federkraftklemme_6-pol_0_08_-_1_mm_rm_5_0-72191?search=Federkraftklemme%25206&) | AST 025-06 | Sensor terminals |
| 1 | [Spring-loaded terminal, 4-pin, 5 mm pin spacing](https://www.reichelt.de/de/de/shop/produkt/federkraftklemme_4-pol_0_08_-_1_mm_rm_5_0-72189) | AST 025-04 | 24 V bus input and pass-through |
| 1 | [USB-A to USB-C data cable, 2 m](https://www.reichelt.de/de/de/shop/produkt/sync-_ladekabel_usb-c_usb-a_2m-418569#open-modal-image-big-slider) |EAN: 5705730336140  | Data connection and power supply for the Arduino Nano R4 |
| ~0.5 m | [Stranded wire H05V-K 1 × 0.75 mm², red](https://www.conrad.de/de/p/helukabel-29101-einzelader-h05v-k-1-x-0-75-mm-rot-meterware-1524557.html) |  EAN: 2050004723250| +24 V wiring |
| ~1 m | [Stranded wire H05V-K 1 × 0.75 mm², orange](https://www.conrad.de/de/p/helukabel-29110-einzelader-h05v-k-1-x-0-75-mm-orange-meterware-1524556.html) |  EAN: 2050004723243| +5 V wiring |
| ~0.5 m | [Stranded wire H05V-K 1 × 0.75 mm², black](https://www.conrad.de/de/p/helu-29097-einzelader-h05v-k-1-x-0-75-mm-schwarz-meterware-1524992.html) |  EAN: 2050004727609| 0 V wiring |
| ~1 m | [Stranded wire H05V-K 1 × 0.75 mm², blue](https://www.conrad.de/de/p/helukabel-29109-einzelader-h05v-k-1-x-0-75-mm-dunkelblau-meterware-1524553.html) |  EAN: 2050004723212| 0 V wiring |
| ~1 m | [Stranded wire H05V-K 1 × 0.5 mm², brown](https://www.conrad.de/de/p/lapp-4510031-litze-h05v-k-1-x-0-50-mm-braun-100-m-600390.html) |  EAN: 4044773396195| Sensor signal wiring for A4/SDA  |
| ~1 m | [Stranded wire H05V-K 1 × 0.75 mm², green](https://www.conrad.de/de/p/helu-29107-einzelader-h05v-k-1-x-0-75-mm-gruen-meterware-1524554.html) |  EAN: 2050004723229| Sensor signal wiring for A5/SCL  |
| ~1 m | [Stranded wire H05V-K 1 × 0.5 mm², purple](https://www.conrad.de/de/p/lapp-4510071-litze-h05v-k-1-x-0-50-mm-violett-100-m-600497.html) |  EAN: 4044773393446| VCC/5V wiring for INA219  |
| 1| [Self-tapping PA Phillips head screws set](https://www.amazon.de/dp/B0G6SWF81Z?ref=ppx_yo2ov_dt_b_fed_asin_title) | B0G6SWF81Z | 4x M1.2 x 6mm; 24x M2.3 x 6 mm ||
| min. 150 g | [PLA/PETG filament ](https://www.google.com/search?q=PLA+PETG+Filament&oq=PLA+PETG+Filament&gs_lcrp=EgRlZGdlKgYIABBFGDkyBggAEEUYOTIKCAEQABgTGBYYHjIKCAIQABgTGBYYHjIKCAMQABgTGBYYHjIKCAQQABgTGBYYHjIKCAUQABgTGBYYHjIKCAYQABgTGBYYHjIKCAcQABgTGBYYHjIKCAgQABgTGBYYHtIBCDc0MDdqMGo3qAIAsAIA&sourceid=chrome&source=chrome.ob&ie=UTF-8) | - | Filament for 3D-printed enclosure parts |

A machine-readable version is provided as `BOM.csv`.