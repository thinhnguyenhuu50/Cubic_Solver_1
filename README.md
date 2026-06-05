# Cubic Solver — RTL Design & Testbench Documentation

## Overview

The `cubic_solver` module solves cubic equations of the form **ax³ + bx² + cx + d = 0** using a Finite State Machine (FSM) approach. All inputs and outputs use IEEE 754 single-precision floating-point (FP32) representation.

### Module Interface

| Port       | Direction | Width | Description                                  |
|------------|-----------|-------|----------------------------------------------|
| `clk`      | Input     | 1     | System clock (25 MHz / 40 ns period)         |
| `rst_n`    | Input     | 1     | Active-low asynchronous reset                |
| `in_valid` | Input     | 1     | Asserted when input coefficients are valid    |
| `in_ready` | Output    | 1     | Asserted when module is ready to accept input |
| `a`        | Input     | 32    | Coefficient of x³ (FP32)                     |
| `b`        | Input     | 32    | Coefficient of x² (FP32)                     |
| `c`        | Input     | 32    | Coefficient of x  (FP32)                     |
| `d`        | Input     | 32    | Constant term     (FP32)                     |
| `out_valid`| Output    | 1     | Asserted when output solutions are valid      |
| `out_ready`| Input     | 1     | Asserted by receiver to acknowledge output    |
| `x0`       | Output    | 32    | First root  (FP32)                           |
| `x1`       | Output    | 32    | Second root (FP32), or NaN if unused         |
| `x2`       | Output    | 32    | Third root  (FP32), or NaN if unused         |

### FSM States

| State            | Description                                                 |
|------------------|-------------------------------------------------------------|
| `IDLE`           | Wait for `in_valid`; assert `in_ready`                      |
| `LOAD`           | Latch inputs; check if `a == 0` (invalid)                   |
| `CALC_DEPRESSED` | Compute depressed cubic parameters `p` and `q`              |
| `CALC_DISC`      | Compute discriminant Δ                                      |
| `PADE_APPROX`    | Padé approximation via lookup table for sqrt/cbrt           |
| `CALC_ROOTS`     | Compute final root values x0, x1, x2                        |
| `DONE`           | Assert `out_valid`; wait for `out_ready` handshake           |

---

## Test Cases

All testbenches are located in the project root directory. Each testbench is a standalone file named `tb_<index>.v` that can be compiled with the DUT `cubic_solver.v` using any Verilog simulator (e.g., Icarus Verilog, ModelSim, VCS).

### How to Run

```bash
# Example: run testbench tb_1 with Icarus Verilog
iverilog -o tb_1.vvp tb_1.v cubic_solver.v
vvp tb_1.vvp
```

### Test Case Summary Table

| No. | Target                        | Test Case Name                | Test Case Explanation                                                                                                                                                          |
|-----|-------------------------------|-------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1   | FP32 Addition                 | `tb_fp32_addition`            | Drives positive integer-valued FP32 coefficients that exercise the addition path in the depressed cubic transformation. Verifies `out_valid` asserts and outputs are not X/Z.  |
| 2   | FP32 Subtraction              | `tb_fp32_subtraction`         | Drives coefficients with negative FP32 values (e.g., `(x−1)³ = 0`) that exercise the subtraction path. Verifies `out_valid` asserts and outputs are not X/Z.                   |
| 3   | FP32 Multiplication           | `tb_fp32_multiplication`      | Drives larger-valued coefficients (e.g., a=2, b=4, c=6, d=8) that stress the multiplication path. Verifies `out_valid` asserts and outputs are not X/Z.                        |
| 4   | FP32 Division                 | `tb_fp32_division`            | Drives non-unity `a` values (e.g., a=3, a=5) that stress the division/normalization path. Verifies `out_valid` asserts and outputs are not X/Z.                                 |
| 5   | Square Root Path              | `tb_sqrt_path`                | Drives coefficients producing a positive discriminant (3 distinct real roots) to exercise the square root computation. Checks valid FP32 outputs.                               |
| 6   | Cube Root Path                | `tb_cbrt_path`                | Drives coefficients producing a negative discriminant (1 real root, 2 complex) to exercise the cube root via Cardano's formula. Checks valid FP32 outputs.                      |
| 7   | Padé Approx / LUT             | `tb_pade_lut`                 | Drives varied coefficients to produce different discriminant low-bit patterns, exercising multiple entries of the Padé approximation lookup table. Checks valid outputs.         |
| 8   | Simple Integer Roots          | `tb_simple_integer_roots`     | Tests simple cubic equations with small integer coefficients whose roots are known exactly (e.g., roots 1,2,3; triple root 1; roots 0,1,−1).                                   |
| 9   | Triple Root                   | `tb_triple_root`              | Tests equations of the form `(x−r)³ = 0` where all three roots are identical (e.g., `(x−1)³`, `(x−2)³`, `(x+1)³`).                                                             |
| 10  | Double Root                   | `tb_double_root`              | Tests equations with exactly one repeated root and one distinct root (e.g., `x³−x²−8x+12 = 0` with roots −3, 2, 2).                                                           |
| 11  | One Real Root (Two Complex)   | `tb_one_real_root`            | Tests equations with one real root and two complex conjugate roots (e.g., `x³+x+2 = 0`, `x³+3x+4 = 0`).                                                                       |
| 12  | Invalid Input (a=0)           | `tb_invalid_input_a_zero`     | Tests the degenerate case where `a = 0` (not a cubic equation). Verifies all three outputs are NaN (`32'h7FC00000`).                                                            |
| 13  | Negative Coefficients         | `tb_negative_coefficients`    | Tests equations with all-negative or mixed-sign large coefficients (e.g., `a = −1, b = 6, c = −11, d = 6`). Verifies module handles sign combinations correctly.                |
| 14  | Special FP32 Values           | `tb_special_fp32_values`      | Tests with IEEE 754 special values: `+Inf`, `NaN`, max normal, min normal. Verifies the module does not hang and `out_valid` eventually asserts.                                 |
| 15  | Back-to-Back Transactions     | `tb_back_to_back`             | Issues 3 consecutive transactions without reset between them. Verifies the handshake protocol works correctly and the FSM returns to IDLE between each transaction.              |

---

## Synthesis

The design targets the GSCL 45nm standard cell library and is synthesized with Cadence Genus.

- **Clock**: 25 MHz (40 ns period)
- **Library**: `fast.lib` (for timing closure with margin)
- **Constraints**: `cubic_solver.sdc`
- **Script**: `run.tcl`

### File Listing

| File                | Description                              |
|---------------------|------------------------------------------|
| `cubic_solver.v`    | RTL source — main cubic solver module    |
| `cubic_solver.sdc`  | Synopsys Design Constraints              |
| `run.tcl`           | Cadence Genus synthesis script           |
| `tb_1.v`–`tb_15.v`  | Testbench files (see table above)        |
| `README.md`         | This file                                |
