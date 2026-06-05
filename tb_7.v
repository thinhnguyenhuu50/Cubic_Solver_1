`timescale 1ns/1ps

//////////////////////////////////////////////////////////////////////////////
// tb_7.v — Padé LUT ROM Readout testbench
// Reads ALL 32 entries for sel=0 (log2 table) and sel=1 (exp2 table).
// Verifies key entries with exact-match comparison.
//////////////////////////////////////////////////////////////////////////////

module tb_7;

    // -----------------------------------------------------------------------
    // Clock generation (40ns period, 25 MHz — kept for consistency)
    // -----------------------------------------------------------------------
    reg clk;
    initial clk = 0;
    always #20 clk = ~clk;

    // -----------------------------------------------------------------------
    // DUT signals — pade_lut
    // -----------------------------------------------------------------------
    reg  [4:0]  addr;
    reg         sel;
    wire [31:0] data;

    pade_lut u_lut (
        .addr (addr),
        .sel  (sel),
        .data (data)
    );

    // -----------------------------------------------------------------------
    // Pass / fail counters
    // -----------------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer i;

    // -----------------------------------------------------------------------
    // Expected values for key entries
    // sel=0 (log2 table)
    // -----------------------------------------------------------------------
    localparam LOG2_ADDR0  = 32'h00000000; // log2(1.0)     = 0.0
    localparam LOG2_ADDR4  = 32'h3E2B8034; // log2(1.125)   ≈ 0.1699 (spot-check)
    localparam LOG2_ADDR8  = 32'h3EA4D3C2; // log2(1.25)    = 0.3219
    localparam LOG2_ADDR12 = 32'h3EF738D3; // log2(1.375)   ≈ 0.4594 (spot-check)
    localparam LOG2_ADDR16 = 32'h3F15C01A; // log2(1.5)     = 0.5850
    localparam LOG2_ADDR20 = 32'h3F3B9476; // log2(1.625)   ≈ 0.7004 (spot-check)
    localparam LOG2_ADDR24 = 32'h3F5B2C3E; // log2(1.75)    ≈ 0.8074 (spot-check)
    localparam LOG2_ADDR31 = 32'h3F7A2F04; // log2(1.96875) = 0.9773

    // -----------------------------------------------------------------------
    // Expected values for key entries
    // sel=1 (exp2 table)
    // -----------------------------------------------------------------------
    localparam EXP2_ADDR0  = 32'h3F800000; // 2^0       = 1.0
    localparam EXP2_ADDR4  = 32'h3F8B95C2; // 2^0.125   ≈ 1.0905 (spot-check)
    localparam EXP2_ADDR8  = 32'h3F9837F0; // 2^0.25    = 1.1892
    localparam EXP2_ADDR12 = 32'h3FA5FED7; // 2^0.375   ≈ 1.2968 (spot-check)
    localparam EXP2_ADDR16 = 32'h3FB504F3; // 2^0.5     = 1.4142
    localparam EXP2_ADDR20 = 32'h3FC5672A; // 2^0.625   ≈ 1.5422 (spot-check)
    localparam EXP2_ADDR24 = 32'h3FD744FD; // 2^0.75    ≈ 1.6818 (spot-check)
    localparam EXP2_ADDR31 = 32'h3FFA83B3; // 2^0.96875 = 1.9571

    // -----------------------------------------------------------------------
    // VCD dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_7.vcd");
        $dumpvars(0, tb_7);
    end

    // -----------------------------------------------------------------------
    // Task: check one LUT entry (exact match)
    // -----------------------------------------------------------------------
    task check_entry;
        input [4:0]  t_addr;
        input        t_sel;
        input [31:0] t_expected;
        input [8*32-1:0] t_label; // up to 32-char label string
        begin
            addr = t_addr;
            sel  = t_sel;
            #10;
            if (data === t_expected) begin
                $display("  [PASS] %0s: addr=%2d sel=%0d -> %h (expected %h)",
                         t_label, t_addr, t_sel, data, t_expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s: addr=%2d sel=%0d -> %h (expected %h)",
                         t_label, t_addr, t_sel, data, t_expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -----------------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;
        addr = 0;
        sel  = 0;

        $display("==========================================================");
        $display("  tb_7 — Pade LUT ROM Readout Testbench");
        $display("==========================================================");

        // ===================================================================
        // sel=0: log2 table — read all 32 entries
        // ===================================================================
        $display("");
        $display("--- sel=0 (log2 table): Full readout ---");

        for (i = 0; i < 32; i = i + 1) begin
            addr = i[4:0];
            sel  = 1'b0;
            #10;
            $display("    log2[%2d] = %h", i, data);
        end

        // Key entry verification for log2 table
        $display("");
        $display("--- sel=0 (log2 table): Key entry checks ---");

        check_entry(5'd0,  1'b0, LOG2_ADDR0,  "log2[0] ");
        check_entry(5'd4,  1'b0, LOG2_ADDR4,  "log2[4] ");
        check_entry(5'd8,  1'b0, LOG2_ADDR8,  "log2[8] ");
        check_entry(5'd12, 1'b0, LOG2_ADDR12, "log2[12]");
        check_entry(5'd16, 1'b0, LOG2_ADDR16, "log2[16]");
        check_entry(5'd20, 1'b0, LOG2_ADDR20, "log2[20]");
        check_entry(5'd24, 1'b0, LOG2_ADDR24, "log2[24]");
        check_entry(5'd31, 1'b0, LOG2_ADDR31, "log2[31]");

        // ===================================================================
        // sel=1: exp2 table — read all 32 entries
        // ===================================================================
        $display("");
        $display("--- sel=1 (exp2 table): Full readout ---");

        for (i = 0; i < 32; i = i + 1) begin
            addr = i[4:0];
            sel  = 1'b1;
            #10;
            $display("    exp2[%2d] = %h", i, data);
        end

        // Key entry verification for exp2 table
        $display("");
        $display("--- sel=1 (exp2 table): Key entry checks ---");

        check_entry(5'd0,  1'b1, EXP2_ADDR0,  "exp2[0] ");
        check_entry(5'd4,  1'b1, EXP2_ADDR4,  "exp2[4] ");
        check_entry(5'd8,  1'b1, EXP2_ADDR8,  "exp2[8] ");
        check_entry(5'd12, 1'b1, EXP2_ADDR12, "exp2[12]");
        check_entry(5'd16, 1'b1, EXP2_ADDR16, "exp2[16]");
        check_entry(5'd20, 1'b1, EXP2_ADDR20, "exp2[20]");
        check_entry(5'd24, 1'b1, EXP2_ADDR24, "exp2[24]");
        check_entry(5'd31, 1'b1, EXP2_ADDR31, "exp2[31]");

        // ===================================================================
        // Summary
        // ===================================================================
        $display("");
        $display("==========================================================");
        $display("  tb_7 SUMMARY: %0d PASSED, %0d FAILED out of %0d checks",
                 pass_count, fail_count, pass_count + fail_count);
        $display("==========================================================");

        $finish;
    end

endmodule
