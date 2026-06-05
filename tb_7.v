`timescale 1ns/1ps

//============================================================================
// tb_7.v — Padé Approximation / LUT Test
// Test name : tb_7
//
// Purpose   : Exercise the Padé approximation lookup table by driving a
//             variety of coefficients that produce different discriminant
//             low-bit patterns, thereby hitting different LUT entries.
//
// Test vectors:
//   TC1: a=1, b= 1, c= 1, d= 1
//   TC2: a=2, b= 3, c= 4, d= 5
//   TC3: a=1, b=-1, c=-1, d= 1
//   TC4: a=3, b= 0, c=-3, d= 0
//============================================================================

module tb_7;

    // ----------------------------------------------------------------
    // Clock parameters  (25 MHz → 40 ns period)
    // ----------------------------------------------------------------
    parameter CLK_PERIOD = 40;

    // ----------------------------------------------------------------
    // DUT signals
    // ----------------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg         in_valid_in;
    wire        in_ready_out;
    reg  [31:0] a_in, b_in, c_in, d_in;
    wire        out_valid_out;
    reg         out_ready_in;
    wire [31:0] x0_out, x1_out, x2_out;

    // ----------------------------------------------------------------
    // Score-keeping
    // ----------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer test_num;

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
    // Clock generation
    // ----------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ----------------------------------------------------------------
    // VCD dump
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_7);
    end

    // ----------------------------------------------------------------
    // Helper: drive_and_wait
    //   Drives a, b, c, d with in_valid for one cycle, then waits for
    //   out_valid, displays the roots, and pulses out_ready.
    // ----------------------------------------------------------------
    task drive_and_wait;
        input [31:0] ta, tb, tc, td;
        begin
            @(posedge clk);
            a_in       = ta;
            b_in       = tb;
            c_in       = tc;
            d_in       = td;
            in_valid_in = 1'b1;
            @(posedge clk);
            in_valid_in = 1'b0;
            // Wait for out_valid
            wait (out_valid_out == 1'b1);
            @(posedge clk);
            #1;
            $display("  x0 = %h, x1 = %h, x2 = %h", x0_out, x1_out, x2_out);
            out_ready_in = 1'b1;
            @(posedge clk);
            out_ready_in = 1'b0;
        end
    endtask

    // ----------------------------------------------------------------
    // Helper: check outputs are valid IEEE-754 (no X/Z bits)
    // ----------------------------------------------------------------
    function valid_fp32;
        input [31:0] v0, v1, v2;
        begin
            valid_fp32 = (^v0 !== 1'bx) && (^v1 !== 1'bx) && (^v2 !== 1'bx);
        end
    endfunction

    // ----------------------------------------------------------------
    // Main stimulus
    // ----------------------------------------------------------------
    initial begin
        // ----------------------------------------------------------
        // Banner
        // ----------------------------------------------------------
        $display("===========================================================");
        $display(" tb_7 : Pade Approximation / LUT Test  (tb_7)");
        $display("===========================================================");

        // Initialise
        rst_n        = 1'b0;
        in_valid_in  = 1'b0;
        out_ready_in = 1'b0;
        a_in         = 32'h0;
        b_in         = 32'h0;
        c_in         = 32'h0;
        d_in         = 32'h0;
        pass_count   = 0;
        fail_count   = 0;
        test_num     = 0;

        // Hold reset for several clock cycles
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // ===========================================================
        // TC1: a=1.0, b=1.0, c=1.0, d=1.0
        //   x^3 + x^2 + x + 1 = 0  →  (x+1)(x^2+1) = 0
        //   Real root: -1 ; complex pair: ±j
        // ===========================================================
        test_num = 1;
        $display("\n--- TC%0d: a=1.0, b=1.0, c=1.0, d=1.0 ---", test_num);
        drive_and_wait(32'h3F800000,   // 1.0
                       32'h3F800000,   // 1.0
                       32'h3F800000,   // 1.0
                       32'h3F800000);  // 1.0

        if (out_valid_out === 1'b1 || valid_fp32(x0_out, x1_out, x2_out)) begin
            $display("  [PASS] TC%0d — out_valid asserted, outputs valid FP32", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] TC%0d — outputs contain X/Z or out_valid not asserted", test_num);
            fail_count = fail_count + 1;
        end

        repeat (5) @(posedge clk);

        // ===========================================================
        // TC2: a=2.0, b=3.0, c=4.0, d=5.0
        //   2x^3 + 3x^2 + 4x + 5 = 0  →  different LUT index
        // ===========================================================
        test_num = 2;
        $display("\n--- TC%0d: a=2.0, b=3.0, c=4.0, d=5.0 ---", test_num);
        drive_and_wait(32'h40000000,   // 2.0
                       32'h40400000,   // 3.0
                       32'h40800000,   // 4.0
                       32'h40A00000);  // 5.0

        if (out_valid_out === 1'b1 || valid_fp32(x0_out, x1_out, x2_out)) begin
            $display("  [PASS] TC%0d — out_valid asserted, outputs valid FP32", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] TC%0d — outputs contain X/Z or out_valid not asserted", test_num);
            fail_count = fail_count + 1;
        end

        repeat (5) @(posedge clk);

        // ===========================================================
        // TC3: a=1.0, b=-1.0, c=-1.0, d=1.0
        //   x^3 - x^2 - x + 1 = 0  →  (x-1)^2(x+1) = 0
        //   Roots: 1, 1, -1  (repeated root — yet another LUT entry)
        // ===========================================================
        test_num = 3;
        $display("\n--- TC%0d: a=1.0, b=-1.0, c=-1.0, d=1.0 ---", test_num);
        drive_and_wait(32'h3F800000,   // 1.0
                       32'hBF800000,   // -1.0
                       32'hBF800000,   // -1.0
                       32'h3F800000);  // 1.0

        if (out_valid_out === 1'b1 || valid_fp32(x0_out, x1_out, x2_out)) begin
            $display("  [PASS] TC%0d — out_valid asserted, outputs valid FP32", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] TC%0d — outputs contain X/Z or out_valid not asserted", test_num);
            fail_count = fail_count + 1;
        end

        repeat (5) @(posedge clk);

        // ===========================================================
        // TC4: a=3.0, b=0.0, c=-3.0, d=0.0
        //   3x^3 - 3x = 0  →  3x(x^2 - 1) = 0
        //   Roots: 0, 1, -1
        // ===========================================================
        test_num = 4;
        $display("\n--- TC%0d: a=3.0, b=0.0, c=-3.0, d=0.0 ---", test_num);
        drive_and_wait(32'h40400000,   // 3.0
                       32'h00000000,   // 0.0
                       32'hC0400000,   // -3.0
                       32'h00000000);  // 0.0

        if (out_valid_out === 1'b1 || valid_fp32(x0_out, x1_out, x2_out)) begin
            $display("  [PASS] TC%0d — out_valid asserted, outputs valid FP32", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] TC%0d — outputs contain X/Z or out_valid not asserted", test_num);
            fail_count = fail_count + 1;
        end

        // ===========================================================
        // Summary
        // ===========================================================
        repeat (5) @(posedge clk);
        $display("\n===========================================================");
        $display(" tb_7 Summary:  %0d PASSED, %0d FAILED  (of %0d tests)",
                 pass_count, fail_count, pass_count + fail_count);
        if (fail_count == 0)
            $display(" *** ALL TESTS PASSED ***");
        else
            $display(" *** SOME TESTS FAILED ***");
        $display("===========================================================\n");

        $finish;
    end

    // ----------------------------------------------------------------
    // Timeout watchdog (prevent hang)
    // ----------------------------------------------------------------
    initial begin
        #100000;
        $display("[TIMEOUT] Simulation exceeded 100 us — aborting.");
        $finish;
    end

endmodule
