# UART_FPGA

A **UART (Universal Asynchronous Receiver/Transmitter) echo** implementation written in Verilog and built in Vivado, targeting the **Digilent Arty A7‑35T** board (Xilinx **Artix‑7 XC7A35T**).

The design receives a byte over the serial line, **echoes the exact same byte back** to the host, and displays the **lower 4 bits** of the received byte on the four on‑board RGB LEDs (blue channel).

![image](https://user-images.githubusercontent.com/96307958/233260290-48cb8957-e2e9-4c5b-b283-705041b81a43.png)

---

## Table of Contents
- [What is UART?](#what-is-uart)
- [Frame Format (8N1)](#frame-format-8n1)
- [Project Structure](#project-structure)
- [Top‑Level Design](#top-level-design-uart_topv)
- [Key Parameters (the important knobs)](#key-parameters-the-important-knobs)
- [Baud‑Rate Generation Explained](#baud-rate-generation-explained)
- [Receiver — `uart_rx.v`](#receiver--uart_rxv)
- [Transmitter — `uart_tx.v`](#transmitter--uart_txv)
- [Stand‑alone `baudrate_gen.v`](#stand-alone-baudrate_genv)
- [Testbench — `test_tb.v`](#testbench--test_tbv)
- [Pin Constraints (.xdc)](#pin-constraints-xdc)
- [How to Build & Run](#how-to-build--run)
- [Known Issues / Notes](#known-issues--notes)

---

## What is UART?

UART is an **asynchronous** serial protocol — there is **no shared clock** between the two endpoints. Both sides must agree in advance on a **baud rate** (bits per second). Each side samples the line using its *own* local clock, timed from that agreed baud rate.

When the line is idle it sits **high (`1`)**. A transmission begins with a **start bit (`0`)**, followed by the data bits (here **8**, sent **LSB first**), and ends with one or more **stop bits (`1`)**. The receiver detects the falling edge of the start bit, then samples each subsequent bit in the **middle of its bit period** to be maximally tolerant of clock drift.

This project uses the most common configuration, **8N1**: 8 data bits, No parity, 1 stop bit.

## Frame Format (8N1)

```
        start      8 data bits (LSB first)        stop
 idle    bit    D0 D1 D2 D3 D4 D5 D6 D7            bit    idle
 ─────┐      ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬─────────────────────
   1  └──0───┘  …  data  …                    1 (stop)   1
```

- **Idle line:** logic `1`
- **Start bit:** logic `0` (one bit period) — marks the beginning of a frame
- **Data:** 8 bits, **least‑significant bit first**
- **Stop bit:** logic `1` (one bit period)
- **No parity bit**

---

## Project Structure

```
UART_FPGA/
└── UART_echo/                                  ← Vivado project
    └── UART_echo.srcs/
        ├── sources_1/new/
        │   ├── uart_top.v        ← top module (wires RX → TX echo + LEDs)
        │   ├── uart_rx.v         ← UART receiver (FSM + mid‑bit sampling)
        │   ├── uart_tx.v         ← UART transmitter (FSM + shift‑out)
        │   └── baudrate_gen.v    ← stand‑alone baud generator (NOT used by uart_top)
        ├── sim_1/new/
        │   └── test_tb.v         ← simulation testbench (drives 0xAA into the design)
        └── constrs_1/imports/digilent-xdc-master/
            └── Arty-A7-35-Master.xdc  ← pin / clock constraints
```

| File | Role |
|------|------|
| `uart_top.v` | Top level. Instantiates `uart_rx` + `uart_tx`, connects the receiver's `done`/`data` to the transmitter to create the echo loop, and drives the LEDs. |
| `uart_rx.v` | Receives one byte, asserts `done` for one cycle when complete. |
| `uart_tx.v` | Transmits one byte when `enable` is asserted. |
| `baudrate_gen.v` | A self‑contained baud tick generator. **Note:** it is *not* instantiated by the current top module — RX and TX each carry their own internal baud counter. |
| `test_tb.v` | Testbench that streams the pattern `0xAA` into the design for simulation. |

---

## Top‑Level Design (`uart_top.v`)

```verilog
module uart_top(
    input  uart_txd_in,   // serial line INTO the FPGA  (host TX → FPGA RX)
    input  CLK100MHZ,     // 100 MHz system clock
    input  btn,           // active‑high reset (board push‑button)
    output uart_rxd_out,  // serial line OUT of the FPGA (FPGA TX → host RX)
    output led0_b,        // blue channel of RGB LED0  ← data[0]
    output led1_b,        // blue channel of RGB LED1  ← data[1]
    output led2_b,        // blue channel of RGB LED2  ← data[2]
    output led3_b         // blue channel of RGB LED3  ← data[3]
);
```

> **Naming convention (important!):** On the Arty board the signals are named from the **host/cable** point of view.
> - `uart_txd_in` = the USB‑UART bridge's **TX** → it is an **input** to the FPGA (this is the FPGA's *receive* line).
> - `uart_rxd_out` = the USB‑UART bridge's **RX** → it is an **output** of the FPGA (this is the FPGA's *transmit* line).

### Internal wiring / echo loop
```verilog
wire done;             // 1‑cycle pulse from RX: "a byte is ready"
wire [7:0] data;       // the received byte

assign {led3_b, led2_b, led1_b, led0_b} = data[3:0];   // show low nibble on LEDs

uart_rx #(.baudrate(baudrate), .clk_frequence(clk_frequence))
  uart_rx ( .uart_txd_in(uart_txd_in), .CLK100MHZ(CLK100MHZ),
            .reset(btn), .done(done), .data(data) );

uart_tx #(.baudrate(baudrate), .clk_frequence(clk_frequence))
  uart_tx ( .data(data), .CLK100MHZ(CLK100MHZ),
            .enable(done), .reset(btn), .uart_rxd_out(uart_rxd_out) );
```

The receiver's **`done`** pulse is fed directly into the transmitter's **`enable`** input. So the instant a byte finishes arriving, the transmitter latches that same `data` byte and sends it straight back out — that is the "echo".

---

## Key Parameters (the important knobs)

These two parameters appear in `uart_top`, `uart_rx`, `uart_tx`, and the testbench. **Change the baud rate here:**

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `baudrate` | `115200` | **Baud rate in bits/second.** This is the single most important UART setting — the host serial terminal **must** be set to the same value. |
| `clk_frequence` | `100000000` | The system clock frequency in Hz (**100 MHz**). Must match the actual board clock fed into `CLK100MHZ`. |
| `clk_per_bit` | `clk_frequence / baudrate` = 100000000 / 115200 ≈ **868** | **Number of 100 MHz clock cycles in one UART bit period.** This is how the design converts the system clock into UART bit timing. (`1 / 115200 s ≈ 8.68 µs`, and `8.68 µs × 100 MHz ≈ 868 cycles`.) |

> To run at a different baud rate, change `baudrate` in `uart_top.v` (it is passed down to RX/TX). The internal `clk_per_bit` recalculates automatically. Remember to also update `baudrate` in `test_tb.v` if you re‑simulate.

State encoding used by both RX and TX FSMs:

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `idle` | `2'b01` | Waiting for a frame. |
| `transmit` | `2'b10` | Actively shifting bits in (RX) / out (TX). The MSB (`state[1]`) doubles as an "active" flag. |

---

## Baud‑Rate Generation Explained

Because UART is asynchronous, the core timing trick is: **count system‑clock cycles to recreate the bit period**, then generate a one‑cycle "baud pulse" once per bit.

```verilog
parameter clk_per_bit = clk_frequence/baudrate;   // ≈ 868 cycles per bit
reg [31:0] counter_bps = 0;                        // counts clock cycles within a bit
```

- A 32‑bit `counter_bps` counts `CLK100MHZ` cycles, but **only while `state == transmit`** (it is held at 0 while idle and on reset).
- When the count reaches a target value, a **`baudrate_pulse`** is produced — this pulse is the heartbeat that advances the bit counter and shifts the data register.

The receiver and transmitter use **different target counts on purpose:**

| Module | Pulse condition | Why |
|--------|-----------------|-----|
| `uart_rx` | `counter_bps == clk_per_bit/2` (≈ 434) | Samples in the **middle of each bit**, the most reliable sampling point — gives maximum margin against clock mismatch and edge jitter. |
| `uart_tx` | `counter_bps == clk_per_bit` (≈ 868) | Advances to the **next full bit** before outputting it. |

---

## Receiver — `uart_rx.v`

### Important signals

| Signal | Width | Purpose |
|--------|-------|---------|
| `uart_txd_in` | 1 | Raw serial input line. |
| `reset` | 1 | Async, active‑high reset (`btn`). |
| `data` | 8 | The decoded received byte (output). |
| `done` | 1 | Pulses high for the cycle the stop condition is reached — "byte ready". |
| `state` / `next` | 2 | FSM current/next state (`idle` / `transmit`). |
| `counter` | 4 | **Bit counter** — counts the 8 data bits (0 → 8). |
| `rx_data` | 9 | Shift register that collects incoming bits. |
| `counter_bps` | 32 | Baud cycle counter (see above). |
| `baudrate_pulse` | 1 | High at the mid‑bit sample point (`counter_bps == clk_per_bit/2`). |
| `uart_rx_reg` | 4 | **Input synchronizer / metastability filter & start‑bit edge detector.** |

### How it works

**1. Metastability / edge detection.** The asynchronous input is fed through a 4‑stage shift register:
```verilog
uart_rx_reg <= {uart_rx_reg[2:0], uart_txd_in};
```
This both **synchronizes** the external signal into the clock domain and lets the design detect the **start‑bit falling edge**:
```verilog
idle: next = (uart_rx_reg[3:2]==2'b10) ? transmit : idle;  // 1→0 transition = start bit
```

**2. Sampling.** Once in `transmit`, on every `baudrate_pulse` (mid‑bit) the new bit is shifted into `rx_data`, **LSB first**:
```verilog
transmit: rx_data = baudrate_pulse ? {uart_txd_in, rx_data[8:1]} : rx_data;
```

**3. Bit counting & completion.** `counter` increments on each sampled bit; when it reaches 8 the receiver asserts `stop`, returns to `idle`, and exposes the byte:
```verilog
assign data = rx_data[8:1];   // the 8 captured data bits
assign done = stop;           // signals the byte is complete
```

---

## Transmitter — `uart_tx.v`

### Important signals

| Signal | Width | Purpose |
|--------|-------|---------|
| `data` | 8 | Byte to transmit (input — comes from the receiver). |
| `enable` | 1 | Start a transmission (driven by RX `done`). |
| `reset` | 1 | Async, active‑high reset. |
| `uart_rxd_out` | 1 | Serial output line. |
| `done` | 1 | Pulses high when the frame finishes sending. |
| `tx_data` | 10 | **Full UART frame** held in a shift register. |
| `counter` | 4 | Bit counter (0 → 8). |
| `baudrate_pulse` | 1 | Registered; high once per full bit period (`counter_bps == clk_per_bit`). |

### The 10‑bit frame

The transmitter packs a complete 8N1 frame into one 10‑bit register:
```verilog
tx_data <= {1'b1, data, 1'b0};   // { stop=1 , 8 data bits , start=0 }
```
- Bit `[0]` (sent first) = **start bit `0`**
- Bits `[8:1]` = the 8 data bits
- Bit `[9]` (sent last) = **stop bit `1`**

### How it works

On each `baudrate_pulse` the frame is shifted right, so the current output bit is always `tx_data[0]`:
```verilog
else if (state==transmit & baudrate_pulse) tx_data <= tx_data >> 1;
...
assign uart_rxd_out = state[1] ? tx_data[0] : 1'b1;   // drive idle '1' when not transmitting
```
After 8 counted bits the transmitter asserts `done` and returns to `idle`, leaving the line high.

---

## Stand‑alone `baudrate_gen.v`

This is a **separate, reusable baud‑tick generator** with both TX and RX clock enables. ⚠️ **It is not instantiated by `uart_top`** in the current design — `uart_rx` and `uart_tx` each implement their own inline baud counter instead. It is kept as an alternative/reference module.

| Port | Direction | Purpose |
|------|-----------|---------|
| `I_clk` | in | System clock (its comments assume **50 MHz**, not 100 MHz). |
| `I_rst_n` | in | **Active‑low** reset (note: opposite polarity to the rest of the design). |
| `I_bps_tx_clk_en` | in | Enable the TX baud counter. |
| `I_bps_rx_clk_en` | in | Enable the RX baud counter. |
| `O_bps_tx_clk` | out | TX baud pulse (fires at count `1`). |
| `O_bps_rx_clk` | out | RX baud pulse (fires at `C_BPS_SELECT >> 1`, i.e. mid‑bit). |

Pre‑computed divider constants (for a **50 MHz** clock):

| Parameter | Value | Baud rate |
|-----------|-------|-----------|
| `C_BPS9600` | 5207 | 9600 |
| `C_BPS19200` | 2603 | 19200 |
| `C_BPS38400` | 1301 | 38400 |
| `C_BPS57600` | 867 | 57600 |
| `C_BPS115200` | 867 | 115200 |
| `C_BPS_SELECT` | `C_BPS115200` | the selected rate |

> ⚠️ The table has an inherited bug: `C_BPS115200` is set to `867`, the **same** value as `C_BPS57600`. For a true 115200 baud at 50 MHz the divider should be ≈ 434. Because this module is unused, it does not affect the working design — but fix it before reusing the module.

---

## Testbench — `test_tb.v`

The testbench instantiates `uart_top` and continuously drives a serial pattern into `uart_txd_in` so you can watch the echo and LED behaviour in simulation.

- Generates the `CLK100MHZ` clock with `always #1 CLK100MHZ = ~CLK100MHZ;` (note `timescale 1us/1ns`).
- Uses the same `baudrate` / `clk_frequence` / `clk_per_bit` parameters to time the stimulus.
- The driven byte is **`0xAA`**, wrapped with framing bits in `uart_in_reg = {8'haa, 2'b01}` and shifted out one bit at a time, LSB first.
- After a full frame it pauses (`#10000`) and re‑loads the pattern to send it again.

Run it as the simulation top in Vivado's simulator and observe `uart_rxd_out` reproduce the input byte and `led*_b` reflect the low nibble of `0xAA` (`0b1010`).

---

## Pin Constraints (.xdc)

From `Arty-A7-35-Master.xdc`, the **active** constraints used by this design (all `LVCMOS33`):

| Signal | FPGA Pin | Board net | Notes |
|--------|----------|-----------|-------|
| `CLK100MHZ` | `E3` | 100 MHz oscillator | `create_clock -period 10.000` (10 ns → 100 MHz) |
| `btn` | `D9` | BTN0 | Active‑high reset push‑button |
| `uart_txd_in` | `A9` | USB‑UART bridge TX | FPGA receive line |
| `uart_rxd_out` | `D10` | USB‑UART bridge RX | FPGA transmit line |
| `led0_b` | `E1` | RGB LED0 (blue) | ← `data[0]` |
| `led1_b` | `G4` | RGB LED1 (blue) | ← `data[1]` |
| `led2_b` | `H4` | RGB LED2 (blue) | ← `data[2]` |
| `led3_b` | `K2` | RGB LED3 (blue) | ← `data[3]` |

---

## How to Build & Run

1. Open `UART_echo/UART_echo.xpr` in **Vivado 2021.2** (or compatible).
2. Make sure `uart_top` is the synthesis top and `test_tb` is the simulation top.
3. (Optional) Run **Behavioral Simulation** to verify the echo with `test_tb.v`.
4. Run **Synthesis → Implementation → Generate Bitstream**.
5. Program the **Arty A7‑35T** over USB.
6. On the host, open a serial terminal (e.g. PuTTY, Tera Term) on the board's COM port with:
   - **Baud rate: 115200**
   - **8 data bits, No parity, 1 stop bit (8N1)**
   - No flow control
7. Type/send any byte. The board sends the **same byte back**, and the **four blue LEDs** display the **lower 4 bits** of that byte.
8. Press **BTN0** to reset.

---

## Known Issues / Notes

- **Clock assumption mismatch in `baudrate_gen.v`:** its divider constants assume a 50 MHz clock and the `C_BPS115200` value duplicates `C_BPS57600` (see above). The active RX/TX modules avoid this by computing `clk_per_bit` directly from `clk_frequence`/`baudrate`, so the working design is correct at 100 MHz / 115200 baud.
- **Reset polarity differs between modules:** the main design uses **active‑high** reset (`btn`), while `baudrate_gen.v` uses **active‑low** (`I_rst_n`). Reconcile these if you ever wire `baudrate_gen` in.
- **`uart_rx` has extra `test`/`test1` debug outputs** in its module declaration that are left unconnected at the top level — they are leftover probe signals and can be removed.
- **No parity / no error checking:** this is a minimal 8N1 implementation; framing errors, overruns, and parity are not detected.
