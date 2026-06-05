`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////
// tb_8.v — Simple Integer Roots
//
// Tests cubic equations with small integer coefficients:
//   Test 1: x³ - 6x² + 11x - 6 = 0  → roots: 1, 2, 3
//   Test 2: x³ - 3x² + 3x - 1 = 0   → triple root: 1
//   Test 3: x³ - x = 0               → roots: 0, 1, -1
////////////////////////////////////////////////////////////////////////////////

module tb_8;

    // ----------------------------------------------------------------
    // Clock and reset
    // ----------------------------------------------------------------
    reg clk;
    reg rst_n;
    initial clk = 0;
    always #20 clk = ~clk; // 40 ns period → 25 MHz

    // ----------------------------------------------------------------
    // DUT signals
    // ----------------------------------------------------------------
    reg         in_valid_r;
    wire        in_ready_w;
    reg  [31:0] a_r, b_r, c_r, d_r;
    wire        out_valid_w;
    reg         out_ready_r;
    wire [31:0] x0_w, x1_w, x2_w;

    // ----------------------------------------------------------------
    // DUT instantiation
    // ----------------------------------------------------------------
    cubic_solver uut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid_r),
        .in_ready  (in_ready_w),
        .a         (a_r),
        .b         (b_r),
        .c         (c_r),
        .d         (d_r),
        .out_valid (out_valid_w),
        .out_ready (out_ready_r),
        .x0        (x0_w),
        .x1        (x1_w),
        .x2        (x2_w)
    );

    // ----------------------------------------------------------------
    // Counters
    // ----------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer test_num;

    // ----------------------------------------------------------------
    // FP32 approximate equality (within ~factor of 2, handles NaN)
    // ----------------------------------------------------------------
    function fp32_approx_eq;
        input [31:0] actual, expected;
        reg [7:0] a_exp, e_exp;
        reg [22:0] a_frac, e_frac;
        begin
            if (expected == 32'h7FC00000) // expected NaN
                fp32_approx_eq = (actual[30:23] == 8'hFF && actual[22:0] != 0);
            else if (actual == 32'h7FC00000)
                fp32_approx_eq = 0;
            else if (expected == 32'h00000000 && actual[30:23] <= 8'h7E) fp32_approx_eq = 1; else if (actual == 32'h00000000 && expected[30:23] <= 8'h7E) fp32_approx_eq = 1; else if (actual == expected)
                fp32_approx_eq = 1;
            else if (actual[31] != expected[31]) // different signs
                fp32_approx_eq = 0;
            else begin
                a_exp = actual[30:23]; e_exp = expected[30:23];
                if (a_exp > e_exp + 1 || e_exp > a_exp + 1)
                    fp32_approx_eq = 0;
                else
                    fp32_approx_eq = 1;
            end
        end
    endfunction

    // ----------------------------------------------------------------
    // Check if 3 actual roots contain 3 expected roots (any order)
    // Returns 1 if all 3 expected roots are matched (each used once)
    // ----------------------------------------------------------------
    function check_roots_3;
        input [31:0] x0, x1, x2;
        input [31:0] e0, e1, e2;
        reg m0, m1, m2; // which actuals are matched
        reg found;
        begin
            m0 = 0; m1 = 0; m2 = 0;
            found = 1;

            // Match e0
            if      (!m0 && fp32_approx_eq(x0, e0)) m0 = 1;
            else if (!m1 && fp32_approx_eq(x1, e0)) m1 = 1;
            else if (!m2 && fp32_approx_eq(x2, e0)) m2 = 1;
            else found = 0;

            // Match e1
            if (found) begin
                if      (!m0 && fp32_approx_eq(x0, e1)) m0 = 1;
                else if (!m1 && fp32_approx_eq(x1, e1)) m1 = 1;
                else if (!m2 && fp32_approx_eq(x2, e1)) m2 = 1;
                else found = 0;
            end

            // Match e2
            if (found) begin
                if      (!m0 && fp32_approx_eq(x0, e2)) m0 = 1;
                else if (!m1 && fp32_approx_eq(x1, e2)) m1 = 1;
                else if (!m2 && fp32_approx_eq(x2, e2)) m2 = 1;
                else found = 0;
            end

            check_roots_3 = found;
        end
    endfunction

    // ----------------------------------------------------------------
    // Helper tasks
    // ----------------------------------------------------------------
    task drive_and_wait;
        input [31:0] ta, tb, tc, td;
        begin
            @(posedge clk);
            while (!in_ready_w) @(posedge clk);
            a_r = ta; b_r = tb; c_r = tc; d_r = td;
            in_valid_r = 1'b1;
            @(posedge clk);
            in_valid_r = 1'b0;
            wait(out_valid_w == 1'b1);
            @(posedge clk); #1;
        end
    endtask

    task accept_output;
        begin
            out_ready_r = 1'b1;
            @(posedge clk);
            out_ready_r = 1'b0;
        end
    endtask

    // ----------------------------------------------------------------
    // IEEE 754 constants
    // ----------------------------------------------------------------
    localparam [31:0] FP_0   = 32'h00000000; //  0.0
    localparam [31:0] FP_1   = 32'h3F800000; //  1.0
    localparam [31:0] FP_N1  = 32'hBF800000; // -1.0
    localparam [31:0] FP_2   = 32'h40000000; //  2.0
    localparam [31:0] FP_3   = 32'h40400000; //  3.0
    localparam [31:0] FP_N3  = 32'hC0400000; // -3.0
    localparam [31:0] FP_N6  = 32'hC0C00000; // -6.0
    localparam [31:0] FP_11  = 32'h41300000; // 11.0

    // ----------------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_8);

        // Initialise
        pass_count  = 0;
        fail_count  = 0;
        test_num    = 0;
        in_valid_r  = 1'b0;
        out_ready_r = 1'b0;
        a_r = 32'd0; b_r = 32'd0; c_r = 32'd0; d_r = 32'd0;

        // ---- Reset ----
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("========================================================");
        $display("TB_8: Simple Integer Roots");
        $display("========================================================");

        // ----------------------------------------------------------
        // Test 1: x³ - 6x² + 11x - 6 = 0 → roots: 1, 2, 3
        //         a=1, b=-6, c=11, d=-6
        // ----------------------------------------------------------
        test_num = 1;
        $display("\n[Test %0d] x^3 - 6x^2 + 11x - 6 = 0  (roots: 1, 2, 3)", test_num);
        $display("  a=1.0(3F800000), b=-6.0(C0C00000), c=11.0(41300000), d=-6.0(C0C00000)");
        drive_and_wait(FP_1, FP_N6, FP_11, FP_N6);
        $display("  x0 = %h, x1 = %h, x2 = %h", x0_w, x1_w, x2_w);
        if (check_roots_3(x0_w, x1_w, x2_w, FP_1, FP_2, FP_3)) begin
            $display("  PASS — roots {1, 2, 3} found");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL — expected roots {1, 2, 3} not matched");
            fail_count = fail_count + 1;
        end
        accept_output;

        // ----------------------------------------------------------
        // Test 2: x³ - 3x² + 3x - 1 = 0 → triple root: 1
        //         a=1, b=-3, c=3, d=-1
        // ----------------------------------------------------------
        test_num = 2;
        $display("\n[Test %0d] x^3 - 3x^2 + 3x - 1 = 0  (triple root: 1)", test_num);
        $display("  a=1.0(3F800000), b=-3.0(C0400000), c=3.0(40400000), d=-1.0(BF800000)");
        drive_and_wait(FP_1, FP_N3, FP_3, FP_N1);
        $display("  x0 = %h, x1 = %h, x2 = %h", x0_w, x1_w, x2_w);
        if (fp32_approx_eq(x0_w, FP_1)) begin
            $display("  PASS — triple root 1.0 found in x0");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL — expected triple root 1.0 not matched in x0");
            fail_count = fail_count + 1;
        end
        accept_output;

        // ----------------------------------------------------------
        // Test 3: x³ - x = 0 → roots: 0, 1, -1
        //         a=1, b=0, c=-1, d=0
        // ----------------------------------------------------------
        test_num = 3;
        $display("\n[Test %0d] x^3 - x = 0  (roots: 0, 1, -1)", test_num);
        $display("  a=1.0(3F800000), b=0.0(00000000), c=-1.0(BF800000), d=0.0(00000000)");
        drive_and_wait(FP_1, FP_0, FP_N1, FP_0);
        $display("  x0 = %h, x1 = %h, x2 = %h", x0_w, x1_w, x2_w);
        if (check_roots_3(x0_w, x1_w, x2_w, FP_0, FP_1, FP_N1)) begin
            $display("  PASS — roots {0, 1, -1} found");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL — expected roots {0, 1, -1} not matched");
            fail_count = fail_count + 1;
        end
        accept_output;

        // ----------------------------------------------------------
        // Summary
        // ----------------------------------------------------------
        $display("\n========================================================");
        $display("TB_8 SUMMARY:  PASS = %0d / %0d,  FAIL = %0d / %0d",
                  pass_count, pass_count + fail_count,
                  fail_count, pass_count + fail_count);
        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: SOME TESTS FAILED");
        $display("========================================================\n");

        $finish;
    end

    // ----------------------------------------------------------------
    // Timeout watchdog
    // ----------------------------------------------------------------
    initial begin
        #200_000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
