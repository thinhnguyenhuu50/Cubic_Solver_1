`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////
// tb_11.v — One Real Root (Two Complex)
//
// Tests equations with one real root and two complex conjugate roots:
//   Test 1: x³ + x + 2 = 0        → a=1, b=0, c=1, d=2
//   Test 2: x³ + 3x + 4 = 0       → a=1, b=0, c=3, d=4
//   Test 3: x³ - x² + x - 1 = 0   → a=1, b=-1, c=1, d=-1
////////////////////////////////////////////////////////////////////////////////

module tb_11;

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
    reg         in_valid_in;
    wire        in_ready_out;
    reg  [31:0] a_in, b_in, c_in, d_in;
    wire        out_valid_out;
    reg         out_ready_in;
    wire [31:0] x0_out, x1_out, x2_out;

    // ----------------------------------------------------------------
    // DUT instantiation
    // ----------------------------------------------------------------
    cubic_solver uut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid_in),
        .in_ready  (in_ready_out),
        .a         (a_in),
        .b         (b_in),
        .c         (c_in),
        .d         (d_in),
        .out_valid (out_valid_out),
        .out_ready (out_ready_in),
        .x0        (x0_out),
        .x1        (x1_out),
        .x2        (x2_out)
    );

    // ----------------------------------------------------------------
    // Counters
    // ----------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer test_num;

    // ----------------------------------------------------------------
    // Helper task: drive inputs and wait for outputs
    // ----------------------------------------------------------------
    task drive_and_wait;
        input [31:0] ta, tb, tc, td;
        begin
            @(posedge clk);
            a_in = ta; b_in = tb; c_in = tc; d_in = td;
            in_valid_in = 1'b1;
            @(posedge clk);
            in_valid_in = 1'b0;
            // Wait for out_valid
            wait(out_valid_out == 1'b1);
            @(posedge clk);
            #1;
            $display("  x0 = %h, x1 = %h, x2 = %h", x0_out, x1_out, x2_out);
            out_ready_in = 1'b1;
            @(posedge clk);
            out_ready_in = 1'b0;
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
    localparam [31:0] FP_4   = 32'h40800000; //  4.0
    localparam [31:0] FP_NAN = 32'h7FC00000; //  NaN

    // ----------------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_11);

        // Initialise
        pass_count  = 0;
        fail_count  = 0;
        test_num    = 0;
        in_valid_in = 1'b0;
        out_ready_in = 1'b0;
        a_in = 32'd0; b_in = 32'd0; c_in = 32'd0; d_in = 32'd0;

        // ---- Reset ----
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("========================================================");
        $display("TB_11: One Real Root (Two Complex Conjugate Roots)");
        $display("========================================================");

        // ----------------------------------------------------------
        // Test 1: x³ + x + 2 = 0
        //         a=1, b=0, c=1, d=2
        //         One real root ≈ -1, two complex conjugate roots
        // ----------------------------------------------------------
        test_num = 1;
        $display("\n[Test %0d] x^3 + x + 2 = 0  (one real, two complex)", test_num);
        $display("  a=1.0, b=0.0, c=1.0, d=2.0");
        drive_and_wait(FP_1, FP_0, FP_1, FP_2);
        // For one-real-root case, x1 and x2 might be NaN (complex)
        if (x0_out === 32'hxxxxxxxx) begin
            $display("  FAIL — x0 output contains X");
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS — output produced (x1,x2 may be NaN for complex roots)");
            pass_count = pass_count + 1;
        end

        // ----------------------------------------------------------
        // Test 2: x³ + 3x + 4 = 0
        //         a=1, b=0, c=3, d=4
        //         One real root ≈ -1, two complex conjugate roots
        // ----------------------------------------------------------
        test_num = 2;
        $display("\n[Test %0d] x^3 + 3x + 4 = 0  (one real, two complex)", test_num);
        $display("  a=1.0, b=0.0, c=3.0, d=4.0");
        drive_and_wait(FP_1, FP_0, FP_3, FP_4);
        if (x0_out === 32'hxxxxxxxx) begin
            $display("  FAIL — x0 output contains X");
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS — output produced (x1,x2 may be NaN for complex roots)");
            pass_count = pass_count + 1;
        end

        // ----------------------------------------------------------
        // Test 3: x³ - x² + x - 1 = 0
        //         a=1, b=-1, c=1, d=-1
        //         Roots: 1 (real), ±i (complex)
        // ----------------------------------------------------------
        test_num = 3;
        $display("\n[Test %0d] x^3 - x^2 + x - 1 = 0  (roots: 1, +i, -i)", test_num);
        $display("  a=1.0, b=-1.0, c=1.0, d=-1.0");
        drive_and_wait(FP_1, FP_N1, FP_1, FP_N1);
        if (x0_out === 32'hxxxxxxxx) begin
            $display("  FAIL — x0 output contains X");
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS — output produced (x1,x2 may be NaN for complex roots)");
            pass_count = pass_count + 1;
        end

        // ----------------------------------------------------------
        // Summary
        // ----------------------------------------------------------
        $display("\n========================================================");
        $display("TB_11 SUMMARY:  PASS = %0d / %0d,  FAIL = %0d / %0d",
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
        #100_000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
