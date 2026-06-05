// ===========================================================================
// fp32_cos.v — IEEE 754 FP32 cosine (purely combinational, LUT-based)
// 64-entry LUT: cos(k*pi/64) for k=0..63, covering [0, pi]
// cos(-x) = cos(x), so use |x|
// ===========================================================================
module fp32_cos (
    input  [31:0] a,
    output reg [31:0] result
);

    // FP32 constants
    localparam [31:0] NaN      = 32'h7FC00000;
    localparam [31:0] FP_ONE   = 32'h3F800000; // cos(0) = 1.0

    // Extract fields from absolute angle (cos is even function)
    wire [7:0]  a_exp  = a[30:23];
    wire [22:0] a_frac = a[22:0];

    // Classification
    wire a_is_nan  = (a_exp == 8'hFF) && (a_frac != 23'd0);
    wire a_is_inf  = (a_exp == 8'hFF) && (a_frac == 23'd0);
    wire a_is_zero = (a[30:0] == 31'd0);

    // ---------------------------------------------------------------
    // Convert FP32 angle to fixed-point (10 fractional bits)
    // fixed_val represents angle * 1024
    // ---------------------------------------------------------------
    wire [23:0] a_mantissa = {1'b1, a_frac}; // hidden bit + fraction

    // shift_amount = 150 - a_exp (where 150 = 127 + 23)
    // If a_exp < 127, the number < 1.0; if a_exp = 127, number in [1,2)
    wire [8:0] shift_amount_raw = 9'd150 - {1'b0, a_exp};

    // We need to right-shift the 24-bit mantissa to get fixed-point with 10 frac bits
    // After shifting: fixed_val = mantissa >> shift_amount
    // For a_exp = 127 (value ~1.0): shift_amount = 23, so mantissa >> 23 = 1 (in integer part)
    //   But we want 10 fractional bits, so actual shift = shift_amount - 10 = 13
    //   Or equivalently: fixed_val = mantissa << (10) >> shift_amount
    //   = mantissa >> (shift_amount - 10)
    // Better approach: work with a wider value
    // Place mantissa at bit position [33:10], then right-shift by shift_amount
    wire [33:0] wide_mantissa = {a_mantissa, 10'd0}; // 24 + 10 = 34 bits
    // Right shift by shift_amount to get fixed-point value
    // Clamp shift to valid range
    wire shift_overflow = shift_amount_raw[8] || (shift_amount_raw > 9'd33);
    wire shift_underflow = 1'b0; // handled below
    wire [5:0] shift_amt = shift_overflow ? 6'd0 : shift_amount_raw[5:0];

    // For very large exponents (shift_amount negative, meaning shift_overflow is true when raw overflows as signed),
    // angle is very large - clamp to max
    wire angle_too_large = shift_amount_raw[8]; // negative shift_amount means exp > 150

    wire [33:0] fixed_val_wide = angle_too_large ? 34'd3217 : (wide_mantissa >> shift_amt);
    wire [11:0] fixed_val = (a_exp < 8'd120) ? 12'd0 :  // very small angle → 0
                            (fixed_val_wide > 34'd3217) ? 12'd3217 : // clamp to π*1024
                            fixed_val_wide[11:0];

    // ---------------------------------------------------------------
    // Map fixed-point [0, π*1024 ≈ 3217] to index [0, 63]
    // idx = (fixed_val * 326) >> 14
    // 3217 * 326 = 1048742 >> 14 = 64 → clamp to 63
    // ---------------------------------------------------------------
    wire [21:0] idx_product = fixed_val * 12'd326; // 12 × 12 → up to 22 bits
    wire [7:0]  idx_raw = idx_product[21:14];
    wire [5:0]  idx = (idx_raw > 8'd63) ? 6'd63 : idx_raw[5:0];

    // ---------------------------------------------------------------
    // LUT: cos(k*pi/64) for k=0..63
    // ---------------------------------------------------------------
    reg [31:0] lut_val;
    always @(*) begin
        case (idx)
            6'd0:  lut_val = 32'h3F800000; // cos(0*pi/64) = 1.000000
            6'd1:  lut_val = 32'h3F7FB10F; // cos(1*pi/64) = 0.998795
            6'd2:  lut_val = 32'h3F7EC46D; // cos(2*pi/64) = 0.995185
            6'd3:  lut_val = 32'h3F7D3AAC; // cos(3*pi/64) = 0.989177
            6'd4:  lut_val = 32'h3F7B14BE; // cos(4*pi/64) = 0.980785
            6'd5:  lut_val = 32'h3F7853F8; // cos(5*pi/64) = 0.970031
            6'd6:  lut_val = 32'h3F74FA0B; // cos(6*pi/64) = 0.956940
            6'd7:  lut_val = 32'h3F710908; // cos(7*pi/64) = 0.941544
            6'd8:  lut_val = 32'h3F6C835E; // cos(8*pi/64) = 0.923880
            6'd9:  lut_val = 32'h3F676BD8; // cos(9*pi/64) = 0.903989
            6'd10: lut_val = 32'h3F61C598; // cos(10*pi/64) = 0.881921
            6'd11: lut_val = 32'h3F5B941A; // cos(11*pi/64) = 0.857729
            6'd12: lut_val = 32'h3F54DB31; // cos(12*pi/64) = 0.831470
            6'd13: lut_val = 32'h3F4D9F02; // cos(13*pi/64) = 0.803208
            6'd14: lut_val = 32'h3F45E403; // cos(14*pi/64) = 0.773010
            6'd15: lut_val = 32'h3F3DAEF9; // cos(15*pi/64) = 0.740951
            6'd16: lut_val = 32'h3F3504F3; // cos(16*pi/64) = 0.707107
            6'd17: lut_val = 32'h3F2BEB4A; // cos(17*pi/64) = 0.671559
            6'd18: lut_val = 32'h3F226799; // cos(18*pi/64) = 0.634393
            6'd19: lut_val = 32'h3F187FC0; // cos(19*pi/64) = 0.595699
            6'd20: lut_val = 32'h3F0E39DA; // cos(20*pi/64) = 0.555570
            6'd21: lut_val = 32'h3F039C3D; // cos(21*pi/64) = 0.514103
            6'd22: lut_val = 32'h3EF15AEA; // cos(22*pi/64) = 0.471397
            6'd23: lut_val = 32'h3EDAE880; // cos(23*pi/64) = 0.427555
            6'd24: lut_val = 32'h3EC3EF15; // cos(24*pi/64) = 0.382683
            6'd25: lut_val = 32'h3EAC7CD4; // cos(25*pi/64) = 0.336890
            6'd26: lut_val = 32'h3E94A031; // cos(26*pi/64) = 0.290285
            6'd27: lut_val = 32'h3E78CFCC; // cos(27*pi/64) = 0.242980
            6'd28: lut_val = 32'h3E47C5C2; // cos(28*pi/64) = 0.195090
            6'd29: lut_val = 32'h3E164083; // cos(29*pi/64) = 0.146730
            6'd30: lut_val = 32'h3DC8BD36; // cos(30*pi/64) = 0.098017
            6'd31: lut_val = 32'h3D48FB30; // cos(31*pi/64) = 0.049068
            6'd32: lut_val = 32'h248D3132; // cos(32*pi/64) = 0.000000
            6'd33: lut_val = 32'hBD48FB30; // cos(33*pi/64) = -0.049068
            6'd34: lut_val = 32'hBDC8BD36; // cos(34*pi/64) = -0.098017
            6'd35: lut_val = 32'hBE164083; // cos(35*pi/64) = -0.146730
            6'd36: lut_val = 32'hBE47C5C2; // cos(36*pi/64) = -0.195090
            6'd37: lut_val = 32'hBE78CFCC; // cos(37*pi/64) = -0.242980
            6'd38: lut_val = 32'hBE94A031; // cos(38*pi/64) = -0.290285
            6'd39: lut_val = 32'hBEAC7CD4; // cos(39*pi/64) = -0.336890
            6'd40: lut_val = 32'hBEC3EF15; // cos(40*pi/64) = -0.382683
            6'd41: lut_val = 32'hBEDAE880; // cos(41*pi/64) = -0.427555
            6'd42: lut_val = 32'hBEF15AEA; // cos(42*pi/64) = -0.471397
            6'd43: lut_val = 32'hBF039C3D; // cos(43*pi/64) = -0.514103
            6'd44: lut_val = 32'hBF0E39DA; // cos(44*pi/64) = -0.555570
            6'd45: lut_val = 32'hBF187FC0; // cos(45*pi/64) = -0.595699
            6'd46: lut_val = 32'hBF226799; // cos(46*pi/64) = -0.634393
            6'd47: lut_val = 32'hBF2BEB4A; // cos(47*pi/64) = -0.671559
            6'd48: lut_val = 32'hBF3504F3; // cos(48*pi/64) = -0.707107
            6'd49: lut_val = 32'hBF3DAEF9; // cos(49*pi/64) = -0.740951
            6'd50: lut_val = 32'hBF45E403; // cos(50*pi/64) = -0.773010
            6'd51: lut_val = 32'hBF4D9F02; // cos(51*pi/64) = -0.803208
            6'd52: lut_val = 32'hBF54DB31; // cos(52*pi/64) = -0.831470
            6'd53: lut_val = 32'hBF5B941A; // cos(53*pi/64) = -0.857729
            6'd54: lut_val = 32'hBF61C598; // cos(54*pi/64) = -0.881921
            6'd55: lut_val = 32'hBF676BD8; // cos(55*pi/64) = -0.903989
            6'd56: lut_val = 32'hBF6C835E; // cos(56*pi/64) = -0.923880
            6'd57: lut_val = 32'hBF710908; // cos(57*pi/64) = -0.941544
            6'd58: lut_val = 32'hBF74FA0B; // cos(58*pi/64) = -0.956940
            6'd59: lut_val = 32'hBF7853F8; // cos(59*pi/64) = -0.970031
            6'd60: lut_val = 32'hBF7B14BE; // cos(60*pi/64) = -0.980785
            6'd61: lut_val = 32'hBF7D3AAC; // cos(61*pi/64) = -0.989177
            6'd62: lut_val = 32'hBF7EC46D; // cos(62*pi/64) = -0.995185
            6'd63: lut_val = 32'hBF7FB10F; // cos(63*pi/64) = -0.998795
            default: lut_val = NaN;
        endcase
    end

    // ---------------------------------------------------------------
    // Output mux: handle special cases
    // ---------------------------------------------------------------
    always @(*) begin
        if (a_is_nan || a_is_inf)
            result = NaN;        // NaN → NaN, Inf → NaN
        else if (a_is_zero)
            result = FP_ONE;     // cos(0) = 1.0
        else
            result = lut_val;
    end

endmodule
