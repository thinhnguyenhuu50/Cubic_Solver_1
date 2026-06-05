// ============================================================================
// fp32_add.v - IEEE 754 FP32 Adder/Subtractor (Purely Combinational)
// ============================================================================
// Performs a + b (sub=0) or a - b (sub=1) in single-precision floating point.
// Handles all IEEE 754 special cases: NaN, Inf, Zero, denormals (treated as 0).
// Uses truncation (no rounding). Purely combinational - no clock.
// ============================================================================

module fp32_add (
    input  [31:0] a,
    input  [31:0] b,
    input          sub,    // 0 = a+b, 1 = a-b
    output [31:0]  result
);

    // ========================================================================
    // Constants
    // ========================================================================
    localparam [31:0] NAN_CONST  = 32'h7FC00000;
    localparam [31:0] POS_INF   = 32'h7F800000;
    localparam [31:0] NEG_INF   = 32'hFF800000;
    localparam [31:0] POS_ZERO  = 32'h00000000;

    // ========================================================================
    // Field extraction
    // ========================================================================
    wire        a_sign;
    wire [7:0]  a_exp;
    wire [22:0] a_frac;
    wire        b_sign;
    wire [7:0]  b_exp;
    wire [22:0] b_frac;

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
    assign a_is_zero = (a_exp == 8'h00);  // exp==0 => treat as zero (denormals as zero)
    assign b_is_zero = (b_exp == 8'h00);  // exp==0 => treat as zero (denormals as zero)

    // ========================================================================
    // Effective sign of b (flip if subtracting)
    // ========================================================================
    wire b_sign_eff;
    assign b_sign_eff = sub ? ~b_sign : b_sign;

    // ========================================================================
    // Mantissa with hidden bit (24 bits)
    // ========================================================================
    wire [23:0] a_mant, b_mant;
    assign a_mant = a_is_zero ? 24'b0 : {1'b1, a_frac};
    assign b_mant = b_is_zero ? 24'b0 : {1'b1, b_frac};

    // ========================================================================
    // Special case detection and result
    // ========================================================================
    wire        special;
    reg  [31:0] special_result;

    // Inf sign for b considering sub
    wire b_inf_sign;
    assign b_inf_sign = b_sign_eff;

    always @(*) begin
        // Default
        special_result = NAN_CONST;

        if (a_is_nan || b_is_nan) begin
            // Any NaN input => NaN
            special_result = NAN_CONST;
        end else if (a_is_inf && b_is_inf) begin
            // Both Inf
            if (a_sign == b_sign_eff) begin
                // Same effective sign => that Inf
                special_result = a_sign ? NEG_INF : POS_INF;
            end else begin
                // Different effective sign => NaN (Inf - Inf)
                special_result = NAN_CONST;
            end
        end else if (a_is_inf) begin
            // Only a is Inf
            special_result = a_sign ? NEG_INF : POS_INF;
        end else if (b_is_inf) begin
            // Only b is Inf
            special_result = b_sign_eff ? NEG_INF : POS_INF;
        end else if (a_is_zero && b_is_zero) begin
            // Both zero => +0
            special_result = POS_ZERO;
        end else if (a_is_zero) begin
            // a is zero, result = b with effective sign
            special_result = {b_sign_eff, b_exp, b_frac};
        end else if (b_is_zero) begin
            // b is zero, result = a
            special_result = a;
        end
    end

    assign special = a_is_nan || b_is_nan || a_is_inf || b_is_inf ||
                     a_is_zero || b_is_zero;

    // ========================================================================
    // Normal computation
    // ========================================================================
    // Effective subtraction?
    wire eff_sub;
    assign eff_sub = a_sign ^ b_sign_eff;

    // Magnitude comparison: determine which operand is larger
    wire a_larger;
    assign a_larger = (a_exp > b_exp) ||
                      ((a_exp == b_exp) && (a_mant >= b_mant));

    // Swap to get large and small operands
    wire        large_sign, small_sign_eff;
    wire [7:0]  large_exp, small_exp;
    wire [23:0] large_mant, small_mant;

    assign large_sign    = a_larger ? a_sign     : b_sign_eff;
    assign small_sign_eff = a_larger ? b_sign_eff : a_sign;
    assign large_exp     = a_larger ? a_exp      : b_exp;
    assign small_exp     = a_larger ? b_exp      : a_exp;
    assign large_mant    = a_larger ? a_mant     : b_mant;
    assign small_mant    = a_larger ? b_mant     : a_mant;

    // Exponent difference
    wire [7:0] exp_diff;
    assign exp_diff = large_exp - small_exp;

    // Shift small mantissa right by exp_diff (barrel shifter, capped at 24)
    wire [23:0] small_mant_shifted;
    assign small_mant_shifted = (exp_diff >= 8'd24) ? 24'b0 :
                                (small_mant >> exp_diff);

    // ========================================================================
    // Addition / Subtraction of mantissas
    // ========================================================================
    wire [24:0] mant_sum;    // 25-bit for addition (can overflow by 1 bit)
    wire [23:0] mant_diff;   // 24-bit for subtraction

    assign mant_sum  = {1'b0, large_mant} + {1'b0, small_mant_shifted};
    assign mant_diff = large_mant - small_mant_shifted;

    // ========================================================================
    // Leading zero count for subtraction normalization
    // ========================================================================
    // Count leading zeros of mant_diff (24-bit input)
    // Returns value 0..24 (24 means all zeros)
    function [4:0] count_leading_zeros;
        input [23:0] val;
        integer i;
        begin
            count_leading_zeros = 5'd24; // default: all zeros
            for (i = 23; i >= 0; i = i - 1) begin
                if (val[i]) begin
                    count_leading_zeros = 5'd23 - i[4:0];
                end
            end
        end
    endfunction

    wire [4:0] lzc;
    assign lzc = count_leading_zeros(mant_diff);

    // ========================================================================
    // Normalize and compute result exponent/mantissa
    // ========================================================================
    reg        res_sign;
    reg [8:0]  res_exp;    // 9-bit to detect overflow/underflow
    reg [22:0] res_frac;

    always @(*) begin
        res_sign = large_sign;

        if (eff_sub == 1'b0) begin
            // ---- Effective addition ----
            if (mant_sum[24]) begin
                // Overflow: shift right by 1, increment exponent
                res_exp  = {1'b0, large_exp} + 9'd1;
                res_frac = mant_sum[23:1]; // drop hidden bit (bit 24->23), take [23:1]
            end else begin
                res_exp  = {1'b0, large_exp};
                res_frac = mant_sum[22:0]; // hidden bit is bit 23
            end
        end else begin
            // ---- Effective subtraction ----
            if (mant_diff == 24'b0) begin
                // Exact zero result
                res_sign = 1'b0; // +0
                res_exp  = 9'd0;
                res_frac = 23'b0;
            end else begin
                // Normalize: shift left by lzc, decrement exponent
                if ({1'b0, large_exp} <= {4'b0, lzc}) begin
                    // Underflow to zero
                    res_exp  = 9'd0;
                    res_frac = 23'b0;
                end else begin
                    res_exp = {1'b0, large_exp} - {4'b0, lzc};
                    // Shift mant_diff left by lzc, then take bits [22:0]
                    // After shifting, bit 23 should be 1 (hidden bit)
                    begin : shift_block
                        reg [23:0] shifted_mant;
                        shifted_mant = mant_diff << lzc;
                        res_frac = shifted_mant[22:0]; // drop hidden bit 23
                    end
                end
            end
        end
    end

    // ========================================================================
    // Overflow / Underflow clamping
    // ========================================================================
    reg [31:0] normal_result;

    always @(*) begin
        if (res_exp >= 9'd255) begin
            // Overflow => Inf
            normal_result = res_sign ? NEG_INF : POS_INF;
        end else if (res_exp == 9'd0) begin
            // Underflow => Zero
            normal_result = {res_sign, 31'b0};
        end else begin
            normal_result = {res_sign, res_exp[7:0], res_frac};
        end
    end

    // ========================================================================
    // Final result mux
    // ========================================================================
    assign result = special ? special_result : normal_result;

endmodule
