# FOSSDAQ
Free and Open Source Data Acquisition 

## Project aim

The system was deliberately not designed as a fully industrialised measurement system, but rather as an easily replicable, open and cost-effective platform for use in teaching and laboratories. The focus is on low material costs, the use of readily available standard components, an easily comprehensible circuit topology, and the ability for students to assemble and adapt modules themselves, and to replace them with minimal effort in the event of a fault. Additional measures to increase robustness, EMC immunity or comprehensive fault protection were therefore only taken into account to the extent that they are necessary for the intended use in supervised laboratory environments. For applications in harsh industrial environments or with increased requirements for reliability and immunity to interference, more extensive protection and interface circuitry is required.

## Repository structure

The FOSSDAQ repository is organised by purpose and module:

- `README.md`  
  Entry point to the project: overview, goals, modules, and links.

- `LICENSE-*`  
  License files for hardware, software, and documentation.

- `docs/`  
  System-level documentation, background information, contribution guidelines, and general design notes that are not tied to a single module.

- `common/`  
  Shared specifications and resources used across multiple modules, e.g. power bus concept, mechanical interface, naming conventions, and templates.

- `modules/`  
  All hardware modules of the FOSSDAQ system.  
  Each subdirectory (e.g. `pi-base/`, `ai-8x-0to3v3/`) contains everything needed for that module:
  - `hardware/` – CAD, KiCad, manufacturing files  
  - `firmware/` – module-specific microcontroller code  
  - `docs/` – build and test notes  
  - `bom/` – parts list  
  - `images/` – photos and renders  

- `software/`  
  System-level software components and tooling.

  - `software/nodered/`  
    Node-RED based control and visualisation:
    - `README.md` – how to install and use the flows with FOSSDAQ  
    - `flows/` – exported Node-RED flows  
    - `nodes/` – custom nodes or subflows (if any)  
    - `examples/` – example setups for specific modules


## Contributors

FOSSDAQ is developed as an open modular measurement system in the context of student projects and teaching.

#### Project lead and supervision
- Prof. Dr. Peter Stein

#### Core contributors
- Jürgen Altemeier (basic concept and first modules - 2026)
- Patrick Uitz (basic concept and first modules - 2026)

#### Further module contributors
- To be added as new modules are published


## License

FOSSDAQ uses different licenses for different parts of the project:

- **Hardware design files** in `hardware/` are licensed under **CERN-OHL-W-2.0**.  
  See `LICENSE-HARDWARE - CERN-OHL-W-2.0`.

- **Firmware and software** in `firmware/` and `software/` are licensed under **GPL-3.0-or-later**.  
  See `LICENSE-SOFTWARE - GPL-3.0`.

- **Documentation** in `docs/` is licensed under **CC-BY-SA-4.0**.  
  See `LICENSE-DOCS - CC-BY-SA-4.0`.

Unless explicitly stated otherwise, new files should follow the license of their parent directory.
