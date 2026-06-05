// ===========================================================================
// fp32_acos.v — IEEE 754 FP32 arccosine (purely combinational, LUT-based)
// 64-entry LUT: acos(-1 + k*2/63) for k=0..63, covering [-1, 1]
// ===========================================================================
module fp32_acos (
    input  [31:0] a,
    output reg [31:0] result
);

    // FP32 constants
    localparam [31:0] NaN      = 32'h7FC00000;
    localparam [31:0] FP_PI    = 32'h40490FDB; // 3.141593
    localparam [31:0] FP_PI_2  = 32'h3FC90FDB; // 1.570796
    localparam [31:0] FP_ZERO  = 32'h00000000;
    localparam [31:0] FP_ONE   = 32'h3F800000; // 1.0

    // Extract fields
    wire        a_sign = a[31];
    wire [7:0]  a_exp  = a[30:23];
    wire [22:0] a_frac = a[22:0];

    // Classification
    wire a_is_nan    = (a_exp == 8'hFF) && (a_frac != 23'd0);
    wire a_is_inf    = (a_exp == 8'hFF) && (a_frac == 23'd0);
    wire a_is_zero   = (a[30:0] == 31'd0);

    // Check if |a| > 1.0 (exponent > 127, or exponent == 127 and fraction != 0 means > 1)
    // Actually: |a| > 1.0 when exponent > 127, or (exponent == 127 and fraction != 0)
    wire abs_gt_one = (a_exp > 8'd127) || ((a_exp == 8'd127) && (a_frac != 23'd0));

    // Check if a == +1.0 exactly
    wire a_is_pos_one = (!a_sign) && (a_exp == 8'd127) && (a_frac == 23'd0);
    // Check if a == -1.0 exactly
    wire a_is_neg_one = (a_sign) && (a_exp == 8'd127) && (a_frac == 23'd0);

    // ---------------------------------------------------------------
    // Convert FP32 |x| to fixed-point with 10 fractional bits
    // For x ∈ [-1, 1], max |x| = 1.0 → fixed = 1024
    // ---------------------------------------------------------------
    wire [23:0] a_mantissa = {1'b1, a_frac}; // hidden bit + fraction

    // shift_amount = 150 - a_exp (where 150 = 127 + 23)
    wire [8:0] shift_amount_raw = 9'd150 - {1'b0, a_exp};

    // Place mantissa with 10 fractional bits, then right-shift
    wire [33:0] wide_mantissa = {a_mantissa, 10'd0}; // 34 bits
    wire shift_overflow = shift_amount_raw[8] || (shift_amount_raw > 9'd33);
    wire [5:0] shift_amt = shift_overflow ? 6'd0 : shift_amount_raw[5:0];

    wire [33:0] fixed_abs_wide = wide_mantissa >> shift_amt;
    // Clamp to 1024 (value 1.0 in 10-bit fixed point)
    wire [10:0] fixed_abs = (a_exp < 8'd120) ? 11'd0 :         // very small |x| → 0
                            (fixed_abs_wide > 34'd1024) ? 11'd1024 :
                            fixed_abs_wide[10:0];

    // ---------------------------------------------------------------
    // Convert to signed fixed-point: [-1024, +1024]
    // Positive x → +fixed_abs, Negative x → -fixed_abs
    // ---------------------------------------------------------------
    wire signed [11:0] fixed_signed = a_sign ? -$signed({1'b0, fixed_abs}) :
                                               $signed({1'b0, fixed_abs});

    // ---------------------------------------------------------------
    // Map signed fixed-point [-1024, +1024] to index [0, 63]
    // idx = (fixed_signed + 1024) >> 5
    // -1024 → 0, 0 → ~32, +1024 → 64 (clamp to 63)
    // ---------------------------------------------------------------
    wire signed [11:0] shifted_val = fixed_signed + 12'sd1024;
    wire [11:0] shifted_unsigned = shifted_val[11:0]; // now in [0, 2048]
    wire [6:0] idx_raw = shifted_unsigned[11:5]; // >> 5
    wire [5:0] idx = (idx_raw > 7'd63) ? 6'd63 : idx_raw[5:0];

    // ---------------------------------------------------------------
    // LUT: acos(-1 + k*2/63) for k=0..63
    // ---------------------------------------------------------------
    reg [31:0] lut_val;
    always @(*) begin
        case (idx)
            6'd0:  lut_val = 32'h40490FDB; // acos(-1.00000) = 3.141593
            6'd1:  lut_val = 32'h4038E479; // acos(-0.96825) = 2.888945
            6'd2:  lut_val = 32'h4032221A; // acos(-0.93651) = 2.783331
            6'd3:  lut_val = 32'h402CE74A; // acos(-0.90476) = 2.701617
            6'd4:  lut_val = 32'h40287520; // acos(-0.87302) = 2.632149
            6'd5:  lut_val = 32'h402481D4; // acos(-0.84127) = 2.570424
            6'd6:  lut_val = 32'h4020E79E; // acos(-0.80952) = 2.514137
            6'd7:  lut_val = 32'h401D9014; // acos(-0.77778) = 2.461919
            6'd8:  lut_val = 32'h401A6C9D; // acos(-0.74603) = 2.412879
            6'd9:  lut_val = 32'h40177316; // acos(-0.71429) = 2.366399
            6'd10: lut_val = 32'h40149C1D; // acos(-0.68254) = 2.322028
            6'd11: lut_val = 32'h4011E21C; // acos(-0.65079) = 2.279426
            6'd12: lut_val = 32'h400F40BB; // acos(-0.61905) = 2.238326
            6'd13: lut_val = 32'h400CB481; // acos(-0.58730) = 2.198517
            6'd14: lut_val = 32'h400A3A9C; // acos(-0.55556) = 2.159827
            6'd15: lut_val = 32'h4007D0B4; // acos(-0.52381) = 2.122113
            6'd16: lut_val = 32'h400574D1; // acos(-0.49206) = 2.085255
            6'd17: lut_val = 32'h40032542; // acos(-0.46032) = 2.049149
            6'd18: lut_val = 32'h4000E095; // acos(-0.42857) = 2.013707
            6'd19: lut_val = 32'h3FFD4B06; // acos(-0.39683) = 1.978852
            6'd20: lut_val = 32'h3FF8E5D9; // acos(-0.36508) = 1.944514
            6'd21: lut_val = 32'h3FF48FA1; // acos(-0.33333) = 1.910633
            6'd22: lut_val = 32'h3FF04690; // acos(-0.30159) = 1.877153
            6'd23: lut_val = 32'h3FEC08FF; // acos(-0.26984) = 1.844025
            6'd24: lut_val = 32'h3FE7D56B; // acos(-0.23810) = 1.811201
            6'd25: lut_val = 32'h3FE3AA6F; // acos(-0.20635) = 1.778639
            6'd26: lut_val = 32'h3FDF86BA; // acos(-0.17460) = 1.746299
            6'd27: lut_val = 32'h3FDB6911; // acos(-0.14286) = 1.714144
            6'd28: lut_val = 32'h3FD75047; // acos(-0.11111) = 1.682137
            6'd29: lut_val = 32'h3FD33B3A; // acos(-0.07937) = 1.650245
            6'd30: lut_val = 32'h3FCF28D3; // acos(-0.04762) = 1.618433
            6'd31: lut_val = 32'h3FCB1801; // acos(-0.01587) = 1.586670
            6'd32: lut_val = 32'h3FC707B5; // acos(0.01587) = 1.554923
            6'd33: lut_val = 32'h3FC2F6E2; // acos(0.04762) = 1.523159
            6'd34: lut_val = 32'h3FBEE47B; // acos(0.07937) = 1.491348
            6'd35: lut_val = 32'h3FBACF6F; // acos(0.11111) = 1.459455
            6'd36: lut_val = 32'h3FB6B6A4; // acos(0.14286) = 1.427449
            6'd37: lut_val = 32'h3FB298FB; // acos(0.17460) = 1.395294
            6'd38: lut_val = 32'h3FAE7546; // acos(0.20635) = 1.362954
            6'd39: lut_val = 32'h3FAA4A4A; // acos(0.23810) = 1.330392
            6'd40: lut_val = 32'h3FA616B7; // acos(0.26984) = 1.297568
            6'd41: lut_val = 32'h3FA1D926; // acos(0.30159) = 1.264439
            6'd42: lut_val = 32'h3F9D9014; // acos(0.33333) = 1.230959
            6'd43: lut_val = 32'h3F9939DC; // acos(0.36508) = 1.197078
            6'd44: lut_val = 32'h3F94D4B0; // acos(0.39683) = 1.162741
            6'd45: lut_val = 32'h3F905E8C; // acos(0.42857) = 1.127885
            6'd46: lut_val = 32'h3F8BD531; // acos(0.46032) = 1.092444
            6'd47: lut_val = 32'h3F873614; // acos(0.49206) = 1.056338
            6'd48: lut_val = 32'h3F827E4D; // acos(0.52381) = 1.019479
            6'd49: lut_val = 32'h3F7B54F9; // acos(0.55556) = 0.981765
            6'd50: lut_val = 32'h3F716D66; // acos(0.58730) = 0.943076
            6'd51: lut_val = 32'h3F673C80; // acos(0.61905) = 0.903267
            6'd52: lut_val = 32'h3F5CB6FB; // acos(0.65079) = 0.862167
            6'd53: lut_val = 32'h3F51CEF8; // acos(0.68254) = 0.819564
            6'd54: lut_val = 32'h3F467313; // acos(0.71429) = 0.775193
            6'd55: lut_val = 32'h3F3A8CF7; // acos(0.74603) = 0.728713
            6'd56: lut_val = 32'h3F2DFF1A; // acos(0.77778) = 0.679674
            6'd57: lut_val = 32'h3F20A0F1; // acos(0.80952) = 0.627456
            6'd58: lut_val = 32'h3F123819; // acos(0.84127) = 0.571168
            6'd59: lut_val = 32'h3F026AE9; // acos(0.87302) = 0.509444
            6'd60: lut_val = 32'h3EE14487; // acos(0.90476) = 0.439976
            6'd61: lut_val = 32'h3EB76E04; // acos(0.93651) = 0.358261
            6'd62: lut_val = 32'h3E815B0B; // acos(0.96825) = 0.252648
            6'd63: lut_val = 32'h00000000; // acos(1.00000) = 0.000000
            default: lut_val = NaN;
        endcase
    end

    // ---------------------------------------------------------------
    // Output mux: handle special cases
    // ---------------------------------------------------------------
    always @(*) begin
        if (a_is_nan)
            result = NaN;           // NaN → NaN
        else if (a_is_inf)
            result = NaN;           // Inf → NaN (acos undefined)
        else if (abs_gt_one)
            result = a_sign ? FP_PI : FP_ZERO;  // Clamp out-of-bounds to 0 or pi
        else if (a_is_pos_one)
            result = FP_ZERO;       // acos(1.0) = 0
        else if (a_is_neg_one)
            result = FP_PI;         // acos(-1.0) = π
        else if (a_is_zero)
            result = FP_PI_2;       // acos(0) = π/2
        else
            result = lut_val;
    end

endmodule
