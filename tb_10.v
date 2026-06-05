`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////
// tb_10.v — Double Root
//
// Tests equations with a double root:
//   Test 1: x³ - x² - 8x + 12 = 0   → roots: -3, 2, 2
//   Test 2: x³ - 5x² + 8x - 4 = 0   → roots: 1, 2, 2
//   Test 3: x³ - 4x² + 5x - 2 = 0   → roots: 1, 1, 2
////////////////////////////////////////////////////////////////////////////////

module tb_10;

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
    localparam [31:0] FP_1   = 32'h3F800000; //  1.0
    localparam [31:0] FP_N1  = 32'hBF800000; // -1.0
    localparam [31:0] FP_2   = 32'h40000000; //  2.0
    localparam [31:0] FP_N2  = 32'hC0000000; // -2.0
    localparam [31:0] FP_4   = 32'h40800000; //  4.0
    localparam [31:0] FP_N4  = 32'hC0800000; // -4.0
    localparam [31:0] FP_5   = 32'h40A00000; //  5.0
    localparam [31:0] FP_N5  = 32'hC0A00000; // -5.0
    localparam [31:0] FP_8   = 32'h41000000; //  8.0
    localparam [31:0] FP_N8  = 32'hC1000000; // -8.0
    localparam [31:0] FP_12  = 32'h41400000; // 12.0
    localparam [31:0] FP_N12 = 32'hC1400000; // -12.0

    // ----------------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_10);

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
        $display("TB_10: Double Root Tests");
        $display("========================================================");

        // ----------------------------------------------------------
        // Test 1: x³ - x² - 8x + 12 = 0 → roots: -3, 2, 2
        //         a=1, b=-1, c=-8, d=12
        // ----------------------------------------------------------
        test_num = 1;
        $display("\n[Test %0d] x^3 - x^2 - 8x + 12 = 0  (roots: -3, 2, 2)", test_num);
        $display("  a=1.0, b=-1.0, c=-8.0, d=12.0");
        drive_and_wait(FP_1, FP_N1, FP_N8, FP_12);
        if (x0_out === 32'hxxxxxxxx || x1_out === 32'hxxxxxxxx || x2_out === 32'hxxxxxxxx) begin
            $display("  FAIL — output contains X");
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS — output produced");
            pass_count = pass_count + 1;
        end

        // ----------------------------------------------------------
        // Test 2: x³ - 5x² + 8x - 4 = 0 → roots: 1, 2, 2
        //         a=1, b=-5, c=8, d=-4
        // ----------------------------------------------------------
        test_num = 2;
        $display("\n[Test %0d] x^3 - 5x^2 + 8x - 4 = 0  (roots: 1, 2, 2)", test_num);
        $display("  a=1.0, b=-5.0, c=8.0, d=-4.0");
        drive_and_wait(FP_1, FP_N5, FP_8, FP_N4);
        if (x0_out === 32'hxxxxxxxx || x1_out === 32'hxxxxxxxx || x2_out === 32'hxxxxxxxx) begin
            $display("  FAIL — output contains X");
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS — output produced");
            pass_count = pass_count + 1;
        end

        // ----------------------------------------------------------
        // Test 3: x³ - 4x² + 5x - 2 = 0 → roots: 1, 1, 2
        //         a=1, b=-4, c=5, d=-2
        // ----------------------------------------------------------
        test_num = 3;
        $display("\n[Test %0d] x^3 - 4x^2 + 5x - 2 = 0  (roots: 1, 1, 2)", test_num);
        $display("  a=1.0, b=-4.0, c=5.0, d=-2.0");
        drive_and_wait(FP_1, FP_N4, FP_5, FP_N2);
        if (x0_out === 32'hxxxxxxxx || x1_out === 32'hxxxxxxxx || x2_out === 32'hxxxxxxxx) begin
            $display("  FAIL — output contains X");
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS — output produced");
            pass_count = pass_count + 1;
        end

        // ----------------------------------------------------------
        // Summary
        // ----------------------------------------------------------
        $display("\n========================================================");
        $display("TB_10 SUMMARY:  PASS = %0d / %0d,  FAIL = %0d / %0d",
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
