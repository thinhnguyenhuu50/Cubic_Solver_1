// ===========================================================================
// fp32_sqrt.v — IEEE 754 FP32 square root (purely combinational)
// sqrt(x) = exp2(0.5 * log2(x))
// ===========================================================================
module fp32_sqrt (
    input  [31:0] a,
    output [31:0] result
);

    // FP32 constants
    localparam [31:0] NaN       = 32'h7FC00000;
    localparam [31:0] POS_INF   = 32'h7F800000;
    localparam [31:0] POS_ZERO  = 32'h00000000;
    localparam [31:0] FP_HALF   = 32'h3F000000; // 0.5

    // Extract fields
    wire        a_sign = a[31];
    wire [7:0]  a_exp  = a[30:23];
    wire [22:0] a_frac = a[22:0];

    // Classification
    wire a_is_nan  = (a_exp == 8'hFF) && (a_frac != 23'd0);
    wire a_is_inf  = (a_exp == 8'hFF) && (a_frac == 23'd0);
    wire a_is_zero = (a[30:0] == 31'd0);
    wire a_is_neg  = a_sign && !a_is_zero; // negative (not -0)

    // ---------------------------------------------------------------
    // Computational path: sqrt(a) = exp2(0.5 * log2(a))
    // ---------------------------------------------------------------
    wire [31:0] log_val;
    fp32_log2 log_inst (.a(a), .result(log_val));

    wire [31:0] half_log;
    fp32_mul mul_inst (.a(log_val), .b(FP_HALF), .result(half_log));

    wire [31:0] sqrt_raw;
    fp32_exp2 exp_inst (.a(half_log), .result(sqrt_raw));

    // ---------------------------------------------------------------
    // Output mux: handle special cases
    // ---------------------------------------------------------------
    assign result = a_is_nan   ? NaN      :   // NaN → NaN
                    a_is_neg   ? NaN      :   // negative → NaN
                    a_is_zero  ? POS_ZERO :   // ±0 → +0
                    a_is_inf   ? POS_INF  :   // +Inf → +Inf
                                 sqrt_raw;    // normal case

endmodule
