`timescale 1ns/1ps

//============================================================================
// tb_2.v — FP32 Subtraction Testbench
// Tests fp32_add with sub=1 (subtraction mode)
//============================================================================
module tb_2;

    // -----------------------------------------------------------------------
    // Signals
    // -----------------------------------------------------------------------
    reg  [31:0] a, b;
    reg         sub;
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
    fp32_add uut (
        .a      (a),
        .b      (b),
        .sub    (sub),
        .result (result)
    );

    // -----------------------------------------------------------------------
    // VCD dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_2.vcd");
        $dumpvars(0, tb_2);
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
    localparam FP_1p0    = 32'h3F800000;
    localparam FP_NEG1p0 = 32'hBF800000;
    localparam FP_2p0    = 32'h40000000;
    localparam FP_3p0    = 32'h40400000;
    localparam FP_NEG3p0 = 32'hC0400000;
    localparam FP_5p0    = 32'h40A00000;
    localparam FP_NEG5p0 = 32'hC0A00000;
    localparam FP_8p0    = 32'h41000000;
    localparam FP_NAN    = 32'h7FC00000;
    localparam FP_PINF   = 32'h7F800000;

    // -----------------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num   = 1;
        sub        = 1'b1; // Subtraction mode throughout

        $display("==========================================================");
        $display("  tb_2: FP32 Subtraction Tests (fp32_add, sub=1)");
        $display("==========================================================");

        // Test 1: 3.0 - 1.0 = 2.0
        @(posedge clk);
        a = FP_3p0; b = FP_1p0;
        #10;
        check(FP_2p0, "3.0 - 1.0 = 2.0");

        // Test 2: 1.0 - 1.0 = 0.0
        @(posedge clk);
        a = FP_1p0; b = FP_1p0;
        #10;
        check(FP_0p0, "1.0 - 1.0 = 0.0");

        // Test 3: 5.0 - 8.0 = -3.0
        @(posedge clk);
        a = FP_5p0; b = FP_8p0;
        #10;
        check(FP_NEG3p0, "5.0 - 8.0 = -3.0");

        // Test 4: -1.0 - (-3.0) = 2.0
        @(posedge clk);
        a = FP_NEG1p0; b = FP_NEG3p0;
        #10;
        check(FP_2p0, "-1.0 - (-3.0) = 2.0");

        // Test 5: 0.0 - 5.0 = -5.0
        @(posedge clk);
        a = FP_0p0; b = FP_5p0;
        #10;
        check(FP_NEG5p0, "0.0 - 5.0 = -5.0");

        // Test 6: NaN - 1.0 = NaN
        @(posedge clk);
        a = FP_NAN; b = FP_1p0;
        #10;
        check(FP_NAN, "NaN - 1.0 = NaN");

        // Test 7: +Inf - +Inf = NaN
        @(posedge clk);
        a = FP_PINF; b = FP_PINF;
        #10;
        check(FP_NAN, "+Inf - +Inf = NaN");

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
