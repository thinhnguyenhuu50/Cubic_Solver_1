// =============================================================================
// Module: pade_lut
// Description: Combinational LUT ROM for log2 and exp2 tables.
//              sel=0 -> log2(1 + k/32) for k=0..31
//              sel=1 -> 2^(k/32) for k=0..31
//              Purely combinational, no clk.
// =============================================================================
module pade_lut (
    input  [4:0]  addr,   // 0-31 table index
    input         sel,    // 0 = log2 table, 1 = exp2 table
    output reg [31:0] data
);

    // Internal wires for both tables
    reg [31:0] log2_data;
    reg [31:0] exp2_data;

    // --- LOG2 TABLE: log2(1 + k/32) for k=0..31 ---
    always @(*) begin
        case (addr)
            5'd0:  log2_data = 32'h00000000; // log2(1.00000) = 0.000000
            5'd1:  log2_data = 32'h3D35D69C; // log2(1.03125) = 0.044394
            5'd2:  log2_data = 32'h3DB31FB8; // log2(1.06250) = 0.087463
            5'd3:  log2_data = 32'h3E0462C4; // log2(1.09375) = 0.129283
            5'd4:  log2_data = 32'h3E2E00D2; // log2(1.12500) = 0.169925
            5'd5:  log2_data = 32'h3E567AF1; // log2(1.15625) = 0.209453
            5'd6:  log2_data = 32'h3E7DE0B6; // log2(1.18750) = 0.247928
            5'd7:  log2_data = 32'h3E92203D; // log2(1.21875) = 0.285402
            5'd8:  log2_data = 32'h3EA4D3C2; // log2(1.25000) = 0.321928
            5'd9:  log2_data = 32'h3EB7110E; // log2(1.28125) = 0.357552
            5'd10: log2_data = 32'h3EC8DDD4; // log2(1.31250) = 0.392317
            5'd11: log2_data = 32'h3EDA3F60; // log2(1.34375) = 0.426265
            5'd12: log2_data = 32'h3EEB3A9F; // log2(1.37500) = 0.459432
            5'd13: log2_data = 32'h3EFBD42B; // log2(1.40625) = 0.491853
            5'd14: log2_data = 32'h3F060828; // log2(1.43750) = 0.523562
            5'd15: log2_data = 32'h3F0DF989; // log2(1.46875) = 0.554589
            5'd16: log2_data = 32'h3F15C01A; // log2(1.50000) = 0.584963
            5'd17: log2_data = 32'h3F1D5DA0; // log2(1.53125) = 0.614710
            5'd18: log2_data = 32'h3F24D3C2; // log2(1.56250) = 0.643856
            5'd19: log2_data = 32'h3F2C2411; // log2(1.59375) = 0.672425
            5'd20: log2_data = 32'h3F335004; // log2(1.62500) = 0.700440
            5'd21: log2_data = 32'h3F3A58FF; // log2(1.65625) = 0.727920
            5'd22: log2_data = 32'h3F41404F; // log2(1.68750) = 0.754888
            5'd23: log2_data = 32'h3F480731; // log2(1.71875) = 0.781360
            5'd24: log2_data = 32'h3F4EAED0; // log2(1.75000) = 0.807355
            5'd25: log2_data = 32'h3F553848; // log2(1.78125) = 0.832890
            5'd26: log2_data = 32'h3F5BA4A4; // log2(1.81250) = 0.857981
            5'd27: log2_data = 32'h3F61F4E5; // log2(1.84375) = 0.882643
            5'd28: log2_data = 32'h3F6829FB; // log2(1.87500) = 0.906891
            5'd29: log2_data = 32'h3F6E44CD; // log2(1.90625) = 0.930737
            5'd30: log2_data = 32'h3F744636; // log2(1.93750) = 0.954196
            5'd31: log2_data = 32'h3F7A2F04; // log2(1.96875) = 0.977280
            default: log2_data = 32'h00000000;
        endcase
    end

    // --- EXP2 TABLE: 2^(k/32) for k=0..31 ---
    always @(*) begin
        case (addr)
            5'd0:  exp2_data = 32'h3F800000; // 2^(0.00000) = 1.000000
            5'd1:  exp2_data = 32'h3F82CD87; // 2^(0.03125) = 1.021897
            5'd2:  exp2_data = 32'h3F85AAC3; // 2^(0.06250) = 1.044274
            5'd3:  exp2_data = 32'h3F88980F; // 2^(0.09375) = 1.067140
            5'd4:  exp2_data = 32'h3F8B95C2; // 2^(0.12500) = 1.090508
            5'd5:  exp2_data = 32'h3F8EA43A; // 2^(0.15625) = 1.114387
            5'd6:  exp2_data = 32'h3F91C3D3; // 2^(0.18750) = 1.138789
            5'd7:  exp2_data = 32'h3F94F4F0; // 2^(0.21875) = 1.163725
            5'd8:  exp2_data = 32'h3F9837F0; // 2^(0.25000) = 1.189207
            5'd9:  exp2_data = 32'h3F9B8D3A; // 2^(0.28125) = 1.215247
            5'd10: exp2_data = 32'h3F9EF532; // 2^(0.31250) = 1.241858
            5'd11: exp2_data = 32'h3FA27043; // 2^(0.34375) = 1.269051
            5'd12: exp2_data = 32'h3FA5FED7; // 2^(0.37500) = 1.296840
            5'd13: exp2_data = 32'h3FA9A15B; // 2^(0.40625) = 1.325237
            5'd14: exp2_data = 32'h3FAD583F; // 2^(0.43750) = 1.354256
            5'd15: exp2_data = 32'h3FB123F6; // 2^(0.46875) = 1.383910
            5'd16: exp2_data = 32'h3FB504F3; // 2^(0.50000) = 1.414214
            5'd17: exp2_data = 32'h3FB8FBAF; // 2^(0.53125) = 1.445181
            5'd18: exp2_data = 32'h3FBD08A4; // 2^(0.56250) = 1.476826
            5'd19: exp2_data = 32'h3FC12C4D; // 2^(0.59375) = 1.509164
            5'd20: exp2_data = 32'h3FC5672A; // 2^(0.62500) = 1.542211
            5'd21: exp2_data = 32'h3FC9B9BE; // 2^(0.65625) = 1.575981
            5'd22: exp2_data = 32'h3FCE248C; // 2^(0.68750) = 1.610490
            5'd23: exp2_data = 32'h3FD2A81E; // 2^(0.71875) = 1.645755
            5'd24: exp2_data = 32'h3FD744FD; // 2^(0.75000) = 1.681793
            5'd25: exp2_data = 32'h3FDBFBB8; // 2^(0.78125) = 1.718619
            5'd26: exp2_data = 32'h3FE0CCDF; // 2^(0.81250) = 1.756252
            5'd27: exp2_data = 32'h3FE5B907; // 2^(0.84375) = 1.794709
            5'd28: exp2_data = 32'h3FEAC0C7; // 2^(0.87500) = 1.834008
            5'd29: exp2_data = 32'h3FEFE4BA; // 2^(0.90625) = 1.874168
            5'd30: exp2_data = 32'h3FF5257D; // 2^(0.93750) = 1.915207
            5'd31: exp2_data = 32'h3FFA83B3; // 2^(0.96875) = 1.957144
            default: exp2_data = 32'h3F800000;
        endcase
    end

    // --- Output mux ---
    always @(*) begin
        data = sel ? exp2_data : log2_data;
    end

endmodule
