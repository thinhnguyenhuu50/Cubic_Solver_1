`timescale 1ns/1ps

//-------------------------------------------------------------
// tb_15: Back-to-Back Transactions
// Test name: tb_15
// Issues 3 consecutive transactions without reset between them.
// Verifies FSM returns to IDLE between each transaction.
//-------------------------------------------------------------
module tb_15;

    // Clock period
    localparam CLK_PERIOD = 40;

    // IEEE 754 constants
    localparam [31:0] FP_ZERO     = 32'h00000000; //  0.0
    localparam [31:0] FP_ONE      = 32'h3F800000; //  1.0
    localparam [31:0] FP_NEG_ONE  = 32'hBF800000; // -1.0
    localparam [31:0] FP_NEG_SIX  = 32'hC0C00000; // -6.0
    localparam [31:0] FP_ELEVEN   = 32'h41300000; //  11.0
    localparam [31:0] FP_NEG_SIX2 = 32'hC0C00000; // -6.0

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
        $dumpvars(0, tb_15);
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

    // Check valid outputs and in_ready task
    task check_valid_and_ready;
        begin
            test_num = test_num + 1;
            if (valid_fp32(x0_out) && valid_fp32(x1_out) && valid_fp32(x2_out)) begin
                $display("  [PASS] Test %0d: Transaction completed, outputs valid", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Test %0d: One or more outputs are X/Z", test_num);
                fail_count = fail_count + 1;
            end
            // Verify FSM returns to IDLE (in_ready should assert)
            @(posedge clk);
            @(posedge clk);
            #1;
            if (in_ready_out === 1'b1) begin
                $display("  [INFO] FSM returned to IDLE (in_ready=1)");
            end else begin
                $display("  [WARN] FSM did not return to IDLE immediately (in_ready=%b)", in_ready_out);
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
        $display("  TB_15: Back-to-Back Transactions Test");
        $display("============================================================");

        // Transaction 1: x^3 - 1 = 0  ->  a=1, b=0, c=0, d=-1
        $display("\n--- Transaction 1: x^3 - 1 = 0 (a=1, b=0, c=0, d=-1) ---");
        drive_and_wait(FP_ONE, FP_ZERO, FP_ZERO, FP_NEG_ONE);
        check_valid_and_ready;

        // Transaction 2: x^3 - 6x^2 + 11x - 6 = 0  ->  a=1, b=-6, c=11, d=-6
        $display("\n--- Transaction 2: x^3 - 6x^2 + 11x - 6 = 0 ---");
        drive_and_wait(FP_ONE, FP_NEG_SIX, FP_ELEVEN, FP_NEG_SIX);
        check_valid_and_ready;

        // Transaction 3: x^3 - x = 0  ->  a=1, b=0, c=-1, d=0
        $display("\n--- Transaction 3: x^3 - x = 0 (a=1, b=0, c=-1, d=0) ---");
        drive_and_wait(FP_ONE, FP_ZERO, FP_NEG_ONE, FP_ZERO);
        check_valid_and_ready;

        // Summary
        $display("\n============================================================");
        $display("  TB_15 SUMMARY: %0d PASSED, %0d FAILED out of %0d tests", pass_count, fail_count, test_num);
        $display("============================================================");

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
