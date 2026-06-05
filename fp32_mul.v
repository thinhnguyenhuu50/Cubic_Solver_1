// ============================================================================
// fp32_mul.v - IEEE 754 FP32 Multiplier (Purely Combinational)
// ============================================================================
// Performs a * b in single-precision floating point.
// Handles all IEEE 754 special cases: NaN, Inf, Zero, denormals (treated as 0).
// Uses truncation (no rounding). Purely combinational - no clock.
// ============================================================================

module fp32_mul (
    input  [31:0] a,
    input  [31:0] b,
    output [31:0]  result
);

    // ========================================================================
    // Constants
    // ========================================================================
    localparam [31:0] NAN_CONST = 32'h7FC00000;
    localparam [31:0] POS_INF   = 32'h7F800000;
    localparam [31:0] NEG_INF   = 32'hFF800000;

    // ========================================================================
    // Field extraction
    // ========================================================================
    wire        a_sign, b_sign;
    wire [7:0]  a_exp,  b_exp;
    wire [22:0] a_frac, b_frac;

    assign a_sign = a[31];
    assign a_exp  = a[30:23];
    assign a_frac = a[22:0];
    assign b_sign = b[31];
    assign b_exp  = b[30:23];
    assign b_frac = b[22:0];

    // ========================================================================
    // Classification flags
    // ========================================================================
    wire a_is_nan, b_is_nan;
    wire a_is_inf, b_is_inf;
    wire a_is_zero, b_is_zero;

    assign a_is_nan  = (a_exp == 8'hFF) && (a_frac != 23'b0);
    assign b_is_nan  = (b_exp == 8'hFF) && (b_frac != 23'b0);
    assign a_is_inf  = (a_exp == 8'hFF) && (a_frac == 23'b0);
    assign b_is_inf  = (b_exp == 8'hFF) && (b_frac == 23'b0);
    assign a_is_zero = (a_exp == 8'h00);  // denormals treated as zero
    assign b_is_zero = (b_exp == 8'h00);  // denormals treated as zero

    // ========================================================================
    // Result sign
    // ========================================================================
    wire res_sign;
    assign res_sign = a_sign ^ b_sign;

    // ========================================================================
    // Special case handling
    // ========================================================================
    wire        special;
    reg  [31:0] special_result;

    always @(*) begin
        special_result = NAN_CONST; // default

        if (a_is_nan || b_is_nan) begin
            // Any NaN => NaN
            special_result = NAN_CONST;
        end else if (a_is_inf || b_is_inf) begin
            if (a_is_zero || b_is_zero) begin
                // Inf * 0 => NaN
                special_result = NAN_CONST;
            end else begin
                // Inf * nonzero => Inf with correct sign
                special_result = res_sign ? NEG_INF : POS_INF;
            end
        end else if (a_is_zero || b_is_zero) begin
            // Zero * anything => Zero with correct sign
            special_result = {res_sign, 31'b0};
        end
    end

    assign special = a_is_nan || b_is_nan || a_is_inf || b_is_inf ||
                     a_is_zero || b_is_zero;

    // ========================================================================
    // Mantissa multiplication (24-bit x 24-bit = 48-bit product)
    // ========================================================================
    wire [23:0] a_mant, b_mant;
    assign a_mant = {1'b1, a_frac};
    assign b_mant = {1'b1, b_frac};

    wire [47:0] product;
    assign product = a_mant * b_mant;

    // ========================================================================
    // Exponent computation (10-bit signed to detect overflow/underflow)
    // ========================================================================
    wire signed [9:0] exp_sum;
    assign exp_sum = {2'b0, a_exp} + {2'b0, b_exp} - 10'sd127;

    // ========================================================================
    // Normalization
    // ========================================================================
    wire signed [9:0] norm_exp;
    wire [22:0]       norm_frac;

    // If product[47]==1: 1x.xxx format, take [46:24], exp+1
    // If product[47]==0: 0 1.xxx format, take [45:23]
    assign norm_exp  = product[47] ? (exp_sum + 10'sd1) : exp_sum;
    assign norm_frac = product[47] ? product[46:24] : product[45:23];

    // ========================================================================
    // Overflow / Underflow clamping
    // ========================================================================
    reg [31:0] normal_result;

    always @(*) begin
        if (norm_exp >= 10'sd255) begin
            // Overflow => Inf
            normal_result = res_sign ? NEG_INF : POS_INF;
        end else if (norm_exp <= 10'sd0) begin
            // Underflow => Zero
            normal_result = {res_sign, 31'b0};
        end else begin
            normal_result = {res_sign, norm_exp[7:0], norm_frac};
        end
    end

    // ========================================================================
    // Final result mux
    // ========================================================================
    assign result = special ? special_result : normal_result;

endmodule
