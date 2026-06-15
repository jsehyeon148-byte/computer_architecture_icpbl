# Design Report — MIPS PWM Motor Controller

## 1. Introduction

This project implements a complete embedded motor control system built on a 5-stage pipelined MIPS CPU. The CPU reads a target motor speed from physical switches via Memory-Mapped I/O, compares it against the current duty cycle, and incrementally adjusts the PWM output to track the target. The system demonstrates the full software-hardware integration path: from assembly instructions executing in a pipeline, through MMIO address decoding, to a PWM peripheral driving a motor output.

---

## 2. System Architecture

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

| Module | Description |
|---|---|
| `mips.v` | Top-level module; connects control unit, hazard unit, and datapath |
| `datapath.v` | 5-stage pipeline with IF/ID/EX/MEM/WB registers |
| `control_unit.v` | Decodes opcode/funct and generates control signals |
| `hazard_unit.v` | Handles load-use stalls, data forwarding, and branch flush |
| `data_memory.v` | RAM + MMIO address decoder for switches, LEDs, and PWM |
| `pwm_controller.v` | 8-bit free-running counter + comparator, outputs square wave |
| `instruction_memory.v` | ROM loaded from `memfile.dat` |
| `reg_file.v` | 32-entry register file with write-on-falling-edge |
| `alu.v` / `alu_decoder.v` | ALU with add, sub, and, or, slt operations |
| `pc.v` | Program counter with stall enable |

---

## 3. MMIO Design

### Address Map

| Address | Device | Direction | Notes |
|---|---|---|---|
| 0x000–0x08F | Internal RAM | Read/Write | 64-word general purpose memory |
| 0x090 | Switches | Read-only | 8-bit external input, target speed |
| 0x094 | LEDs | Write-only | 8-bit status display |
| 0x098 | PWM Duty | Write-only | 8-bit duty cycle (0–255) |
| 0x09C | PWM Enable | Write-only | 1-bit on/off control |

### Address Decoding

Inside `data_memory.v`, a `case` statement on the 32-bit address routes reads and writes:

```verilog
// Synchronous Write
always @(posedge clk) begin
    if (mem_write_en) begin
        case (addr)
            32'h00000094: led      <= write_data[7:0];
            32'h00000098: pwm_duty <= write_data[7:0];
            32'h0000009c: pwm_en   <= write_data[0];
            default:      ram[addr[7:2]] <= write_data;
        endcase
    end
end

// Combinational Read
always @(*) begin
    case (addr)
        32'h00000090: read_data = {24'b0, switches};
        32'h00000094: read_data = {24'b0, led};
        32'h00000098: read_data = {24'b0, pwm_duty};
        32'h0000009c: read_data = {31'b0, pwm_en};
        default:      read_data = ram[addr[7:2]];
    endcase
end
```

**Writes are synchronous** (clocked) because peripheral registers like `pwm_duty` and `pwm_en` are sequential elements that should only update on a clock edge, preventing glitches.

**Reads are combinational** so that the MEM stage can sample the result in the same cycle without introducing an extra pipeline stage.

---

## 4. PWM Controller Design

### Counter + Comparator Architecture

```
clk ──► [8-bit counter] ──► counter[7:0]
                                  |
                                  v
                           [comparator] ──► pwm_out
                                  ^
                            duty_cycle[7:0]
```

The counter increments by 1 every clock cycle and wraps at 256. The comparator outputs `1` while `counter < duty_cycle`, and `0` otherwise. This produces a square wave with a high-time fraction equal to `duty_cycle / 256`.

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)         counter <= 8'b0;
    else if (enable)    counter <= counter + 1;
    else                counter <= 8'b0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)      pwm_out <= 0;
    else if (enable) pwm_out <= (counter < duty_cycle);
    else             pwm_out <= 0;
end
```

### PWM Frequency

With a 100 MHz clock (10 ns period):

```
PWM period = 256 × 10 ns = 2,560 ns = 2.56 µs
PWM frequency ≈ 390 kHz
```

This is simulation-optimized. In real hardware a prescaler would reduce the frequency to the 20–50 kHz range typical for motor control.

---

## 5. Software Algorithm

### Profile Selected: Option D — Two-stage (Switch-controlled target tracking)

Option D was chosen because it is the most realistic motor control scenario. The CPU continuously reads a target speed from the switches, then ramps the duty cycle up or down one step per loop iteration until it matches the target. This mirrors how a real speed controller behaves.

### Pseudocode

```
pwm_en = 1                       # Enable PWM
current_duty = 0
write(0x98, current_duty)        # Initialize duty to 0

loop:
    target = read(0x90)          # Read switches

    if current_duty < target:
        current_duty++
    elif current_duty > target:
        current_duty--
    # else: equal, hold

    write(0x98, current_duty)    # Update PWM duty
    write(0x94, current_duty)    # Update LED display

    delay(100)                   # Small delay loop

    goto loop
```

### Assembly → Hex Mapping (memfile.dat)

| Word | PC (byte) | Hex | Assembly | Comment |
|---|---|---|---|---|
| 00 | 0x00000000 | `200B0001` | `addi $t3, $zero, 1` | Load enable value 1 |
| 01 | 0x00000004 | `AC0B009C` | `sw $t3, 0x9C($zero)` | Enable PWM |
| 02 | 0x00000008 | `20080000` | `addi $t0, $zero, 0` | current_duty = 0 |
| 03 | 0x0000000C | `AC080098` | `sw $t0, 0x98($zero)` | Init PWM duty |
| 04 | 0x00000010 | `AC080094` | `sw $t0, 0x94($zero)` | Init LED |
| 05 | 0x00000014 | `8C090090` | `lw $t1, 0x90($zero)` | Read switches ← **control_loop** |
| 06 | 0x00000018 | `20000000` | `nop` | Pipeline safety NOP |
| 07 | 0x0000001C | `20000000` | `nop` | Pipeline safety NOP |
| 08 | 0x00000020 | `0109502A` | `slt $t2, $t0, $t1` | t2 = (current < target) |
| 09 | 0x00000024 | `15400003` | `bne $t2, $zero, +3` | Branch to accelerate (→ 0x34) |
| 0A | 0x00000028 | `0128502A` | `slt $t2, $t1, $t0` | t2 = (target < current) |
| 0B | 0x0000002C | `15400005` | `bne $t2, $zero, +5` | Branch to decelerate (→ 0x44) |
| 0C | 0x00000030 | `08000014` | `j 0x14` | Equal → jump to update |
| 0D | 0x00000034 | `21080001` | `addi $t0, $t0, 1` | current_duty++ ← **accelerate** |
| 0E | 0x00000038 | `20000000` | `nop` | Pipeline safety NOP |
| 0F | 0x0000003C | `20000000` | `nop` | Pipeline safety NOP |
| 10 | 0x00000040 | `08000014` | `j 0x14` | Jump to update |
| 11 | 0x00000044 | `2108FFFF` | `addi $t0, $t0, -1` | current_duty-- ← **decelerate** |
| 12 | 0x00000048 | `20000000` | `nop` | Pipeline safety NOP |
| 13 | 0x0000004C | `20000000` | `nop` | Pipeline safety NOP |
| 14 | 0x00000050 | `AC080098` | `sw $t0, 0x98($zero)` | Write PWM duty ← **update** |
| 15 | 0x00000054 | `AC080094` | `sw $t0, 0x94($zero)` | Write LED |
| 16 | 0x00000058 | `200B0064` | `addi $t3, $zero, 100` | delay counter = 100 |
| 17 | 0x0000005C | `216BFFFF` | `addi $t3, $t3, -1` | delay-- ← **delay** |
| 18 | 0x00000060 | `1560FFFE` | `bne $t3, $zero, -2` | Loop until 0 (→ 0x5C) |
| 19 | 0x00000064 | `08000005` | `j 0x05` | Repeat main loop |

### Delay Loop

The delay loop runs 100 iterations. Based on the measured waveform, one duty-step update occurs approximately every 390 µs. This matches the observed ramp behavior in simulation.

---

## 6. Reflection

**One thing that was harder than expected:**
Tracing the full data path of a `sw` instruction through the pipeline to confirm the correct value reaches the MMIO register was more involved than expected. The write data travels through the EX/MEM pipeline register as `write_data_M`, which is sourced from `src_b_E_temp` (before the ALU mux), so forwarding needed to be verified carefully to ensure the correct value is written.

**One thing I would change with more time:**
The delay loop constant (100) is hardcoded in the assembly. With more time, it would be better to adjust the ramp rate based on the difference between the current duty and the target value, allowing faster response to large changes and smoother response to small adjustments.
