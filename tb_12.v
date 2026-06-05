`timescale 1ns/1ps

//-------------------------------------------------------------
// tb_12: Invalid Input (a=0)
// Test name: tb_12
// Verifies that when a=0 the module outputs all NaN.
//-------------------------------------------------------------
module tb_12;

    // Clock period
    localparam CLK_PERIOD = 40;

    // IEEE 754 constants
    localparam [31:0] FP_ZERO = 32'h00000000; // 0.0
    localparam [31:0] FP_ONE  = 32'h3F800000; // 1.0
    localparam [31:0] FP_TWO  = 32'h40000000; // 2.0
    localparam [31:0] FP_THREE= 32'h40400000; // 3.0
    localparam [31:0] FP_NAN  = 32'h7FC00000; // NaN

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
        $dumpvars(0, tb_12);
    end

    // Timeout watchdog
    initial begin
        #1000000;
        $display("ERROR: Simulation timed out!");
        $finish;
    end

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

    // Check NaN task
    task check_all_nan;
        begin
            test_num = test_num + 1;
            if (x0_out === FP_NAN && x1_out === FP_NAN && x2_out === FP_NAN) begin
                $display("  [PASS] Test %0d: All outputs are NaN as expected", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Test %0d: Expected all NaN, got x0=%h x1=%h x2=%h", test_num, x0_out, x1_out, x2_out);
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
        $display("  TB_12: Invalid Input (a=0) Test");
        $display("============================================================");

        // TC1: a=0, b=1, c=2, d=3
        $display("\n--- TC1: a=0, b=1, c=2, d=3 ---");
        drive_and_wait(FP_ZERO, FP_ONE, FP_TWO, FP_THREE);
        check_all_nan;

        // TC2: a=0, b=0, c=1, d=1
        $display("\n--- TC2: a=0, b=0, c=1, d=1 ---");
        drive_and_wait(FP_ZERO, FP_ZERO, FP_ONE, FP_ONE);
        check_all_nan;

        // TC3: a=0, b=0, c=0, d=0
        $display("\n--- TC3: a=0, b=0, c=0, d=0 ---");
        drive_and_wait(FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO);
        check_all_nan;

        // Summary
        $display("\n============================================================");
        $display("  TB_12 SUMMARY: %0d PASSED, %0d FAILED out of %0d tests", pass_count, fail_count, test_num);
        $display("============================================================");

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
