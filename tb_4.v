`timescale 1ns/1ps

//============================================================================
// Testbench: tb_4
// Purpose : Exercise the FP32 division path inside cubic_solver.
//           The first step of solving a general cubic  ax^3+bx^2+cx+d = 0
//           is to normalise by dividing every coefficient by a, yielding
//               x^3 + (b/a)x^2 + (c/a)x + (d/a) = 0
//           We use non-unity values of a (3, 5, 7) so the FP32 divider
//           is exercised with non-trivial divisors.
//============================================================================

module tb_4;

    // ---------------------------------------------------------------
    // Clock & reset
    // ---------------------------------------------------------------
    reg         clk;
    reg         rst_n;

    // DUT interface signals
    reg         in_valid_in;
    reg         out_ready_in;
    reg  [31:0] a_in, b_in, c_in, d_in;

    wire        in_ready_out;
    wire        out_valid_out;
    wire [31:0] x0_out, x1_out, x2_out;

    // ---------------------------------------------------------------
    // DUT instantiation
    // ---------------------------------------------------------------
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

    // ---------------------------------------------------------------
    // Clock generation — 40 ns period (25 MHz)
    // ---------------------------------------------------------------
    initial clk = 0;
    always #20 clk = ~clk;

    // ---------------------------------------------------------------
    // VCD dump
    // ---------------------------------------------------------------
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_4);
    end

    // ---------------------------------------------------------------
    // Score keeping
    // ---------------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // ---------------------------------------------------------------
    // Helper: drive_and_wait
    // ---------------------------------------------------------------
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

    // ---------------------------------------------------------------
    // Helper: check outputs are not X/Z
    // ---------------------------------------------------------------
    task check_outputs;
        input [255:0] test_label;
        begin
            if (out_valid_out !== 1'b1) begin
                $display("  [FAIL] out_valid did not assert.");
                fail_count = fail_count + 1;
            end else if (^x0_out === 1'bx || ^x1_out === 1'bx || ^x2_out === 1'bx) begin
                $display("  [FAIL] One or more outputs contain X/Z.");
                fail_count = fail_count + 1;
            end else begin
                $display("  [PASS]");
                pass_count = pass_count + 1;
            end
        end
    endtask

    // ---------------------------------------------------------------
    // Main stimulus
    // ---------------------------------------------------------------
    initial begin
        // Initialise
        in_valid_in  = 1'b0;
        out_ready_in = 1'b0;
        a_in         = 32'h0;
        b_in         = 32'h0;
        c_in         = 32'h0;
        d_in         = 32'h0;
        pass_count   = 0;
        fail_count   = 0;

        // Reset sequence — hold rst_n low for 100 ns
        rst_n = 1'b0;
        #100;
        rst_n = 1'b1;
        @(posedge clk);

        $display("==========================================================");
        $display(" tb_4 — FP32 Division Path Tests");
        $display("==========================================================");

        // ----------------------------------------------------------
        // Test Vector 1:  3x^3 - 3x^2 - 3x + 3 = 0
        //   a=3.0  (40400000)
        //   b=-3.0 (C0400000)
        //   c=-3.0 (C0400000)
        //   d=3.0  (40400000)
        //   Division by 3:  b/a=-1, c/a=-1, d/a=1
        //   Normalised: x^3 - x^2 - x + 1 = (x-1)^2(x+1)
        //   Roots: x = 1, 1, -1
        // ----------------------------------------------------------
        $display("----------------------------------------------------------");
        $display(" Test 1: a=3.0, b=-3.0, c=-3.0, d=3.0  (div by 3)");
        $display("----------------------------------------------------------");
        drive_and_wait(32'h40400000, 32'hC0400000, 32'hC0400000, 32'h40400000);
        check_outputs("Test1");

        // ----------------------------------------------------------
        // Test Vector 2:  5x^3 + 5x^2 - 5x - 5 = 0
        //   a=5.0  (40A00000)
        //   b=5.0  (40A00000)
        //   c=-5.0 (C0A00000)
        //   d=-5.0 (C0A00000)
        //   Division by 5:  b/a=1, c/a=-1, d/a=-1
        //   Normalised: x^3 + x^2 - x - 1 = (x-1)(x+1)^2
        //   Roots: x = 1, -1, -1
        // ----------------------------------------------------------
        $display("----------------------------------------------------------");
        $display(" Test 2: a=5.0, b=5.0, c=-5.0, d=-5.0  (div by 5)");
        $display("----------------------------------------------------------");
        drive_and_wait(32'h40A00000, 32'h40A00000, 32'hC0A00000, 32'hC0A00000);
        check_outputs("Test2");

        // ----------------------------------------------------------
        // Test Vector 3:  7x^3 - 7x = 0  =>  7x(x^2-1) = 0
        //   a=7.0  (40E00000)
        //   b=0.0  (00000000)
        //   c=-7.0 (C0E00000)
        //   d=0.0  (00000000)
        //   Division by 7:  b/a=0, c/a=-1, d/a=0
        //   Normalised: x^3 - x = x(x-1)(x+1)
        //   Roots: x = 0, 1, -1
        // ----------------------------------------------------------
        $display("----------------------------------------------------------");
        $display(" Test 3: a=7.0, b=0.0, c=-7.0, d=0.0  (div by 7)");
        $display("----------------------------------------------------------");
        drive_and_wait(32'h40E00000, 32'h00000000, 32'hC0E00000, 32'h00000000);
        check_outputs("Test3");

        // ----------------------------------------------------------
        // Summary
        // ----------------------------------------------------------
        $display("==========================================================");
        $display(" FP32 Division Test Summary: %0d PASSED, %0d FAILED",
                 pass_count, fail_count);
        $display("==========================================================");

        #200;
        $finish;
    end

    // ---------------------------------------------------------------
    // Timeout watchdog
    // ---------------------------------------------------------------
    initial begin
        #1_000_000;
        $display("[TIMEOUT] Simulation exceeded 1 ms — aborting.");
        $finish;
    end

endmodule
