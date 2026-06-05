`timescale 1ns/1ps

//============================================================================
// Testbench: tb_3
// Purpose : Exercise the FP32 multiplication path inside cubic_solver.
//           The depressed-cubic transformation and Cardano's formula
//           involve products such as b^2, 3a^2, b*c, a*d, etc.
//           We choose larger coefficient values so that mantissa
//           multiplication is heavily exercised.
//============================================================================

module tb_3;

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
        $dumpvars(0, tb_3);
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
        $display(" tb_3 — FP32 Multiplication Path Tests");
        $display("==========================================================");

        // ----------------------------------------------------------
        // Test Vector 1:  2x^3 + 4x^2 + 6x + 8 = 0
        //   a=2.0, b=4.0, c=6.0, d=8.0
        //   Normalised: x^3 + 2x^2 + 3x + 4
        //   Multiplications: b^2=16, 3a^2=12, b*c=24, a*d=16
        //   Large intermediate products stress the multiplier.
        // ----------------------------------------------------------
        $display("----------------------------------------------------------");
        $display(" Test 1: a=2.0, b=4.0, c=6.0, d=8.0");
        $display("----------------------------------------------------------");
        drive_and_wait(32'h40000000, 32'h40800000, 32'h40C00000, 32'h41000000);
        check_outputs("Test1");

        // ----------------------------------------------------------
        // Test Vector 2:  4x^3 + 8x^2 + 4x + 8 = 0
        //   a=4.0, b=8.0, c=4.0, d=8.0
        //   Normalised: x^3 + 2x^2 + x + 2 = (x+2)(x^2+1)
        //   b^2=64, 3a^2=48, b*c=32 — multiplications with powers of 2.
        //   Real root: x = -2
        // ----------------------------------------------------------
        $display("----------------------------------------------------------");
        $display(" Test 2: a=4.0, b=8.0, c=4.0, d=8.0");
        $display("----------------------------------------------------------");
        drive_and_wait(32'h40800000, 32'h41000000, 32'h40800000, 32'h41000000);
        check_outputs("Test2");

        // ----------------------------------------------------------
        // Test Vector 3:  3x^3 + 12x^2 + 12x + 3 = 0
        //   a=3.0, b=12.0, c=12.0, d=3.0
        //   Normalised: x^3 + 4x^2 + 4x + 1
        //   b^2=144, 3a^2=27, b*c=144 — large products exercise
        //   the 24-bit mantissa multiplier fully.
        // ----------------------------------------------------------
        $display("----------------------------------------------------------");
        $display(" Test 3: a=3.0, b=12.0, c=12.0, d=3.0");
        $display("----------------------------------------------------------");
        drive_and_wait(32'h40400000, 32'h41400000, 32'h41400000, 32'h40400000);
        check_outputs("Test3");

        // ----------------------------------------------------------
        // Summary
        // ----------------------------------------------------------
        $display("==========================================================");
        $display(" FP32 Multiplication Test Summary: %0d PASSED, %0d FAILED",
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
