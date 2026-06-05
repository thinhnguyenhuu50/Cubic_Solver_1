// =============================================================================
// Module: fp32_log2
// Description: Compute log2(x) for positive FP32 x.
//              Uses LUT-based approach: log2(x) = e + log2(1.f)
//              where x = 1.f * 2^e.
//              Purely combinational, no clk.
// =============================================================================
module fp32_log2 (
    input  [31:0] a,
    output [31:0] result
);

    // --- FP32 field extraction ---
    wire        a_sign = a[31];
    wire [7:0]  a_exp  = a[30:23];
    wire [22:0] a_frac = a[22:0];

    // --- Special case detection ---
    wire a_is_zero     = (a_exp == 8'd0) && (a_frac == 23'd0);
    wire a_is_denorm   = (a_exp == 8'd0) && (a_frac != 23'd0);   // treat as zero
    wire a_is_inf      = (a_exp == 8'hFF) && (a_frac == 23'd0);
    wire a_is_nan      = (a_exp == 8'hFF) && (a_frac != 23'd0);
    wire a_is_negative = a_sign && !a_is_zero && !a_is_denorm;     // negative (not -0)

    // --- Special case result ---
    // log2(0)    = -Inf
    // log2(-0)   = -Inf  (treat -0 same as +0)
    // log2(neg)  = NaN
    // log2(NaN)  = NaN
    // log2(+Inf) = +Inf
    // log2(denorm) = -Inf (treat as zero)
    wire special_case = a_is_zero | a_is_denorm | a_is_inf | a_is_nan | a_is_negative;

    reg [31:0] special_result;
    always @(*) begin
        if (a_is_nan || a_is_negative)
            special_result = 32'h7FC00000;     // NaN
        else if (a_is_zero || a_is_denorm)
            special_result = 32'hFF800000;     // -Inf
        else // a_is_inf (and positive)
            special_result = 32'h7F800000;     // +Inf
    end

    // --- Normal path ---
    // log2(x) = e + log2(1.f)
    // e = a_exp - 127 (signed integer in range [-126, 128])
    wire signed [8:0] e_signed = {1'b0, a_exp} - 9'sd127;

    // --- LUT lookup for log2(1.f) ---
    // Use top 5 bits of fraction as LUT address
    wire [4:0] lut_addr = a_frac[22:18];
    wire [31:0] lut_val;

    pade_lut log2_lut_inst (
        .addr(lut_addr),
        .sel(1'b0),         // sel=0 for log2 table
        .data(lut_val)
    );

    // --- Convert signed integer e to FP32 ---
    // e is in range [-126, 128]
    // Handle e == 0: FP32 = +0.0
    // Handle e == 1: FP32 = 1.0 (3F800000)
    // General: find MSB position, pack exponent and fraction

    wire e_is_zero = (e_signed == 9'sd0);
    wire e_negative = e_signed[8];
    wire [8:0] abs_e = e_negative ? -e_signed : e_signed;
    wire [7:0] abs_e_val = abs_e[7:0]; // fits in 8 bits (max 128)

    // Priority encoder: find MSB position of abs_e_val (0-7)
    reg [2:0] msb_pos;
    reg msb_found;
    always @(*) begin
        if      (abs_e_val[7]) begin msb_pos = 3'd7; msb_found = 1'b1; end
        else if (abs_e_val[6]) begin msb_pos = 3'd6; msb_found = 1'b1; end
        else if (abs_e_val[5]) begin msb_pos = 3'd5; msb_found = 1'b1; end
        else if (abs_e_val[4]) begin msb_pos = 3'd4; msb_found = 1'b1; end
        else if (abs_e_val[3]) begin msb_pos = 3'd3; msb_found = 1'b1; end
        else if (abs_e_val[2]) begin msb_pos = 3'd2; msb_found = 1'b1; end
        else if (abs_e_val[1]) begin msb_pos = 3'd1; msb_found = 1'b1; end
        else if (abs_e_val[0]) begin msb_pos = 3'd0; msb_found = 1'b1; end
        else                   begin msb_pos = 3'd0; msb_found = 1'b0; end
    end

    // Build FP32 from integer
    // exponent = 127 + msb_pos
    // fraction: shift abs_e_val left so MSB is at bit 23 (hidden bit), then take bits [22:0]
    // For value with MSB at position msb_pos, shift left by (23 - msb_pos) and mask out bit 23
    wire [7:0] e_fp32_exp = 8'd127 + {5'd0, msb_pos};

    // Shift abs_e_val into 24-bit mantissa position
    // abs_e_val is 8 bits, msb at msb_pos. Shift left by (23 - msb_pos) to put MSB at bit 23.
    reg [23:0] e_mantissa_shifted;
    always @(*) begin
        case (msb_pos)
            3'd0: e_mantissa_shifted = {abs_e_val[0],   23'd0};   // shift left 23
            3'd1: e_mantissa_shifted = {abs_e_val[1:0],  22'd0};   // shift left 22
            3'd2: e_mantissa_shifted = {abs_e_val[2:0],  21'd0};   // shift left 21
            3'd3: e_mantissa_shifted = {abs_e_val[3:0],  20'd0};   // shift left 20
            3'd4: e_mantissa_shifted = {abs_e_val[4:0],  19'd0};   // shift left 19
            3'd5: e_mantissa_shifted = {abs_e_val[5:0],  18'd0};   // shift left 18
            3'd6: e_mantissa_shifted = {abs_e_val[6:0],  17'd0};   // shift left 17
            3'd7: e_mantissa_shifted = {abs_e_val[7:0],  16'd0};   // shift left 16
            default: e_mantissa_shifted = 24'd0;
        endcase
    end

    wire [22:0] e_fp32_frac = e_mantissa_shifted[22:0]; // strip hidden bit (bit 23)

    wire [31:0] e_fp32 = e_is_zero ? 32'h00000000 :
                          {e_negative, e_fp32_exp, e_fp32_frac};

    // --- Final addition: result = e_fp32 + lut_val ---
    wire [31:0] add_result;

    fp32_add add_inst (
        .a(e_fp32),
        .b(lut_val),
        .sub(1'b0),
        .result(add_result)
    );

    // --- Output mux ---
    assign result = special_case ? special_result : add_result;

endmodule
