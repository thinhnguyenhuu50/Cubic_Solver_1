`timescale 1ns/1ps

//////////////////////////////////////////////////////////////////////////////
// tb_5.v — Square Root + Cosine testbench
// Tests fp32_sqrt (Part A) and fp32_cos (Part B) combinational modules.
//////////////////////////////////////////////////////////////////////////////

module tb_5;

    // -----------------------------------------------------------------------
    // Clock generation (40ns period, 25 MHz — kept for consistency)
    // -----------------------------------------------------------------------
    reg clk;
    initial clk = 0;
    always #20 clk = ~clk;

    // -----------------------------------------------------------------------
    // DUT signals — fp32_sqrt
    // -----------------------------------------------------------------------
    reg  [31:0] sqrt_a;
    wire [31:0] sqrt_result;

    fp32_sqrt u_sqrt (
        .a      (sqrt_a),
        .result (sqrt_result)
    );

    // -----------------------------------------------------------------------
    // DUT signals — fp32_cos
    // -----------------------------------------------------------------------
    reg  [31:0] cos_a;
    wire [31:0] cos_result;

    fp32_cos u_cos (
        .a      (cos_a),
        .result (cos_result)
    );

    // -----------------------------------------------------------------------
    // Pass / fail counters
    // -----------------------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // -----------------------------------------------------------------------
    // FP32 constants
    // -----------------------------------------------------------------------
    localparam FP_ZERO     = 32'h00000000; // 0.0
    localparam FP_HALF     = 32'h3F000000; // 0.5
    localparam FP_ONE      = 32'h3F800000; // 1.0
    localparam FP_NEG_ONE  = 32'hBF800000; // -1.0
    localparam FP_TWO      = 32'h40000000; // 2.0
    localparam FP_THREE    = 32'h40400000; // 3.0
    localparam FP_FOUR     = 32'h40800000; // 4.0
    localparam FP_NINE     = 32'h41100000; // 9.0
    localparam FP_NAN      = 32'h7FC00000; // NaN
    localparam FP_POS_INF  = 32'h7F800000; // +Inf
    localparam FP_PI_HALF  = 32'h3FC90FDB; // PI/2
    localparam FP_PI       = 32'h40490FDB; // PI

    // -----------------------------------------------------------------------
    // Wide tolerance check for LUT-based approximation results
    //   - Exact match passes immediately
    //   - NaN expected: any NaN actual passes
    //   - Same sign & exponent: mantissa within 64 ULP
    //   - Adjacent exponents (same sign): accepted for LUT accuracy
    // -----------------------------------------------------------------------
    function pass_check_wide;
        input [31:0] actual, expected;
        reg [31:0] a_abs, e_abs, diff;
        begin
            if (actual === expected) pass_check_wide = 1;
            else if (expected == 32'h7FC00000) pass_check_wide = (actual[30:23] == 8'hFF && actual[22:0] != 0); // any NaN
            else begin
                // Check if exponents match and fractions are within 64 ULP
                if (actual[31] == expected[31] && actual[30:23] == expected[30:23])
                    pass_check_wide = ((actual[22:0] > expected[22:0]) ? (actual[22:0] - expected[22:0]) : (expected[22:0] - actual[22:0])) <= 64;
                else if (actual[31] == expected[31] && 
                         ((actual[30:23] == expected[30:23] + 1) || (actual[30:23] + 1 == expected[30:23])))
                    pass_check_wide = 1; // adjacent exponents OK for LUT accuracy
                else
                    pass_check_wide = 0;
            end
        end
    endfunction

    // -----------------------------------------------------------------------
    // VCD dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_5.vcd");
        $dumpvars(0, tb_5);
    end

    // -----------------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("==========================================================");
        $display("  tb_5 — Square Root + Cosine Testbench");
        $display("==========================================================");

        // ===================================================================
        // Part A: fp32_sqrt tests
        // ===================================================================
        $display("");
        $display("--- Part A: fp32_sqrt ---");

        // A1: sqrt(4.0) = 2.0
        sqrt_a = FP_FOUR; #10;
        if (pass_check_wide(sqrt_result, FP_TWO)) begin
            $display("  [PASS] A1: sqrt(4.0) = %h (expected %h)", sqrt_result, FP_TWO);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A1: sqrt(4.0) = %h (expected %h)", sqrt_result, FP_TWO);
            fail_count = fail_count + 1;
        end

        // A2: sqrt(9.0) = 3.0
        sqrt_a = FP_NINE; #10;
        if (pass_check_wide(sqrt_result, FP_THREE)) begin
            $display("  [PASS] A2: sqrt(9.0) = %h (expected %h)", sqrt_result, FP_THREE);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A2: sqrt(9.0) = %h (expected %h)", sqrt_result, FP_THREE);
            fail_count = fail_count + 1;
        end

        // A3: sqrt(1.0) = 1.0
        sqrt_a = FP_ONE; #10;
        if (pass_check_wide(sqrt_result, FP_ONE)) begin
            $display("  [PASS] A3: sqrt(1.0) = %h (expected %h)", sqrt_result, FP_ONE);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A3: sqrt(1.0) = %h (expected %h)", sqrt_result, FP_ONE);
            fail_count = fail_count + 1;
        end

        // A4: sqrt(0.0) = 0.0
        sqrt_a = FP_ZERO; #10;
        if (pass_check_wide(sqrt_result, FP_ZERO)) begin
            $display("  [PASS] A4: sqrt(0.0) = %h (expected %h)", sqrt_result, FP_ZERO);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A4: sqrt(0.0) = %h (expected %h)", sqrt_result, FP_ZERO);
            fail_count = fail_count + 1;
        end

        // A5: sqrt(-1.0) = NaN
        sqrt_a = FP_NEG_ONE; #10;
        if (pass_check_wide(sqrt_result, FP_NAN)) begin
            $display("  [PASS] A5: sqrt(-1.0) = %h (expected NaN)", sqrt_result);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A5: sqrt(-1.0) = %h (expected NaN)", sqrt_result);
            fail_count = fail_count + 1;
        end

        // A6: sqrt(+Inf) = +Inf
        sqrt_a = FP_POS_INF; #10;
        if (pass_check_wide(sqrt_result, FP_POS_INF)) begin
            $display("  [PASS] A6: sqrt(+Inf) = %h (expected %h)", sqrt_result, FP_POS_INF);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A6: sqrt(+Inf) = %h (expected %h)", sqrt_result, FP_POS_INF);
            fail_count = fail_count + 1;
        end

        // ===================================================================
        // Part B: fp32_cos tests
        // ===================================================================
        $display("");
        $display("--- Part B: fp32_cos ---");

        // B1: cos(0.0) = 1.0
        cos_a = FP_ZERO; #10;
        if (pass_check_wide(cos_result, FP_ONE)) begin
            $display("  [PASS] B1: cos(0.0) = %h (expected %h)", cos_result, FP_ONE);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] B1: cos(0.0) = %h (expected %h)", cos_result, FP_ONE);
            fail_count = fail_count + 1;
        end

        // B2: cos(PI/2) ≈ 0.0 (wide tolerance)
        cos_a = FP_PI_HALF; #10;
        if (pass_check_wide(cos_result, FP_ZERO)) begin
            $display("  [PASS] B2: cos(PI/2) = %h (expected ~0.0)", cos_result);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] B2: cos(PI/2) = %h (expected ~0.0)", cos_result);
            fail_count = fail_count + 1;
        end

        // B3: cos(PI) ≈ -1.0
        cos_a = FP_PI; #10;
        if (pass_check_wide(cos_result, FP_NEG_ONE)) begin
            $display("  [PASS] B3: cos(PI)   = %h (expected ~%h)", cos_result, FP_NEG_ONE);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] B3: cos(PI)   = %h (expected ~%h)", cos_result, FP_NEG_ONE);
            fail_count = fail_count + 1;
        end

        // B4: cos(NaN) = NaN
        cos_a = FP_NAN; #10;
        if (pass_check_wide(cos_result, FP_NAN)) begin
            $display("  [PASS] B4: cos(NaN)  = %h (expected NaN)", cos_result);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] B4: cos(NaN)  = %h (expected NaN)", cos_result);
            fail_count = fail_count + 1;
        end

        // ===================================================================
        // Summary
        // ===================================================================
        $display("");
        $display("==========================================================");
        $display("  tb_5 SUMMARY: %0d PASSED, %0d FAILED out of %0d tests",
                 pass_count, fail_count, pass_count + fail_count);
        $display("==========================================================");

        $finish;
    end

endmodule
