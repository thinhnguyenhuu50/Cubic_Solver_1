// =============================================================================
// Module: fp32_exp2
// Description: Compute 2^x for FP32 x.
//              Uses LUT-based approach: 2^(n+f) = 2^n * 2^f
//              where n = floor(x) and f = x - n, 0 <= f < 1.
//              2^f is looked up from LUT, 2^n is exponent adjustment.
//              Purely combinational, no clk.
// =============================================================================
module fp32_exp2 (
    input  [31:0] a,
    output [31:0] result
);

    // --- FP32 field extraction ---
    wire        a_sign = a[31];
    wire [7:0]  a_exp  = a[30:23];
    wire [22:0] a_frac = a[22:0];

    // --- Special case detection ---
    wire a_is_zero   = (a_exp == 8'd0) && (a_frac == 23'd0);   // +0 or -0
    wire a_is_denorm = (a_exp == 8'd0) && (a_frac != 23'd0);   // treat as zero
    wire a_is_inf_p  = (a[31] == 1'b0) && (a_exp == 8'hFF) && (a_frac == 23'd0);
    wire a_is_inf_n  = (a[31] == 1'b1) && (a_exp == 8'hFF) && (a_frac == 23'd0);
    wire a_is_nan    = (a_exp == 8'hFF) && (a_frac != 23'd0);

    // 2^0     = 1.0
    // 2^NaN   = NaN
    // 2^(+Inf)= +Inf
    // 2^(-Inf)= 0
    // 2^denorm= 1.0 (treat denorm as zero)
    wire special_case = a_is_zero | a_is_denorm | a_is_inf_p | a_is_inf_n | a_is_nan;

    reg [31:0] special_result;
    always @(*) begin
        if (a_is_nan)
            special_result = 32'h7FC00000;     // NaN
        else if (a_is_inf_p)
            special_result = 32'h7F800000;     // +Inf
        else if (a_is_inf_n)
            special_result = 32'h00000000;     // +0
        else // a_is_zero or a_is_denorm
            special_result = 32'h3F800000;     // 1.0
    end

    // =========================================================================
    // Normal path: compute 2^a where a is a normal FP32 number.
    //
    // Strategy: decompose a = n + f where n = floor(a), 0 <= f < 1.
    // Then 2^a = 2^n * 2^f.
    // 2^f is looked up from LUT (using top 5 bits of f as index).
    // 2^n is done by adding n to the LUT result's exponent.
    // =========================================================================

    // --- Full mantissa with hidden bit: 1.fraction ---
    wire [23:0] a_mantissa = {1'b1, a_frac};  // 24 bits: 1.fraction

    // --- Unbiased exponent (signed) ---
    // Range for normal numbers: -126 to 127
    wire signed [8:0] a_unbiased = {1'b0, a_exp} - 9'sd127;

    // --- Extract integer part n = floor(a) and fractional part f ---
    // The mantissa is 1.frac (24 bits with implicit point after bit 23).
    // If unbiased_exp = e, the binary point is after bit (23-e) from LSB.
    //   - If e >= 23: the entire mantissa is integer, no fraction.
    //   - If e >= 0 and e < 23: top (e+1) bits are integer, rest is fraction.
    //   - If e < 0: |a| < 1, so integer part of |a| is 0.
    //
    // For positive a: n = floor(a) = integer part of a; f = a - n.
    // For negative a: floor(-2.5) = -3, f = -2.5 - (-3) = 0.5.
    //   So: n = -(integer_part + (frac_part != 0 ? 1 : 0)), f = 1.0 - frac_part (if frac != 0).

    // Shift amount for extracting integer bits: 23 - e
    // We clamp e to reasonable range. If e >= 8 (i.e., |a| >= 256), result
    // will overflow/underflow anyway.

    // --- Compute shift amount ---
    // For e >= 0: shift_right = 23 - e (to get integer bits from mantissa)
    // We need to handle this carefully with limited bit widths.

    // Maximum useful exponent: if e >= 8, |n| can be >= 128, which will
    // overflow/underflow the result exponent. We still compute but check later.

    // Extract integer and fractional parts of |a|
    reg [7:0]  abs_n;          // |n| (integer part of |a|), max ~255
    reg [22:0] frac_bits;      // fractional bits of |a| (23 bits, implicit 0.)
    reg        has_frac;       // whether |a| has any fractional part

    always @(*) begin
        if (a_unbiased >= 9'sd23) begin
            // All bits are integer, no fraction
            // Shift mantissa left by (e - 23) to get integer value
            // But we cap abs_n at 8 bits. For very large e, overflow is handled later.
            abs_n     = a_mantissa[7:0]; // This isn't right for large e; overflow catches it
            frac_bits = 23'd0;
            has_frac  = 1'b0;
            // Actually for e >= 23, the integer value is mantissa << (e-23).
            // This can be huge. We handle overflow downstream.
            // For correctness up to e=7 (which covers |a| up to 255), this path
            // won't be taken since e < 23.
            // For e >= 23, the integer part is enormous (>= 2^23 = 8M), so
            // the result 2^(8M) is infinity or zero (underflow). We detect this later.
        end
        else if (a_unbiased >= 9'sd0) begin
            // 0 <= e < 23: mix of integer and fractional bits
            // Integer part: top (e+1) bits of mantissa
            // Fractional part: bottom (23-e) bits of mantissa shifted to top

            case (a_unbiased[4:0])
                5'd0: begin
                    abs_n     = {7'd0, a_mantissa[23]};
                    frac_bits = a_mantissa[22:0];
                end
                5'd1: begin
                    abs_n     = {6'd0, a_mantissa[23:22]};
                    frac_bits = {a_mantissa[21:0], 1'b0};
                end
                5'd2: begin
                    abs_n     = {5'd0, a_mantissa[23:21]};
                    frac_bits = {a_mantissa[20:0], 2'b0};
                end
                5'd3: begin
                    abs_n     = {4'd0, a_mantissa[23:20]};
                    frac_bits = {a_mantissa[19:0], 3'b0};
                end
                5'd4: begin
                    abs_n     = {3'd0, a_mantissa[23:19]};
                    frac_bits = {a_mantissa[18:0], 4'b0};
                end
                5'd5: begin
                    abs_n     = {2'd0, a_mantissa[23:18]};
                    frac_bits = {a_mantissa[17:0], 5'b0};
                end
                5'd6: begin
                    abs_n     = {1'd0, a_mantissa[23:17]};
                    frac_bits = {a_mantissa[16:0], 6'b0};
                end
                5'd7: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[15:0], 7'b0};
                end
                // For e >= 8 the integer part exceeds 255; these result in
                // exponent overflow/underflow which is caught downstream.
                5'd8: begin
                    abs_n     = a_mantissa[23:16]; // truncated; overflow later
                    frac_bits = {a_mantissa[14:0], 8'b0};
                end
                5'd9: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[13:0], 9'b0};
                end
                5'd10: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[12:0], 10'b0};
                end
                5'd11: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[11:0], 11'b0};
                end
                5'd12: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[10:0], 12'b0};
                end
                5'd13: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[9:0], 13'b0};
                end
                5'd14: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[8:0], 14'b0};
                end
                5'd15: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[7:0], 15'b0};
                end
                5'd16: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[6:0], 16'b0};
                end
                5'd17: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[5:0], 17'b0};
                end
                5'd18: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[4:0], 18'b0};
                end
                5'd19: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[3:0], 19'b0};
                end
                5'd20: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[2:0], 20'b0};
                end
                5'd21: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[1:0], 21'b0};
                end
                5'd22: begin
                    abs_n     = a_mantissa[23:16];
                    frac_bits = {a_mantissa[0], 22'b0};
                end
                default: begin
                    abs_n     = 8'd0;
                    frac_bits = 23'd0;
                end
            endcase
            has_frac = (frac_bits != 23'd0);
        end
        else begin
            // e < 0: |a| < 1.0, so integer part is 0
            abs_n     = 8'd0;
            has_frac  = 1'b1;   // |a| is entirely fractional (nonzero since not special)
            // The fractional value IS |a| itself. We need to represent it as 0.xxxxx
            // |a| has mantissa 1.frac and exponent e (negative), so:
            // |a| = 1.frac * 2^e
            // As a fixed-point 0.23 number: shift (1.frac) right by (1 + |e|) = (1 - e)
            // since |a| = mantissa >> (23 - e) mapped to 23-bit fraction -> shift right by -e more
            // Actually: in our 0.23 fixed point, frac_bits represents frac_bits / 2^23.
            // |a| = mantissa * 2^(e - 23) where mantissa is 24-bit integer.
            // To get 23-bit fixed point: frac_bits = mantissa >> (1 - e) and take lower 23 bits.
            // But e is negative: 1 - e = 1 + |e|.
            case (a_unbiased[3:0])
                // e = -1: |a| in [0.5, 1.0), shift mantissa right by 1
                4'd15: frac_bits = a_mantissa[23:1];              // e=-1, >> 1
                // e = -2: |a| in [0.25, 0.5), shift mantissa right by 2
                4'd14: frac_bits = {1'b0, a_mantissa[23:2]};     // e=-2, >> 2
                // e = -3: shift right by 3
                4'd13: frac_bits = {2'b0, a_mantissa[23:3]};     // e=-3, >> 3
                // e = -4: shift right by 4
                4'd12: frac_bits = {3'b0, a_mantissa[23:4]};     // e=-4, >> 4
                // e = -5: shift right by 5
                4'd11: frac_bits = {4'b0, a_mantissa[23:5]};     // e=-5, >> 5
                // e = -6: shift right by 6
                4'd10: frac_bits = {5'b0, a_mantissa[23:6]};     // e=-6, >> 6
                // e = -7: shift right by 7
                4'd9:  frac_bits = {6'b0, a_mantissa[23:7]};     // e=-7, >> 7
                // For e <= -8: |a| < 1/128, top 5 frac bits are 0 → LUT addr = 0
                // 2^f ≈ 1.0 for very small f
                default: frac_bits = 23'd0;
            endcase
        end
    end

    // --- Compute n (signed integer) from abs_n ---
    // For positive a: n = floor(a) = abs_n (positive)
    // For negative a: n = floor(-|a|)
    //   If has_frac: n = -(abs_n + 1) [floor of negative non-integer]
    //   If !has_frac: n = -abs_n       [already integer]
    // For negative a, fractional part f = a - n:
    //   If has_frac: f = 1.0 - frac_of_|a|
    //   If !has_frac: f = 0

    reg signed [8:0] n_signed;
    reg [22:0] f_bits;         // fractional part in [0, 1) as 0.23 fixed point

    always @(*) begin
        if (!a_sign) begin
            // Positive a
            n_signed = {1'b0, abs_n};
            f_bits   = frac_bits;
        end
        else begin
            // Negative a
            if (has_frac) begin
                n_signed = -(({1'b0, abs_n}) + 9'sd1);
                // f = 1.0 - frac_of_|a|
                // In 23-bit fixed point: (2^23) - frac_bits, but we need 23 bits.
                // 1.0 in 0.23 format is 2^23 = 24'h800000, but that's 24 bits.
                // We compute: if frac_bits == 0, f = 0 (but has_frac is true, so frac_bits != 0)
                // f_bits = (24'h800000 - {1'b0, frac_bits})[22:0]
                f_bits = (24'h800000 - {1'b0, frac_bits});
            end
            else begin
                n_signed = -({1'b0, abs_n});
                f_bits   = 23'd0;
            end
        end
    end

    // --- LUT lookup for 2^f ---
    wire [4:0] lut_addr = f_bits[22:18]; // top 5 bits of fractional part
    wire [31:0] lut_val;

    pade_lut exp2_lut_inst (
        .addr(lut_addr),
        .sel(1'b1),         // sel=1 for exp2 table
        .data(lut_val)
    );

    // --- Result = lut_val * 2^n ---
    // lut_val is 2^f, a normal FP32 in [1.0, 2.0).
    // Multiplying by 2^n = adding n to the exponent field.
    wire [7:0] lut_exp = lut_val[30:23];
    wire signed [9:0] result_exp_full = {2'b0, lut_exp} + {{1{n_signed[8]}}, n_signed};

    // --- Overflow/underflow detection ---
    wire exp_overflow  = (result_exp_full >= 10'sd255);
    wire exp_underflow = (result_exp_full <= 10'sd0);

    // Also detect if a_unbiased >= 23 (huge exponent, guaranteed overflow/underflow)
    wire huge_exp = (a_unbiased >= 9'sd8); // |a| >= 256, guaranteed extreme

    // For huge positive a: overflow to +Inf
    // For huge negative a: underflow to 0
    wire huge_overflow  = huge_exp && !a_sign;
    wire huge_underflow = huge_exp && a_sign;

    // --- Pack result ---
    wire [7:0] result_exp = result_exp_full[7:0];
    wire [31:0] normal_result = {1'b0, result_exp, lut_val[22:0]};

    // --- Final output mux ---
    assign result = special_case     ? special_result :
                    huge_overflow    ? 32'h7F800000 :   // +Inf
                    huge_underflow   ? 32'h00000000 :   // +0
                    exp_overflow     ? 32'h7F800000 :   // +Inf
                    exp_underflow    ? 32'h00000000 :   // +0 (flush to zero)
                    normal_result;

endmodule
