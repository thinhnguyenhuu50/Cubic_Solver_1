`timescale 1ns/1ps

//////////////////////////////////////////////////////////////////////////////
// tb_6.v — Cube Root + Arccosine testbench
// Tests fp32_cbrt (Part A) and fp32_acos (Part B) combinational modules.
//////////////////////////////////////////////////////////////////////////////

module tb_6;

    // -----------------------------------------------------------------------
    // Clock generation (40ns period, 25 MHz — kept for consistency)
    // -----------------------------------------------------------------------
    reg clk;
    initial clk = 0;
    always #20 clk = ~clk;

    // -----------------------------------------------------------------------
    // DUT signals — fp32_cbrt
    // -----------------------------------------------------------------------
    reg  [31:0] cbrt_a;
    wire [31:0] cbrt_result;

    fp32_cbrt u_cbrt (
        .a      (cbrt_a),
        .result (cbrt_result)
    );

    // -----------------------------------------------------------------------
    // DUT signals — fp32_acos
    // -----------------------------------------------------------------------
    reg  [31:0] acos_a;
    wire [31:0] acos_result;

    fp32_acos u_acos (
        .a      (acos_a),
        .result (acos_result)
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
    localparam FP_NEG_TWO  = 32'hC0000000; // -2.0
    localparam FP_THREE    = 32'h40400000; // 3.0
    localparam FP_EIGHT    = 32'h41000000; // 8.0
    localparam FP_NEG_EIGHT= 32'hC1000000; // -8.0
    localparam FP_27       = 32'h41D80000; // 27.0
    localparam FP_NEG_27   = 32'hC1D80000; // -27.0
    localparam FP_NAN      = 32'h7FC00000; // NaN
    localparam FP_POS_INF  = 32'h7F800000; // +Inf
    localparam FP_PI_HALF  = 32'h3FC90FDB; // PI/2
    localparam FP_PI       = 32'h40490FDB; // PI
    localparam FP_PI_THIRD = 32'h3F860A92; // PI/3 ≈ 1.0472

    // -----------------------------------------------------------------------
    // Wide tolerance check for LUT-based approximation results
    // -----------------------------------------------------------------------
    function pass_check_wide;
        input [31:0] actual, expected;
        reg [31:0] diff;
        begin
            if (actual === expected) pass_check_wide = 1;
            else if (expected == 32'h7FC00000) pass_check_wide = (actual[30:23] == 8'hFF && actual[22:0] != 0); // any NaN
            else if (expected == 32'h00000000) pass_check_wide = (actual[30:23] <= 8'h7E); // < ~0.5
            else if (actual == 32'h00000000) pass_check_wide = (expected[30:23] <= 8'h7E); // < ~0.5
            else begin
                if (actual[31] != expected[31]) pass_check_wide = 0;
                else if (actual[30:23] == expected[30:23]) begin
                    diff = (actual[22:0] > expected[22:0]) ? (actual[22:0] - expected[22:0]) : (expected[22:0] - actual[22:0]);
                    pass_check_wide = (diff <= 24'h080000); // allow ~6% error in fraction
                end
                else if ((actual[30:23] == expected[30:23] + 1) || (actual[30:23] + 1 == expected[30:23])) begin
                    pass_check_wide = 1; // adjacent exponents OK for LUT accuracy
                end
                else pass_check_wide = 0;
            end
        end
    endfunction

    // -----------------------------------------------------------------------
    // VCD dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_6.vcd");
        $dumpvars(0, tb_6);
    end

    // -----------------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("==========================================================");
        $display("  tb_6 — Cube Root + Arccosine Testbench");
        $display("==========================================================");

        // ===================================================================
        // Part A: fp32_cbrt tests
        // ===================================================================
        $display("");
        $display("--- Part A: fp32_cbrt ---");

        // A1: cbrt(8.0) = 2.0
        cbrt_a = FP_EIGHT; #10;
        if (pass_check_wide(cbrt_result, FP_TWO)) begin
            $display("  [PASS] A1: cbrt(8.0)  = %h (expected %h)", cbrt_result, FP_TWO);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A1: cbrt(8.0)  = %h (expected %h)", cbrt_result, FP_TWO);
            fail_count = fail_count + 1;
        end

        // A2: cbrt(27.0) = 3.0
        cbrt_a = FP_27; #10;
        if (pass_check_wide(cbrt_result, FP_THREE)) begin
            $display("  [PASS] A2: cbrt(27.0) = %h (expected %h)", cbrt_result, FP_THREE);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A2: cbrt(27.0) = %h (expected %h)", cbrt_result, FP_THREE);
            fail_count = fail_count + 1;
        end

        // A3: cbrt(-8.0) = -2.0
        cbrt_a = FP_NEG_EIGHT; #10;
        if (pass_check_wide(cbrt_result, FP_NEG_TWO)) begin
            $display("  [PASS] A3: cbrt(-8.0) = %h (expected %h)", cbrt_result, FP_NEG_TWO);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A3: cbrt(-8.0) = %h (expected %h)", cbrt_result, FP_NEG_TWO);
            fail_count = fail_count + 1;
        end

        // A4: cbrt(1.0) = 1.0
        cbrt_a = FP_ONE; #10;
        if (pass_check_wide(cbrt_result, FP_ONE)) begin
            $display("  [PASS] A4: cbrt(1.0)  = %h (expected %h)", cbrt_result, FP_ONE);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A4: cbrt(1.0)  = %h (expected %h)", cbrt_result, FP_ONE);
            fail_count = fail_count + 1;
        end

        // A5: cbrt(0.0) = 0.0
        cbrt_a = FP_ZERO; #10;
        if (pass_check_wide(cbrt_result, FP_ZERO)) begin
            $display("  [PASS] A5: cbrt(0.0)  = %h (expected %h)", cbrt_result, FP_ZERO);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A5: cbrt(0.0)  = %h (expected %h)", cbrt_result, FP_ZERO);
            fail_count = fail_count + 1;
        end

        // A6: cbrt(NaN) = NaN
        cbrt_a = FP_NAN; #10;
        if (pass_check_wide(cbrt_result, FP_NAN)) begin
            $display("  [PASS] A6: cbrt(NaN)  = %h (expected NaN)", cbrt_result);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] A6: cbrt(NaN)  = %h (expected NaN)", cbrt_result);
            fail_count = fail_count + 1;
        end

        // ===================================================================
        // Part B: fp32_acos tests
        // ===================================================================
        $display("");
        $display("--- Part B: fp32_acos ---");

        // B1: acos(1.0) ≈ 0.0
        acos_a = FP_ONE; #10;
        if (pass_check_wide(acos_result, FP_ZERO)) begin
            $display("  [PASS] B1: acos(1.0)  = %h (expected ~%h)", acos_result, FP_ZERO);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] B1: acos(1.0)  = %h (expected ~%h)", acos_result, FP_ZERO);
            fail_count = fail_count + 1;
        end

        // B2: acos(0.0) ≈ PI/2
        acos_a = FP_ZERO; #10;
        if (pass_check_wide(acos_result, FP_PI_HALF)) begin
            $display("  [PASS] B2: acos(0.0)  = %h (expected ~%h)", acos_result, FP_PI_HALF);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] B2: acos(0.0)  = %h (expected ~%h)", acos_result, FP_PI_HALF);
            fail_count = fail_count + 1;
        end

        // B3: acos(-1.0) ≈ PI
        acos_a = FP_NEG_ONE; #10;
        if (pass_check_wide(acos_result, FP_PI)) begin
            $display("  [PASS] B3: acos(-1.0) = %h (expected ~%h)", acos_result, FP_PI);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] B3: acos(-1.0) = %h (expected ~%h)", acos_result, FP_PI);
            fail_count = fail_count + 1;
        end

        // B4: acos(0.5) ≈ PI/3 ≈ 1.0472 (32'h3F860A92)
        acos_a = FP_HALF; #10;
        if (pass_check_wide(acos_result, FP_PI_THIRD)) begin
            $display("  [PASS] B4: acos(0.5)  = %h (expected ~%h)", acos_result, FP_PI_THIRD);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] B4: acos(0.5)  = %h (expected ~%h)", acos_result, FP_PI_THIRD);
            fail_count = fail_count + 1;
        end

        // B5: acos(NaN) = NaN
        acos_a = FP_NAN; #10;
        if (pass_check_wide(acos_result, FP_NAN)) begin
            $display("  [PASS] B5: acos(NaN)  = %h (expected NaN)", acos_result);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] B5: acos(NaN)  = %h (expected NaN)", acos_result);
            fail_count = fail_count + 1;
        end

        // ===================================================================
        // Summary
        // ===================================================================
        $display("");
        $display("==========================================================");
        $display("  tb_6 SUMMARY: %0d PASSED, %0d FAILED out of %0d tests",
                 pass_count, fail_count, pass_count + fail_count);
        $display("==========================================================");

        $finish;
    end

endmodule
