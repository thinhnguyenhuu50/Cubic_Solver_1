# Cubic Equation Solver (FP32)

## 1. Description of Signals

| Signal Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | Clock signal |
| `rst_n` | Input | 1 | Active-low asynchronous reset |
| `in_valid` | Input | 1 | Handshake signal: high when input coefficients are valid |
| `in_ready` | Output | 1 | Handshake signal: high when module is ready to accept inputs |
| `a`, `b`, `c`, `d` | Input | 32 | IEEE 754 FP32 coefficients for $ax^3 + bx^2 + cx + d = 0$ |
| `out_valid` | Output | 1 | Handshake signal: high when computation is finished and roots are valid |
| `out_ready` | Input | 1 | Handshake signal: high when downstream receiver is ready for output |
| `x0`, `x1`, `x2` | Output | 32 | IEEE 754 FP32 computed roots. Complex roots are output as `NaN`. |

## 2. Functional Implementation

This hardware module computes the roots of a cubic equation $ax^3 + bx^2 + cx + d = 0$ using purely IEEE 754 32-bit floating-point (FP32) arithmetic. The architecture relies on a **Finite State Machine (FSM)** that schedules operations across a highly modular set of combinational math blocks to achieve a balanced critical path suitable for fast synthesis.

The module implements **Cardano's method** as the baseline calculation and diverges to a **Trigonometric method** (using `acos` and `cos`) when the discriminant indicates three real roots (the irreducible case). 

Transcendental functions (e.g. $\log_2(x)$, $2^x$, $\cos(x)$, $\arccos(x)$) are implemented using an ultra-efficient **Padé approximation** approach paired with a tiny 32-entry lookup table (LUT), avoiding the latency and massive area of traditional CORDIC iterators.

## 3. Table of Variable Names of State Machine

| Variable Name | Description |
| :--- | :--- |
| `a_reg`, `b_reg`, `c_reg`, `d_reg` | Registered inputs of coefficients |
| `ba`, `ca`, `da`, `ba3` | Normalized coefficients $b/a$, $c/a$, $d/a$, and $b/3a$ |
| `ba_sq`, `ba_sq_3` | $(b/a)^2$ and $(b/a)^2 / 3$ |
| `p_reg`, `q_reg` | Depressed cubic coefficients $p$ and $q$ |
| `ba_ca`, `ba_ca_3` | $(b/a)(c/a)$ and $(b/a)(c/a)/3$ |
| `ba_cu`, `ba_cu_27` | $(b/a)^3$ and $(b/a)^3 / 27$ |
| `q_tmp` | Intermediate computation for $q$ |
| `p_sq`, `p_cu`, `four_p3` | $p^2$, $p^3$, and $4p^3$ |
| `q_sq`, `t27q2` | $q^2$ and $27q^2$ |
| `disc_sum`, `disc` | Discriminant sum and final Discriminant $\Delta = -(4p^3 + 27q^2)$ |
| `neg_p`, `neg_p_3` | $-p$ and $-p/3$ |
| `A_val`, `A_cu`, `two_A_cu` | $A = \sqrt{-p/3}$, $A^3$, and $2A^3$ |
| `neg_q`, `cos_arg` | $-q$ and Argument for arccosine ($-q / 2A^3$) |
| `theta_full`, `theta` | $\theta_{full} = \arccos(\text{cos\_arg})$ and $\theta = \theta_{full}/3$ |
| `ang1`, `ang2` | Angles $\theta - 2\pi/3$ and $\theta + 2\pi/3$ |
| `cos0`, `cos1`, `cos2` | Cosines of $\theta$, `ang1`, and `ang2` |
| `two_A`, `t0`, `t1`, `t2` | $2A$, and trigonometric roots $t_0, t_1, t_2$ |
| `q_sq_4`, `p_cu_27` | $q^2 / 4$ and $p^3 / 27$ for Cardano's formula |
| `under_sqrt`, `sq_val` | Value inside square root, and its computed square root |
| `neg_q_2`, `S_val`, `T_val` | $-q/2$, and Cardano parameters $S$ and $T$ |
| `cbrt_S`, `cbrt_T` | Cube roots of $S$ and $T$ |

## 4. Table of State Names of State Machine

| State Name | Function |
| :--- | :--- |
| `S_IDLE` | Wait for valid inputs |
| `S_LOAD` | Load inputs into registers |
| `S_NORM_BA` to `S_NORM_BA3` | Normalize coefficients by dividing by $a$ |
| `S_DEP_BA2` to `S_DEP_Q` | Compute depressed cubic coefficients $p$ and $q$ |
| `S_DISC_P2` to `S_DISC_NEG` | Compute discriminant $\Delta = -(4p^3 + 27q^2)$ |
| `S_BRANCH` | Branch to Trigonometric or Cardano based on Discriminant and $p$ |
| `S_TRI_NP` to `S_TRI_X2` | Trigonometric root extraction for 3 real roots ($\Delta \ge 0$) |
| `S_CAR_Q24` to `S_CAR_X0` | Cardano root extraction for 1 real root ($\Delta < 0$ or $p=0$) |
| `S_DONE` | Output the roots and wait for `out_ready` |

## 5. Testcases

| No. | Target | Test case name | Test case explanation |
| :--- | :--- | :--- | :--- |
| 1 | `fp32_add` | `tb_1` | Test FP32 Addition (sub=0) across normal, NaN, Inf, and zero values. |
| 2 | `fp32_add` | `tb_2` | Test FP32 Subtraction (sub=1) handling signs and zero-crossings. |
| 3 | `fp32_mul` | `tb_3` | Test FP32 Multiplication with normal constants and edge cases. |
| 4 | `fp32_div` | `tb_4` | Test FP32 Division (Restoring division algorithm) and zero-division handling. |
| 5 | `fp32_sqrt`, `fp32_cos` | `tb_5` | Test Square Root (via `exp2` and `log2`) and Cosine (LUT approximation). |
| 6 | `fp32_cbrt`, `fp32_acos` | `tb_6` | Test Cube Root and Arccosine approximation modules. |
| 7 | `pade_lut` | `tb_7` | Verify the structural readout of the `log2` and `exp2` Padé LUT ROMs. |
| 8 | `cubic_solver` | `tb_8` | End-to-end integration test with simple cubic equations with three integer roots. |
| 9 | `cubic_solver` | `tb_9` | End-to-end integration test handling triple root cases (e.g. $(x-1)^3=0$). |
| 10 | `cubic_solver` | `tb_10` | End-to-end integration test handling double root cases. |
| 11 | `cubic_solver` | `tb_11` | End-to-end test triggering Cardano's method (1 real root, 2 complex roots). |
| 12 | `cubic_solver` | `tb_12` | Validation test for invalid inputs (e.g. $a=0$, which is not a cubic). |
| 13 | `cubic_solver` | `tb_13` | Validation test with negative IEEE 754 coefficients. |
| 14 | `cubic_solver` | `tb_14` | Validation test providing special FP32 edge case inputs (NaN, +/-Inf, Max/Min normal). |
| 15 | `cubic_solver` | `tb_15` | Handshake sequence test checking back-to-back transaction handling. |
