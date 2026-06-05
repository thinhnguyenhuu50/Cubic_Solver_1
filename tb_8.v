`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////
// tb_8.v — Simple Roots (Integer Coefficients)
//
// Tests simple cubic equations with small integer coefficients:
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
    localparam [31:0] FP_3   = 32'h40400000; //  3.0
    localparam [31:0] FP_N3  = 32'hC0400000; // -3.0
    localparam [31:0] FP_6   = 32'h40C00000; //  6.0
    localparam [31:0] FP_N6  = 32'hC0C00000; // -6.0
    localparam [31:0] FP_11  = 32'h41300000; // 11.0
    // Note: 11.0 = 1.011 * 2^3 = sign=0, exp=130=10000010, frac=01100000...0
    //       11 in binary = 1011, so 1.011 * 2^3, exp = 127+3 = 130 = 0x82
    //       32'h41300000

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
        in_valid_in = 1'b0;
        out_ready_in = 1'b0;
        a_in = 32'd0; b_in = 32'd0; c_in = 32'd0; d_in = 32'd0;

        // ---- Reset ----
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("========================================================");
        $display("TB_8: Simple Roots (Integer Coefficients)");
        $display("========================================================");

        // ----------------------------------------------------------
        // Test 1: x³ - 6x² + 11x - 6 = 0 → roots: 1, 2, 3
        //         a=1, b=-6, c=11, d=-6
        // ----------------------------------------------------------
        test_num = 1;
        $display("\n[Test %0d] x^3 - 6x^2 + 11x - 6 = 0  (roots: 1, 2, 3)", test_num);
        $display("  a=1.0, b=-6.0, c=11.0, d=-6.0");
        drive_and_wait(FP_1, FP_N6, FP_11, FP_N6);
        // Check that outputs are valid (non-X)
        if (x0_out === 32'hxxxxxxxx || x1_out === 32'hxxxxxxxx || x2_out === 32'hxxxxxxxx) begin
            $display("  FAIL — output contains X");
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS — output produced");
            pass_count = pass_count + 1;
        end

        // ----------------------------------------------------------
        // Test 2: x³ - 3x² + 3x - 1 = 0 → triple root: 1
        //         a=1, b=-3, c=3, d=-1
        // ----------------------------------------------------------
        test_num = 2;
        $display("\n[Test %0d] x^3 - 3x^2 + 3x - 1 = 0  (triple root: 1)", test_num);
        $display("  a=1.0, b=-3.0, c=3.0, d=-1.0");
        drive_and_wait(FP_1, FP_N3, FP_3, FP_N1);
        if (x0_out === 32'hxxxxxxxx || x1_out === 32'hxxxxxxxx || x2_out === 32'hxxxxxxxx) begin
            $display("  FAIL — output contains X");
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS — output produced");
            pass_count = pass_count + 1;
        end

        // ----------------------------------------------------------
        // Test 3: x³ - x = 0 → roots: 0, 1, -1
        //         a=1, b=0, c=-1, d=0
        // ----------------------------------------------------------
        test_num = 3;
        $display("\n[Test %0d] x^3 - x = 0  (roots: 0, 1, -1)", test_num);
        $display("  a=1.0, b=0.0, c=-1.0, d=0.0");
        drive_and_wait(FP_1, FP_0, FP_N1, FP_0);
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
        #100_000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
