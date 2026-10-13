# VGA Display Controller

A fully synthesizable VGA display controller implemented in Verilog, targeting the **Numato Mimas A7 (Xilinx Artix-7 50T)** FPGA. Generates standard **640×480 @ 60Hz** timing with color bar pattern output. Verified through functional simulation using Icarus Verilog and GTKWave, and synthesized clean with Yosys (0 errors, 0 warnings).

---

## Table of Contents

- [Overview](#overview)
- [VGA Protocol Background](#vga-protocol-background)
- [Timing Specification](#timing-specification)
- [Architecture](#architecture)
- [Module Descriptions](#module-descriptions)
- [Simulation Results](#simulation-results)
- [Synthesis Results](#synthesis-results)
- [File Structure](#file-structure)
- [How to Run](#how-to-run)
- [Pattern Progression](#pattern-progression)
- [Key Design Decisions](#key-design-decisions)

---

## Overview

VGA (Video Graphics Array) is an analog display standard originally introduced by IBM in 1987. The FPGA generates five key signals:

| Signal | Description |
|--------|-------------|
| Red [3:0] | 4-bit analog red channel (via resistor DAC) |
| Green [3:0] | 4-bit analog green channel |
| Blue [3:0] | 4-bit analog blue channel |
| HSYNC | Horizontal sync — triggers start of new line |
| VSYNC | Vertical sync — triggers start of new frame |

The controller drives these signals in strict accordance with VESA 640×480 @ 60Hz timing. The monitor locks onto the sync pulses and reconstructs the raster image.

---

## VGA Protocol Background

### How a CRT Monitor Works

A CRT monitor contains three electron guns (R, G, B). Each gun fires a beam at a phosphor-coated screen. The beam sweeps left-to-right, top-to-bottom in a **raster pattern**. Electromagnetic deflection coils physically steer the beam. Where the beam hits, the screen glows — that glowing dot is one pixel.

```
→ → → → → → → → → → [HSYNC: beam resets to left]
→ → → → → → → → → → [HSYNC]
→ → → → → → → → → → [HSYNC]
... 480 visible lines ...
[VSYNC: beam resets to top-left, new frame begins]
```

The beam only draws while moving **forward** (left→right, top→bottom). When it resets, it must be switched off — otherwise a diagonal scratch line appears across the screen. This switched-off period is called **blanking**, which consists of the front porch, sync pulse, and back porch.

> **LCD monitors follow the exact same VGA timing** for backwards compatibility, even though they have no physical beam. The blanking periods are dead time for the LCD controller's internal state machine.

### The Five Key Signals

Your FPGA drives only 5 signals to produce a full color display:

- **Red, Green, Blue** — analog voltages saying *"what color is this pixel"*
- **HSYNC** — says *"start a new horizontal line"*
- **VSYNC** — says *"start a new frame"*

---

## Timing Specification

### 640×480 @ 60Hz — Full Parameter Table

| Parameter | Notation | Pixels / Lines | Time |
|-----------|----------|----------------|------|
| Pixel Clock | tclk | — | 39.7 ns (25.175 MHz) |
| H Active Video | thaddr | 640 pixels | 25.422 µs |
| H Front Porch | thfp | 16 pixels | 0.636 µs |
| H Sync Time | ths | 96 pixels | 3.813 µs |
| H Back Porch | thbp | 48 pixels | 1.907 µs |
| **H Total** | | **800 pixels** | **31.778 µs** |
| V Active Video | tvaddr | 480 lines | 15.253 ms |
| V Front Porch | tvfp | 10 lines | 0.318 ms |
| V Sync Time | tvs | 2 lines | 0.064 ms |
| V Back Porch | tvbp | 33 lines | 1.048 ms |
| **V Total** | | **525 lines** | **16.683 ms** |
| **Frame Rate** | | | **≈ 59.94 Hz** |

> **Implementation uses 25 MHz** (±0.5% tolerance) instead of 25.175 MHz. This gives ~59.5 Hz — within monitor sync tolerance.

### Where 800 and 525 Come From

```
Horizontal:  640 (active) + 16 (FP) + 96 (SYNC) + 48 (BP) = 800 total
Vertical:    480 (active) + 10 (FP) +  2 (SYNC) + 33 (BP) = 525 total
```

These are not arbitrary — they are visible pixels plus mandatory blanking overhead. The monitor needs dead time between lines and frames to reset internal circuits.

### Refresh Rate Derivation

```
Pixel clock  = 25,000,000 pixels/sec
Pixels/frame = 800 × 525 = 420,000
Frames/sec   = 25,000,000 ÷ 420,000 ≈ 59.5 Hz
```

60 Hz is not a separate rule — it falls naturally from pixel clock and total pixel count.

### Horizontal Timing Diagram

```
hcount:
  0                639 | 640    655 | 656         751 | 752       799
  |─── Active Video ───|── FP ──|─── HSYNC ───|──── BP ────|
        show color        black      black           black
                                  ↑         ↑
                              HS=0       HS=1
```

### Vertical Timing Diagram

```
vcount:
  0                479 | 480   489 | 490  491 | 492         524
  |─── Active Lines ───|── FP ──|─VSYNC─|──── BP ────|
                                  ↑     ↑
                              VS=0   VS=1
```

### Why Front Porch Is In the Formula But Back Porch Is Not

```verilog
assign h_sync = ~(h_cnt >= H_P + H_FP && h_cnt < H_P + H_FP + H_SYNC);
```

- **Front porch** sits between active video and sync — you must *cross it* to find where sync starts. Hence `H_P + H_FP` gives the sync start address.
- **Back porch** sits after sync. No signal changes during it. HSYNC is already back to 1. The counter simply runs out to 799 and resets automatically. Nothing needs to reference it.

---

## Architecture

### Block Diagram
![Block Diagram](Block%20Diagram.png)
```
        ┌─────────────────────────────────────────┐
        │              vga_top                     │
        │                                          │
clk (100MHz) ──────►│  ┌──────────────┐                       │
        │  │ clk_divider  │                        │
rst ────────────────►│  │ 100→25 MHz  │                        │
      │       │  └──────┬───────┘                        │
      │       │         │ clk_d (25MHz)                  │
      │       │  ┌──────▼───────┐    h_cnt, v_cnt        │
      └───────►│  │    vga       ├──────────────────────► │──► h_sync
        │  │   sync gen   │                        │──► v_sync
        │  └──────┬───────┘                        │
        │         │ h_cnt, v_cnt, video            │
        │  ┌──────▼───────┐                        │
        │  │   pattern    │                        │
        │  │  generator   ├───────────────────────►│──► rgb[11:0]
        │  └──────────────┘                        │
        └─────────────────────────────────────────┘
```

### Signal Flow

```
clk (100MHz) → clk_divider → clk_d (25MHz)
                                   │
                             ┌─────▼──────┐
                             │    vga     │
                             │  h_cnt++  │ (0 to 799)
                             │  v_cnt++  │ (0 to 524, on h_cnt reset)
                             └──┬──┬──┬──┘
                                │  │  │
                    ┌───────────┘  │  └──────────┐
                    ▼              ▼              ▼
              H Sync time?   Visible area?   V Sync time?
              h_sync = 0     video = 1       v_sync = 0
                             RGB output
```

---

## Module Descriptions

### 1. `clk_divider`

Divides the 100MHz board clock down to 25MHz for the pixel clock.

**Interface:**
```verilog
module clk_divider (clk, rst, clk_d);
  input  wire clk;      // 100MHz board clock
  input  wire rst;      // async reset
  output wire clk_d;    // 25MHz pixel clock
```

**Implementation:** Uses a 2-bit counter. `cnt[1]` naturally toggles every 4 input clock cycles, giving 100MHz ÷ 4 = 25MHz. Using `assign clk_d = cnt[1]` avoids the non-synthesizable clock toggle register pattern.

```
cnt: 00 → 01 → 10 → 11 → 00 → ...
cnt[1]:  0    0    1    1    0  ...  ← 25MHz
```

**Why not `clk_d <= ~clk_d`?** That pattern creates multiple edge-sensitive events on one signal — Yosys cannot map it to a single flip-flop and throws a synthesis error.

---

### 2. `vga` (sync generator)

Generates horizontal/vertical counters and all sync signals.

**Counter logic:** `h_cnt` increments every pixel clock. `v_cnt` only increments when `h_cnt` reaches 799 — ensuring it counts lines, not pixels.

**Sync generation:** Both HSYNC and VSYNC are active low. The `~` inversion in the assign statement handles polarity.

---

### 3. `pattern_generator`

Takes pixel coordinates and outputs 12-bit RGB color.

**Critical rule:** RGB is forced to `12'h000` whenever `video` is low — this covers front porch, sync, and back porch. Failing to blank RGB during non-active periods is a common bug that prevents monitor sync.

**Current pattern:** Solid red (`12'hF00`) — sanity check pattern. Color bars next.

---

### 4. `vga_top`

Top-level wrapper. Pure wiring — no logic.

Instantiates all three submodules and connects them. The netlist diagram confirms correct signal routing: `rst` fans out to both `clk_divider` and `vga`, `clk_d` feeds only the `vga` module, and `h_cnt/v_cnt/video` flow from `vga` to `pattern_generator`.

---

## Simulation Results

**Tools:** Icarus Verilog (iverilog), GTKWave

**Testbench:** `tb_vga_top.v` — drives 100MHz clock, applies reset for 20ns, runs for 17ms (one full frame).

### Verified Signals

| Signal | Expected | Verified |
|--------|----------|----------|
| clk_d period | 40ns (25MHz) | ✅ |
| h_cnt range | 0 to 799 | ✅ |
| v_cnt range | 0 to 524 | ✅ |
| h_sync low width | 96 cycles = 3.84µs | ✅ |
| v_sync low width | 2 lines = 64µs | ✅ |
| rgb during blanking | 12'h000 | ✅ |
| rgb during active | 12'hF00 (solid red) | ✅ |
| v_sync period | ~16.8ms | ✅ |

### Waveform Observations

- **h_sync** pulses regularly every 32µs (one full horizontal line)
- **rgb** shows correct color bar values (F00, 0F0, 00F, FF0, 0FF, FFF, 888) during active video, dropping to 000 during blanking
- **v_sync** dips exactly once per frame at the ~15.8ms mark
- **video** goes high only when `h_cnt < 640` AND `v_cnt < 480`

---

## Synthesis Results

**Tool:** Yosys 0.33

```
=== design hierarchy ===

   vga_top                           1
     clk_divider                     1
     pattern_generator               1
     vga                             1

   Number of cells:                160
     $_ANDNOT_                      48
     $_AND_                          4
     $_DFFE_PP0N_                   10
     $_DFF_PP0_                     12
     $_NAND_                        10
     $_NOR_                          6
     $_NOT_                          4
     $_ORNOT_                       13
     $_OR_                          34
     $_XNOR_                         4
     $_XOR_                         15

Found and reported 0 problems.
```

160 cells total. Clean hierarchy. No latches inferred. No multiple-driver errors.

---

## File Structure

```
VGA Display Controller/
├── clk_divider.v        # 100MHz → 25MHz clock divider
├── vga.v                # Sync generator (h_cnt, v_cnt, hsync, vsync, video)
├── pattern_generator.v  # RGB pattern output
├── vga_top.v            # Top-level instantiation
├── tb_vga_top.v         # Testbench
├── vga.json             # Yosys netlist (for netlistsvg)
├── vga.svg              # Netlist schematic
└── README.md
```

---

## How to Run

### Simulate

```bash
iverilog -o sim.out tb_vga_top.v vga_top.v vga.v clk_divider.v pattern_generator.v
vvp sim.out
gtkwave tb_vga_top.vcd
```

### Synthesize with Yosys

```bash
yosys -p "read_verilog *.v; synth -top vga_top; write_json vga.json"
```

### View Netlist

```bash
netlistsvg vga.json -o vga.svg
xdg-open vga.svg
```

---

## Pattern Progression

The `pattern_generator` module is designed to be swapped out independently — the sync timing never changes.

| Step | Pattern | Status |
|------|---------|--------|
| 1 | Solid red — sync sanity check | ✅ Done |
| 2 | Color bars — 8 vertical zones | 🔲 Next |
| 3 | Checkerboard — `hcount[5] ^ vcount[5]` | 🔲 Planned |
| 4 | Gradient — `r = hcount[7:5]`, `g = vcount[7:5]` | 🔲 Planned |
| 5 | Moving box — frame counter shifts position | 🔲 Planned |
| 6 | Text overlay — font ROM in BRAM | 🔲 Planned |

---

## Key Design Decisions

**1. Clock divider uses `cnt[1]` not `clk_d <= ~clk_d`**

The toggle register approach causes a Yosys synthesis error: *"Multiple edge sensitive events found for this signal."* Using the counter bit directly is synthesizable and maps cleanly to standard flip-flops.

**2. Separate modules for sync and pattern**

`vga.v` has zero color logic. `pattern_generator.v` has zero timing logic. Clean separation means patterns can be swapped without touching timing — important as the project grows.

**3. `video_active` gates all RGB output**

```verilog
if (!video) rgb <= 12'h000;
```

This single line prevents color from leaking into blanking regions, which would prevent the monitor from syncing. It covers front porch, sync pulse, and back porch simultaneously.

**4. Back porch requires no localparam in sync logic**

Front porch must be in the formula to locate where sync starts (`H_P + H_FP = 656`). Back porch sits after sync — no signal changes during it, so the counter simply runs to `H_Total - 1` and resets. The 48 BP cycles are mandatory time but need no explicit comparison.

---

## Tools Used

| Tool | Version | Purpose |
|------|---------|---------|
| Icarus Verilog | — | Simulation |
| GTKWave | — | Waveform viewing |
| Yosys | 0.33 | Synthesis / netlist |
| netlistsvg | — | Schematic from netlist |

---

## Board

**Numato Mimas A7** — Xilinx Artix-7 50T  
Requires external Pmod VGA module for hardware testing (resistor DAC for analog RGB output).
