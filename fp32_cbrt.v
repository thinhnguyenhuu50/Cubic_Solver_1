// ===========================================================================
// fp32_cbrt.v — IEEE 754 FP32 cube root (purely combinational)
// cbrt(x) = sign(x) * exp2(log2(|x|) / 3)
// ===========================================================================
module fp32_cbrt (
    input  [31:0] a,
    output [31:0] result
);

    // FP32 constants
    localparam [31:0] NaN          = 32'h7FC00000;
    localparam [31:0] POS_INF      = 32'h7F800000;
    localparam [31:0] NEG_INF      = 32'hFF800000;
    localparam [31:0] POS_ZERO     = 32'h00000000;
    localparam [31:0] FP_ONE_THIRD = 32'h3EAAAAAB; // 1/3

    // Extract fields
    wire        a_sign = a[31];
    wire [7:0]  a_exp  = a[30:23];
    wire [22:0] a_frac = a[22:0];

    // Classification
    wire a_is_nan  = (a_exp == 8'hFF) && (a_frac != 23'd0);
    wire a_is_inf  = (a_exp == 8'hFF) && (a_frac == 23'd0);
    wire a_is_zero = (a[30:0] == 31'd0);

    // ---------------------------------------------------------------
    // Computational path: cbrt(a) = sign(a) * exp2(log2(|a|) * (1/3))
    // ---------------------------------------------------------------

    // Step 1: absolute value
    wire [31:0] abs_a = {1'b0, a[30:0]};

    // Step 2: log2(|a|)
    wire [31:0] log_val;
    fp32_log2 log_inst (.a(abs_a), .result(log_val));

    // Step 3: log2(|a|) * (1/3)
    wire [31:0] third_log;
    fp32_mul mul_inst (.a(log_val), .b(FP_ONE_THIRD), .result(third_log));

    // Step 4: exp2(log2(|a|) / 3)
    wire [31:0] cbrt_raw;
    fp32_exp2 exp_inst (.a(third_log), .result(cbrt_raw));

    // Step 5: restore sign
    wire [31:0] cbrt_signed = {a_sign, cbrt_raw[30:0]};

    // ---------------------------------------------------------------
    // Output mux: handle special cases
    // ---------------------------------------------------------------
    assign result = a_is_nan  ? NaN                           :  // NaN → NaN
                    a_is_zero ? {a_sign, 31'd0}               :  // ±0 → ±0
                    a_is_inf  ? {a_sign, POS_INF[30:0]}       :  // ±Inf → ±Inf
                                cbrt_signed;                      // normal case

endmodule
