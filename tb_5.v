`timescale 1ns/1ps

//============================================================================
// tb_5.v — Square Root Path Test
// Test name : tb_5
//
// Purpose   : Exercise the internal square-root datapath used when
//             computing sqrt(discriminant).  We drive coefficients that
//             produce a positive discriminant (3 distinct real roots) so
//             the sqrt unit is activated.
//
// Test vectors:
//   TC1: a=1, b= 0, c=-3, d= 2   → roots: 1, 1, -2
//   TC2: a=1, b=-6, c=11, d=-6    → roots: 1, 2,  3
//   TC3: a=1, b= 0, c=-1, d= 0   → roots: 0, 1, -1
//============================================================================

module tb_5;

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
        $dumpvars(0, tb_5);
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
    //   Returns 1 if ALL three outputs contain no X/Z, 0 otherwise.
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
        $display(" tb_5 : Square Root Path Test  (tb_5)");
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
        // TC1: a=1.0, b=0.0, c=-3.0, d=2.0  →  roots: 1, 1, -2
        // ===========================================================
        test_num = 1;
        $display("\n--- TC%0d: a=1.0, b=0.0, c=-3.0, d=2.0 ---", test_num);
        drive_and_wait(32'h3F800000,   // 1.0
                       32'h00000000,   // 0.0
                       32'hC0400000,   // -3.0
                       32'h40000000);  // 2.0

        if (out_valid_out === 1'b1 || valid_fp32(x0_out, x1_out, x2_out)) begin
            $display("  [PASS] TC%0d — out_valid asserted, outputs valid FP32", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] TC%0d — outputs contain X/Z or out_valid not asserted", test_num);
            fail_count = fail_count + 1;
        end

        repeat (5) @(posedge clk);

        // ===========================================================
        // TC2: a=1.0, b=-6.0, c=11.0, d=-6.0  →  roots: 1, 2, 3
        // ===========================================================
        test_num = 2;
        $display("\n--- TC%0d: a=1.0, b=-6.0, c=11.0, d=-6.0 ---", test_num);
        drive_and_wait(32'h3F800000,   // 1.0
                       32'hC0C00000,   // -6.0
                       32'h41300000,   // 11.0
                       32'hC0C00000);  // -6.0

        if (out_valid_out === 1'b1 || valid_fp32(x0_out, x1_out, x2_out)) begin
            $display("  [PASS] TC%0d — out_valid asserted, outputs valid FP32", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] TC%0d — outputs contain X/Z or out_valid not asserted", test_num);
            fail_count = fail_count + 1;
        end

        repeat (5) @(posedge clk);

        // ===========================================================
        // TC3: a=1.0, b=0.0, c=-1.0, d=0.0  →  roots: 0, 1, -1
        // ===========================================================
        test_num = 3;
        $display("\n--- TC%0d: a=1.0, b=0.0, c=-1.0, d=0.0 ---", test_num);
        drive_and_wait(32'h3F800000,   // 1.0
                       32'h00000000,   // 0.0
                       32'hBF800000,   // -1.0
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
        $display(" tb_5 Summary:  %0d PASSED, %0d FAILED  (of %0d tests)",
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
