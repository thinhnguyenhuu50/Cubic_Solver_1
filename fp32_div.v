// ============================================================================
// fp32_div.v - IEEE 754 FP32 Divider (Purely Combinational)
// ============================================================================
// Performs a / b in single-precision floating point.
// Uses restoring division (no Verilog '/' operator).
// Handles all IEEE 754 special cases: NaN, Inf, Zero, denormals (treated as 0).
// Uses truncation (no rounding). Purely combinational - no clock.
// ============================================================================

module fp32_div (
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
        end else if (a_is_inf && b_is_inf) begin
            // Inf / Inf => NaN
            special_result = NAN_CONST;
        end else if (a_is_inf) begin
            // Inf / finite nonzero => Inf (b_is_zero already covered by Inf having priority)
            special_result = res_sign ? NEG_INF : POS_INF;
        end else if (b_is_inf) begin
            // finite / Inf => Zero
            special_result = {res_sign, 31'b0};
        end else if (a_is_zero && b_is_zero) begin
            // 0 / 0 => NaN
            special_result = NAN_CONST;
        end else if (b_is_zero) begin
            // x / 0 (x nonzero) => Inf
            special_result = res_sign ? NEG_INF : POS_INF;
        end else if (a_is_zero) begin
            // 0 / x => Zero
            special_result = {res_sign, 31'b0};
        end
    end

    assign special = a_is_nan || b_is_nan || a_is_inf || b_is_inf ||
                     a_is_zero || b_is_zero;

    // ========================================================================
    // Mantissa with hidden bit
    // ========================================================================
    wire [23:0] a_mant, b_mant;
    assign a_mant = {1'b1, a_frac};  // 24-bit: 1.fraction
    assign b_mant = {1'b1, b_frac};  // 24-bit: 1.fraction

    // ========================================================================
    // Restoring division: 48-bit dividend / 24-bit divisor => 25-bit quotient
    // ========================================================================
    // dividend = a_mant << 24 = {a_mant, 24'b0} (48 bits)
    // divisor  = b_mant (24 bits)
    // We perform 25 iterations to get a 25-bit quotient.
    //
    // Algorithm:
    //   remainder starts at 0 (25 bits to hold comparison with 24-bit divisor)
    //   For each bit i from 47 down to 23 (25 iterations):
    //     remainder = {remainder[23:0], dividend[i]}
    //     if (remainder >= divisor):
    //       remainder = remainder - divisor
    //       quotient[i-23] = 1
    //     else:
    //       quotient[i-23] = 0
    // ========================================================================

    reg [24:0] quotient;   // 25-bit quotient
    reg [24:0] remainder;  // 25-bit remainder (needs to compare against 24-bit divisor)

    always @(*) begin : restoring_div_block
        reg [47:0] dividend;
        reg [24:0] trial;
        integer i;

        dividend  = {a_mant, 24'b0};
        remainder = 25'b0;
        quotient  = 25'b0;

        for (i = 47; i >= 23; i = i - 1) begin
            // Shift remainder left and bring in next dividend bit
            remainder = {remainder[23:0], dividend[i]};
            // Trial subtraction
            trial = remainder - {1'b0, b_mant};
            if (trial[24] == 1'b0) begin
                // trial >= 0: subtraction succeeded
                remainder = trial;
                quotient[i - 23] = 1'b1;
            end else begin
                // trial < 0: restore (keep remainder unchanged)
                quotient[i - 23] = 1'b0;
            end
        end
    end

    // ========================================================================
    // Exponent computation (10-bit signed to detect overflow/underflow)
    // ========================================================================
    wire signed [9:0] exp_diff;
    assign exp_diff = {2'b0, a_exp} - {2'b0, b_exp} + 10'sd127;

    // ========================================================================
    // Normalization of quotient
    // ========================================================================
    // Since both mantissas are in [1.0, 2.0), the quotient is in [0.5, 2.0).
    // If quotient[24]==1: quotient >= 1.0, use quotient[23:1] as fraction, exp_diff unchanged
    // If quotient[24]==0: quotient < 1.0, use quotient[22:0] as fraction, exp_diff - 1
    wire signed [9:0] norm_exp;
    wire [22:0]       norm_frac;

    assign norm_exp  = quotient[24] ? exp_diff : (exp_diff - 10'sd1);
    assign norm_frac = quotient[24] ? quotient[23:1] : quotient[22:0];

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
