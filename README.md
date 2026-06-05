# Cubic Solver — RTL Design & Testbench Documentation

## Overview

The `cubic_solver` module solves cubic equations of the form **ax³ + bx² + cx + d = 0** using a multi-cycle Finite State Machine (FSM) approach. It implements **Cardano's method** (one real root) and the **trigonometric method** (three real roots). All inputs and outputs use IEEE 754 single-precision floating-point (FP32) representation.

### Algorithm

1. **Normalize** by `a`: x³ + (b/a)x² + (c/a)x + (d/a) = 0
2. **Depressed cubic** via substitution: t³ + pt + q = 0
3. **Discriminant**: Δ = -(4p³ + 27q²)
4. **Root computation**:
   - Δ ≥ 0 → trigonometric method using `acos`, `cos`, `sqrt`
   - Δ < 0 → Cardano's formula using `cbrt`, `sqrt`
5. **Shift back**: x_k = t_k − b/(3a)

---

## Module Hierarchy

```
cubic_solver (top-level FSM, ~56 states)
├── fp32_add    — IEEE 754 FP32 adder/subtractor (combinational)
├── fp32_mul    — IEEE 754 FP32 multiplier (combinational)
├── fp32_div    — IEEE 754 FP32 divider, restoring division (combinational)
├── fp32_sqrt   — sqrt(x) = exp2(0.5 × log2(x))
│   ├── fp32_log2  — log₂(x) using Padé LUT
│   │   ├── pade_lut (log2 table)
│   │   └── fp32_add
│   ├── fp32_mul
│   └── fp32_exp2  — 2^x using Padé LUT
│       └── pade_lut (exp2 table)
├── fp32_cbrt   — cbrt(x) = sign(x) × exp2(log2(|x|) / 3)
│   ├── fp32_log2
│   ├── fp32_mul
│   └── fp32_exp2
├── fp32_cos    — cosine via 64-entry LUT (combinational)
└── fp32_acos   — arccosine via 64-entry LUT (combinational)
```

### Module Interfaces

| Module | Inputs | Outputs | Type |
|--------|--------|---------|------|
| `fp32_add` | `a[31:0]`, `b[31:0]`, `sub` | `result[31:0]` | Combinational |
| `fp32_mul` | `a[31:0]`, `b[31:0]` | `result[31:0]` | Combinational |
| `fp32_div` | `a[31:0]`, `b[31:0]` | `result[31:0]` | Combinational |
| `fp32_log2` | `a[31:0]` | `result[31:0]` | Combinational |
| `fp32_exp2` | `a[31:0]` | `result[31:0]` | Combinational |
| `fp32_sqrt` | `a[31:0]` | `result[31:0]` | Combinational |
| `fp32_cbrt` | `a[31:0]` | `result[31:0]` | Combinational |
| `fp32_cos` | `a[31:0]` (radians) | `result[31:0]` | Combinational |
| `fp32_acos` | `a[31:0]` (in [-1,1]) | `result[31:0]` | Combinational |
| `pade_lut` | `addr[4:0]`, `sel` | `data[31:0]` | Combinational ROM |
| `cubic_solver` | `clk`, `rst_n`, `in_valid`, `a-d[31:0]`, `out_ready` | `in_ready`, `out_valid`, `x0-x2[31:0]` | Sequential (FSM) |

### Top-Level Interface

| Port       | Direction | Width | Description                                  |
|------------|-----------|-------|----------------------------------------------|
| `clk`      | Input     | 1     | System clock (25 MHz / 40 ns period)         |
| `rst_n`    | Input     | 1     | Active-low asynchronous reset                |
| `in_valid` | Input     | 1     | Asserted when input coefficients are valid    |
| `in_ready` | Output    | 1     | Asserted when module is ready to accept input |
| `a`–`d`    | Input     | 32    | Coefficients of ax³+bx²+cx+d=0 (FP32)       |
| `out_valid`| Output    | 1     | Asserted when output solutions are valid      |
| `out_ready`| Input     | 1     | Asserted by receiver to acknowledge output    |
| `x0`–`x2` | Output    | 32    | Roots (FP32), NaN if unused                  |

---

## Test Cases

All testbenches are standalone files named `tb_<index>.v`. Each can be compiled with all source files.

### How to Run

```bash
# Run a single testbench
iverilog -g2012 -s tb_1 -o sim.vvp *.v && vvp sim.vvp

# Run all testbenches
chmod +x run_all.sh
./run_all.sh
```

### Verification Strategy

| TB Range | Target | Approach |
|----------|--------|----------|
| tb_1–tb_4 | Individual FP32 ops | **Exact golden reference** (±1 ULP tolerance) |
| tb_5–tb_6 | sqrt/cbrt/cos/acos | **Golden reference** with wider tolerance (±64 ULP for LUT-based) |
| tb_7 | Padé LUT ROM | **Exact match** against precomputed constants |
| tb_8–tb_15 | cubic_solver top | **Approximate root matching** (within factor of 2) |

### Test Case Summary Table

| No. | Target                      | Test Case Name              | Test Case Explanation                                                                                                  |
|-----|-----------------------------|-----------------------------|------------------------------------------------------------------------------------------------------------------------|
| 1   | `fp32_add` (add)            | FP32 Addition               | Direct golden comparison: 1.0+2.0=3.0, 0.5+0.5=1.0, NaN/Inf propagation, cancellation to zero. 8 vectors. ±1 ULP.   |
| 2   | `fp32_add` (sub)            | FP32 Subtraction            | Direct golden comparison: 3.0−1.0=2.0, 1.0−1.0=0.0, sign handling, NaN/Inf edge cases. 7 vectors. ±1 ULP.            |
| 3   | `fp32_mul`                  | FP32 Multiplication         | Direct golden comparison: 2.0×3.0=6.0, −1.0×5.0=−5.0, 0.5×0.5=0.25, Inf×0=NaN. 9 vectors. ±1 ULP.                    |
| 4   | `fp32_div`                  | FP32 Division               | Direct golden comparison: 6.0/3.0=2.0, 1.0/2.0=0.5, x/0=Inf, 0/0=NaN. 8 vectors. ±1 ULP.                            |
| 5   | `fp32_sqrt` + `fp32_cos`    | Square Root + Cosine        | sqrt: √4=2, √9=3, √(−1)=NaN. cos: cos(0)=1, cos(π/2)≈0, cos(π)≈−1. 10 vectors. Wide tolerance.                      |
| 6   | `fp32_cbrt` + `fp32_acos`   | Cube Root + Arccosine       | cbrt: ∛8=2, ∛27=3, ∛(−8)=−2. acos: acos(1)≈0, acos(0)≈π/2, acos(−1)≈π. 11 vectors. Wide tolerance.                  |
| 7   | `pade_lut`                  | LUT ROM Readout             | Reads all 32 entries for log2 and exp2 tables. Verifies 16 key entries with exact hex match.                           |
| 8   | `cubic_solver`              | Simple Integer Roots        | x³−6x²+11x−6=0 → {1,2,3}. x³−3x²+3x−1=0 → {1,1,1}. x³−x=0 → {0,1,−1}. Approximate root check.                    |
| 9   | `cubic_solver`              | Triple Root                 | (x−1)³=0, (x−2)³=0, (x+1)³=0. All three outputs should match the triple root.                                        |
| 10  | `cubic_solver`              | Double Root                 | x³−x²−8x+12=0 → {−3,2,2}. x³−5x²+8x−4=0 → {1,2,2}. Approximate root check.                                         |
| 11  | `cubic_solver`              | One Real Root               | x³+x+2=0, x³+3x+4=0, x³−x²+x−1=0. Check one real root, others NaN.                                                 |
| 12  | `cubic_solver`              | Invalid Input (a=0)         | a=0 with various b,c,d. Verifies all outputs are NaN.                                                                  |
| 13  | `cubic_solver`              | Negative Coefficients       | −x³+6x²−11x+6=0 (negated a). Mixed-sign large coefficients.                                                           |
| 14  | `cubic_solver`              | Special FP32 Values         | a=+Inf, a=NaN, a=MaxNormal, a=MinNormal. Verifies module doesn't hang.                                                |
| 15  | `cubic_solver`              | Back-to-Back Transactions   | 3 consecutive transactions without reset. Verifies FSM handshake protocol.                                              |

---

## Synthesis

- **Technology**: GSCL 45nm standard cell library
- **Tool**: Cadence Genus
- **Clock**: 25 MHz (40 ns period)
- **Library**: `fast.lib`
- **Constraints**: `cubic_solver.sdc`
- **Script**: `run.tcl`

### Source File Listing

| File | Lines | Description |
|------|-------|-------------|
| `pade_lut.v` | 101 | 32-entry ROM for log2/exp2 Padé approximation |
| `fp32_add.v` | 247 | IEEE 754 FP32 adder/subtractor |
| `fp32_mul.v` | 134 | IEEE 754 FP32 multiplier |
| `fp32_div.v` | 186 | IEEE 754 FP32 divider (restoring division) |
| `fp32_log2.v` | 127 | Binary logarithm via Padé LUT |
| `fp32_exp2.v` | 321 | Binary exponentiation via Padé LUT |
| `fp32_sqrt.v` | 48 | Square root: exp2(0.5 × log2(x)) |
| `fp32_cbrt.v` | 57 | Cube root: sign(x) × exp2(log2(\|x\|) / 3) |
| `fp32_cos.v` | 153 | Cosine via 64-entry LUT |
| `fp32_acos.v` | 167 | Arccosine via 64-entry LUT |
| `cubic_solver.v` | 478 | Top-level FSM (~56 states) |
| `tb_1.v`–`tb_15.v` | — | Testbench files |
| `cubic_solver.sdc` | 96 | Timing constraints |
| `run.tcl` | 208 | Cadence Genus synthesis script |
| `README.md` | — | This file |
