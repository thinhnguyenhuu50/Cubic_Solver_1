`timescale 1ns/1ps

//============================================================================
// Testbench: tb_1
// Purpose : Exercise the FP32 addition path inside cubic_solver.
//           The depressed-cubic transformation computes
//               p = c/a - b^2/(3a^2)
//           which requires additions internally.
//           We choose positive integer-valued coefficients so the adder
//           is exercised with straightforward mantissa alignment cases.
//============================================================================

module tb_1;

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
        $dumpvars(0, tb_1);
    end

    // ---------------------------------------------------------------
    // Score keeping
    // ---------------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // ---------------------------------------------------------------
    // Helper: drive_and_wait
    // Drives a, b, c, d with in_valid for one cycle, then waits for
    // out_valid before capturing outputs.
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
        input [255:0] test_label; // 32-char label packed
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
        $display(" tb_1 — FP32 Addition Path Tests");
        $display("==========================================================");

        // ----------------------------------------------------------
        // Test Vector 1:  x^3 + 3x^2 + 3x + 1 = 0   =>  (x+1)^3 = 0
        //   a=1.0, b=3.0, c=3.0, d=1.0
        //   p = 3/1 - 9/3 = 3 - 3 = 0  (addition of 3 + (-3))
        //   Root: x = -1
        // ----------------------------------------------------------
        $display("----------------------------------------------------------");
        $display(" Test 1: a=1.0, b=3.0, c=3.0, d=1.0  => (x+1)^3");
        $display("----------------------------------------------------------");
        drive_and_wait(32'h3F800000, 32'h40400000, 32'h40400000, 32'h3F800000);
        check_outputs("Test1");

        // ----------------------------------------------------------
        // Test Vector 2:  x^3 + 6x^2 + 12x + 8 = 0  =>  (x+2)^3 = 0
        //   a=1.0, b=6.0, c=12.0, d=8.0
        //   p = 12/1 - 36/3 = 12 - 12 = 0  (addition path exercised)
        //   Root: x = -2
        // ----------------------------------------------------------
        $display("----------------------------------------------------------");
        $display(" Test 2: a=1.0, b=6.0, c=12.0, d=8.0  => (x+2)^3");
        $display("----------------------------------------------------------");
        drive_and_wait(32'h3F800000, 32'h40C00000, 32'h41400000, 32'h41000000);
        check_outputs("Test2");

        // ----------------------------------------------------------
        // Test Vector 3:  2x^3 + 6x^2 + 6x + 2 = 0  =>  2(x+1)^3 = 0
        //   a=2.0, b=6.0, c=6.0, d=2.0
        //   After normalisation by a=2:  x^3 + 3x^2 + 3x + 1
        //   p = 3 - 3 = 0  (addition of normalised terms)
        //   Root: x = -1
        // ----------------------------------------------------------
        $display("----------------------------------------------------------");
        $display(" Test 3: a=2.0, b=6.0, c=6.0, d=2.0  => 2(x+1)^3");
        $display("----------------------------------------------------------");
        drive_and_wait(32'h40000000, 32'h40C00000, 32'h40C00000, 32'h40000000);
        check_outputs("Test3");

        // ----------------------------------------------------------
        // Summary
        // ----------------------------------------------------------
        $display("==========================================================");
        $display(" FP32 Addition Test Summary: %0d PASSED, %0d FAILED",
                 pass_count, fail_count);
        $display("==========================================================");

        #200;
        $finish;
    end

    // ---------------------------------------------------------------
    // Timeout watchdog — prevent infinite hangs
    // ---------------------------------------------------------------
    initial begin
        #1_000_000;
        $display("[TIMEOUT] Simulation exceeded 1 ms — aborting.");
        $finish;
    end

endmodule
