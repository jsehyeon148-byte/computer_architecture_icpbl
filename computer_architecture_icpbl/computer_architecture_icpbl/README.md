# MIPS PWM Motor Controller

A 5-stage pipelined MIPS CPU that reads a target motor speed from switches via Memory-Mapped I/O and drives a PWM controller to track that speed in real time.

**Implemented Motor Profile: Option D (accelerate to switch-set target, then hold)**

---

## System Block Diagram

```
  +----------+     +-----------------------------------------+     +----------------+
  | Switches |---->|           5-Stage Pipelined MIPS CPU     |     | PWM Controller |
  | (0x90)   |     |                                          |     |                |
  +----------+     |  IF --> ID --> EX --> MEM --> WB         |---->| counter[7:0]   |---> pwm_out
                   |                                          |     | comparator     |
  +----------+     |  - Control Unit   - Hazard Unit          |     +----------------+
  |  LEDs    |<----|  - Datapath       - Data Forwarding      |
  | (0x94)   |     |  - Early Branch Resolution               |
  +----------+     +-----------------------------------------+
                                      |
                              data_memory.v
                           (MMIO address decoder)
```

---

## MMIO Address Map

| Address | Device | Direction | Notes |
|---|---|---|---|
| 0x000–0x08F | Internal RAM | Read/Write | 64-word general purpose memory |
| 0x090 | Switches | Read-only | 8-bit external input, target speed |
| 0x094 | LEDs | Write-only | 8-bit status display |
| 0x098 | PWM Duty | Write-only | 8-bit duty cycle (0–255) |
| 0x09C | PWM Enable | Write-only | 1-bit on/off control |

---

## How to Build and Run

**Compile and run simulation:**
```bash
make
```


Or using the Makefile target:
```bash
make wave
```

**Clean generated files:**
```bash
make clean
```

---

## What You'll See

After running the simulation, the testbench drives `switches` through four phases:

1. **Phase 1 (0 – 20 ms)** — `switches = 0x00`: CPU initializes PWM enable and duty to 0. `pwm_out` stays low.
2. **Phase 2 (20 – 100 ms)** — `switches = 0x80 (128)`: `pwm_duty` and `led` ramp up from 0 to 128 one step at a time. `pwm_out` pulse width gradually widens to ~50%.
3. **Phase 3 (100 – 180 ms)** — `switches = 0x20 (32)`: `pwm_duty` ramps down from 128 to 32. `pwm_out` pulse width narrows to ~12%.
4. **Phase 4 (180 – 280 ms)** — `switches = 0xFF (255)`: `pwm_duty` ramps up from 32 to 255. `pwm_out` becomes nearly always high.

In GTKWave, add these signals to observe the behavior:
- `switches[7:0]` — target speed input
- `pwm_duty[7:0]` — current duty cycle
- `led[7:0]` — mirrors duty cycle
- `pwm_out` — PWM square wave output

---

## File Layout

```
computer_architecture_icpbl/
├── README.md               # This file
├── Makefile                # make = compile + run, make wave = open GTKWave
├── memfile.dat             # Motor control program (hex)
├── mips.v                  # Top-level CPU (switches input, pwm_out output)
├── mips_tb.v               # Testbench (drives switches, monitors pwm_out)
├── datapath.v              # 5-stage pipelined datapath
├── data_memory.v           # RAM + MMIO address decoder
├── pwm_controller.v        # PWM peripheral (8-bit counter + comparator)
├── control_unit.v          # Opcode decoder → control signals
├── main_decoder.v          # Main control decoder
├── alu_decoder.v           # ALU operation decoder
├── hazard_unit.v           # Load-use stall, forwarding, branch flush
├── instruction_memory.v    # ROM loaded from memfile.dat
├── pc.v                    # Program counter with stall enable
├── reg_file.v              # 32-entry register file
├── alu.v                   # ALU (add, sub, and, or, slt)
└── docs/
    ├── design_report.md    # Design decisions and architecture
    ├── test_report.md      # Simulation verification and edge cases
    ├── waveform_profile.png    # GTKWave screenshot: acceleration phase
    └── waveform_profile1.png   # GTKWave screenshot: hold phase
```
