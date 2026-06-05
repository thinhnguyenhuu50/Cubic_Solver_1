// ===========================================================================
// cubic_solver.v — Top-level multi-cycle FSM for solving ax^3+bx^2+cx+d=0
// Uses Cardano's method (one real root) and trigonometric method (three real roots)
// All FP32 arithmetic is done by instantiated combinational submodules.
// Each FSM state performs ONE arithmetic operation to keep critical paths short.
// ===========================================================================
module cubic_solver (
    input         clk,
    input         rst_n,

    input         in_valid,
    output reg    in_ready,

    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] c,
    input  [31:0] d,

    output reg    out_valid,
    input         out_ready,

    output reg [31:0] x0,
    output reg [31:0] x1,
    output reg [31:0] x2
);

    // ---------------------------------------------------------------
    // FP32 constants
    // ---------------------------------------------------------------
    localparam [31:0] FP_ZERO       = 32'h00000000;
    localparam [31:0] FP_ONE        = 32'h3F800000;
    localparam [31:0] FP_NEG_ONE    = 32'hBF800000;
    localparam [31:0] FP_TWO        = 32'h40000000;
    localparam [31:0] FP_THREE      = 32'h40400000;
    localparam [31:0] FP_FOUR       = 32'h40800000;
    localparam [31:0] FP_HALF       = 32'h3F000000;
    localparam [31:0] FP_ONE_THIRD  = 32'h3EAAAAAB;
    localparam [31:0] FP_TWO_27TH   = 32'h3D97B426;
    localparam [31:0] FP_TWENTY7    = 32'h41D80000;
    localparam [31:0] FP_QUARTER    = 32'h3E800000; // 0.25
    localparam [31:0] FP_ONE_27TH   = 32'h3D17B426;
    localparam [31:0] FP_PI         = 32'h40490FDB;
    localparam [31:0] FP_TWO_PI_3   = 32'h40060A92;
    localparam [31:0] NaN           = 32'h7FC00000;

    // ---------------------------------------------------------------
    // FSM state encoding
    // ---------------------------------------------------------------
    localparam [5:0]
        S_IDLE       = 6'd0,
        S_LOAD       = 6'd1,
        // --- Normalize by a ---
        S_NORM_BA    = 6'd2,   // ba = b / a
        S_NORM_CA    = 6'd3,   // ca = c / a
        S_NORM_DA    = 6'd4,   // da = d / a
        S_NORM_BA3   = 6'd5,   // ba3 = ba * (1/3)
        // --- Depressed cubic: t^3 + pt + q = 0 ---
        S_DEP_BA2    = 6'd6,   // ba_sq = ba * ba
        S_DEP_BA2_3  = 6'd7,   // ba_sq_3 = ba_sq * (1/3)
        S_DEP_P      = 6'd8,   // p = ca - ba_sq_3
        S_DEP_BACA   = 6'd9,   // ba_ca = ba * ca
        S_DEP_BACA3  = 6'd10,  // ba_ca_3 = ba_ca * (1/3)
        S_DEP_BA3CU  = 6'd11,  // ba_cu = ba_sq * ba
        S_DEP_BA3_27 = 6'd12,  // ba_cu_27 = ba_cu * (2/27)
        S_DEP_QT     = 6'd13,  // q_tmp = da - ba_ca_3
        S_DEP_Q      = 6'd14,  // q = q_tmp + ba_cu_27
        // --- Discriminant: disc = -(4p^3 + 27q^2) ---
        S_DISC_P2    = 6'd15,  // p_sq = p * p
        S_DISC_P3    = 6'd16,  // p_cu = p_sq * p
        S_DISC_4P3   = 6'd17,  // four_p3 = p_cu * 4
        S_DISC_Q2    = 6'd18,  // q_sq = q * q
        S_DISC_27Q2  = 6'd19,  // t27q2 = q_sq * 27
        S_DISC_SUM   = 6'd20,  // disc_sum = four_p3 + t27q2
        S_DISC_NEG   = 6'd21,  // disc = -disc_sum (negate sign bit)
        // --- Branch on discriminant ---
        S_BRANCH     = 6'd22,
        // --- Three real roots (trigonometric) ---
        S_TRI_NP     = 6'd23,  // neg_p = -p
        S_TRI_NP3    = 6'd24,  // neg_p_3 = neg_p * (1/3)
        S_TRI_A      = 6'd25,  // A = sqrt(neg_p_3)
        S_TRI_ACU    = 6'd26,  // A_cu = A * A * ... actually A*neg_p_3
        S_TRI_2ACU   = 6'd27,  // two_A_cu = A_cu * 2
        S_TRI_NQ     = 6'd28,  // neg_q = -q
        S_TRI_ARG    = 6'd29,  // cos_arg = neg_q / two_A_cu
        S_TRI_THETA  = 6'd30,  // theta_full = acos(cos_arg)
        S_TRI_TH3    = 6'd31,  // theta = theta_full * (1/3)
        S_TRI_ANG1   = 6'd32,  // ang1 = theta - 2*pi/3
        S_TRI_ANG2   = 6'd33,  // ang2 = theta + 2*pi/3
        S_TRI_COS0   = 6'd34,  // cos0 = cos(theta)
        S_TRI_COS1   = 6'd35,  // cos1 = cos(ang1)
        S_TRI_COS2   = 6'd36,  // cos2 = cos(ang2)
        S_TRI_2A     = 6'd37,  // two_A = A * 2
        S_TRI_T0     = 6'd38,  // t0 = two_A * cos0
        S_TRI_T1     = 6'd39,  // t1 = two_A * cos1
        S_TRI_T2     = 6'd40,  // t2 = two_A * cos2
        S_TRI_X0     = 6'd41,  // x0 = t0 - ba3
        S_TRI_X1     = 6'd42,  // x1 = t1 - ba3
        S_TRI_X2     = 6'd43,  // x2 = t2 - ba3
        // --- One real root (Cardano) ---
        S_CAR_Q24    = 6'd44,  // q_sq_4 = q_sq * 0.25
        S_CAR_P327   = 6'd45,  // p_cu_27 = p_cu * (1/27)
        S_CAR_UNDER  = 6'd46,  // under_sqrt = q_sq_4 + p_cu_27
        S_CAR_SQ     = 6'd47,  // sq = sqrt(under_sqrt)
        S_CAR_NQ2    = 6'd48,  // neg_q_2 = neg_q * 0.5
        S_CAR_S      = 6'd49,  // S = neg_q_2 + sq
        S_CAR_T      = 6'd50,  // T = neg_q_2 - sq
        S_CAR_CS     = 6'd51,  // cbrt_S = cbrt(S)
        S_CAR_CT     = 6'd52,  // cbrt_T = cbrt(T)
        S_CAR_T0     = 6'd53,  // t0 = cbrt_S + cbrt_T
        S_CAR_X0     = 6'd54,  // x0 = t0 - ba3
        // --- Output ---
        S_DONE       = 6'd55;

    reg [5:0] state, next_state;

    // ---------------------------------------------------------------
    // Intermediate registers
    // ---------------------------------------------------------------
    reg [31:0] a_reg, b_reg, c_reg, d_reg;
    reg [31:0] ba, ca, da, ba3;
    reg [31:0] ba_sq, ba_sq_3, p_reg;
    reg [31:0] ba_ca, ba_ca_3, ba_cu, ba_cu_27;
    reg [31:0] q_tmp, q_reg;
    reg [31:0] p_sq, p_cu, four_p3;
    reg [31:0] q_sq, t27q2, disc_sum, disc;
    reg [31:0] neg_p, neg_p_3, A_val, A_cu, two_A_cu;
    reg [31:0] neg_q, cos_arg, theta_full, theta;
    reg [31:0] ang1, ang2;
    reg [31:0] cos0, cos1, cos2, two_A;
    reg [31:0] t0, t1, t2;
    reg [31:0] q_sq_4, p_cu_27, under_sqrt, sq_val;
    reg [31:0] neg_q_2, S_val, T_val, cbrt_S, cbrt_T;

    // ---------------------------------------------------------------
    // Shared arithmetic unit ports (muxed by FSM)
    // ---------------------------------------------------------------
    reg  [31:0] add_a, add_b;
    reg         add_sub;
    wire [31:0] add_result;

    reg  [31:0] mul_a, mul_b;
    wire [31:0] mul_result;

    reg  [31:0] div_a, div_b;
    wire [31:0] div_result;

    reg  [31:0] sqrt_in;
    wire [31:0] sqrt_out;

    reg  [31:0] cbrt_in;
    wire [31:0] cbrt_out;

    reg  [31:0] cos_in;
    wire [31:0] cos_out;

    reg  [31:0] acos_in;
    wire [31:0] acos_out;

    // ---------------------------------------------------------------
    // Instantiate shared arithmetic modules (all combinational)
    // ---------------------------------------------------------------
    fp32_add  u_add  (.a(add_a),  .b(add_b), .sub(add_sub), .result(add_result));
    fp32_mul  u_mul  (.a(mul_a),  .b(mul_b),                .result(mul_result));
    fp32_div  u_div  (.a(div_a),  .b(div_b),                .result(div_result));
    fp32_sqrt u_sqrt (.a(sqrt_in),                           .result(sqrt_out));
    fp32_cbrt u_cbrt (.a(cbrt_in),                           .result(cbrt_out));
    fp32_cos  u_cos  (.a(cos_in),                            .result(cos_out));
    fp32_acos u_acos (.a(acos_in),                           .result(acos_out));

    // ---------------------------------------------------------------
    // Helper: check if FP32 value is zero
    // ---------------------------------------------------------------
    function is_fp_zero;
        input [31:0] v;
        begin
            is_fp_zero = (v[30:0] == 31'd0);
        end
    endfunction

    // ---------------------------------------------------------------
    // Helper: negate FP32 (flip sign bit)
    // ---------------------------------------------------------------
    function [31:0] fp_neg;
        input [31:0] v;
        begin
            fp_neg = {~v[31], v[30:0]};
        end
    endfunction

    // ---------------------------------------------------------------
    // FSM — next state logic
    // ---------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:      if (in_valid)  next_state = S_LOAD;
            S_LOAD:      next_state = is_fp_zero(a_reg) ? S_DONE : S_NORM_BA;
            S_NORM_BA:   next_state = S_NORM_CA;
            S_NORM_CA:   next_state = S_NORM_DA;
            S_NORM_DA:   next_state = S_NORM_BA3;
            S_NORM_BA3:  next_state = S_DEP_BA2;
            S_DEP_BA2:   next_state = S_DEP_BA2_3;
            S_DEP_BA2_3: next_state = S_DEP_P;
            S_DEP_P:     next_state = S_DEP_BACA;
            S_DEP_BACA:  next_state = S_DEP_BACA3;
            S_DEP_BACA3: next_state = S_DEP_BA3CU;
            S_DEP_BA3CU: next_state = S_DEP_BA3_27;
            S_DEP_BA3_27:next_state = S_DEP_QT;
            S_DEP_QT:    next_state = S_DEP_Q;
            S_DEP_Q:     next_state = S_DISC_P2;
            S_DISC_P2:   next_state = S_DISC_P3;
            S_DISC_P3:   next_state = S_DISC_4P3;
            S_DISC_4P3:  next_state = S_DISC_Q2;
            S_DISC_Q2:   next_state = S_DISC_27Q2;
            S_DISC_27Q2: next_state = S_DISC_SUM;
            S_DISC_SUM:  next_state = S_DISC_NEG;
            S_DISC_NEG:  next_state = S_BRANCH;
            S_BRANCH: begin
                // disc >= 0 (sign bit = 0) → three real roots
                // disc < 0 (sign bit = 1) → one real root (Cardano)
                // If p is 0, we must avoid dividing by p in trig method. Cardano works perfectly for p=0.
                if ((!disc[31] || is_fp_zero(disc)) && !is_fp_zero(p_reg))
                    next_state = S_TRI_NP;
                else
                    next_state = S_CAR_Q24;
            end
            // Three real roots path
            S_TRI_NP:    next_state = S_TRI_NP3;
            S_TRI_NP3:   next_state = S_TRI_A;
            S_TRI_A:     next_state = S_TRI_ACU;
            S_TRI_ACU:   next_state = S_TRI_2ACU;
            S_TRI_2ACU:  next_state = S_TRI_NQ;
            S_TRI_NQ:    next_state = S_TRI_ARG;
            S_TRI_ARG:   next_state = S_TRI_THETA;
            S_TRI_THETA: next_state = S_TRI_TH3;
            S_TRI_TH3:   next_state = S_TRI_ANG1;
            S_TRI_ANG1:  next_state = S_TRI_ANG2;
            S_TRI_ANG2:  next_state = S_TRI_COS0;
            S_TRI_COS0:  next_state = S_TRI_COS1;
            S_TRI_COS1:  next_state = S_TRI_COS2;
            S_TRI_COS2:  next_state = S_TRI_2A;
            S_TRI_2A:    next_state = S_TRI_T0;
            S_TRI_T0:    next_state = S_TRI_T1;
            S_TRI_T1:    next_state = S_TRI_T2;
            S_TRI_T2:    next_state = S_TRI_X0;
            S_TRI_X0:    next_state = S_TRI_X1;
            S_TRI_X1:    next_state = S_TRI_X2;
            S_TRI_X2:    next_state = S_DONE;
            // Cardano path
            S_CAR_Q24:   next_state = S_CAR_P327;
            S_CAR_P327:  next_state = S_CAR_UNDER;
            S_CAR_UNDER: next_state = S_CAR_SQ;
            S_CAR_SQ:    next_state = S_CAR_NQ2;
            S_CAR_NQ2:   next_state = S_CAR_S;
            S_CAR_S:     next_state = S_CAR_T;
            S_CAR_T:     next_state = S_CAR_CS;
            S_CAR_CS:    next_state = S_CAR_CT;
            S_CAR_CT:    next_state = S_CAR_T0;
            S_CAR_T0:    next_state = S_CAR_X0;
            S_CAR_X0:    next_state = S_DONE;
            // Done
            S_DONE:      if (out_ready) next_state = S_IDLE;
            default:     next_state = S_IDLE;
        endcase
    end

    // ---------------------------------------------------------------
    // FSM — output signals
    // ---------------------------------------------------------------
    always @(*) begin
        in_ready  = (state == S_IDLE);
        out_valid = (state == S_DONE);
    end

    // ---------------------------------------------------------------
    // Arithmetic unit input muxing (combinational)
    // ---------------------------------------------------------------
    always @(*) begin
        // Defaults (don't cares — saves power by not toggling)
        add_a   = FP_ZERO;  add_b = FP_ZERO;  add_sub = 1'b0;
        mul_a   = FP_ZERO;  mul_b = FP_ZERO;
        div_a   = FP_ZERO;  div_b = FP_ONE;
        sqrt_in = FP_ZERO;
        cbrt_in = FP_ZERO;
        cos_in  = FP_ZERO;
        acos_in = FP_ZERO;

        case (state)
            // --- Normalize ---
            S_NORM_BA:   begin div_a = b_reg; div_b = a_reg; end
            S_NORM_CA:   begin div_a = c_reg; div_b = a_reg; end
            S_NORM_DA:   begin div_a = d_reg; div_b = a_reg; end
            S_NORM_BA3:  begin mul_a = ba;    mul_b = FP_ONE_THIRD; end
            // --- Depressed cubic ---
            S_DEP_BA2:   begin mul_a = ba;     mul_b = ba; end
            S_DEP_BA2_3: begin mul_a = ba_sq;  mul_b = FP_ONE_THIRD; end
            S_DEP_P:     begin add_a = ca;     add_b = ba_sq_3; add_sub = 1'b1; end
            S_DEP_BACA:  begin mul_a = ba;     mul_b = ca; end
            S_DEP_BACA3: begin mul_a = ba_ca;  mul_b = FP_ONE_THIRD; end
            S_DEP_BA3CU: begin mul_a = ba_sq;  mul_b = ba; end
            S_DEP_BA3_27:begin mul_a = ba_cu;  mul_b = FP_TWO_27TH; end
            S_DEP_QT:    begin add_a = da;     add_b = ba_ca_3; add_sub = 1'b1; end
            S_DEP_Q:     begin add_a = q_tmp;  add_b = ba_cu_27; add_sub = 1'b0; end
            // --- Discriminant ---
            S_DISC_P2:   begin mul_a = p_reg;  mul_b = p_reg; end
            S_DISC_P3:   begin mul_a = p_sq;   mul_b = p_reg; end
            S_DISC_4P3:  begin mul_a = p_cu;   mul_b = FP_FOUR; end
            S_DISC_Q2:   begin mul_a = q_reg;  mul_b = q_reg; end
            S_DISC_27Q2: begin mul_a = q_sq;   mul_b = FP_TWENTY7; end
            S_DISC_SUM:  begin add_a = four_p3; add_b = t27q2; add_sub = 1'b0; end
            // S_DISC_NEG: handled in datapath (just flip sign bit)
            // --- Trigonometric path ---
            S_TRI_NP3:   begin mul_a = neg_p;  mul_b = FP_ONE_THIRD; end
            S_TRI_A:     begin sqrt_in = neg_p_3; end
            S_TRI_ACU:   begin mul_a = A_val;  mul_b = neg_p_3; end // A * (neg_p/3) = A * A^2 = A^3
            S_TRI_2ACU:  begin mul_a = A_cu;   mul_b = FP_TWO; end
            S_TRI_ARG:   begin div_a = neg_q;  div_b = two_A_cu; end
            S_TRI_THETA: begin acos_in = cos_arg; end
            S_TRI_TH3:   begin mul_a = theta_full; mul_b = FP_ONE_THIRD; end
            S_TRI_ANG1:  begin add_a = theta;  add_b = FP_TWO_PI_3; add_sub = 1'b1; end
            S_TRI_ANG2:  begin add_a = theta;  add_b = FP_TWO_PI_3; add_sub = 1'b0; end
            S_TRI_COS0:  begin cos_in = theta; end
            S_TRI_COS1:  begin cos_in = ang1; end
            S_TRI_COS2:  begin cos_in = ang2; end
            S_TRI_2A:    begin mul_a = A_val;  mul_b = FP_TWO; end
            S_TRI_T0:    begin mul_a = two_A;  mul_b = cos0; end
            S_TRI_T1:    begin mul_a = two_A;  mul_b = cos1; end
            S_TRI_T2:    begin mul_a = two_A;  mul_b = cos2; end
            S_TRI_X0:    begin add_a = t0;     add_b = ba3; add_sub = 1'b1; end
            S_TRI_X1:    begin add_a = t1;     add_b = ba3; add_sub = 1'b1; end
            S_TRI_X2:    begin add_a = t2;     add_b = ba3; add_sub = 1'b1; end
            // --- Cardano path ---
            S_CAR_Q24:   begin mul_a = q_sq;   mul_b = FP_QUARTER; end
            S_CAR_P327:  begin mul_a = p_cu;   mul_b = FP_ONE_27TH; end
            S_CAR_UNDER: begin add_a = q_sq_4; add_b = p_cu_27; add_sub = 1'b0; end
            S_CAR_SQ:    begin sqrt_in = under_sqrt; end
            S_CAR_NQ2:   begin mul_a = neg_q;  mul_b = FP_HALF; end
            S_CAR_S:     begin add_a = neg_q_2; add_b = sq_val; add_sub = 1'b0; end
            S_CAR_T:     begin add_a = neg_q_2; add_b = sq_val; add_sub = 1'b1; end
            S_CAR_CS:    begin cbrt_in = S_val; end
            S_CAR_CT:    begin cbrt_in = T_val; end
            S_CAR_T0:    begin add_a = cbrt_S; add_b = cbrt_T; add_sub = 1'b0; end
            S_CAR_X0:    begin add_a = t0;     add_b = ba3; add_sub = 1'b1; end
            default: ;
        endcase
    end

    // ---------------------------------------------------------------
    // FSM — sequential datapath
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            a_reg <= FP_ZERO; b_reg <= FP_ZERO;
            c_reg <= FP_ZERO; d_reg <= FP_ZERO;
            x0 <= NaN; x1 <= NaN; x2 <= NaN;
            // All other regs will be written before use
            ba <= FP_ZERO; ca <= FP_ZERO; da <= FP_ZERO; ba3 <= FP_ZERO;
            ba_sq <= FP_ZERO; ba_sq_3 <= FP_ZERO; p_reg <= FP_ZERO;
            ba_ca <= FP_ZERO; ba_ca_3 <= FP_ZERO; ba_cu <= FP_ZERO; ba_cu_27 <= FP_ZERO;
            q_tmp <= FP_ZERO; q_reg <= FP_ZERO;
            p_sq <= FP_ZERO; p_cu <= FP_ZERO; four_p3 <= FP_ZERO;
            q_sq <= FP_ZERO; t27q2 <= FP_ZERO; disc_sum <= FP_ZERO; disc <= FP_ZERO;
            neg_p <= FP_ZERO; neg_p_3 <= FP_ZERO; A_val <= FP_ZERO;
            A_cu <= FP_ZERO; two_A_cu <= FP_ZERO;
            neg_q <= FP_ZERO; cos_arg <= FP_ZERO;
            theta_full <= FP_ZERO; theta <= FP_ZERO;
            ang1 <= FP_ZERO; ang2 <= FP_ZERO;
            cos0 <= FP_ZERO; cos1 <= FP_ZERO; cos2 <= FP_ZERO;
            two_A <= FP_ZERO;
            t0 <= FP_ZERO; t1 <= FP_ZERO; t2 <= FP_ZERO;
            q_sq_4 <= FP_ZERO; p_cu_27 <= FP_ZERO; under_sqrt <= FP_ZERO;
            sq_val <= FP_ZERO; neg_q_2 <= FP_ZERO;
            S_val <= FP_ZERO; T_val <= FP_ZERO;
            cbrt_S <= FP_ZERO; cbrt_T <= FP_ZERO;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    if (in_valid) begin
                        a_reg <= a;
                        b_reg <= b;
                        c_reg <= c;
                        d_reg <= d;
                    end
                end

                S_LOAD: begin
                    // If a==0, output all NaN and go to DONE
                    if (is_fp_zero(a_reg)) begin
                        x0 <= NaN;
                        x1 <= NaN;
                        x2 <= NaN;
                    end
                end

                // --- Normalize ---
                S_NORM_BA:   ba      <= div_result;
                S_NORM_CA:   ca      <= div_result;
                S_NORM_DA:   da      <= div_result;
                S_NORM_BA3:  ba3     <= mul_result;

                // --- Depressed cubic ---
                S_DEP_BA2:   ba_sq   <= mul_result;
                S_DEP_BA2_3: ba_sq_3 <= mul_result;
                S_DEP_P:     p_reg   <= add_result;
                S_DEP_BACA:  ba_ca   <= mul_result;
                S_DEP_BACA3: ba_ca_3 <= mul_result;
                S_DEP_BA3CU: ba_cu   <= mul_result;
                S_DEP_BA3_27:ba_cu_27<= mul_result;
                S_DEP_QT:    q_tmp   <= add_result;
                S_DEP_Q:     q_reg   <= add_result;

                // --- Discriminant ---
                S_DISC_P2:   p_sq    <= mul_result;
                S_DISC_P3:   p_cu    <= mul_result;
                S_DISC_4P3:  four_p3 <= mul_result;
                S_DISC_Q2:   q_sq    <= mul_result;
                S_DISC_27Q2: t27q2   <= mul_result;
                S_DISC_SUM:  disc_sum<= add_result;
                S_DISC_NEG:  disc    <= fp_neg(disc_sum);

                // --- Branch (no register update, just state transition) ---
                S_BRANCH: begin
                    neg_p <= fp_neg(p_reg);
                    neg_q <= fp_neg(q_reg);
                end

                // --- Trigonometric path ---
                S_TRI_NP: begin
                    neg_p <= fp_neg(p_reg);
                end
                S_TRI_NP3:    neg_p_3    <= mul_result;
                S_TRI_A:      A_val      <= sqrt_out;
                S_TRI_ACU:    A_cu       <= mul_result;
                S_TRI_2ACU:   two_A_cu   <= mul_result;
                S_TRI_NQ: begin
                    neg_q <= fp_neg(q_reg);
                end
                S_TRI_ARG:    cos_arg    <= div_result;
                S_TRI_THETA:  theta_full <= acos_out;
                S_TRI_TH3:    theta      <= mul_result;
                S_TRI_ANG1:   ang1       <= add_result;
                S_TRI_ANG2:   ang2       <= add_result;
                S_TRI_COS0:   cos0       <= cos_out;
                S_TRI_COS1:   cos1       <= cos_out;
                S_TRI_COS2:   cos2       <= cos_out;
                S_TRI_2A:     two_A      <= mul_result;
                S_TRI_T0:     t0         <= mul_result;
                S_TRI_T1:     t1         <= mul_result;
                S_TRI_T2:     t2         <= mul_result;
                S_TRI_X0:     x0         <= add_result;
                S_TRI_X1:     x1         <= add_result;
                S_TRI_X2:     x2         <= add_result;

                // --- Cardano path ---
                S_CAR_Q24:    q_sq_4     <= mul_result;
                S_CAR_P327:   p_cu_27    <= mul_result;
                S_CAR_UNDER:  under_sqrt <= add_result;
                S_CAR_SQ:     sq_val     <= sqrt_out;
                S_CAR_NQ2:    neg_q_2    <= mul_result;
                S_CAR_S:      S_val      <= add_result;
                S_CAR_T:      T_val      <= add_result;
                S_CAR_CS:     cbrt_S     <= cbrt_out;
                S_CAR_CT:     cbrt_T     <= cbrt_out;
                S_CAR_T0:     t0         <= add_result;
                S_CAR_X0: begin
                    x0 <= add_result;
                    x1 <= NaN;
                    x2 <= NaN;
                end

                default: ;
            endcase
        end
    end

endmodule
