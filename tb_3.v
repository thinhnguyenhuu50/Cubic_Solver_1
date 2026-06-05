`timescale 1ns/1ps

//============================================================================
// tb_3.v — FP32 Multiplication Testbench
// Tests fp32_mul (combinational)
//============================================================================
module tb_3;

    // -----------------------------------------------------------------------
    // Signals
    // -----------------------------------------------------------------------
    reg  [31:0] a, b;
    wire [31:0] result;

    // Clock for sequencing
    reg clk;
    initial clk = 0;
    always #20 clk = ~clk; // 40ns period, 25 MHz

    // Counters
    integer pass_count, fail_count, test_num;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    fp32_mul uut (
        .a      (a),
        .b      (b),
        .result (result)
    );

    // -----------------------------------------------------------------------
    // VCD dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_3.vcd");
        $dumpvars(0, tb_3);
    end

    // -----------------------------------------------------------------------
    // Tolerance check: exact match OR <=1 ULP difference
    // -----------------------------------------------------------------------
    function pass_check;
        input [31:0] actual, expected;
        reg [22:0] a_frac, e_frac;
        reg [31:0] diff;
        begin
            if (actual === expected) pass_check = 1;
            else if (actual[31] == expected[31] && actual[30:23] == expected[30:23]) begin
                a_frac = actual[22:0];
                e_frac = expected[22:0];
                diff = (a_frac > e_frac) ? (a_frac - e_frac) : (e_frac - a_frac);
                pass_check = (diff <= 1);
            end
            else pass_check = 0;
        end
    endfunction

    // -----------------------------------------------------------------------
    // Check task
    // -----------------------------------------------------------------------
    task check;
        input [31:0] expected;
        input [8*64-1:0] desc;
        begin
            if (pass_check(result, expected)) begin
                $display("  [PASS] Test %0d: %0s | result=%h expected=%h", test_num, desc, result, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Test %0d: %0s | result=%h expected=%h", test_num, desc, result, expected);
                fail_count = fail_count + 1;
            end
            test_num = test_num + 1;
        end
    endtask

    // -----------------------------------------------------------------------
    // FP32 constants
    // -----------------------------------------------------------------------
    localparam FP_0p0    = 32'h00000000;
    localparam FP_0p25   = 32'h3E800000;
    localparam FP_0p5    = 32'h3F000000;
    localparam FP_1p0    = 32'h3F800000;
    localparam FP_NEG1p0 = 32'hBF800000;
    localparam FP_2p0    = 32'h40000000;
    localparam FP_NEG2p0 = 32'hC0000000;
    localparam FP_3p0    = 32'h40400000;
    localparam FP_NEG3p0 = 32'hC0400000;
    localparam FP_4p0    = 32'h40800000;
    localparam FP_5p0    = 32'h40A00000;
    localparam FP_NEG5p0 = 32'hC0A00000;
    localparam FP_6p0    = 32'h40C00000;
    localparam FP_NAN    = 32'h7FC00000;
    localparam FP_PINF   = 32'h7F800000;

    // -----------------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num   = 1;

        $display("==========================================================");
        $display("  tb_3: FP32 Multiplication Tests (fp32_mul)");
        $display("==========================================================");

        // Test 1: 2.0 * 3.0 = 6.0
        @(posedge clk);
        a = FP_2p0; b = FP_3p0;
        #10;
        check(FP_6p0, "2.0 * 3.0 = 6.0");

        // Test 2: -1.0 * 5.0 = -5.0
        @(posedge clk);
        a = FP_NEG1p0; b = FP_5p0;
        #10;
        check(FP_NEG5p0, "-1.0 * 5.0 = -5.0");

        // Test 3: 0.5 * 0.5 = 0.25
        @(posedge clk);
        a = FP_0p5; b = FP_0p5;
        #10;
        check(FP_0p25, "0.5 * 0.5 = 0.25");

        // Test 4: 4.0 * 0.0 = 0.0
        @(posedge clk);
        a = FP_4p0; b = FP_0p0;
        #10;
        check(FP_0p0, "4.0 * 0.0 = 0.0");

        // Test 5: 1.0 * 1.0 = 1.0
        @(posedge clk);
        a = FP_1p0; b = FP_1p0;
        #10;
        check(FP_1p0, "1.0 * 1.0 = 1.0");

        // Test 6: -3.0 * -2.0 = 6.0
        @(posedge clk);
        a = FP_NEG3p0; b = FP_NEG2p0;
        #10;
        check(FP_6p0, "-3.0 * -2.0 = 6.0");

        // Test 7: NaN * 2.0 = NaN
        @(posedge clk);
        a = FP_NAN; b = FP_2p0;
        #10;
        check(FP_NAN, "NaN * 2.0 = NaN");

        // Test 8: +Inf * 0.0 = NaN
        @(posedge clk);
        a = FP_PINF; b = FP_0p0;
        #10;
        check(FP_NAN, "+Inf * 0.0 = NaN");

        // Test 9: +Inf * 2.0 = +Inf
        @(posedge clk);
        a = FP_PINF; b = FP_2p0;
        #10;
        check(FP_PINF, "+Inf * 2.0 = +Inf");

        // ----- Summary -----
        $display("==========================================================");
        $display("  Summary: %0d PASSED, %0d FAILED out of %0d tests",
                 pass_count, fail_count, pass_count + fail_count);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");
        $display("==========================================================");

        $finish;
    end

endmodule
