`timescale 1ns/1ps

//-------------------------------------------------------------
// tb_13: Negative Coefficients
// Test name: tb_13
// Tests equations with all-negative or mixed-sign large coefficients.
//-------------------------------------------------------------
module tb_13;

    // Clock period
    localparam CLK_PERIOD = 40;

    // IEEE 754 constants
    localparam [31:0] FP_ONE     = 32'h3F800000; //  1.0
    localparam [31:0] FP_NEG_ONE = 32'hBF800000; // -1.0
    localparam [31:0] FP_TWO     = 32'h40000000; //  2.0
    localparam [31:0] FP_NEG_TWO = 32'hC0000000; // -2.0
    localparam [31:0] FP_FOUR    = 32'h40800000; //  4.0
    localparam [31:0] FP_SIX     = 32'h40C00000; //  6.0
    localparam [31:0] FP_NEG_SIX = 32'hC0C00000; // -6.0
    localparam [31:0] FP_EIGHT   = 32'h41000000; //  8.0
    localparam [31:0] FP_NEG_EIGHT= 32'hC1000000;// -8.0
    localparam [31:0] FP_ELEVEN  = 32'h41300000; // 11.0
    localparam [31:0] FP_NEG_ELEVEN = 32'hC1300000; // -11.0
    localparam [31:0] FP_TWELVE  = 32'h41400000; // 12.0

    // DUT signals
    reg clk, rst_n;
    reg in_valid_in, out_ready_in;
    reg [31:0] a_in, b_in, c_in, d_in;
    wire in_ready_out, out_valid_out;
    wire [31:0] x0_out, x1_out, x2_out;

    // Counters
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num   = 0;

    // DUT instantiation
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

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // VCD dump
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_13);
    end

    // Timeout watchdog
    initial begin
        #1000000;
        $display("ERROR: Simulation timed out!");
        $finish;
    end

    // Valid FP32 check function
    function valid_fp32;
        input [31:0] val;
        begin
            valid_fp32 = (val !== 32'hxxxxxxxx) && (val !== 32'hzzzzzzzz);
        end
    endfunction

    // Drive and wait task
    task drive_and_wait;
        input [31:0] ta, tb, tc, td;
        begin
            @(posedge clk);
            a_in = ta; b_in = tb; c_in = tc; d_in = td;
            in_valid_in = 1'b1;
            @(posedge clk);
            in_valid_in = 1'b0;
            wait(out_valid_out == 1'b1);
            @(posedge clk);
            #1;
            $display("  x0 = %h, x1 = %h, x2 = %h", x0_out, x1_out, x2_out);
            out_ready_in = 1'b1;
            @(posedge clk);
            out_ready_in = 1'b0;
        end
    endtask

    // Check valid outputs task
    task check_valid;
        begin
            test_num = test_num + 1;
            if (valid_fp32(x0_out) && valid_fp32(x1_out) && valid_fp32(x2_out)) begin
                $display("  [PASS] Test %0d: Outputs are valid FP32 values", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Test %0d: One or more outputs are X/Z", test_num);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Main test sequence
    initial begin
        // Initialize
        rst_n = 1'b0;
        in_valid_in = 1'b0;
        out_ready_in = 1'b0;
        a_in = 32'd0; b_in = 32'd0; c_in = 32'd0; d_in = 32'd0;

        // Reset
        #100;
        rst_n = 1'b1;
        #(CLK_PERIOD * 2);

        $display("============================================================");
        $display("  TB_13: Negative Coefficients Test");
        $display("============================================================");

        // TC1: a=-1, b=6, c=-11, d=6 (negated a version of 1,-6,11,-6)
        $display("\n--- TC1: a=-1, b=6, c=-11, d=6 ---");
        drive_and_wait(FP_NEG_ONE, FP_SIX, FP_NEG_ELEVEN, FP_SIX);
        check_valid;

        // TC2: a=1, b=-1, c=-8, d=12
        $display("\n--- TC2: a=1, b=-1, c=-8, d=12 ---");
        drive_and_wait(FP_ONE, FP_NEG_ONE, FP_NEG_EIGHT, FP_TWELVE);
        check_valid;

        // TC3: a=-2, b=4, c=6, d=-8
        $display("\n--- TC3: a=-2, b=4, c=6, d=-8 ---");
        drive_and_wait(FP_NEG_TWO, FP_FOUR, FP_SIX, FP_NEG_EIGHT);
        check_valid;

        // Summary
        $display("\n============================================================");
        $display("  TB_13 SUMMARY: %0d PASSED, %0d FAILED out of %0d tests", pass_count, fail_count, test_num);
        $display("============================================================");

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
