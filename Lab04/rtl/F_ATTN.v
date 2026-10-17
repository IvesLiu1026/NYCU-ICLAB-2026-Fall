module F_ATTN (
    input wire clk, input wire rst_n, input wire in_valid,
    input wire [31:0] Q, input wire [31:0] K, input wire [31:0] V,
    input wire [31:0] out_weight, output reg out_valid, output wire [31:0] out
);
parameter inst_sig_width=23;
parameter inst_exp_width=8;
parameter inst_ieee_compliance=0;
reg [7:0] cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 8'd0;
    else if (cnt == 8'd0) cnt <= in_valid ? 8'd1 : 8'd0;
    else cnt <= (cnt == 8'd128) ? 8'd0 : cnt + 8'd1;
end
wire [1:0] beat_d = cnt[1:0];

wire [7:0] cnt_nx = cnt + 8'd1;
reg c60, c61, c62, c63, c64, c65, f_pk, hu_ev, rH0, rZW, rH1, word_now, f_A;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin c60 <= 1'b0; c61 <= 1'b0; c62 <= 1'b0; c63 <= 1'b0; c64 <= 1'b0; c65 <= 1'b0; f_pk <= 1'b0; hu_ev <= 1'b0; rH0 <= 1'b0; rZW <= 1'b0; rH1 <= 1'b0; word_now <= 1'b0; f_A <= 1'b0; end
    else begin
        c60 <= cnt_nx == 8'd60;
        c61 <= cnt_nx == 8'd61;
        c62 <= cnt_nx == 8'd62;
        c63 <= cnt_nx == 8'd63;
        c64 <= cnt_nx == 8'd64;
        c65 <= cnt_nx == 8'd65;
        f_pk <= (cnt_nx >= 8'd60) && (cnt_nx <= 8'd63);
        hu_ev <= (cnt_nx == 8'd63) || (cnt_nx == 8'd65);
        rH0 <= (cnt_nx >= 8'd66) && (cnt_nx <= 8'd122) && (cnt_nx[1:0] == 2'd2);
        rZW <= (cnt_nx >= 8'd67) && (cnt_nx <= 8'd123) && (cnt_nx[1:0] == 2'd3);
        rH1 <= (cnt_nx >= 8'd68) && (cnt_nx <= 8'd124) && (cnt_nx[1:0] == 2'd0);
        word_now <= (cnt_nx >= 8'd64) && (cnt_nx <= 8'd127);
        f_A <= (cnt_nx == 8'd64) || ((cnt_nx >= 8'd68) && (cnt_nx <= 8'd124) && (cnt_nx[1:0] == 2'd0));
    end
end
wire [27:0] cap_k; wire signed [22:0] cap_v; wire signed [23:0] cap_w;
reg [31:0] wraw; reg [3:0] widx; reg wv;
always @(posedge clk or negedge rst_n) if (!rst_n) wv <= 1'b0; else wv <= in_valid && (cnt < 8'd16);
always @(posedge clk) if (in_valid && cnt < 8'd16) begin wraw <= out_weight; widx <= cnt[3:0]; end
cs_input_kvw u_cap(.K(K),.V(V),.W(wraw),.k(cap_k),.v(cap_v),.w(cap_w));
reg [27:0] rk0 [0:16];
reg signed [22:0] rv0 [0:16];
reg [27:0] rk1 [0:16];
reg signed [22:0] rv1 [0:16];
reg [27:0] rk2 [0:16];
reg signed [22:0] rv2 [0:16];
reg [27:0] rk3 [0:16];
reg signed [22:0] rv3 [0:16];
integer ri;
always @(posedge clk) begin
    for (ri = 0; ri < 17; ri = ri + 1) begin
        rk0[ri] <= rk0[(ri == 16) ? 0 : ri + 1];
        rv0[ri] <= rv0[(ri == 16) ? 0 : ri + 1];
        rk1[ri] <= rk1[(ri == 16) ? 0 : ri + 1];
        rv1[ri] <= rv1[(ri == 16) ? 0 : ri + 1];
        rk2[ri] <= rk2[(ri == 16) ? 0 : ri + 1];
        rv2[ri] <= rv2[(ri == 16) ? 0 : ri + 1];
        rk3[ri] <= rk3[(ri == 16) ? 0 : ri + 1];
        rv3[ri] <= rv3[(ri == 16) ? 0 : ri + 1];
    end
    if (in_valid && beat_d == 2'd0) begin rk0[4] <= cap_k; rv0[4] <= cap_v; end
    if (in_valid && beat_d == 2'd1) begin rk1[3] <= cap_k; rv1[3] <= cap_v; end
    if (in_valid && beat_d == 2'd2) begin rk2[2] <= cap_k; rv2[2] <= cap_v; end
    if (in_valid && beat_d == 2'd3) begin rk3[1] <= cap_k; rv3[1] <= cap_v; end
end
wire [55:0] tap00 = {rk0[3], rk1[3]};
wire [55:0] tap01 = {rk0[2], rk1[2]};
wire [55:0] tap10 = {rk2[1], rk3[1]};
wire [55:0] tap11 = {rk2[0], rk3[0]};

wire [45:0] vtap00 = {rv0[2], rv1[2]};
wire [45:0] vtap01 = {rv0[1], rv1[1]};
wire [45:0] vtap10 = {rv2[0], rv3[0]};
wire [45:0] vtap11 = {rv2[16], rv3[16]};
reg signed [23:0] wb [0:15];
always @(posedge clk) if (wv) wb[widx] <= cap_w;
reg signed [26:0] q_0_0_0, q_0_0_1;
reg signed [26:0] q_0_1_0, q_0_1_1;
reg signed [26:0] q_1_0_0, q_1_0_1;
reg signed [26:0] q_1_1_0, q_1_1_1;
reg signed [26:0] q_2_0_0, q_2_0_1;
reg signed [26:0] q_2_1_0, q_2_1_1;
reg signed [26:0] q_3_0_0, q_3_0_1;
reg signed [26:0] q_3_1_0, q_3_1_1;
reg signed [26:0] q_4_0_0, q_4_0_1;
reg signed [26:0] q_4_1_0, q_4_1_1;
reg signed [26:0] q_5_0_0, q_5_0_1;
reg signed [26:0] q_5_1_0, q_5_1_1;
reg signed [26:0] q_6_0_0, q_6_0_1;
reg signed [26:0] q_6_1_0, q_6_1_1;
reg signed [26:0] q_7_0_0, q_7_0_1;
reg signed [26:0] q_7_1_0, q_7_1_1;
reg signed [26:0] q_8_0_0, q_8_0_1;
reg signed [26:0] q_8_1_0, q_8_1_1;
reg signed [26:0] q_9_0_0, q_9_0_1;
reg signed [26:0] q_9_1_0, q_9_1_1;
reg signed [26:0] q_10_0_0, q_10_0_1;
reg signed [26:0] q_10_1_0, q_10_1_1;
reg signed [26:0] q_11_0_0, q_11_0_1;
reg signed [26:0] q_11_1_0, q_11_1_1;
reg signed [26:0] q_12_0_0, q_12_0_1;
reg signed [26:0] q_12_1_0, q_12_1_1;
reg signed [26:0] q_13_0_0, q_13_0_1;
reg signed [26:0] q_13_1_0, q_13_1_1;
reg signed [26:0] q_14_0_0, q_14_0_1;
reg signed [26:0] q_14_1_0, q_14_1_1;
reg signed [26:0] q_15_0_0, q_15_0_1;
reg signed [26:0] q_15_1_0, q_15_1_1;

reg [31:0] qraw; reg [5:0] qidx; reg qv;
always @(posedge clk or negedge rst_n) if (!rst_n) qv <= 1'b0; else qv <= in_valid;
always @(posedge clk) if (in_valid) begin qraw <= Q; qidx <= cnt[5:0]; end
wire signed [26:0] cq;
cs_cvtq u_cq(.x(qraw),.q(cq));
always @(posedge clk) if (qv) begin
    case (qidx)
        6'd0: q_0_0_0 <= cq;
        6'd1: q_0_0_1 <= cq;
        6'd2: q_0_1_0 <= cq;
        6'd3: q_0_1_1 <= cq;
        6'd4: q_1_0_0 <= cq;
        6'd5: q_1_0_1 <= cq;
        6'd6: q_1_1_0 <= cq;
        6'd7: q_1_1_1 <= cq;
        6'd8: q_2_0_0 <= cq;
        6'd9: q_2_0_1 <= cq;
        6'd10: q_2_1_0 <= cq;
        6'd11: q_2_1_1 <= cq;
        6'd12: q_3_0_0 <= cq;
        6'd13: q_3_0_1 <= cq;
        6'd14: q_3_1_0 <= cq;
        6'd15: q_3_1_1 <= cq;
        6'd16: q_4_0_0 <= cq;
        6'd17: q_4_0_1 <= cq;
        6'd18: q_4_1_0 <= cq;
        6'd19: q_4_1_1 <= cq;
        6'd20: q_5_0_0 <= cq;
        6'd21: q_5_0_1 <= cq;
        6'd22: q_5_1_0 <= cq;
        6'd23: q_5_1_1 <= cq;
        6'd24: q_6_0_0 <= cq;
        6'd25: q_6_0_1 <= cq;
        6'd26: q_6_1_0 <= cq;
        6'd27: q_6_1_1 <= cq;
        6'd28: q_7_0_0 <= cq;
        6'd29: q_7_0_1 <= cq;
        6'd30: q_7_1_0 <= cq;
        6'd31: q_7_1_1 <= cq;
        6'd32: q_8_0_0 <= cq;
        6'd33: q_8_0_1 <= cq;
        6'd34: q_8_1_0 <= cq;
        6'd35: q_8_1_1 <= cq;
        6'd36: q_9_0_0 <= cq;
        6'd37: q_9_0_1 <= cq;
        6'd38: q_9_1_0 <= cq;
        6'd39: q_9_1_1 <= cq;
        6'd40: q_10_0_0 <= cq;
        6'd41: q_10_0_1 <= cq;
        6'd42: q_10_1_0 <= cq;
        6'd43: q_10_1_1 <= cq;
        6'd44: q_11_0_0 <= cq;
        6'd45: q_11_0_1 <= cq;
        6'd46: q_11_1_0 <= cq;
        6'd47: q_11_1_1 <= cq;
        6'd48: q_12_0_0 <= cq;
        6'd49: q_12_0_1 <= cq;
        6'd50: q_12_1_0 <= cq;
        6'd51: q_12_1_1 <= cq;
        6'd52: q_13_0_0 <= cq;
        6'd53: q_13_0_1 <= cq;
        6'd54: q_13_1_0 <= cq;
        6'd55: q_13_1_1 <= cq;
        6'd56: q_14_0_0 <= cq;
        6'd57: q_14_0_1 <= cq;
        6'd58: q_14_1_0 <= cq;
        6'd59: q_14_1_1 <= cq;
        6'd60: q_15_0_0 <= cq;
        6'd61: q_15_0_1 <= cq;
        6'd62: q_15_1_0 <= cq;
        6'd63: q_15_1_1 <= cq;
        default: begin end
    endcase
end
reg [105:0] fst0;
reg [105:0] fst1;
reg v_0; reg h_0; reg d_0; reg [2:0] qs_0; reg [2:0] ss_0; reg sd_0;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin v_0<=1'b0; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
    else begin
        v_0<=1'b0; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0;
        case (cnt_nx)
            8'd3: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b1; end
            8'd7: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd11: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd13: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b1; end
            8'd14: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd17: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd18: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd20: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd21: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd22: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd23: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b1; end
            8'd24: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd25: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd26: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd27: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd28: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd29: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd30: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd31: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd32: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd33: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b1; end
            8'd34: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd35: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd36: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd37: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd38: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd39: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd40: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd41: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd42: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd43: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd44: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd45: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd46: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd47: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd48: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd49: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd50: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd51: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd52: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd53: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd54: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd55: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd56: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd57: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd58: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd0; ss_0<=3'd0; sd_0<=1'b0; end
            8'd59: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd60: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd61: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd62: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd63: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd64: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd65: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b1; end
            8'd66: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd67: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd1; ss_0<=3'd1; sd_0<=1'b0; end
            8'd68: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd69: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd70: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd71: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd72: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd73: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd74: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd75: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd76: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b1; end
            8'd77: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd2; ss_0<=3'd2; sd_0<=1'b0; end
            8'd78: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd79: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd80: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd81: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd82: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd83: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd84: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd85: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd86: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd87: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd3; ss_0<=3'd3; sd_0<=1'b0; end
            8'd88: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd89: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd90: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd91: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd92: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd93: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd94: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd95: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd96: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd97: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd98: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd4; ss_0<=3'd0; sd_0<=1'b0; end
            8'd99: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd100: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd101: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd102: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd103: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b0; qs_0<=3'd6; ss_0<=3'd4; sd_0<=1'b0; end
            8'd104: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd105: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd106: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd107: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd108: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd5; ss_0<=3'd1; sd_0<=1'b0; end
            8'd109: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b0; qs_0<=3'd7; ss_0<=3'd5; sd_0<=1'b0; end
            8'd110: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd6; ss_0<=3'd4; sd_0<=1'b0; end
            8'd111: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd6; ss_0<=3'd4; sd_0<=1'b0; end
            8'd112: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd7; ss_0<=3'd5; sd_0<=1'b0; end
            8'd114: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd7; ss_0<=3'd5; sd_0<=1'b0; end
            8'd116: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd6; ss_0<=3'd4; sd_0<=1'b0; end
            8'd117: begin v_0<=1'b1; h_0<=1'b0; d_0<=1'b1; qs_0<=3'd6; ss_0<=3'd4; sd_0<=1'b0; end
            8'd118: begin v_0<=1'b1; h_0<=1'b1; d_0<=1'b1; qs_0<=3'd7; ss_0<=3'd5; sd_0<=1'b0; end
            default: begin end
        endcase
    end
end
reg v_1; reg h_1; reg d_1; reg [2:0] qs_1; reg [2:0] ss_1; reg sd_1;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin v_1<=1'b0; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
    else begin
        v_1<=1'b0; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0;
        case (cnt_nx)
            8'd9: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b1; end
            8'd13: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd15: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b1; end
            8'd16: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd18: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd19: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd20: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd21: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd22: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd23: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd24: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd25: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b1; end
            8'd26: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd27: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd28: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd29: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd30: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd31: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd32: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd33: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd34: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd35: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b1; end
            8'd36: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd37: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd38: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd39: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd40: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd41: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd42: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd43: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd44: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd45: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd46: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd47: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd48: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd49: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd50: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd51: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd52: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd53: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd54: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd55: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd56: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd57: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd58: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd59: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd60: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd0; ss_1<=3'd0; sd_1<=1'b0; end
            8'd61: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd62: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b1; end
            8'd63: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd64: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd65: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd66: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd67: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd68: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd69: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd1; ss_1<=3'd1; sd_1<=1'b0; end
            8'd70: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd71: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd72: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd73: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd74: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd75: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd76: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd77: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd78: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd79: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd2; ss_1<=3'd2; sd_1<=1'b0; end
            8'd80: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd81: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd82: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b1; end
            8'd83: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd84: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd85: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd6; ss_1<=3'd4; sd_1<=1'b0; end
            8'd86: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd87: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd88: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd89: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd3; ss_1<=3'd3; sd_1<=1'b0; end
            8'd90: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd91: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b0; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd92: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd93: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd94: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd95: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd96: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd97: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd98: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd99: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd4; ss_1<=3'd0; sd_1<=1'b0; end
            8'd100: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd101: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd102: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd103: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd104: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd105: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd106: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd107: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd108: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd6; ss_1<=3'd4; sd_1<=1'b0; end
            8'd109: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd110: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b0; qs_1<=3'd5; ss_1<=3'd1; sd_1<=1'b0; end
            8'd111: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd7; ss_1<=3'd5; sd_1<=1'b0; end
            8'd112: begin v_1<=1'b1; h_1<=1'b0; d_1<=1'b1; qs_1<=3'd6; ss_1<=3'd4; sd_1<=1'b0; end
            8'd113: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd7; ss_1<=3'd5; sd_1<=1'b0; end
            8'd117: begin v_1<=1'b1; h_1<=1'b1; d_1<=1'b1; qs_1<=3'd7; ss_1<=3'd5; sd_1<=1'b0; end
            default: begin end
        endcase
    end
end
reg v_2; reg h_2; reg d_2; reg [2:0] qs_2; reg [2:0] ss_2; reg sd_2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin v_2<=1'b0; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
    else begin
        v_2<=1'b0; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0;
        case (cnt_nx)
            8'd7: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b1; end
            8'd10: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd14: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd17: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b1; end
            8'd18: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd20: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd21: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd22: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd23: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd24: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd25: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd26: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd27: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b1; end
            8'd28: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd29: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd30: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd31: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd32: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd33: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd34: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd35: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd36: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd37: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b1; end
            8'd38: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd39: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd40: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd41: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd42: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd43: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd44: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd45: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd46: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd47: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd48: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd49: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd50: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd51: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd52: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd53: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd54: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd55: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd56: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd57: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd58: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd59: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd60: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd61: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd62: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd0; ss_2<=3'd0; sd_2<=1'b0; end
            8'd63: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd64: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd65: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd66: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd67: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd68: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b1; end
            8'd69: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd70: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd71: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd1; ss_2<=3'd1; sd_2<=1'b0; end
            8'd72: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd73: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd74: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b1; end
            8'd75: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd76: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd77: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd78: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd79: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd80: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd81: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd2; ss_2<=3'd2; sd_2<=1'b0; end
            8'd82: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd83: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd84: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd85: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd86: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd87: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd88: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd89: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd90: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd91: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd92: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd3; ss_2<=3'd3; sd_2<=1'b0; end
            8'd93: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd94: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd95: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b0; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd96: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd97: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd98: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd99: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd100: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd101: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd102: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd4; ss_2<=3'd1; sd_2<=1'b0; end
            8'd103: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd104: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd7; ss_2<=3'd5; sd_2<=1'b0; end
            8'd105: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd7; ss_2<=3'd5; sd_2<=1'b0; end
            8'd106: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd107: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd108: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b1; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd109: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd110: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd111: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd112: begin v_2<=1'b1; h_2<=1'b1; d_2<=1'b0; qs_2<=3'd5; ss_2<=3'd0; sd_2<=1'b0; end
            8'd113: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd6; ss_2<=3'd4; sd_2<=1'b0; end
            8'd114: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd6; ss_2<=3'd4; sd_2<=1'b0; end
            8'd115: begin v_2<=1'b1; h_2<=1'b0; d_2<=1'b1; qs_2<=3'd6; ss_2<=3'd4; sd_2<=1'b0; end
            default: begin end
        endcase
    end
end
reg v_3; reg h_3; reg d_3; reg [2:0] qs_3; reg [2:0] ss_3; reg sd_3;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin v_3<=1'b0; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
    else begin
        v_3<=1'b0; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0;
        case (cnt_nx)
            8'd9: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b1; end
            8'd12: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd16: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd19: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b1; end
            8'd20: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd21: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd22: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd23: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd24: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd25: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd26: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd27: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd28: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd29: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b1; end
            8'd30: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd31: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd32: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd33: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd34: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd35: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd36: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd37: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd38: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd39: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b1; end
            8'd40: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd41: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd42: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd43: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd44: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd45: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd46: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd47: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd48: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd49: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd50: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd51: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd52: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd53: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd54: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd55: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd56: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd57: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd58: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd59: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd60: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd61: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd62: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd63: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd64: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd0; ss_3<=3'd0; sd_3<=1'b0; end
            8'd65: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd66: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b1; end
            8'd67: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd68: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd69: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd70: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd71: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd72: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd73: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd1; ss_3<=3'd1; sd_3<=1'b0; end
            8'd74: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd7; ss_3<=3'd5; sd_3<=1'b0; end
            8'd75: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd76: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd77: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd78: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b1; end
            8'd79: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd80: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd81: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd82: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd83: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd2; ss_3<=3'd2; sd_3<=1'b0; end
            8'd84: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd85: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd86: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd87: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd88: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd89: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd90: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd91: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd6; ss_3<=3'd4; sd_3<=1'b0; end
            8'd92: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd93: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd94: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd3; ss_3<=3'd3; sd_3<=1'b0; end
            8'd95: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd96: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd97: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd98: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd99: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd100: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd101: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd102: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd103: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd104: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd4; ss_3<=3'd0; sd_3<=1'b0; end
            8'd105: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd106: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd107: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd108: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b0; qs_3<=3'd7; ss_3<=3'd5; sd_3<=1'b0; end
            8'd109: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd110: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd111: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd112: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b1; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd113: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd114: begin v_3<=1'b1; h_3<=1'b0; d_3<=1'b0; qs_3<=3'd5; ss_3<=3'd1; sd_3<=1'b0; end
            8'd115: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd7; ss_3<=3'd5; sd_3<=1'b0; end
            8'd116: begin v_3<=1'b1; h_3<=1'b1; d_3<=1'b1; qs_3<=3'd7; ss_3<=3'd5; sd_3<=1'b0; end
            default: begin end
        endcase
    end
end
reg v_4; reg h_4; reg d_4; reg [2:0] qs_4; reg [2:0] ss_4; reg sd_4;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin v_4<=1'b0; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
    else begin
        v_4<=1'b0; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0;
        case (cnt_nx)
            8'd11: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b1; end
            8'd15: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd18: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd19: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd21: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b1; end
            8'd22: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd23: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd24: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd25: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd26: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd27: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd28: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd29: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd30: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd31: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b1; end
            8'd32: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd33: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd34: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd35: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd36: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd37: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd38: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd39: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd40: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd41: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd42: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd43: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd44: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd45: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd46: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b1; end
            8'd47: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd48: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd49: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd50: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd51: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd52: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd53: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd54: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd55: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd56: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd57: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd58: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd59: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd60: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd61: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd62: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd63: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd0; ss_4<=3'd0; sd_4<=1'b0; end
            8'd64: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd65: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd66: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd67: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd68: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b1; end
            8'd69: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd70: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd6; ss_4<=3'd4; sd_4<=1'b1; end
            8'd71: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd72: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd7; ss_4<=3'd5; sd_4<=1'b1; end
            8'd73: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd74: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd75: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd1; ss_4<=3'd1; sd_4<=1'b0; end
            8'd76: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd77: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd78: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd79: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd80: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd81: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd82: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd83: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd84: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd85: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd2; ss_4<=3'd2; sd_4<=1'b0; end
            8'd86: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd87: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b1; end
            8'd88: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd89: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd90: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd6; ss_4<=3'd4; sd_4<=1'b0; end
            8'd91: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd92: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd93: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd94: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd95: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd3; ss_4<=3'd3; sd_4<=1'b0; end
            8'd96: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd97: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd98: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd99: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd100: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd101: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd102: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd103: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd104: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd105: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd4; ss_4<=3'd0; sd_4<=1'b0; end
            8'd106: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b1; qs_4<=3'd6; ss_4<=3'd4; sd_4<=1'b0; end
            8'd107: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd108: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd109: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd110: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd111: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd112: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd113: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd114: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd115: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd116: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd5; ss_4<=3'd1; sd_4<=1'b0; end
            8'd118: begin v_4<=1'b1; h_4<=1'b0; d_4<=1'b0; qs_4<=3'd6; ss_4<=3'd4; sd_4<=1'b0; end
            8'd119: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b1; qs_4<=3'd7; ss_4<=3'd5; sd_4<=1'b0; end
            8'd120: begin v_4<=1'b1; h_4<=1'b1; d_4<=1'b0; qs_4<=3'd7; ss_4<=3'd5; sd_4<=1'b0; end
            default: begin end
        endcase
    end
end
wire [423:0] lst_0; wire fw0_0, fw1_0; wire [105:0] fwd_0;
cs_eng u_eng0(.clk(clk),.rst_n(rst_n),.v(v_0),.h(h_0),.d(d_0),.qs(qs_0),.ss(ss_0),.sd(sd_0),.tap00(tap00),.tap01(tap01),.tap10(tap10),.tap11(tap11),.vtap00(vtap00),.vtap01(vtap01),.vtap10(vtap10),.vtap11(vtap11),.qbus({q_15_1_0, q_15_1_1, q_15_0_0, q_15_0_1, q_12_1_0, q_12_1_1, q_10_0_0, q_10_0_1, q_7_1_0, q_7_1_1, q_5_0_0, q_5_0_1, q_2_1_0, q_2_1_1, q_0_0_0, q_0_0_1}),.fst0(fst0),.fst1(fst1),.lst(lst_0),.fw0(fw0_0),.fw1(fw1_0),.fwd(fwd_0));
wire [423:0] lst_1; wire fw0_1, fw1_1; wire [105:0] fwd_1;
cs_eng u_eng1(.clk(clk),.rst_n(rst_n),.v(v_1),.h(h_1),.d(d_1),.qs(qs_1),.ss(ss_1),.sd(sd_1),.tap00(tap00),.tap01(tap01),.tap10(tap10),.tap11(tap11),.vtap00(vtap00),.vtap01(vtap01),.vtap10(vtap10),.vtap11(vtap11),.qbus({q_15_1_0, q_15_1_1, q_15_0_0, q_15_0_1, q_13_0_0, q_13_0_1, q_10_1_0, q_10_1_1, q_8_0_0, q_8_0_1, q_5_1_0, q_5_1_1, q_3_0_0, q_3_0_1, q_0_1_0, q_0_1_1}),.fst0(fst0),.fst1(fst1),.lst(lst_1),.fw0(fw0_1),.fw1(fw1_1),.fwd(fwd_1));
wire [423:0] lst_2; wire fw0_2, fw1_2; wire [105:0] fwd_2;
cs_eng u_eng2(.clk(clk),.rst_n(rst_n),.v(v_2),.h(h_2),.d(d_2),.qs(qs_2),.ss(ss_2),.sd(sd_2),.tap00(tap00),.tap01(tap01),.tap10(tap10),.tap11(tap11),.vtap00(vtap00),.vtap01(vtap01),.vtap10(vtap10),.vtap11(vtap11),.qbus({q_15_1_0, q_15_1_1, q_15_0_0, q_15_0_1, q_13_1_0, q_13_1_1, q_11_0_0, q_11_0_1, q_8_1_0, q_8_1_1, q_6_0_0, q_6_0_1, q_3_1_0, q_3_1_1, q_1_0_0, q_1_0_1}),.fst0(fst0),.fst1(fst1),.lst(lst_2),.fw0(fw0_2),.fw1(fw1_2),.fwd(fwd_2));
wire [423:0] lst_3; wire fw0_3, fw1_3; wire [105:0] fwd_3;
cs_eng u_eng3(.clk(clk),.rst_n(rst_n),.v(v_3),.h(h_3),.d(d_3),.qs(qs_3),.ss(ss_3),.sd(sd_3),.tap00(tap00),.tap01(tap01),.tap10(tap10),.tap11(tap11),.vtap00(vtap00),.vtap01(vtap01),.vtap10(vtap10),.vtap11(vtap11),.qbus({q_15_1_0, q_15_1_1, q_15_0_0, q_15_0_1, q_14_0_0, q_14_0_1, q_11_1_0, q_11_1_1, q_9_0_0, q_9_0_1, q_6_1_0, q_6_1_1, q_4_0_0, q_4_0_1, q_1_1_0, q_1_1_1}),.fst0(fst0),.fst1(fst1),.lst(lst_3),.fw0(fw0_3),.fw1(fw1_3),.fwd(fwd_3));
wire [423:0] lst_4; wire fw0_4, fw1_4; wire [105:0] fwd_4;
cs_eng u_eng4(.clk(clk),.rst_n(rst_n),.v(v_4),.h(h_4),.d(d_4),.qs(qs_4),.ss(ss_4),.sd(sd_4),.tap00(tap00),.tap01(tap01),.tap10(tap10),.tap11(tap11),.vtap00(vtap00),.vtap01(vtap01),.vtap10(vtap10),.vtap11(vtap11),.qbus({q_15_1_0, q_15_1_1, q_15_0_0, q_15_0_1, q_14_1_0, q_14_1_1, q_12_0_0, q_12_0_1, q_9_1_0, q_9_1_1, q_7_0_0, q_7_0_1, q_4_1_0, q_4_1_1, q_2_0_0, q_2_0_1}),.fst0(fst0),.fst1(fst1),.lst(lst_4),.fw0(fw0_4),.fw1(fw1_4),.fwd(fwd_4));
always @(posedge clk) if (fw0_0 | fw0_1 | fw0_2 | fw0_3 | fw0_4) fst0 <= ({106{fw0_0}} & fwd_0) | ({106{fw0_1}} & fwd_1) | ({106{fw0_2}} & fwd_2) | ({106{fw0_3}} & fwd_3) | ({106{fw0_4}} & fwd_4);
always @(posedge clk) if (fw1_0 | fw1_1 | fw1_2 | fw1_3 | fw1_4) fst1 <= ({106{fw1_0}} & fwd_0) | ({106{fw1_1}} & fwd_1) | ({106{fw1_2}} & fwd_2) | ({106{fw1_3}} & fwd_3) | ({106{fw1_4}} & fwd_4);
reg rd_now; reg cap_now; reg [2:0] cap_e;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin rd_now <= 1'b0; cap_now <= 1'b0; cap_e <= 3'd0; end
    else begin
        rd_now <= 1'b0; cap_now <= 1'b0; cap_e <= 3'd0;
        case (cnt_nx)
            8'd61: rd_now <= 1'b1;
            8'd63: rd_now <= 1'b1;
            8'd65: rd_now <= 1'b1;
            8'd67: rd_now <= 1'b1;
            8'd69: rd_now <= 1'b1;
            8'd71: rd_now <= 1'b1;
            8'd73: rd_now <= 1'b1;
            8'd75: rd_now <= 1'b1;
            8'd77: rd_now <= 1'b1;
            8'd79: rd_now <= 1'b1;
            8'd81: rd_now <= 1'b1;
            8'd83: rd_now <= 1'b1;
            8'd85: rd_now <= 1'b1;
            8'd87: rd_now <= 1'b1;
            8'd89: rd_now <= 1'b1;
            8'd91: rd_now <= 1'b1;
            8'd93: rd_now <= 1'b1;
            8'd95: rd_now <= 1'b1;
            8'd97: rd_now <= 1'b1;
            8'd99: rd_now <= 1'b1;
            8'd101: rd_now <= 1'b1;
            8'd103: rd_now <= 1'b1;
            8'd105: rd_now <= 1'b1;
            8'd107: rd_now <= 1'b1;
            8'd109: rd_now <= 1'b1;
            8'd111: rd_now <= 1'b1;
            8'd113: rd_now <= 1'b1;
            8'd115: rd_now <= 1'b1;
            8'd117: rd_now <= 1'b1;
            8'd119: rd_now <= 1'b1;
            8'd121: rd_now <= 1'b1;
            8'd123: rd_now <= 1'b1;
            default: begin end
        endcase
        case (cnt_nx)
            8'd60: begin cap_now <= 1'b1; cap_e <= 3'd0; end
            8'd62: begin cap_now <= 1'b1; cap_e <= 3'd1; end
            8'd64: begin cap_now <= 1'b1; cap_e <= 3'd2; end
            8'd66: begin cap_now <= 1'b1; cap_e <= 3'd3; end
            8'd69: begin cap_now <= 1'b1; cap_e <= 3'd0; end
            8'd71: begin cap_now <= 1'b1; cap_e <= 3'd1; end
            8'd73: begin cap_now <= 1'b1; cap_e <= 3'd2; end
            8'd75: begin cap_now <= 1'b1; cap_e <= 3'd3; end
            8'd77: begin cap_now <= 1'b1; cap_e <= 3'd4; end
            8'd79: begin cap_now <= 1'b1; cap_e <= 3'd0; end
            8'd81: begin cap_now <= 1'b1; cap_e <= 3'd1; end
            8'd83: begin cap_now <= 1'b1; cap_e <= 3'd2; end
            8'd85: begin cap_now <= 1'b1; cap_e <= 3'd3; end
            8'd87: begin cap_now <= 1'b1; cap_e <= 3'd4; end
            8'd89: begin cap_now <= 1'b1; cap_e <= 3'd0; end
            8'd91: begin cap_now <= 1'b1; cap_e <= 3'd1; end
            8'd94: begin cap_now <= 1'b1; cap_e <= 3'd2; end
            8'd96: begin cap_now <= 1'b1; cap_e <= 3'd3; end
            8'd97: begin cap_now <= 1'b1; cap_e <= 3'd4; end
            8'd100: begin cap_now <= 1'b1; cap_e <= 3'd0; end
            8'd101: begin cap_now <= 1'b1; cap_e <= 3'd1; end
            8'd104: begin cap_now <= 1'b1; cap_e <= 3'd2; end
            8'd106: begin cap_now <= 1'b1; cap_e <= 3'd3; end
            8'd107: begin cap_now <= 1'b1; cap_e <= 3'd4; end
            8'd110: begin cap_now <= 1'b1; cap_e <= 3'd0; end
            8'd112: begin cap_now <= 1'b1; cap_e <= 3'd1; end
            8'd114: begin cap_now <= 1'b1; cap_e <= 3'd2; end
            8'd116: begin cap_now <= 1'b1; cap_e <= 3'd3; end
            8'd118: begin cap_now <= 1'b1; cap_e <= 3'd4; end
            8'd120: begin cap_now <= 1'b1; cap_e <= 3'd4; end
            8'd122: begin cap_now <= 1'b1; cap_e <= 3'd4; end
            default: begin end
        endcase
    end
end
reg [105:0] ps;
reg [105:0] capmux;
always @(*) begin
    case (cap_e)
        3'd0: capmux = fwd_0;
        3'd1: capmux = fwd_1;
        3'd2: capmux = fwd_2;
        3'd3: capmux = fwd_3;
        3'd4: capmux = fwd_4;
        default: capmux = fwd_0;
    endcase
end
reg slcap;
always @(posedge clk or negedge rst_n) if (!rst_n) slcap <= 1'b0; else slcap <= (cnt_nx == 8'd68);
always @(posedge clk) if (cap_now) ps <= capmux; else if (slcap) ps <= lst_4[105:0];
wire [105:0] zsrc = cap_now ? capmux : ps;
wire [105:0] pst = ps;
wire signed [9:0] pr_m = pst[105:96];
wire [31:0] pr_l = pst[95:64];
wire signed [31:0] pr_z0 = pst[63:32]; wire signed [31:0] pr_z1 = pst[31:0];
wire [24:0] rc_y; wire [2:0] rc_e; wire [30:0] rc_n;
cs_rcp u_rc(.l(pr_l),.y(rc_y),.e(rc_e),.nrm(rc_n));
wire [21:0] lg_b; wire [15:0] lg_i;
cs_log2 u_lg(.nrm(rc_n),.lb_o(lg_b),.li_o(lg_i));

wire signed [10:0] me = $signed({pr_m[9], pr_m}) + $signed({8'd0, rc_e});
reg [2:0] e_r;
always @(posedge clk) if (rd_now) e_r <= rc_e;


wire [23:0] kmant = {1'b1, K[22:0]}; wire [7:0] kexp = K[30:23]; wire ksgn = K[31];
wire [23:0] vmant = (V[30:23] == 8'd0) ? {1'b0, V[22:0]} : {1'b1, V[22:0]}; wire [7:0] vexp = (V[30:23] == 8'd0) ? 8'd1 : V[30:23]; wire vsgn = V[31];
reg [36:0] pa; reg [8:0] ea; reg [36:0] pb; reg [8:0] eb; reg signed [46:0] cm;
wire [8:0] kexp1h = {kexp == 8'd134, kexp == 8'd133, kexp == 8'd132, kexp == 8'd131, kexp == 8'd130, kexp == 8'd129, kexp == 8'd128, kexp == 8'd127, kexp == 8'd126};
wire signed [53:0] pa_f = {pa, 17'd0}; wire signed [53:0] pb_f = {pb, 17'd0};

function signed [44:0] kal; input signed [36:0] p; input [8:0] oh;
    reg signed [44:0] f; begin f = {{8{p[36]}}, p};
    kal = ($signed({45{oh[0]}}) & (f <<< 0)) | ($signed({45{oh[1]}}) & (f <<< 1)) | ($signed({45{oh[2]}}) & (f <<< 2)) | ($signed({45{oh[3]}}) & (f <<< 3)) | ($signed({45{oh[4]}}) & (f <<< 4)) | ($signed({45{oh[5]}}) & (f <<< 5)) | ($signed({45{oh[6]}}) & (f <<< 6)) | ($signed({45{oh[7]}}) & (f <<< 7)) | ($signed({45{oh[8]}}) & (f <<< 8));
    end
endfunction
wire signed [44:0] pa_al = kal(pa, ea);
wire signed [44:0] pb_al = kal(pb, eb);
wire signed [46:0] xs = cm + $signed({{2{pb_al[44]}}, pb_al});
wire signed [34:0] sg_x = $signed(xs[45:11]);
wire sg_neg; wire [22:0] sg_b; wire [12:0] sg_i; wire [22:0] sg_v; wire [12:0] sg_d; wire [13:0] sg_lt;
cs_sig3 u_sg(.x(sg_x),.neg(sg_neg),.b(sg_b),.i(sg_i),.v(sg_v),.d(sg_d),.lt(sg_lt));
reg signed [24:0] th0, th1, hcA0, hcA1, hcB0, hcB1, hc2, hc3;

wire signed [22:0] ev0 = c62 ? rv0[3] : rv2[1];
wire signed [22:0] ev1 = c62 ? rv1[3] : rv3[1];

reg signed [28:0] ha0, ha1; reg signed [25:0] hb0, hb1;
wire signed [28:0] hu_a0 = ha0; wire signed [28:0] hu_a1 = ha1;
wire signed [25:0] hu_b0 = hb0; wire signed [25:0] hu_b1 = hb1;

wire [54:0] hu_c0 = hu_ev ? {{8{th0[24]}}, th0, 1'b1, 21'd0} : 55'd0;
wire [54:0] hu_c1 = hu_ev ? {{8{th1[24]}}, th1, 1'b1, 21'd0} : 55'd0;
wire signed [54:0] hu_p0; tm_h u_h0(.a(hu_a0),.b(hu_b0),.c(hu_c0),.p(hu_p0));
wire signed [54:0] hu_p1; tm_h u_h1(.a(hu_a1),.b(hu_b1),.c(hu_c1),.p(hu_p1));
wire signed [28:0] hu_sl0 = hu_p0[52:24]; wire signed [28:0] hu_sl1 = hu_p1[52:24];
wire signed [28:0] hu_hs0 = hu_sl0 >>> e_r; wire signed [28:0] hu_hs1 = hu_sl1 >>> e_r;
wire signed [24:0] hu_o0 = hu_ev ? $signed(hu_p0[46:22]) : hu_hs0[24:0];
wire signed [24:0] hu_o1 = hu_ev ? $signed(hu_p1[46:22]) : hu_hs1[24:0];
wire signed [25:0] eun0 = $signed({ev0, 2'b00}) - hu_o0;
wire signed [25:0] eun1 = $signed({ev1, 2'b00}) - hu_o1;
always @(posedge clk) begin
    if (c62 || c64) begin ha0 <= {{3{eun0[25]}}, eun0}; ha1 <= {{3{eun1[25]}}, eun1}; hb0 <= {3'b000, sg_v}; hb1 <= {3'b000, sg_v}; end
    else if (rd_now) begin ha0 <= pr_z0[31:3]; ha1 <= pr_z1[31:3]; hb0 <= {1'b0, rc_y}; hb1 <= {1'b0, rc_y}; end
    else if (rH0) begin ha0 <= zsrc[63:35]; ha1 <= zsrc[31:3]; hb0 <= {{2{wb[2][23]}}, wb[2]}; hb1 <= {{2{wb[3][23]}}, wb[3]}; end
end
wire signed [35:0] hu_zs = $signed(hu_p0[54:20]) + $signed(hu_p1[54:20]);
wire signed [31:0] z01_0 = pr_z0; wire signed [31:0] z01_1 = pr_z1;
reg signed [31:0] pa_r; reg signed [25:0] pb_r;
reg signed [26:0] pu_a0, pu_a1; reg signed [24:0] pu_a3; reg signed [23:0] pu_b0, pu_b1; reg signed [24:0] pu_b3; reg pu_f3;
wire hsel = cnt[2];
always @(*) begin
    pu_a0 = hsel ? {{2{hcB0[24]}}, hcB0} : {{2{hcA0[24]}}, hcA0};
    pu_a1 = hsel ? {{2{hcB1[24]}}, hcB1} : {{2{hcA1[24]}}, hcA1};
    pu_a3 = hc3; pu_f3 = 1'b0;
    pu_b0 = wb[{cnt[1:0], 2'd0}]; pu_b1 = wb[{cnt[1:0], 2'd1}];
    pu_b3 = {wb[{cnt[1:0], 2'd3}][23], wb[{cnt[1:0], 2'd3}]};
    if (c63) begin pu_a0 = z01_0[31:5]; pu_a1 = z01_1[31:5]; pu_b0 = wb[2]; pu_b1 = wb[3];
        pu_a3 = {1'b0, vmant}; pu_b3 = {wb[3][23], wb[3]}; pu_f3 = vsgn; end

    if (c65) begin pu_a0 = {{2{hu_o0[24]}}, hu_o0}; pu_b0 = wb[6]; pu_a1 = {{2{hu_o1[24]}}, hu_o1}; pu_b1 = wb[7];
        pu_a3 = hcA1; pu_b3 = {wb[5][23], wb[5]}; end
end


wire signed [50:0] pu_p0; tm_p01 u_p0(.a(pu_a0),.b(pu_b0),.p(pu_p0));
wire signed [50:0] pu_p1; tm_p01 u_p1(.a(pu_a1),.b(pu_b1),.p(pu_p1));
wire signed [33:0] pu_zw = $signed(pu_p0[50:18]) + $signed(pu_p1[50:18]);
wire signed [26:0] gg;
wire [57:0] p2c = c64 ? {{4{gg[26]}}, gg, 27'd0} : 58'd0;
wire signed [57:0] pu_p2; tm_pa u_p2(.a(pa_r),.b(pb_r),.flip(c64),.c(p2c),.p(pu_p2));
wire signed [49:0] pu_p3; tm_p3f u_p3(.a(pu_a3),.b(pu_b3),.flip(pu_f3),.p(pu_p3));
wire signed [31:0] pu_s01h = $signed(pu_p0[48:18]) + $signed(pu_p1[48:18]);
wire signed [31:0] pu_s23h = $signed(pu_p2[48:18]) + $signed(pu_p3[48:18]);
wire signed [32:0] pu_toth = $signed(pu_p0[48:18]) + $signed(pu_p1[48:18]) + $signed(pu_p2[48:18]) + $signed(pu_p3[48:18]);
wire [1:0] wn = cnt_nx[1:0];
wire word_nx = (cnt_nx >= 8'd64) && (cnt_nx <= 8'd127);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin pa_r <= 32'sd0; pb_r <= 26'sd0; end
    else if (c62) begin pa_r <= {{9{cap_v[22]}}, cap_v}; pb_r <= {{2{wb[2][23]}}, wb[2]}; end
    else if (c63) begin pa_r <= $signed(pu_zw[31:0]) >>> rc_e; pb_r <= $signed({1'b0, rc_y}); end
    else if (rZW) begin pa_r <= $signed(hu_zs[31:0]) >>> rc_e; pb_r <= $signed({1'b0, rc_y}); end
    else if (c64) begin pa_r <= {{7{hcA0[24]}}, hcA0}; pb_r <= {{2{wb[4][23]}}, wb[4]}; end
    else if (c65 || rH1) begin pa_r <= {{7{hu_o0[24]}}, hu_o0}; pb_r <= {{2{wb[{wn, 2'd2}][23]}}, wb[{wn, 2'd2}]}; end
    else if (word_nx && wn != 2'd0) begin pa_r <= {{7{hc2[24]}}, hc2}; pb_r <= {{2{wb[{wn, 2'd2}][23]}}, wb[{wn, 2'd2}]}; end
    else begin pa_r <= 32'sd0; pb_r <= 26'sd0; end
end
reg signed [30:0] g2r; reg signed [31:0] g3r; reg [7:0] e3r; wire signed [37:0] ts_zw;
always @(posedge clk) begin
    if (c63) begin g2r <= pu_p2[48:18]; g3r <= pu_p3[49:18]; e3r <= vexp; end
end
wire signed [49:0] g3f = {g3r, 18'd0};
wire [7:0] g3sh = 8'd128 - e3r;
wire signed [49:0] g3a = (g3sh >= 8'd48) ? $signed({50{g3f[49]}}) : (g3f >>> g3sh);
wire signed [49:0] gsum = $signed({{1{g2r[30]}}, g2r, 18'd0}) + g3a;
assign gg = gsum[47:21];

reg signed [26:0] pk_q;
always @(*) begin
    case (cnt[1:0])
        2'd0: pk_q = q_0_0_0;
        2'd1: pk_q = q_0_0_1;
        2'd2: pk_q = q_0_1_0;
        default: pk_q = q_0_1_1;
    endcase
end
wire signed [24:0] a0_h = pu_p2[51:27];
wire signed [26:0] u0 = pu_p2[53:27];
wire signed [24:0] t1_a = f_pk ? $signed({1'b0, kmant}) : $signed({2'b00, sg_b});
wire signed [26:0] t1_b = f_pk ? pk_q : u0; wire t1_f = f_pk ? ksgn : sg_neg;
wire signed [51:0] tsm_p1; tm_t1f u_t1(.a(t1_a),.b(t1_b),.flip(t1_f),.p(tsm_p1));
assign ts_zw = 38'sd0;
always @(posedge clk) begin
    if (c60 || c62) begin pa <= {{2{tsm_p1[51]}}, tsm_p1[51:17]}; ea <= kexp1h; end
    if (c61 || c63) begin pb <= {{2{tsm_p1[51]}}, tsm_p1[51:17]}; eb <= kexp1h;
        cm <= $signed({{2{pa_al[44]}}, pa_al}) - $signed({me, 33'd0}) - $signed({14'd0, lg_b, 11'd0}) - $signed({20'd0, lg_i, 11'd0}); end
end

wire signed [41:0] ulf; tm_ul u_ul(.a(u0),.b($signed({1'b0, sg_lt})),.p(ulf));
wire signed [27:0] ul = ulf[41:14];
wire signed [41:0] uis; tm_ud u_ud(.a(ul),.b($signed({1'b0, sg_d})),.p(uis));
wire signed [32:0] ui17 = $signed(uis[41:17]);
always @(posedge clk) begin
    if (c62 || c64) begin th0 <= hu_o0; th1 <= hu_o1; end
    if (c63 || (rH0 && cnt[2])) begin hcA0 <= hu_o0; hcA1 <= hu_o1; end
    if (rH0 && !cnt[2]) begin hcB0 <= hu_o0; hcB1 <= hu_o1; end
    if (c65 || rH1) begin hc2 <= hu_o0; hc3 <= hu_o1; end
end
reg signed [32:0] out_s, out_c, out_d;
wire signed [26:0] w0_q = sg_neg ? gg : (gg - u0);
wire signed [32:0] w0_s = $signed({pu_s01h[31], pu_s01h}) + $signed({{1{w0_q[26]}}, w0_q, 5'd0}) + $signed({32'd0, sg_neg});
wire signed [32:0] wr_s = $signed({pu_s01h[31], pu_s01h}) + $signed({{3{a0_h[24]}}, a0_h, 5'd0});
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin out_valid <= 1'b0; out_s <= 33'sd0; out_c <= 33'sd0; out_d <= 33'sd0; end
    else begin
        out_valid <= word_now;
        if (c64) begin out_s <= w0_s; out_c <= tsm_p1[49:17]; out_d <= ui17 ^ {33{sg_neg}}; end
        else if (rH1) begin out_s <= {pu_s01h[31], pu_s01h}; out_c <= $signed({{3{a0_h[24]}}, a0_h, 5'd0}); out_d <= 33'sd0; end
        else if (word_now) begin out_s <= {pu_s01h[31], pu_s01h}; out_c <= {pu_s23h[31], pu_s23h}; out_d <= 33'sd0; end
        else begin out_s <= 33'sd0; out_c <= 33'sd0; out_d <= 33'sd0; end
    end
end
cs_fmt u_fmt(.s(out_s),.c(out_c),.d(out_d),.out(out));
endmodule


module cs_fmt(input wire signed [32:0] s, input wire signed [32:0] c, input wire signed [32:0] d, output wire [31:0] out);

parameter inst_sig_width=23;
parameter inst_exp_width=8;
wire signed [32:0] out_t = s + c + d;
wire signed [28:0] result_fixed = out_t[30:2];
wire [28:0] magnitude = result_fixed[28] ? ~result_fixed : result_fixed;
wire [31:0] float_word; wire [7:0] float_status;
DW_fp_i2flt #(inst_sig_width,inst_exp_width,29,0) u_formatter(.a(magnitude),.rnd(3'b001),.z(float_word),.status(float_status));
wire [7:0] adjusted_exponent = float_word[30:23] - 8'd27;
assign out = (magnitude == 29'd0) ? 32'd0 : {result_fixed[28], adjusted_exponent, float_word[22:0]};
endmodule


module cs_eng(input wire clk, input wire rst_n, input wire v, input wire h, input wire d, input wire [2:0] qs,
              input wire [2:0] ss, input wire sd, input wire [55:0] tap00, input wire [55:0] tap01,
              input wire [55:0] tap10, input wire [55:0] tap11, input wire [45:0] vtap00, input wire [45:0] vtap01,
              input wire [45:0] vtap10, input wire [45:0] vtap11, input wire [431:0] qbus,
              input wire [105:0] fst0, input wire [105:0] fst1, output wire [423:0] lst,
              output wire fw0, output wire fw1, output wire [105:0] fwd);

reg [55:0] tp;
always @(*) begin
    case ({h, d})
        2'b00: tp = tap00;
        2'b01: tp = tap01;
        2'b10: tp = tap10;
        default: tp = tap11;
    endcase
end
wire [53:0] qq = qbus[54*qs +: 54];
wire signed [26:0] q0 = qq[53:27];
wire signed [26:0] q1 = qq[26:0];
wire signed [33:0] s;
cs_score u_sc(.q0(q0),.q1(q1),.k0(tp[55:28]),.k1(tp[27:0]),.s(s));
reg p1v, p1sd; reg [2:0] p1ss; reg signed [33:0] p1s; reg [1:0] p1hd;
always @(posedge clk or negedge rst_n) if (!rst_n) p1v <= 1'b0; else p1v <= v;
always @(posedge clk) begin p1sd <= sd; p1ss <= ss; p1s <= s; p1hd <= {h, d}; end

reg [45:0] vt;
always @(*) begin
    case (p1hd)
        2'b00: vt = vtap00;
        2'b01: vt = vtap01;
        2'b10: vt = vtap10;
        default: vt = vtap11;
    endcase
end
wire signed [22:0] p1v0 = vt[45:23];
wire signed [22:0] p1v1 = vt[22:0];

wire [19:0] pm;
cs_exp u_ex(.f(p1s[23:0]),.m(pm));
wire signed [43:0] vp0;
tm_v u_v0(.a(p1v0),.b($signed({1'b0, pm})),.p(vp0));
wire signed [43:0] vp1;
tm_v u_v1(.a(p1v1),.b($signed({1'b0, pm})),.p(vp1));
reg p2v, p2sd; reg [2:0] p2ss; reg signed [9:0] p2n; reg [19:0] p2m; reg signed [25:0] p2w0, p2w1;
always @(posedge clk or negedge rst_n) if (!rst_n) p2v <= 1'b0; else p2v <= p1v;
always @(posedge clk) begin p2sd <= p1sd; p2ss <= p1ss; p2n <= p1s[33:24]; p2m <= pm; p2w0 <= vp0[41:16]; p2w1 <= vp1[41:16]; end

reg [105:0] sl0, sl1, sl2, sl3;
assign lst = {sl3, sl2, sl1, sl0};
reg [105:0] st;
always @(*) begin
    case (p2ss)
        3'd0: st = sl0;
        3'd1: st = sl1;
        3'd2: st = sl2;
        3'd3: st = sl3;
        3'd4: st = fst0;
        default: st = fst1;
    endcase
end
wire signed [9:0] mn; wire [31:0] ln; wire signed [31:0] zn0, zn1;
cs_upd u_up(.n(p2n),.p({p2m, 8'd0}),.w0({p2w0, 2'b00}),.w1({p2w1, 2'b00}),.seed(p2sd),.m(st[105:96]),.l(st[95:64]),
            .z0(st[63:32]),.z1(st[31:0]),.mn(mn),.ln(ln),.zn0(zn0),.zn1(zn1));
wire [105:0] nst = {mn, ln & 32'hfffffff0, zn0 & 32'hfffffffe, zn1 & 32'hfffffffe};
assign fwd = nst;
assign fw0 = p2v && (p2ss == 3'd4);
assign fw1 = p2v && (p2ss == 3'd5);
always @(posedge clk) begin
    if (p2v && p2ss == 3'd0) sl0 <= nst;
    if (p2v && p2ss == 3'd1) sl1 <= nst;
    if (p2v && p2ss == 3'd2) sl2 <= nst;
    if (p2v && p2ss == 3'd3) sl3 <= nst;
end
endmodule


module cs_score(input wire signed [26:0] q0, input wire signed [26:0] q1, input wire [27:0] k0, input wire [27:0] k1,
                output wire signed [33:0] s);

wire signed [51:0] cp0;
tm_s u_m0(.a(q0),.b($signed({1'b0, k0[23:0]})),.flip(k0[24]),.p(cp0));
wire signed [51:0] cp1;
tm_s u_m1(.a(q1),.b($signed({1'b0, k1[23:0]})),.flip(k1[24]),.p(cp1));

wire signed [33:0] h0 = cp0[51:18];
wire signed [33:0] h1 = cp1[51:18];
wire signed [37:0] x0 = $signed({{4{h0[33]}}, h0}) <<< k0[27:25];
wire signed [37:0] x1 = $signed({{4{h1[33]}}, h1}) <<< k1[27:25];
wire signed [38:0] total = $signed({x0[37], x0}) + $signed({x1[37], x1});
assign s = total[37:4];
endmodule

module cs_upd(input wire signed [9:0] n, input wire [27:0] p, input wire signed [27:0] w0, input wire signed [27:0] w1,
              input wire seed, input wire signed [9:0] m, input wire [31:0] l, input wire signed [31:0] z0,
              input wire signed [31:0] z1, output wire signed [9:0] mn, output wire [31:0] ln,
              output wire signed [31:0] zn0, output wire signed [31:0] zn1);
wire signed [31:0] weight0 = {{4{w0[27]}}, w0};
wire signed [31:0] weight1 = {{4{w1[27]}}, w1};
wire signed [10:0] delta = $signed({n[9], n}) - $signed({m[9], m});
wire rise = (n > m);
wire [10:0] absolute_delta = delta[10] ? $unsigned(-delta) : $unsigned(delta);
wire [9:0] distance = absolute_delta[9:0];
wire far = (distance >= 10'd32);
wire [4:0] shift = distance[4:0];
wire [31:0] selected_l = rise ? l : {4'd0, p};
wire [31:0] add_l = rise ? {4'd0, p} : l;
wire [31:0] shifted_l = far ? 32'd0 : selected_l >> shift;
wire signed [31:0] selected_z0 = rise ? z0 : weight0;
wire signed [31:0] selected_z1 = rise ? z1 : weight1;
wire signed [31:0] add_z0 = rise ? weight0 : z0;
wire signed [31:0] add_z1 = rise ? weight1 : z1;
wire signed [31:0] shifted_z0 = far ? $signed({32{selected_z0[31]}}) : selected_z0 >>> shift;
wire signed [31:0] shifted_z1 = far ? $signed({32{selected_z1[31]}}) : selected_z1 >>> shift;
assign mn = (seed || rise) ? n : m;
assign ln = seed ? {4'd0, p} : shifted_l + add_l;
assign zn0 = seed ? weight0 : shifted_z0 + add_z0;
assign zn1 = seed ? weight1 : shifted_z1 + add_z1;
endmodule

module cs_log2(input wire [30:0] nrm, output wire [21:0] lb_o, output wire [15:0] li_o);

reg [21:0] lb; reg [15:0] ld;
always @(*) begin
    case (nrm[29:23])
        8'd0: begin lb = 22'd23; ld = 16'd47091; end
        8'd1: begin lb = 22'd47113; ld = 16'd46726; end
        8'd2: begin lb = 22'd93839; ld = 16'd46369; end
        8'd3: begin lb = 22'd140208; ld = 16'd46016; end
        8'd4: begin lb = 22'd186224; ld = 16'd45669; end
        8'd5: begin lb = 22'd231892; ld = 16'd45327; end
        8'd6: begin lb = 22'd277219; ld = 16'd44990; end
        8'd7: begin lb = 22'd322208; ld = 16'd44658; end
        8'd8: begin lb = 22'd366866; ld = 16'd44330; end
        8'd9: begin lb = 22'd411196; ld = 16'd44009; end
        8'd10: begin lb = 22'd455204; ld = 16'd43690; end
        8'd11: begin lb = 22'd498895; ld = 16'd43377; end
        8'd12: begin lb = 22'd542271; ld = 16'd43069; end
        8'd13: begin lb = 22'd585340; ld = 16'd42764; end
        8'd14: begin lb = 22'd628104; ld = 16'd42464; end
        8'd15: begin lb = 22'd670567; ld = 16'd42168; end
        8'd16: begin lb = 22'd712735; ld = 16'd41876; end
        8'd17: begin lb = 22'd754611; ld = 16'd41589; end
        8'd18: begin lb = 22'd796199; ld = 16'd41305; end
        8'd19: begin lb = 22'd837504; ld = 16'd41024; end
        8'd20: begin lb = 22'd878528; ld = 16'd40748; end
        8'd21: begin lb = 22'd919276; ld = 16'd40476; end
        8'd22: begin lb = 22'd959752; ld = 16'd40207; end
        8'd23: begin lb = 22'd999959; ld = 16'd39941; end
        8'd24: begin lb = 22'd1039899; ld = 16'd39680; end
        8'd25: begin lb = 22'd1079579; ld = 16'd39421; end
        8'd26: begin lb = 22'd1119000; ld = 16'd39166; end
        8'd27: begin lb = 22'd1158165; ld = 16'd38914; end
        8'd28: begin lb = 22'd1197079; ld = 16'd38665; end
        8'd29: begin lb = 22'd1235744; ld = 16'd38420; end
        8'd30: begin lb = 22'd1274164; ld = 16'd38177; end
        8'd31: begin lb = 22'd1312341; ld = 16'd37938; end
        8'd32: begin lb = 22'd1350279; ld = 16'd37702; end
        8'd33: begin lb = 22'd1387981; ld = 16'd37468; end
        8'd34: begin lb = 22'd1425448; ld = 16'd37238; end
        8'd35: begin lb = 22'd1462686; ld = 16'd37010; end
        8'd36: begin lb = 22'd1499696; ld = 16'd36785; end
        8'd37: begin lb = 22'd1536481; ld = 16'd36562; end
        8'd38: begin lb = 22'd1573043; ld = 16'd36343; end
        8'd39: begin lb = 22'd1609385; ld = 16'd36127; end
        8'd40: begin lb = 22'd1645512; ld = 16'd35911; end
        8'd41: begin lb = 22'd1681423; ld = 16'd35700; end
        8'd42: begin lb = 22'd1717123; ld = 16'd35490; end
        8'd43: begin lb = 22'd1752613; ld = 16'd35284; end
        8'd44: begin lb = 22'd1787897; ld = 16'd35079; end
        8'd45: begin lb = 22'd1822975; ld = 16'd34877; end
        8'd46: begin lb = 22'd1857852; ld = 16'd34677; end
        8'd47: begin lb = 22'd1892529; ld = 16'd34479; end
        8'd48: begin lb = 22'd1927008; ld = 16'd34284; end
        8'd49: begin lb = 22'd1961292; ld = 16'd34091; end
        8'd50: begin lb = 22'd1995383; ld = 16'd33899; end
        8'd51: begin lb = 22'd2029282; ld = 16'd33711; end
        8'd52: begin lb = 22'd2062992; ld = 16'd33525; end
        8'd53: begin lb = 22'd2096517; ld = 16'd33339; end
        8'd54: begin lb = 22'd2129856; ld = 16'd33157; end
        8'd55: begin lb = 22'd2163013; ld = 16'd32976; end
        8'd56: begin lb = 22'd2195989; ld = 16'd32797; end
        8'd57: begin lb = 22'd2228786; ld = 16'd32621; end
        8'd58: begin lb = 22'd2261407; ld = 16'd32446; end
        8'd59: begin lb = 22'd2293853; ld = 16'd32272; end
        8'd60: begin lb = 22'd2326124; ld = 16'd32102; end
        8'd61: begin lb = 22'd2358226; ld = 16'd31932; end
        8'd62: begin lb = 22'd2390158; ld = 16'd31764; end
        8'd63: begin lb = 22'd2421922; ld = 16'd31599; end
        8'd64: begin lb = 22'd2453521; ld = 16'd31434; end
        8'd65: begin lb = 22'd2484955; ld = 16'd31272; end
        8'd66: begin lb = 22'd2516227; ld = 16'd31111; end
        8'd67: begin lb = 22'd2547338; ld = 16'd30952; end
        8'd68: begin lb = 22'd2578290; ld = 16'd30794; end
        8'd69: begin lb = 22'd2609084; ld = 16'd30639; end
        8'd70: begin lb = 22'd2639723; ld = 16'd30484; end
        8'd71: begin lb = 22'd2670206; ld = 16'd30332; end
        8'd72: begin lb = 22'd2700538; ld = 16'd30180; end
        8'd73: begin lb = 22'd2730718; ld = 16'd30030; end
        8'd74: begin lb = 22'd2760748; ld = 16'd29882; end
        8'd75: begin lb = 22'd2790630; ld = 16'd29735; end
        8'd76: begin lb = 22'd2820365; ld = 16'd29590; end
        8'd77: begin lb = 22'd2849955; ld = 16'd29446; end
        8'd78: begin lb = 22'd2879401; ld = 16'd29303; end
        8'd79: begin lb = 22'd2908704; ld = 16'd29162; end
        8'd80: begin lb = 22'd2937866; ld = 16'd29022; end
        8'd81: begin lb = 22'd2966888; ld = 16'd28884; end
        8'd82: begin lb = 22'd2995771; ld = 16'd28746; end
        8'd83: begin lb = 22'd3024517; ld = 16'd28611; end
        8'd84: begin lb = 22'd3053128; ld = 16'd28475; end
        8'd85: begin lb = 22'd3081603; ld = 16'd28343; end
        8'd86: begin lb = 22'd3109946; ld = 16'd28210; end
        8'd87: begin lb = 22'd3138156; ld = 16'd28080; end
        8'd88: begin lb = 22'd3166236; ld = 16'd27949; end
        8'd89: begin lb = 22'd3194185; ld = 16'd27822; end
        8'd90: begin lb = 22'd3222007; ld = 16'd27693; end
        8'd91: begin lb = 22'd3249700; ld = 16'd27568; end
        8'd92: begin lb = 22'd3277268; ld = 16'd27443; end
        8'd93: begin lb = 22'd3304710; ld = 16'd27319; end
        8'd94: begin lb = 22'd3332029; ld = 16'd27196; end
        8'd95: begin lb = 22'd3359225; ld = 16'd27074; end
        8'd96: begin lb = 22'd3386299; ld = 16'd26954; end
        8'd97: begin lb = 22'd3413253; ld = 16'd26834; end
        8'd98: begin lb = 22'd3440087; ld = 16'd26716; end
        8'd99: begin lb = 22'd3466803; ld = 16'd26598; end
        8'd100: begin lb = 22'd3493401; ld = 16'd26482; end
        8'd101: begin lb = 22'd3519883; ld = 16'd26366; end
        8'd102: begin lb = 22'd3546249; ld = 16'd26252; end
        8'd103: begin lb = 22'd3572501; ld = 16'd26139; end
        8'd104: begin lb = 22'd3598640; ld = 16'd26026; end
        8'd105: begin lb = 22'd3624666; ld = 16'd25915; end
        8'd106: begin lb = 22'd3650581; ld = 16'd25805; end
        8'd107: begin lb = 22'd3676386; ld = 16'd25694; end
        8'd108: begin lb = 22'd3702080; ld = 16'd25586; end
        8'd109: begin lb = 22'd3727666; ld = 16'd25479; end
        8'd110: begin lb = 22'd3753145; ld = 16'd25371; end
        8'd111: begin lb = 22'd3778516; ld = 16'd25266; end
        8'd112: begin lb = 22'd3803782; ld = 16'd25160; end
        8'd113: begin lb = 22'd3828941; ld = 16'd25057; end
        8'd114: begin lb = 22'd3853998; ld = 16'd24953; end
        8'd115: begin lb = 22'd3878951; ld = 16'd24850; end
        8'd116: begin lb = 22'd3903802; ld = 16'd24749; end
        8'd117: begin lb = 22'd3928551; ld = 16'd24648; end
        8'd118: begin lb = 22'd3953199; ld = 16'd24548; end
        8'd119: begin lb = 22'd3977747; ld = 16'd24449; end
        8'd120: begin lb = 22'd4002195; ld = 16'd24351; end
        8'd121: begin lb = 22'd4026546; ld = 16'd24253; end
        8'd122: begin lb = 22'd4050799; ld = 16'd24156; end
        8'd123: begin lb = 22'd4074955; ld = 16'd24060; end
        8'd124: begin lb = 22'd4099015; ld = 16'd23965; end
        8'd125: begin lb = 22'd4122980; ld = 16'd23870; end
        8'd126: begin lb = 22'd4146850; ld = 16'd23777; end
        8'd127: begin lb = 22'd4170626; ld = 16'd23683; end
        default: begin lb = 22'd0; ld = 16'd0; end
    endcase
end
wire [29:0] lprod = ld * nrm[22:9];
wire [29:0] lrnd = lprod + 30'd8192;
assign lb_o = lb; assign li_o = lrnd[29:14];
endmodule

module cs_sig3(input wire signed [34:0] x, output wire neg, output wire [22:0] b, output wire [12:0] i, output wire [22:0] v,
               output wire [12:0] d, output wire [13:0] lt);

assign neg = x[34];
wire [34:0] a = neg ? ~x : x;
wire sat = (a >= 35'd100663296);
wire [4:0] ai = a[26:22];
wire [21:0] f = a[21:0];
reg [9:0] ca; reg [2:0] sg;
always @(*) begin
    ca = 10'd0; sg = 3'd0;
    case (ai)
        5'd0: begin ca = 10'd0; sg = 3'd0; end
        5'd1: begin ca = 10'd128; sg = 3'd0; end
        5'd2: begin ca = 10'd256; sg = 3'd0; end
        5'd3: begin ca = 10'd384; sg = 3'd0; end
        5'd4: begin ca = 10'd512; sg = 3'd1; end
        5'd5: begin ca = 10'd576; sg = 3'd1; end
        5'd6: begin ca = 10'd640; sg = 3'd2; end
        5'd7: begin ca = 10'd672; sg = 3'd2; end
        5'd8: begin ca = 10'd704; sg = 3'd3; end
        5'd9: begin ca = 10'd720; sg = 3'd3; end
        5'd10: begin ca = 10'd736; sg = 3'd4; end
        5'd11: begin ca = 10'd744; sg = 3'd4; end
        5'd12: begin ca = 10'd752; sg = 3'd5; end
        5'd13: begin ca = 10'd756; sg = 3'd5; end
        5'd14: begin ca = 10'd760; sg = 3'd6; end
        5'd15: begin ca = 10'd762; sg = 3'd6; end
        5'd16: begin ca = 10'd764; sg = 3'd6; end
        5'd17: begin ca = 10'd766; sg = 3'd6; end
        5'd18: begin ca = 10'd768; sg = 3'd6; end
        5'd19: begin ca = 10'd770; sg = 3'd6; end
        5'd20: begin ca = 10'd772; sg = 3'd6; end
        5'd21: begin ca = 10'd774; sg = 3'd6; end
        5'd22: begin ca = 10'd776; sg = 3'd6; end
        5'd23: begin ca = 10'd778; sg = 3'd6; end
        default: begin ca = 10'd0; sg = 3'd0; end
    endcase
end
reg [9:0] adr; reg [13:0] ltr;
always @(*) begin
    adr = ca; ltr = 14'd0;
    case (sg)
        3'd0: begin adr = ca | {3'd0, f[21:15]}; ltr = f[14:1]; end
        3'd1: begin adr = ca | {4'd0, f[21:16]}; ltr = f[15:2]; end
        3'd2: begin adr = ca | {5'd0, f[21:17]}; ltr = f[16:3]; end
        3'd3: begin adr = ca | {6'd0, f[21:18]}; ltr = f[17:4]; end
        3'd4: begin adr = ca | {7'd0, f[21:19]}; ltr = f[18:5]; end
        3'd5: begin adr = ca | {8'd0, f[21:20]}; ltr = f[19:6]; end
        3'd6: begin adr = ca | {9'd0, f[21:21]}; ltr = f[20:7]; end
        default: begin end
    endcase
end
reg [22:0] tb; reg [13:0] td;
always @(*) begin
    case (adr)
        10'd0: begin tb = 23'd2097152; td = 14'd5678; end
        10'd1: begin tb = 23'd2102830; td = 14'd5678; end
        10'd2: begin tb = 23'd2108508; td = 14'd5678; end
        10'd3: begin tb = 23'd2114186; td = 14'd5678; end
        10'd4: begin tb = 23'd2119864; td = 14'd5678; end
        10'd5: begin tb = 23'd2125542; td = 14'd5677; end
        10'd6: begin tb = 23'd2131219; td = 14'd5676; end
        10'd7: begin tb = 23'd2136895; td = 14'd5676; end
        10'd8: begin tb = 23'd2142571; td = 14'd5675; end
        10'd9: begin tb = 23'd2148246; td = 14'd5675; end
        10'd10: begin tb = 23'd2153921; td = 14'd5673; end
        10'd11: begin tb = 23'd2159594; td = 14'd5673; end
        10'd12: begin tb = 23'd2165267; td = 14'd5672; end
        10'd13: begin tb = 23'd2170939; td = 14'd5671; end
        10'd14: begin tb = 23'd2176610; td = 14'd5669; end
        10'd15: begin tb = 23'd2182279; td = 14'd5668; end
        10'd16: begin tb = 23'd2187947; td = 14'd5667; end
        10'd17: begin tb = 23'd2193614; td = 14'd5666; end
        10'd18: begin tb = 23'd2199280; td = 14'd5664; end
        10'd19: begin tb = 23'd2204944; td = 14'd5662; end
        10'd20: begin tb = 23'd2210606; td = 14'd5661; end
        10'd21: begin tb = 23'd2216267; td = 14'd5659; end
        10'd22: begin tb = 23'd2221926; td = 14'd5657; end
        10'd23: begin tb = 23'd2227583; td = 14'd5656; end
        10'd24: begin tb = 23'd2233239; td = 14'd5653; end
        10'd25: begin tb = 23'd2238892; td = 14'd5651; end
        10'd26: begin tb = 23'd2244543; td = 14'd5650; end
        10'd27: begin tb = 23'd2250193; td = 14'd5646; end
        10'd28: begin tb = 23'd2255839; td = 14'd5645; end
        10'd29: begin tb = 23'd2261484; td = 14'd5642; end
        10'd30: begin tb = 23'd2267126; td = 14'd5640; end
        10'd31: begin tb = 23'd2272766; td = 14'd5637; end
        10'd32: begin tb = 23'd2278403; td = 14'd5635; end
        10'd33: begin tb = 23'd2284038; td = 14'd5631; end
        10'd34: begin tb = 23'd2289670; td = 14'd5629; end
        10'd35: begin tb = 23'd2295299; td = 14'd5626; end
        10'd36: begin tb = 23'd2300924; td = 14'd5624; end
        10'd37: begin tb = 23'd2306548; td = 14'd5620; end
        10'd38: begin tb = 23'd2312168; td = 14'd5617; end
        10'd39: begin tb = 23'd2317785; td = 14'd5614; end
        10'd40: begin tb = 23'd2323399; td = 14'd5610; end
        10'd41: begin tb = 23'd2329009; td = 14'd5607; end
        10'd42: begin tb = 23'd2334616; td = 14'd5604; end
        10'd43: begin tb = 23'd2340220; td = 14'd5600; end
        10'd44: begin tb = 23'd2345820; td = 14'd5597; end
        10'd45: begin tb = 23'd2351417; td = 14'd5593; end
        10'd46: begin tb = 23'd2357010; td = 14'd5589; end
        10'd47: begin tb = 23'd2362599; td = 14'd5585; end
        10'd48: begin tb = 23'd2368184; td = 14'd5582; end
        10'd49: begin tb = 23'd2373766; td = 14'd5577; end
        10'd50: begin tb = 23'd2379343; td = 14'd5574; end
        10'd51: begin tb = 23'd2384917; td = 14'd5569; end
        10'd52: begin tb = 23'd2390486; td = 14'd5565; end
        10'd53: begin tb = 23'd2396051; td = 14'd5561; end
        10'd54: begin tb = 23'd2401612; td = 14'd5556; end
        10'd55: begin tb = 23'd2407168; td = 14'd5552; end
        10'd56: begin tb = 23'd2412720; td = 14'd5547; end
        10'd57: begin tb = 23'd2418268; td = 14'd5543; end
        10'd58: begin tb = 23'd2423811; td = 14'd5538; end
        10'd59: begin tb = 23'd2429348; td = 14'd5534; end
        10'd60: begin tb = 23'd2434882; td = 14'd5528; end
        10'd61: begin tb = 23'd2440410; td = 14'd5524; end
        10'd62: begin tb = 23'd2445934; td = 14'd5519; end
        10'd63: begin tb = 23'd2451453; td = 14'd5513; end
        10'd64: begin tb = 23'd2456966; td = 14'd5509; end
        10'd65: begin tb = 23'd2462475; td = 14'd5503; end
        10'd66: begin tb = 23'd2467979; td = 14'd5498; end
        10'd67: begin tb = 23'd2473476; td = 14'd5493; end
        10'd68: begin tb = 23'd2478970; td = 14'd5487; end
        10'd69: begin tb = 23'd2484457; td = 14'd5482; end
        10'd70: begin tb = 23'd2489938; td = 14'd5477; end
        10'd71: begin tb = 23'd2495415; td = 14'd5470; end
        10'd72: begin tb = 23'd2500886; td = 14'd5465; end
        10'd73: begin tb = 23'd2506351; td = 14'd5459; end
        10'd74: begin tb = 23'd2511809; td = 14'd5454; end
        10'd75: begin tb = 23'd2517263; td = 14'd5447; end
        10'd76: begin tb = 23'd2522710; td = 14'd5442; end
        10'd77: begin tb = 23'd2528152; td = 14'd5435; end
        10'd78: begin tb = 23'd2533587; td = 14'd5429; end
        10'd79: begin tb = 23'd2539017; td = 14'd5423; end
        10'd80: begin tb = 23'd2544440; td = 14'd5417; end
        10'd81: begin tb = 23'd2549856; td = 14'd5411; end
        10'd82: begin tb = 23'd2555267; td = 14'd5404; end
        10'd83: begin tb = 23'd2560671; td = 14'd5397; end
        10'd84: begin tb = 23'd2566069; td = 14'd5391; end
        10'd85: begin tb = 23'd2571459; td = 14'd5385; end
        10'd86: begin tb = 23'd2576844; td = 14'd5378; end
        10'd87: begin tb = 23'd2582222; td = 14'd5371; end
        10'd88: begin tb = 23'd2587593; td = 14'd5364; end
        10'd89: begin tb = 23'd2592957; td = 14'd5358; end
        10'd90: begin tb = 23'd2598315; td = 14'd5350; end
        10'd91: begin tb = 23'd2603665; td = 14'd5344; end
        10'd92: begin tb = 23'd2609009; td = 14'd5336; end
        10'd93: begin tb = 23'd2614346; td = 14'd5329; end
        10'd94: begin tb = 23'd2619674; td = 14'd5323; end
        10'd95: begin tb = 23'd2624997; td = 14'd5314; end
        10'd96: begin tb = 23'd2630312; td = 14'd5308; end
        10'd97: begin tb = 23'd2635620; td = 14'd5300; end
        10'd98: begin tb = 23'd2640920; td = 14'd5293; end
        10'd99: begin tb = 23'd2646213; td = 14'd5285; end
        10'd100: begin tb = 23'd2651498; td = 14'd5278; end
        10'd101: begin tb = 23'd2656776; td = 14'd5270; end
        10'd102: begin tb = 23'd2662045; td = 14'd5263; end
        10'd103: begin tb = 23'd2667308; td = 14'd5254; end
        10'd104: begin tb = 23'd2672563; td = 14'd5247; end
        10'd105: begin tb = 23'd2677810; td = 14'd5239; end
        10'd106: begin tb = 23'd2683049; td = 14'd5231; end
        10'd107: begin tb = 23'd2688280; td = 14'd5223; end
        10'd108: begin tb = 23'd2693503; td = 14'd5215; end
        10'd109: begin tb = 23'd2698718; td = 14'd5207; end
        10'd110: begin tb = 23'd2703925; td = 14'd5199; end
        10'd111: begin tb = 23'd2709123; td = 14'd5191; end
        10'd112: begin tb = 23'd2714314; td = 14'd5182; end
        10'd113: begin tb = 23'd2719497; td = 14'd5174; end
        10'd114: begin tb = 23'd2724671; td = 14'd5166; end
        10'd115: begin tb = 23'd2729837; td = 14'd5157; end
        10'd116: begin tb = 23'd2734993; td = 14'd5149; end
        10'd117: begin tb = 23'd2740142; td = 14'd5140; end
        10'd118: begin tb = 23'd2745282; td = 14'd5132; end
        10'd119: begin tb = 23'd2750414; td = 14'd5123; end
        10'd120: begin tb = 23'd2755537; td = 14'd5114; end
        10'd121: begin tb = 23'd2760652; td = 14'd5105; end
        10'd122: begin tb = 23'd2765757; td = 14'd5097; end
        10'd123: begin tb = 23'd2770854; td = 14'd5088; end
        10'd124: begin tb = 23'd2775941; td = 14'd5079; end
        10'd125: begin tb = 23'd2781020; td = 14'd5070; end
        10'd126: begin tb = 23'd2786090; td = 14'd5061; end
        10'd127: begin tb = 23'd2791151; td = 14'd5052; end
        10'd128: begin tb = 23'd2796203; td = 14'd5042; end
        10'd129: begin tb = 23'd2801246; td = 14'd5034; end
        10'd130: begin tb = 23'd2806280; td = 14'd5024; end
        10'd131: begin tb = 23'd2811303; td = 14'd5016; end
        10'd132: begin tb = 23'd2816319; td = 14'd5005; end
        10'd133: begin tb = 23'd2821325; td = 14'd4997; end
        10'd134: begin tb = 23'd2826322; td = 14'd4987; end
        10'd135: begin tb = 23'd2831308; td = 14'd4978; end
        10'd136: begin tb = 23'd2836286; td = 14'd4968; end
        10'd137: begin tb = 23'd2841254; td = 14'd4959; end
        10'd138: begin tb = 23'd2846213; td = 14'd4949; end
        10'd139: begin tb = 23'd2851162; td = 14'd4939; end
        10'd140: begin tb = 23'd2856101; td = 14'd4930; end
        10'd141: begin tb = 23'd2861031; td = 14'd4920; end
        10'd142: begin tb = 23'd2865951; td = 14'd4910; end
        10'd143: begin tb = 23'd2870861; td = 14'd4901; end
        10'd144: begin tb = 23'd2875762; td = 14'd4890; end
        10'd145: begin tb = 23'd2880653; td = 14'd4881; end
        10'd146: begin tb = 23'd2885533; td = 14'd4871; end
        10'd147: begin tb = 23'd2890404; td = 14'd4861; end
        10'd148: begin tb = 23'd2895265; td = 14'd4850; end
        10'd149: begin tb = 23'd2900116; td = 14'd4841; end
        10'd150: begin tb = 23'd2904957; td = 14'd4831; end
        10'd151: begin tb = 23'd2909787; td = 14'd4821; end
        10'd152: begin tb = 23'd2914608; td = 14'd4810; end
        10'd153: begin tb = 23'd2919419; td = 14'd4800; end
        10'd154: begin tb = 23'd2924219; td = 14'd4790; end
        10'd155: begin tb = 23'd2929009; td = 14'd4780; end
        10'd156: begin tb = 23'd2933789; td = 14'd4769; end
        10'd157: begin tb = 23'd2938558; td = 14'd4759; end
        10'd158: begin tb = 23'd2943317; td = 14'd4749; end
        10'd159: begin tb = 23'd2948066; td = 14'd4738; end
        10'd160: begin tb = 23'd2952804; td = 14'd4728; end
        10'd161: begin tb = 23'd2957532; td = 14'd4717; end
        10'd162: begin tb = 23'd2962249; td = 14'd4707; end
        10'd163: begin tb = 23'd2966956; td = 14'd4696; end
        10'd164: begin tb = 23'd2971652; td = 14'd4686; end
        10'd165: begin tb = 23'd2976337; td = 14'd4675; end
        10'd166: begin tb = 23'd2981013; td = 14'd4664; end
        10'd167: begin tb = 23'd2985676; td = 14'd4654; end
        10'd168: begin tb = 23'd2990330; td = 14'd4643; end
        10'd169: begin tb = 23'd2994973; td = 14'd4632; end
        10'd170: begin tb = 23'd2999606; td = 14'd4621; end
        10'd171: begin tb = 23'd3004227; td = 14'd4611; end
        10'd172: begin tb = 23'd3008838; td = 14'd4599; end
        10'd173: begin tb = 23'd3013437; td = 14'd4589; end
        10'd174: begin tb = 23'd3018026; td = 14'd4578; end
        10'd175: begin tb = 23'd3022604; td = 14'd4567; end
        10'd176: begin tb = 23'd3027171; td = 14'd4556; end
        10'd177: begin tb = 23'd3031727; td = 14'd4545; end
        10'd178: begin tb = 23'd3036271; td = 14'd4535; end
        10'd179: begin tb = 23'd3040806; td = 14'd4523; end
        10'd180: begin tb = 23'd3045329; td = 14'd4512; end
        10'd181: begin tb = 23'd3049842; td = 14'd4500; end
        10'd182: begin tb = 23'd3054342; td = 14'd4490; end
        10'd183: begin tb = 23'd3058832; td = 14'd4479; end
        10'd184: begin tb = 23'd3063311; td = 14'd4467; end
        10'd185: begin tb = 23'd3067778; td = 14'd4457; end
        10'd186: begin tb = 23'd3072234; td = 14'd4445; end
        10'd187: begin tb = 23'd3076679; td = 14'd4434; end
        10'd188: begin tb = 23'd3081114; td = 14'd4422; end
        10'd189: begin tb = 23'd3085536; td = 14'd4412; end
        10'd190: begin tb = 23'd3089947; td = 14'd4400; end
        10'd191: begin tb = 23'd3094347; td = 14'd4389; end
        10'd192: begin tb = 23'd3098736; td = 14'd4377; end
        10'd193: begin tb = 23'd3103114; td = 14'd4366; end
        10'd194: begin tb = 23'd3107479; td = 14'd4355; end
        10'd195: begin tb = 23'd3111834; td = 14'd4343; end
        10'd196: begin tb = 23'd3116178; td = 14'd4332; end
        10'd197: begin tb = 23'd3120510; td = 14'd4320; end
        10'd198: begin tb = 23'd3124830; td = 14'd4309; end
        10'd199: begin tb = 23'd3129139; td = 14'd4298; end
        10'd200: begin tb = 23'd3133437; td = 14'd4286; end
        10'd201: begin tb = 23'd3137723; td = 14'd4274; end
        10'd202: begin tb = 23'd3141997; td = 14'd4263; end
        10'd203: begin tb = 23'd3146260; td = 14'd4252; end
        10'd204: begin tb = 23'd3150512; td = 14'd4240; end
        10'd205: begin tb = 23'd3154752; td = 14'd4228; end
        10'd206: begin tb = 23'd3158980; td = 14'd4217; end
        10'd207: begin tb = 23'd3163197; td = 14'd4205; end
        10'd208: begin tb = 23'd3167402; td = 14'd4194; end
        10'd209: begin tb = 23'd3171596; td = 14'd4182; end
        10'd210: begin tb = 23'd3175778; td = 14'd4170; end
        10'd211: begin tb = 23'd3179948; td = 14'd4159; end
        10'd212: begin tb = 23'd3184107; td = 14'd4147; end
        10'd213: begin tb = 23'd3188254; td = 14'd4135; end
        10'd214: begin tb = 23'd3192389; td = 14'd4124; end
        10'd215: begin tb = 23'd3196513; td = 14'd4112; end
        10'd216: begin tb = 23'd3200625; td = 14'd4100; end
        10'd217: begin tb = 23'd3204725; td = 14'd4089; end
        10'd218: begin tb = 23'd3208814; td = 14'd4077; end
        10'd219: begin tb = 23'd3212891; td = 14'd4065; end
        10'd220: begin tb = 23'd3216956; td = 14'd4053; end
        10'd221: begin tb = 23'd3221009; td = 14'd4042; end
        10'd222: begin tb = 23'd3225051; td = 14'd4030; end
        10'd223: begin tb = 23'd3229081; td = 14'd4018; end
        10'd224: begin tb = 23'd3233098; td = 14'd4007; end
        10'd225: begin tb = 23'd3237105; td = 14'd3994; end
        10'd226: begin tb = 23'd3241100; td = 14'd3983; end
        10'd227: begin tb = 23'd3245083; td = 14'd3971; end
        10'd228: begin tb = 23'd3249054; td = 14'd3959; end
        10'd229: begin tb = 23'd3253013; td = 14'd3948; end
        10'd230: begin tb = 23'd3256961; td = 14'd3935; end
        10'd231: begin tb = 23'd3260896; td = 14'd3924; end
        10'd232: begin tb = 23'd3264820; td = 14'd3912; end
        10'd233: begin tb = 23'd3268732; td = 14'd3900; end
        10'd234: begin tb = 23'd3272632; td = 14'd3889; end
        10'd235: begin tb = 23'd3276521; td = 14'd3876; end
        10'd236: begin tb = 23'd3280397; td = 14'd3865; end
        10'd237: begin tb = 23'd3284262; td = 14'd3853; end
        10'd238: begin tb = 23'd3288115; td = 14'd3841; end
        10'd239: begin tb = 23'd3291956; td = 14'd3829; end
        10'd240: begin tb = 23'd3295785; td = 14'd3818; end
        10'd241: begin tb = 23'd3299603; td = 14'd3805; end
        10'd242: begin tb = 23'd3303408; td = 14'd3794; end
        10'd243: begin tb = 23'd3307202; td = 14'd3782; end
        10'd244: begin tb = 23'd3310984; td = 14'd3770; end
        10'd245: begin tb = 23'd3314754; td = 14'd3758; end
        10'd246: begin tb = 23'd3318512; td = 14'd3747; end
        10'd247: begin tb = 23'd3322259; td = 14'd3734; end
        10'd248: begin tb = 23'd3325993; td = 14'd3723; end
        10'd249: begin tb = 23'd3329716; td = 14'd3711; end
        10'd250: begin tb = 23'd3333427; td = 14'd3699; end
        10'd251: begin tb = 23'd3337126; td = 14'd3687; end
        10'd252: begin tb = 23'd3340813; td = 14'd3676; end
        10'd253: begin tb = 23'd3344489; td = 14'd3663; end
        10'd254: begin tb = 23'd3348152; td = 14'd3652; end
        10'd255: begin tb = 23'd3351804; td = 14'd3640; end
        10'd256: begin tb = 23'd3355444; td = 14'd3628; end
        10'd257: begin tb = 23'd3359072; td = 14'd3617; end
        10'd258: begin tb = 23'd3362689; td = 14'd3604; end
        10'd259: begin tb = 23'd3366293; td = 14'd3593; end
        10'd260: begin tb = 23'd3369886; td = 14'd3581; end
        10'd261: begin tb = 23'd3373467; td = 14'd3569; end
        10'd262: begin tb = 23'd3377036; td = 14'd3558; end
        10'd263: begin tb = 23'd3380594; td = 14'd3545; end
        10'd264: begin tb = 23'd3384139; td = 14'd3534; end
        10'd265: begin tb = 23'd3387672; td = 14'd3523; end
        10'd266: begin tb = 23'd3391195; td = 14'd3510; end
        10'd267: begin tb = 23'd3394705; td = 14'd3499; end
        10'd268: begin tb = 23'd3398204; td = 14'd3487; end
        10'd269: begin tb = 23'd3401691; td = 14'd3475; end
        10'd270: begin tb = 23'd3405167; td = 14'd3463; end
        10'd271: begin tb = 23'd3408630; td = 14'd3452; end
        10'd272: begin tb = 23'd3412082; td = 14'd3440; end
        10'd273: begin tb = 23'd3415522; td = 14'd3428; end
        10'd274: begin tb = 23'd3418950; td = 14'd3417; end
        10'd275: begin tb = 23'd3422367; td = 14'd3405; end
        10'd276: begin tb = 23'd3425771; td = 14'd3394; end
        10'd277: begin tb = 23'd3429165; td = 14'd3381; end
        10'd278: begin tb = 23'd3432547; td = 14'd3370; end
        10'd279: begin tb = 23'd3435917; td = 14'd3359; end
        10'd280: begin tb = 23'd3439275; td = 14'd3347; end
        10'd281: begin tb = 23'd3442622; td = 14'd3335; end
        10'd282: begin tb = 23'd3445958; td = 14'd3323; end
        10'd283: begin tb = 23'd3449281; td = 14'd3312; end
        10'd284: begin tb = 23'd3452593; td = 14'd3301; end
        10'd285: begin tb = 23'd3455894; td = 14'd3289; end
        10'd286: begin tb = 23'd3459183; td = 14'd3277; end
        10'd287: begin tb = 23'd3462460; td = 14'd3266; end
        10'd288: begin tb = 23'd3465726; td = 14'd3254; end
        10'd289: begin tb = 23'd3468980; td = 14'd3243; end
        10'd290: begin tb = 23'd3472223; td = 14'd3231; end
        10'd291: begin tb = 23'd3475454; td = 14'd3220; end
        10'd292: begin tb = 23'd3478674; td = 14'd3209; end
        10'd293: begin tb = 23'd3481882; td = 14'd3197; end
        10'd294: begin tb = 23'd3485079; td = 14'd3185; end
        10'd295: begin tb = 23'd3488265; td = 14'd3174; end
        10'd296: begin tb = 23'd3491439; td = 14'd3163; end
        10'd297: begin tb = 23'd3494602; td = 14'd3151; end
        10'd298: begin tb = 23'd3497753; td = 14'd3140; end
        10'd299: begin tb = 23'd3500893; td = 14'd3128; end
        10'd300: begin tb = 23'd3504020; td = 14'd3118; end
        10'd301: begin tb = 23'd3507138; td = 14'd3105; end
        10'd302: begin tb = 23'd3510244; td = 14'd3095; end
        10'd303: begin tb = 23'd3513339; td = 14'd3083; end
        10'd304: begin tb = 23'd3516422; td = 14'd3072; end
        10'd305: begin tb = 23'd3519494; td = 14'd3061; end
        10'd306: begin tb = 23'd3522555; td = 14'd3049; end
        10'd307: begin tb = 23'd3525604; td = 14'd3038; end
        10'd308: begin tb = 23'd3528642; td = 14'd3027; end
        10'd309: begin tb = 23'd3531669; td = 14'd3016; end
        10'd310: begin tb = 23'd3534685; td = 14'd3005; end
        10'd311: begin tb = 23'd3537690; td = 14'd2993; end
        10'd312: begin tb = 23'd3540683; td = 14'd2983; end
        10'd313: begin tb = 23'd3543666; td = 14'd2971; end
        10'd314: begin tb = 23'd3546637; td = 14'd2960; end
        10'd315: begin tb = 23'd3549597; td = 14'd2949; end
        10'd316: begin tb = 23'd3552546; td = 14'd2938; end
        10'd317: begin tb = 23'd3555484; td = 14'd2927; end
        10'd318: begin tb = 23'd3558411; td = 14'd2916; end
        10'd319: begin tb = 23'd3561327; td = 14'd2905; end
        10'd320: begin tb = 23'd3564232; td = 14'd2894; end
        10'd321: begin tb = 23'd3567126; td = 14'd2883; end
        10'd322: begin tb = 23'd3570009; td = 14'd2872; end
        10'd323: begin tb = 23'd3572881; td = 14'd2861; end
        10'd324: begin tb = 23'd3575742; td = 14'd2850; end
        10'd325: begin tb = 23'd3578591; td = 14'd2840; end
        10'd326: begin tb = 23'd3581431; td = 14'd2828; end
        10'd327: begin tb = 23'd3584259; td = 14'd2818; end
        10'd328: begin tb = 23'd3587078; td = 14'd2806; end
        10'd329: begin tb = 23'd3589884; td = 14'd2796; end
        10'd330: begin tb = 23'd3592680; td = 14'd2786; end
        10'd331: begin tb = 23'd3595466; td = 14'd2774; end
        10'd332: begin tb = 23'd3598240; td = 14'd2764; end
        10'd333: begin tb = 23'd3601004; td = 14'd2753; end
        10'd334: begin tb = 23'd3603757; td = 14'd2742; end
        10'd335: begin tb = 23'd3606499; td = 14'd2732; end
        10'd336: begin tb = 23'd3609231; td = 14'd2721; end
        10'd337: begin tb = 23'd3611952; td = 14'd2710; end
        10'd338: begin tb = 23'd3614662; td = 14'd2700; end
        10'd339: begin tb = 23'd3617362; td = 14'd2689; end
        10'd340: begin tb = 23'd3620051; td = 14'd2679; end
        10'd341: begin tb = 23'd3622730; td = 14'd2668; end
        10'd342: begin tb = 23'd3625398; td = 14'd2658; end
        10'd343: begin tb = 23'd3628056; td = 14'd2647; end
        10'd344: begin tb = 23'd3630702; td = 14'd2637; end
        10'd345: begin tb = 23'd3633339; td = 14'd2626; end
        10'd346: begin tb = 23'd3635966; td = 14'd2616; end
        10'd347: begin tb = 23'd3638582; td = 14'd2605; end
        10'd348: begin tb = 23'd3641187; td = 14'd2595; end
        10'd349: begin tb = 23'd3643782; td = 14'd2585; end
        10'd350: begin tb = 23'd3646367; td = 14'd2574; end
        10'd351: begin tb = 23'd3648940; td = 14'd2565; end
        10'd352: begin tb = 23'd3651505; td = 14'd2553; end
        10'd353: begin tb = 23'd3654059; td = 14'd2544; end
        10'd354: begin tb = 23'd3656603; td = 14'd2533; end
        10'd355: begin tb = 23'd3659135; td = 14'd2524; end
        10'd356: begin tb = 23'd3661659; td = 14'd2513; end
        10'd357: begin tb = 23'd3664172; td = 14'd2502; end
        10'd358: begin tb = 23'd3666675; td = 14'd2493; end
        10'd359: begin tb = 23'd3669168; td = 14'd2483; end
        10'd360: begin tb = 23'd3671651; td = 14'd2472; end
        10'd361: begin tb = 23'd3674123; td = 14'd2463; end
        10'd362: begin tb = 23'd3676586; td = 14'd2452; end
        10'd363: begin tb = 23'd3679038; td = 14'd2443; end
        10'd364: begin tb = 23'd3681481; td = 14'd2432; end
        10'd365: begin tb = 23'd3683913; td = 14'd2423; end
        10'd366: begin tb = 23'd3686335; td = 14'd2413; end
        10'd367: begin tb = 23'd3688749; td = 14'd2402; end
        10'd368: begin tb = 23'd3691151; td = 14'd2393; end
        10'd369: begin tb = 23'd3693544; td = 14'd2383; end
        10'd370: begin tb = 23'd3695926; td = 14'd2374; end
        10'd371: begin tb = 23'd3698300; td = 14'd2363; end
        10'd372: begin tb = 23'd3700663; td = 14'd2354; end
        10'd373: begin tb = 23'd3703017; td = 14'd2344; end
        10'd374: begin tb = 23'd3705361; td = 14'd2334; end
        10'd375: begin tb = 23'd3707696; td = 14'd2324; end
        10'd376: begin tb = 23'd3710020; td = 14'd2315; end
        10'd377: begin tb = 23'd3712334; td = 14'd2306; end
        10'd378: begin tb = 23'd3714640; td = 14'd2295; end
        10'd379: begin tb = 23'd3716936; td = 14'd2286; end
        10'd380: begin tb = 23'd3719222; td = 14'd2277; end
        10'd381: begin tb = 23'd3721498; td = 14'd2267; end
        10'd382: begin tb = 23'd3723765; td = 14'd2257; end
        10'd383: begin tb = 23'd3726023; td = 14'd2248; end
        10'd384: begin tb = 23'd3728270; td = 14'd2239; end
        10'd385: begin tb = 23'd3730509; td = 14'd2229; end
        10'd386: begin tb = 23'd3732738; td = 14'd2220; end
        10'd387: begin tb = 23'd3734958; td = 14'd2210; end
        10'd388: begin tb = 23'd3737169; td = 14'd2201; end
        10'd389: begin tb = 23'd3739369; td = 14'd2192; end
        10'd390: begin tb = 23'd3741561; td = 14'd2182; end
        10'd391: begin tb = 23'd3743744; td = 14'd2173; end
        10'd392: begin tb = 23'd3745917; td = 14'd2164; end
        10'd393: begin tb = 23'd3748081; td = 14'd2155; end
        10'd394: begin tb = 23'd3750236; td = 14'd2145; end
        10'd395: begin tb = 23'd3752381; td = 14'd2137; end
        10'd396: begin tb = 23'd3754518; td = 14'd2127; end
        10'd397: begin tb = 23'd3756645; td = 14'd2118; end
        10'd398: begin tb = 23'd3758763; td = 14'd2109; end
        10'd399: begin tb = 23'd3760872; td = 14'd2100; end
        10'd400: begin tb = 23'd3762971; td = 14'd2092; end
        10'd401: begin tb = 23'd3765063; td = 14'd2082; end
        10'd402: begin tb = 23'd3767145; td = 14'd2073; end
        10'd403: begin tb = 23'd3769218; td = 14'd2064; end
        10'd404: begin tb = 23'd3771283; td = 14'd2055; end
        10'd405: begin tb = 23'd3773337; td = 14'd2047; end
        10'd406: begin tb = 23'd3775384; td = 14'd2037; end
        10'd407: begin tb = 23'd3777421; td = 14'd2029; end
        10'd408: begin tb = 23'd3779450; td = 14'd2020; end
        10'd409: begin tb = 23'd3781470; td = 14'd2011; end
        10'd410: begin tb = 23'd3783482; td = 14'd2002; end
        10'd411: begin tb = 23'd3785484; td = 14'd1994; end
        10'd412: begin tb = 23'd3787478; td = 14'd1985; end
        10'd413: begin tb = 23'd3789463; td = 14'd1976; end
        10'd414: begin tb = 23'd3791439; td = 14'd1968; end
        10'd415: begin tb = 23'd3793407; td = 14'd1959; end
        10'd416: begin tb = 23'd3795366; td = 14'd1951; end
        10'd417: begin tb = 23'd3797316; td = 14'd1942; end
        10'd418: begin tb = 23'd3799259; td = 14'd1933; end
        10'd419: begin tb = 23'd3801191; td = 14'd1926; end
        10'd420: begin tb = 23'd3803117; td = 14'd1916; end
        10'd421: begin tb = 23'd3805034; td = 14'd1908; end
        10'd422: begin tb = 23'd3806942; td = 14'd1900; end
        10'd423: begin tb = 23'd3808842; td = 14'd1891; end
        10'd424: begin tb = 23'd3810733; td = 14'd1883; end
        10'd425: begin tb = 23'd3812616; td = 14'd1875; end
        10'd426: begin tb = 23'd3814491; td = 14'd1866; end
        10'd427: begin tb = 23'd3816357; td = 14'd1858; end
        10'd428: begin tb = 23'd3818215; td = 14'd1850; end
        10'd429: begin tb = 23'd3820065; td = 14'd1842; end
        10'd430: begin tb = 23'd3821907; td = 14'd1833; end
        10'd431: begin tb = 23'd3823739; td = 14'd1826; end
        10'd432: begin tb = 23'd3825565; td = 14'd1817; end
        10'd433: begin tb = 23'd3827383; td = 14'd1809; end
        10'd434: begin tb = 23'd3829192; td = 14'd1801; end
        10'd435: begin tb = 23'd3830993; td = 14'd1793; end
        10'd436: begin tb = 23'd3832786; td = 14'd1785; end
        10'd437: begin tb = 23'd3834571; td = 14'd1777; end
        10'd438: begin tb = 23'd3836347; td = 14'd1769; end
        10'd439: begin tb = 23'd3838117; td = 14'd1761; end
        10'd440: begin tb = 23'd3839878; td = 14'd1753; end
        10'd441: begin tb = 23'd3841630; td = 14'd1746; end
        10'd442: begin tb = 23'd3843376; td = 14'd1737; end
        10'd443: begin tb = 23'd3845113; td = 14'd1730; end
        10'd444: begin tb = 23'd3846843; td = 14'd1721; end
        10'd445: begin tb = 23'd3848565; td = 14'd1714; end
        10'd446: begin tb = 23'd3850278; td = 14'd1707; end
        10'd447: begin tb = 23'd3851985; td = 14'd1698; end
        10'd448: begin tb = 23'd3853684; td = 14'd1691; end
        10'd449: begin tb = 23'd3855375; td = 14'd1683; end
        10'd450: begin tb = 23'd3857058; td = 14'd1676; end
        10'd451: begin tb = 23'd3858734; td = 14'd1668; end
        10'd452: begin tb = 23'd3860402; td = 14'd1660; end
        10'd453: begin tb = 23'd3862062; td = 14'd1653; end
        10'd454: begin tb = 23'd3863714; td = 14'd1646; end
        10'd455: begin tb = 23'd3865360; td = 14'd1638; end
        10'd456: begin tb = 23'd3866998; td = 14'd1630; end
        10'd457: begin tb = 23'd3868628; td = 14'd1623; end
        10'd458: begin tb = 23'd3870252; td = 14'd1615; end
        10'd459: begin tb = 23'd3871866; td = 14'd1609; end
        10'd460: begin tb = 23'd3873475; td = 14'd1600; end
        10'd461: begin tb = 23'd3875075; td = 14'd1594; end
        10'd462: begin tb = 23'd3876669; td = 14'd1586; end
        10'd463: begin tb = 23'd3878255; td = 14'd1579; end
        10'd464: begin tb = 23'd3879834; td = 14'd1571; end
        10'd465: begin tb = 23'd3881406; td = 14'd1565; end
        10'd466: begin tb = 23'd3882970; td = 14'd1557; end
        10'd467: begin tb = 23'd3884528; td = 14'd1550; end
        10'd468: begin tb = 23'd3886077; td = 14'd1543; end
        10'd469: begin tb = 23'd3887620; td = 14'd1536; end
        10'd470: begin tb = 23'd3889156; td = 14'd1528; end
        10'd471: begin tb = 23'd3890685; td = 14'd1522; end
        10'd472: begin tb = 23'd3892206; td = 14'd1515; end
        10'd473: begin tb = 23'd3893721; td = 14'd1507; end
        10'd474: begin tb = 23'd3895228; td = 14'd1501; end
        10'd475: begin tb = 23'd3896729; td = 14'd1493; end
        10'd476: begin tb = 23'd3898223; td = 14'd1487; end
        10'd477: begin tb = 23'd3899709; td = 14'd1480; end
        10'd478: begin tb = 23'd3901189; td = 14'd1473; end
        10'd479: begin tb = 23'd3902662; td = 14'd1466; end
        10'd480: begin tb = 23'd3904128; td = 14'd1459; end
        10'd481: begin tb = 23'd3905587; td = 14'd1453; end
        10'd482: begin tb = 23'd3907040; td = 14'd1445; end
        10'd483: begin tb = 23'd3908486; td = 14'd1439; end
        10'd484: begin tb = 23'd3909925; td = 14'd1432; end
        10'd485: begin tb = 23'd3911357; td = 14'd1426; end
        10'd486: begin tb = 23'd3912782; td = 14'd1419; end
        10'd487: begin tb = 23'd3914201; td = 14'd1412; end
        10'd488: begin tb = 23'd3915613; td = 14'd1406; end
        10'd489: begin tb = 23'd3917019; td = 14'd1399; end
        10'd490: begin tb = 23'd3918418; td = 14'd1392; end
        10'd491: begin tb = 23'd3919810; td = 14'd1386; end
        10'd492: begin tb = 23'd3921196; td = 14'd1379; end
        10'd493: begin tb = 23'd3922576; td = 14'd1373; end
        10'd494: begin tb = 23'd3923948; td = 14'd1367; end
        10'd495: begin tb = 23'd3925315; td = 14'd1360; end
        10'd496: begin tb = 23'd3926675; td = 14'd1353; end
        10'd497: begin tb = 23'd3928029; td = 14'd1347; end
        10'd498: begin tb = 23'd3929376; td = 14'd1341; end
        10'd499: begin tb = 23'd3930716; td = 14'd1335; end
        10'd500: begin tb = 23'd3932051; td = 14'd1328; end
        10'd501: begin tb = 23'd3933379; td = 14'd1322; end
        10'd502: begin tb = 23'd3934701; td = 14'd1316; end
        10'd503: begin tb = 23'd3936017; td = 14'd1309; end
        10'd504: begin tb = 23'd3937327; td = 14'd1303; end
        10'd505: begin tb = 23'd3938630; td = 14'd1297; end
        10'd506: begin tb = 23'd3939927; td = 14'd1291; end
        10'd507: begin tb = 23'd3941217; td = 14'd1285; end
        10'd508: begin tb = 23'd3942502; td = 14'd1279; end
        10'd509: begin tb = 23'd3943781; td = 14'd1272; end
        10'd510: begin tb = 23'd3945053; td = 14'd1267; end
        10'd511: begin tb = 23'd3946320; td = 14'd1260; end
        10'd512: begin tb = 23'd3947582; td = 14'd2503; end
        10'd513: begin tb = 23'd3950085; td = 14'd2479; end
        10'd514: begin tb = 23'd3952563; td = 14'd2456; end
        10'd515: begin tb = 23'd3955019; td = 14'd2432; end
        10'd516: begin tb = 23'd3957451; td = 14'd2409; end
        10'd517: begin tb = 23'd3959860; td = 14'd2385; end
        10'd518: begin tb = 23'd3962246; td = 14'd2363; end
        10'd519: begin tb = 23'd3964609; td = 14'd2340; end
        10'd520: begin tb = 23'd3966948; td = 14'd2318; end
        10'd521: begin tb = 23'd3969266; td = 14'd2295; end
        10'd522: begin tb = 23'd3971561; td = 14'd2274; end
        10'd523: begin tb = 23'd3973835; td = 14'd2251; end
        10'd524: begin tb = 23'd3976086; td = 14'd2230; end
        10'd525: begin tb = 23'd3978316; td = 14'd2208; end
        10'd526: begin tb = 23'd3980524; td = 14'd2186; end
        10'd527: begin tb = 23'd3982710; td = 14'd2166; end
        10'd528: begin tb = 23'd3984876; td = 14'd2144; end
        10'd529: begin tb = 23'd3987020; td = 14'd2124; end
        10'd530: begin tb = 23'd3989144; td = 14'd2103; end
        10'd531: begin tb = 23'd3991247; td = 14'd2082; end
        10'd532: begin tb = 23'd3993329; td = 14'd2063; end
        10'd533: begin tb = 23'd3995392; td = 14'd2042; end
        10'd534: begin tb = 23'd3997434; td = 14'd2022; end
        10'd535: begin tb = 23'd3999456; td = 14'd2002; end
        10'd536: begin tb = 23'd4001458; td = 14'd1983; end
        10'd537: begin tb = 23'd4003441; td = 14'd1964; end
        10'd538: begin tb = 23'd4005405; td = 14'd1944; end
        10'd539: begin tb = 23'd4007349; td = 14'd1925; end
        10'd540: begin tb = 23'd4009274; td = 14'd1906; end
        10'd541: begin tb = 23'd4011180; td = 14'd1887; end
        10'd542: begin tb = 23'd4013067; td = 14'd1869; end
        10'd543: begin tb = 23'd4014936; td = 14'd1850; end
        10'd544: begin tb = 23'd4016786; td = 14'd1833; end
        10'd545: begin tb = 23'd4018619; td = 14'd1814; end
        10'd546: begin tb = 23'd4020433; td = 14'd1796; end
        10'd547: begin tb = 23'd4022229; td = 14'd1778; end
        10'd548: begin tb = 23'd4024007; td = 14'd1761; end
        10'd549: begin tb = 23'd4025768; td = 14'd1743; end
        10'd550: begin tb = 23'd4027511; td = 14'd1726; end
        10'd551: begin tb = 23'd4029237; td = 14'd1709; end
        10'd552: begin tb = 23'd4030946; td = 14'd1692; end
        10'd553: begin tb = 23'd4032638; td = 14'd1675; end
        10'd554: begin tb = 23'd4034313; td = 14'd1658; end
        10'd555: begin tb = 23'd4035971; td = 14'd1642; end
        10'd556: begin tb = 23'd4037613; td = 14'd1626; end
        10'd557: begin tb = 23'd4039239; td = 14'd1609; end
        10'd558: begin tb = 23'd4040848; td = 14'd1593; end
        10'd559: begin tb = 23'd4042441; td = 14'd1577; end
        10'd560: begin tb = 23'd4044018; td = 14'd1562; end
        10'd561: begin tb = 23'd4045580; td = 14'd1546; end
        10'd562: begin tb = 23'd4047126; td = 14'd1530; end
        10'd563: begin tb = 23'd4048656; td = 14'd1515; end
        10'd564: begin tb = 23'd4050171; td = 14'd1500; end
        10'd565: begin tb = 23'd4051671; td = 14'd1485; end
        10'd566: begin tb = 23'd4053156; td = 14'd1469; end
        10'd567: begin tb = 23'd4054625; td = 14'd1455; end
        10'd568: begin tb = 23'd4056080; td = 14'd1441; end
        10'd569: begin tb = 23'd4057521; td = 14'd1426; end
        10'd570: begin tb = 23'd4058947; td = 14'd1411; end
        10'd571: begin tb = 23'd4060358; td = 14'd1398; end
        10'd572: begin tb = 23'd4061755; td = 14'd1383; end
        10'd573: begin tb = 23'd4063139; td = 14'd1369; end
        10'd574: begin tb = 23'd4064508; td = 14'd1355; end
        10'd575: begin tb = 23'd4065863; td = 14'd1342; end
        10'd576: begin tb = 23'd4067205; td = 14'd1328; end
        10'd577: begin tb = 23'd4068532; td = 14'd1315; end
        10'd578: begin tb = 23'd4069847; td = 14'd1301; end
        10'd579: begin tb = 23'd4071149; td = 14'd1288; end
        10'd580: begin tb = 23'd4072437; td = 14'd1275; end
        10'd581: begin tb = 23'd4073712; td = 14'd1262; end
        10'd582: begin tb = 23'd4074974; td = 14'd1249; end
        10'd583: begin tb = 23'd4076223; td = 14'd1237; end
        10'd584: begin tb = 23'd4077460; td = 14'd1224; end
        10'd585: begin tb = 23'd4078684; td = 14'd1211; end
        10'd586: begin tb = 23'd4079895; td = 14'd1199; end
        10'd587: begin tb = 23'd4081094; td = 14'd1187; end
        10'd588: begin tb = 23'd4082281; td = 14'd1175; end
        10'd589: begin tb = 23'd4083456; td = 14'd1163; end
        10'd590: begin tb = 23'd4084619; td = 14'd1151; end
        10'd591: begin tb = 23'd4085770; td = 14'd1139; end
        10'd592: begin tb = 23'd4086909; td = 14'd1128; end
        10'd593: begin tb = 23'd4088036; td = 14'd1116; end
        10'd594: begin tb = 23'd4089153; td = 14'd1104; end
        10'd595: begin tb = 23'd4090257; td = 14'd1094; end
        10'd596: begin tb = 23'd4091350; td = 14'd1082; end
        10'd597: begin tb = 23'd4092432; td = 14'd1071; end
        10'd598: begin tb = 23'd4093503; td = 14'd1060; end
        10'd599: begin tb = 23'd4094563; td = 14'd1049; end
        10'd600: begin tb = 23'd4095613; td = 14'd1038; end
        10'd601: begin tb = 23'd4096651; td = 14'd1028; end
        10'd602: begin tb = 23'd4097679; td = 14'd1017; end
        10'd603: begin tb = 23'd4098695; td = 14'd1007; end
        10'd604: begin tb = 23'd4099702; td = 14'd996; end
        10'd605: begin tb = 23'd4100699; td = 14'd986; end
        10'd606: begin tb = 23'd4101685; td = 14'd976; end
        10'd607: begin tb = 23'd4102660; td = 14'd966; end
        10'd608: begin tb = 23'd4103626; td = 14'd956; end
        10'd609: begin tb = 23'd4104582; td = 14'd946; end
        10'd610: begin tb = 23'd4105528; td = 14'd936; end
        10'd611: begin tb = 23'd4106464; td = 14'd927; end
        10'd612: begin tb = 23'd4107391; td = 14'd917; end
        10'd613: begin tb = 23'd4108308; td = 14'd907; end
        10'd614: begin tb = 23'd4109216; td = 14'd898; end
        10'd615: begin tb = 23'd4110114; td = 14'd889; end
        10'd616: begin tb = 23'd4111003; td = 14'd880; end
        10'd617: begin tb = 23'd4111882; td = 14'd871; end
        10'd618: begin tb = 23'd4112753; td = 14'd861; end
        10'd619: begin tb = 23'd4113614; td = 14'd853; end
        10'd620: begin tb = 23'd4114467; td = 14'd844; end
        10'd621: begin tb = 23'd4115311; td = 14'd835; end
        10'd622: begin tb = 23'd4116146; td = 14'd826; end
        10'd623: begin tb = 23'd4116972; td = 14'd818; end
        10'd624: begin tb = 23'd4117790; td = 14'd809; end
        10'd625: begin tb = 23'd4118600; td = 14'd801; end
        10'd626: begin tb = 23'd4119400; td = 14'd793; end
        10'd627: begin tb = 23'd4120193; td = 14'd784; end
        10'd628: begin tb = 23'd4120978; td = 14'd776; end
        10'd629: begin tb = 23'd4121754; td = 14'd768; end
        10'd630: begin tb = 23'd4122521; td = 14'd761; end
        10'd631: begin tb = 23'd4123282; td = 14'd752; end
        10'd632: begin tb = 23'd4124034; td = 14'd744; end
        10'd633: begin tb = 23'd4124778; td = 14'd737; end
        10'd634: begin tb = 23'd4125515; td = 14'd729; end
        10'd635: begin tb = 23'd4126244; td = 14'd721; end
        10'd636: begin tb = 23'd4126966; td = 14'd714; end
        10'd637: begin tb = 23'd4127680; td = 14'd706; end
        10'd638: begin tb = 23'd4128385; td = 14'd700; end
        10'd639: begin tb = 23'd4129085; td = 14'd691; end
        10'd640: begin tb = 23'd4129778; td = 14'd1362; end
        10'd641: begin tb = 23'd4131140; td = 14'd1334; end
        10'd642: begin tb = 23'd4132473; td = 14'd1306; end
        10'd643: begin tb = 23'd4133779; td = 14'd1278; end
        10'd644: begin tb = 23'd4135058; td = 14'd1252; end
        10'd645: begin tb = 23'd4136310; td = 14'd1226; end
        10'd646: begin tb = 23'd4137536; td = 14'd1200; end
        10'd647: begin tb = 23'd4138735; td = 14'd1176; end
        10'd648: begin tb = 23'd4139911; td = 14'd1150; end
        10'd649: begin tb = 23'd4141062; td = 14'd1127; end
        10'd650: begin tb = 23'd4142189; td = 14'd1103; end
        10'd651: begin tb = 23'd4143292; td = 14'd1080; end
        10'd652: begin tb = 23'd4144371; td = 14'd1058; end
        10'd653: begin tb = 23'd4145429; td = 14'd1035; end
        10'd654: begin tb = 23'd4146464; td = 14'd1014; end
        10'd655: begin tb = 23'd4147478; td = 14'd992; end
        10'd656: begin tb = 23'd4148470; td = 14'd972; end
        10'd657: begin tb = 23'd4149442; td = 14'd951; end
        10'd658: begin tb = 23'd4150393; td = 14'd932; end
        10'd659: begin tb = 23'd4151325; td = 14'd911; end
        10'd660: begin tb = 23'd4152236; td = 14'd893; end
        10'd661: begin tb = 23'd4153129; td = 14'd874; end
        10'd662: begin tb = 23'd4154003; td = 14'd855; end
        10'd663: begin tb = 23'd4154858; td = 14'd838; end
        10'd664: begin tb = 23'd4155696; td = 14'd820; end
        10'd665: begin tb = 23'd4156516; td = 14'd802; end
        10'd666: begin tb = 23'd4157318; td = 14'd786; end
        10'd667: begin tb = 23'd4158104; td = 14'd769; end
        10'd668: begin tb = 23'd4158873; td = 14'd753; end
        10'd669: begin tb = 23'd4159626; td = 14'd737; end
        10'd670: begin tb = 23'd4160363; td = 14'd722; end
        10'd671: begin tb = 23'd4161085; td = 14'd706; end
        10'd672: begin tb = 23'd4161791; td = 14'd691; end
        10'd673: begin tb = 23'd4162482; td = 14'd677; end
        10'd674: begin tb = 23'd4163159; td = 14'd663; end
        10'd675: begin tb = 23'd4163822; td = 14'd648; end
        10'd676: begin tb = 23'd4164470; td = 14'd635; end
        10'd677: begin tb = 23'd4165105; td = 14'd622; end
        10'd678: begin tb = 23'd4165727; td = 14'd608; end
        10'd679: begin tb = 23'd4166335; td = 14'd595; end
        10'd680: begin tb = 23'd4166930; td = 14'd583; end
        10'd681: begin tb = 23'd4167513; td = 14'd571; end
        10'd682: begin tb = 23'd4168084; td = 14'd558; end
        10'd683: begin tb = 23'd4168642; td = 14'd547; end
        10'd684: begin tb = 23'd4169188; td = 14'd535; end
        10'd685: begin tb = 23'd4169724; td = 14'd523; end
        10'd686: begin tb = 23'd4170247; td = 14'd513; end
        10'd687: begin tb = 23'd4170760; td = 14'd502; end
        10'd688: begin tb = 23'd4171262; td = 14'd491; end
        10'd689: begin tb = 23'd4171752; td = 14'd481; end
        10'd690: begin tb = 23'd4172233; td = 14'd470; end
        10'd691: begin tb = 23'd4172703; td = 14'd461; end
        10'd692: begin tb = 23'd4173164; td = 14'd450; end
        10'd693: begin tb = 23'd4173614; td = 14'd442; end
        10'd694: begin tb = 23'd4174056; td = 14'd431; end
        10'd695: begin tb = 23'd4174488; td = 14'd423; end
        10'd696: begin tb = 23'd4174910; td = 14'd414; end
        10'd697: begin tb = 23'd4175324; td = 14'd405; end
        10'd698: begin tb = 23'd4175729; td = 14'd396; end
        10'd699: begin tb = 23'd4176125; td = 14'd388; end
        10'd700: begin tb = 23'd4176513; td = 14'd380; end
        10'd701: begin tb = 23'd4176893; td = 14'd371; end
        10'd702: begin tb = 23'd4177264; td = 14'd364; end
        10'd703: begin tb = 23'd4177628; td = 14'd356; end
        10'd704: begin tb = 23'd4177986; td = 14'd689; end
        10'd705: begin tb = 23'd4178675; td = 14'd660; end
        10'd706: begin tb = 23'd4179335; td = 14'd633; end
        10'd707: begin tb = 23'd4179968; td = 14'd606; end
        10'd708: begin tb = 23'd4180574; td = 14'd580; end
        10'd709: begin tb = 23'd4181154; td = 14'd556; end
        10'd710: begin tb = 23'd4181709; td = 14'd533; end
        10'd711: begin tb = 23'd4182242; td = 14'd510; end
        10'd712: begin tb = 23'd4182752; td = 14'd488; end
        10'd713: begin tb = 23'd4183240; td = 14'd468; end
        10'd714: begin tb = 23'd4183708; td = 14'd448; end
        10'd715: begin tb = 23'd4184156; td = 14'd430; end
        10'd716: begin tb = 23'd4184586; td = 14'd411; end
        10'd717: begin tb = 23'd4184997; td = 14'd394; end
        10'd718: begin tb = 23'd4185391; td = 14'd377; end
        10'd719: begin tb = 23'd4185768; td = 14'd361; end
        10'd720: begin tb = 23'd4186129; td = 14'd346; end
        10'd721: begin tb = 23'd4186475; td = 14'd331; end
        10'd722: begin tb = 23'd4186806; td = 14'd318; end
        10'd723: begin tb = 23'd4187124; td = 14'd304; end
        10'd724: begin tb = 23'd4187427; td = 14'd291; end
        10'd725: begin tb = 23'd4187718; td = 14'd279; end
        10'd726: begin tb = 23'd4187997; td = 14'd267; end
        10'd727: begin tb = 23'd4188265; td = 14'd255; end
        10'd728: begin tb = 23'd4188520; td = 14'd245; end
        10'd729: begin tb = 23'd4188765; td = 14'd235; end
        10'd730: begin tb = 23'd4188999; td = 14'd225; end
        10'd731: begin tb = 23'd4189224; td = 14'd215; end
        10'd732: begin tb = 23'd4189439; td = 14'd206; end
        10'd733: begin tb = 23'd4189645; td = 14'd197; end
        10'd734: begin tb = 23'd4189843; td = 14'd189; end
        10'd735: begin tb = 23'd4190031; td = 14'd181; end
        10'd736: begin tb = 23'd4190214; td = 14'd339; end
        10'd737: begin tb = 23'd4190552; td = 14'd312; end
        10'd738: begin tb = 23'd4190864; td = 14'd285; end
        10'd739: begin tb = 23'd4191149; td = 14'd262; end
        10'd740: begin tb = 23'd4191411; td = 14'd240; end
        10'd741: begin tb = 23'd4191651; td = 14'd220; end
        10'd742: begin tb = 23'd4191871; td = 14'd202; end
        10'd743: begin tb = 23'd4192073; td = 14'd185; end
        10'd744: begin tb = 23'd4192258; td = 14'd170; end
        10'd745: begin tb = 23'd4192427; td = 14'd156; end
        10'd746: begin tb = 23'd4192584; td = 14'd142; end
        10'd747: begin tb = 23'd4192726; td = 14'd131; end
        10'd748: begin tb = 23'd4192857; td = 14'd120; end
        10'd749: begin tb = 23'd4192976; td = 14'd111; end
        10'd750: begin tb = 23'd4193087; td = 14'd101; end
        10'd751: begin tb = 23'd4193188; td = 14'd92; end
        10'd752: begin tb = 23'd4193282; td = 14'd163; end
        10'd753: begin tb = 23'd4193445; td = 14'd137; end
        10'd754: begin tb = 23'd4193581; td = 14'd115; end
        10'd755: begin tb = 23'd4193696; td = 14'd97; end
        10'd756: begin tb = 23'd4193793; td = 14'd82; end
        10'd757: begin tb = 23'd4193874; td = 14'd68; end
        10'd758: begin tb = 23'd4193942; td = 14'd58; end
        10'd759: begin tb = 23'd4194000; td = 14'd48; end
        10'd760: begin tb = 23'd4194050; td = 14'd75; end
        10'd761: begin tb = 23'd4194124; td = 14'd53; end
        10'd762: begin tb = 23'd4194177; td = 14'd37; end
        10'd763: begin tb = 23'd4194214; td = 14'd27; end
        10'd764: begin tb = 23'd4194240; td = 14'd19; end
        10'd765: begin tb = 23'd4194259; td = 14'd13; end
        10'd766: begin tb = 23'd4194272; td = 14'd9; end
        10'd767: begin tb = 23'd4194281; td = 14'd7; end
        10'd768: begin tb = 23'd4194288; td = 14'd5; end
        10'd769: begin tb = 23'd4194293; td = 14'd3; end
        10'd770: begin tb = 23'd4194296; td = 14'd2; end
        10'd771: begin tb = 23'd4194298; td = 14'd2; end
        10'd772: begin tb = 23'd4194300; td = 14'd1; end
        10'd773: begin tb = 23'd4194301; td = 14'd1; end
        10'd774: begin tb = 23'd4194302; td = 14'd1; end
        10'd775: begin tb = 23'd4194303; td = 14'd0; end
        10'd776: begin tb = 23'd4194303; td = 14'd0; end
        10'd777: begin tb = 23'd4194303; td = 14'd1; end
        10'd778: begin tb = 23'd4194304; td = 14'd0; end
        10'd779: begin tb = 23'd4194304; td = 14'd0; end
        default: begin tb = 23'd0; td = 14'd0; end
    endcase
end
assign lt = ltr;
wire [27:0] ip = td * ltr;
wire [27:0] ir = ip + 28'd8192;
assign b = sat ? 23'd4194304 : tb;
assign d = sat ? 13'd0 : td[12:0];
assign i = sat ? 13'd0 : ir[26:14];
wire [22:0] bi = b + {10'd0, i};
assign v = neg ? (23'd4194304 - bi) : bi;
endmodule

module cs_rcp(input wire [31:0] l, output wire [24:0] y, output wire [2:0] e, output wire [30:0] nrm);

reg [30:0] normalized; reg [2:0] range_exponent;
always @* begin
    normalized = 31'd0; range_exponent = 3'd0;
    casez (l[31:27])
        5'b1????: begin normalized = l[31:1]; range_exponent = 3'd4; end
        5'b01???: begin normalized = l[30:0]; range_exponent = 3'd3; end
        5'b001??: begin normalized = {l[29:0], 1'd0}; range_exponent = 3'd2; end
        5'b0001?: begin normalized = {l[28:0], 2'd0}; range_exponent = 3'd1; end
        5'b00001: begin normalized = {l[27:0], 3'd0}; range_exponent = 3'd0; end
        default: begin normalized = 31'd0; range_exponent = 3'd0; end
    endcase
end
assign e = range_exponent; assign nrm = normalized;
wire [7:0] idx = normalized[29:22];
wire [14:0] low = normalized[21:7];
reg [24:0] rb; reg [15:0] rd;
always @(*) begin
    case (idx)
        8'd0: begin rb = 25'd16777184; rd = 16'd65281; end
        8'd1: begin rb = 25'd16711904; rd = 16'd64775; end
        8'd2: begin rb = 25'd16647129; rd = 16'd64275; end
        8'd3: begin rb = 25'd16582855; rd = 16'd63780; end
        8'd4: begin rb = 25'd16519075; rd = 16'd63292; end
        8'd5: begin rb = 25'd16455783; rd = 16'd62808; end
        8'd6: begin rb = 25'd16392975; rd = 16'd62331; end
        8'd7: begin rb = 25'd16330645; rd = 16'd61859; end
        8'd8: begin rb = 25'd16268787; rd = 16'd61392; end
        8'd9: begin rb = 25'd16207395; rd = 16'd60930; end
        8'd10: begin rb = 25'd16146465; rd = 16'd60474; end
        8'd11: begin rb = 25'd16085992; rd = 16'd60022; end
        8'd12: begin rb = 25'd16025970; rd = 16'd59576; end
        8'd13: begin rb = 25'd15966394; rd = 16'd59135; end
        8'd14: begin rb = 25'd15907259; rd = 16'd58698; end
        8'd15: begin rb = 25'd15848561; rd = 16'd58267; end
        8'd16: begin rb = 25'd15790294; rd = 16'd57840; end
        8'd17: begin rb = 25'd15732455; rd = 16'd57418; end
        8'd18: begin rb = 25'd15675037; rd = 16'd57000; end
        8'd19: begin rb = 25'd15618037; rd = 16'd56587; end
        8'd20: begin rb = 25'd15561451; rd = 16'd56179; end
        8'd21: begin rb = 25'd15505272; rd = 16'd55774; end
        8'd22: begin rb = 25'd15449498; rd = 16'd55375; end
        8'd23: begin rb = 25'd15394123; rd = 16'd54979; end
        8'd24: begin rb = 25'd15339145; rd = 16'd54588; end
        8'd25: begin rb = 25'd15284557; rd = 16'd54201; end
        8'd26: begin rb = 25'd15230357; rd = 16'd53818; end
        8'd27: begin rb = 25'd15176540; rd = 16'd53439; end
        8'd28: begin rb = 25'd15123101; rd = 16'd53064; end
        8'd29: begin rb = 25'd15070038; rd = 16'd52693; end
        8'd30: begin rb = 25'd15017345; rd = 16'd52325; end
        8'd31: begin rb = 25'd14965020; rd = 16'd51962; end
        8'd32: begin rb = 25'd14913058; rd = 16'd51602; end
        8'd33: begin rb = 25'd14861456; rd = 16'd51246; end
        8'd34: begin rb = 25'd14810210; rd = 16'd50894; end
        8'd35: begin rb = 25'd14759316; rd = 16'd50546; end
        8'd36: begin rb = 25'd14708771; rd = 16'd50201; end
        8'd37: begin rb = 25'd14658570; rd = 16'd49859; end
        8'd38: begin rb = 25'd14608711; rd = 16'd49521; end
        8'd39: begin rb = 25'd14559191; rd = 16'd49187; end
        8'd40: begin rb = 25'd14510004; rd = 16'd48855; end
        8'd41: begin rb = 25'd14461149; rd = 16'd48527; end
        8'd42: begin rb = 25'd14412622; rd = 16'd48203; end
        8'd43: begin rb = 25'd14364419; rd = 16'd47881; end
        8'd44: begin rb = 25'd14316538; rd = 16'd47563; end
        8'd45: begin rb = 25'd14268975; rd = 16'd47248; end
        8'd46: begin rb = 25'd14221727; rd = 16'd46936; end
        8'd47: begin rb = 25'd14174791; rd = 16'd46628; end
        8'd48: begin rb = 25'd14128163; rd = 16'd46322; end
        8'd49: begin rb = 25'd14081841; rd = 16'd46019; end
        8'd50: begin rb = 25'd14035822; rd = 16'd45719; end
        8'd51: begin rb = 25'd13990103; rd = 16'd45422; end
        8'd52: begin rb = 25'd13944681; rd = 16'd45128; end
        8'd53: begin rb = 25'd13899552; rd = 16'd44837; end
        8'd54: begin rb = 25'd13854715; rd = 16'd44549; end
        8'd55: begin rb = 25'd13810166; rd = 16'd44263; end
        8'd56: begin rb = 25'd13765904; rd = 16'd43981; end
        8'd57: begin rb = 25'd13721923; rd = 16'd43700; end
        8'd58: begin rb = 25'd13678223; rd = 16'd43423; end
        8'd59: begin rb = 25'd13634800; rd = 16'd43148; end
        8'd60: begin rb = 25'd13591652; rd = 16'd42876; end
        8'd61: begin rb = 25'd13548776; rd = 16'd42606; end
        8'd62: begin rb = 25'd13506170; rd = 16'd42339; end
        8'd63: begin rb = 25'd13463831; rd = 16'd42075; end
        8'd64: begin rb = 25'd13421756; rd = 16'd41812; end
        8'd65: begin rb = 25'd13379945; rd = 16'd41553; end
        8'd66: begin rb = 25'd13338392; rd = 16'd41295; end
        8'd67: begin rb = 25'd13297096; rd = 16'd41040; end
        8'd68: begin rb = 25'd13256056; rd = 16'd40788; end
        8'd69: begin rb = 25'd13215269; rd = 16'd40538; end
        8'd70: begin rb = 25'd13174731; rd = 16'd40290; end
        8'd71: begin rb = 25'd13134441; rd = 16'd40044; end
        8'd72: begin rb = 25'd13094398; rd = 16'd39801; end
        8'd73: begin rb = 25'd13054597; rd = 16'd39559; end
        8'd74: begin rb = 25'd13015037; rd = 16'd39320; end
        8'd75: begin rb = 25'd12975718; rd = 16'd39084; end
        8'd76: begin rb = 25'd12936634; rd = 16'd38849; end
        8'd77: begin rb = 25'd12897785; rd = 16'd38616; end
        8'd78: begin rb = 25'd12859169; rd = 16'd38386; end
        8'd79: begin rb = 25'd12820784; rd = 16'd38157; end
        8'd80: begin rb = 25'd12782627; rd = 16'd37931; end
        8'd81: begin rb = 25'd12744696; rd = 16'd37706; end
        8'd82: begin rb = 25'd12706990; rd = 16'd37484; end
        8'd83: begin rb = 25'd12669506; rd = 16'd37263; end
        8'd84: begin rb = 25'd12632243; rd = 16'd37045; end
        8'd85: begin rb = 25'd12595199; rd = 16'd36828; end
        8'd86: begin rb = 25'd12558370; rd = 16'd36613; end
        8'd87: begin rb = 25'd12521757; rd = 16'd36400; end
        8'd88: begin rb = 25'd12485357; rd = 16'd36189; end
        8'd89: begin rb = 25'd12449167; rd = 16'd35980; end
        8'd90: begin rb = 25'd12413187; rd = 16'd35773; end
        8'd91: begin rb = 25'd12377414; rd = 16'd35567; end
        8'd92: begin rb = 25'd12341847; rd = 16'd35363; end
        8'd93: begin rb = 25'd12306484; rd = 16'd35161; end
        8'd94: begin rb = 25'd12271323; rd = 16'd34961; end
        8'd95: begin rb = 25'd12236362; rd = 16'd34762; end
        8'd96: begin rb = 25'd12201599; rd = 16'd34565; end
        8'd97: begin rb = 25'd12167034; rd = 16'd34370; end
        8'd98: begin rb = 25'd12132664; rd = 16'd34177; end
        8'd99: begin rb = 25'd12098488; rd = 16'd33985; end
        8'd100: begin rb = 25'd12064503; rd = 16'd33794; end
        8'd101: begin rb = 25'd12030709; rd = 16'd33605; end
        8'd102: begin rb = 25'd11997104; rd = 16'd33418; end
        8'd103: begin rb = 25'd11963686; rd = 16'd33232; end
        8'd104: begin rb = 25'd11930453; rd = 16'd33048; end
        8'd105: begin rb = 25'd11897405; rd = 16'd32866; end
        8'd106: begin rb = 25'd11864539; rd = 16'd32685; end
        8'd107: begin rb = 25'd11831855; rd = 16'd32505; end
        8'd108: begin rb = 25'd11799350; rd = 16'd32327; end
        8'd109: begin rb = 25'd11767023; rd = 16'd32150; end
        8'd110: begin rb = 25'd11734872; rd = 16'd31975; end
        8'd111: begin rb = 25'd11702897; rd = 16'd31801; end
        8'd112: begin rb = 25'd11671096; rd = 16'd31629; end
        8'd113: begin rb = 25'd11639467; rd = 16'd31458; end
        8'd114: begin rb = 25'd11608009; rd = 16'd31288; end
        8'd115: begin rb = 25'd11576721; rd = 16'd31120; end
        8'd116: begin rb = 25'd11545601; rd = 16'd30953; end
        8'd117: begin rb = 25'd11514647; rd = 16'd30788; end
        8'd118: begin rb = 25'd11483860; rd = 16'd30624; end
        8'd119: begin rb = 25'd11453236; rd = 16'd30461; end
        8'd120: begin rb = 25'd11422775; rd = 16'd30299; end
        8'd121: begin rb = 25'd11392476; rd = 16'd30139; end
        8'd122: begin rb = 25'd11362338; rd = 16'd29980; end
        8'd123: begin rb = 25'd11332358; rd = 16'd29822; end
        8'd124: begin rb = 25'd11302536; rd = 16'd29665; end
        8'd125: begin rb = 25'd11272870; rd = 16'd29510; end
        8'd126: begin rb = 25'd11243360; rd = 16'd29356; end
        8'd127: begin rb = 25'd11214004; rd = 16'd29203; end
        8'd128: begin rb = 25'd11184801; rd = 16'd29051; end
        8'd129: begin rb = 25'd11155750; rd = 16'd28901; end
        8'd130: begin rb = 25'd11126849; rd = 16'd28752; end
        8'd131: begin rb = 25'd11098097; rd = 16'd28603; end
        8'd132: begin rb = 25'd11069494; rd = 16'd28456; end
        8'd133: begin rb = 25'd11041038; rd = 16'd28310; end
        8'd134: begin rb = 25'd11012728; rd = 16'd28166; end
        8'd135: begin rb = 25'd10984562; rd = 16'd28022; end
        8'd136: begin rb = 25'd10956540; rd = 16'd27879; end
        8'd137: begin rb = 25'd10928661; rd = 16'd27738; end
        8'd138: begin rb = 25'd10900923; rd = 16'd27597; end
        8'd139: begin rb = 25'd10873326; rd = 16'd27458; end
        8'd140: begin rb = 25'd10845869; rd = 16'd27320; end
        8'd141: begin rb = 25'd10818549; rd = 16'd27182; end
        8'd142: begin rb = 25'd10791367; rd = 16'd27046; end
        8'd143: begin rb = 25'd10764321; rd = 16'd26911; end
        8'd144: begin rb = 25'd10737410; rd = 16'd26777; end
        8'd145: begin rb = 25'd10710633; rd = 16'd26643; end
        8'd146: begin rb = 25'd10683990; rd = 16'd26511; end
        8'd147: begin rb = 25'd10657479; rd = 16'd26380; end
        8'd148: begin rb = 25'd10631099; rd = 16'd26250; end
        8'd149: begin rb = 25'd10604849; rd = 16'd26120; end
        8'd150: begin rb = 25'd10578729; rd = 16'd25992; end
        8'd151: begin rb = 25'd10552738; rd = 16'd25865; end
        8'd152: begin rb = 25'd10526873; rd = 16'd25738; end
        8'd153: begin rb = 25'd10501135; rd = 16'd25613; end
        8'd154: begin rb = 25'd10475522; rd = 16'd25488; end
        8'd155: begin rb = 25'd10450034; rd = 16'd25364; end
        8'd156: begin rb = 25'd10424670; rd = 16'd25241; end
        8'd157: begin rb = 25'd10399429; rd = 16'd25119; end
        8'd158: begin rb = 25'd10374310; rd = 16'd24998; end
        8'd159: begin rb = 25'd10349311; rd = 16'd24878; end
        8'd160: begin rb = 25'd10324433; rd = 16'd24759; end
        8'd161: begin rb = 25'd10299674; rd = 16'd24640; end
        8'd162: begin rb = 25'd10275034; rd = 16'd24523; end
        8'd163: begin rb = 25'd10250511; rd = 16'd24406; end
        8'd164: begin rb = 25'd10226105; rd = 16'd24290; end
        8'd165: begin rb = 25'd10201815; rd = 16'd24175; end
        8'd166: begin rb = 25'd10177641; rd = 16'd24061; end
        8'd167: begin rb = 25'd10153580; rd = 16'd23947; end
        8'd168: begin rb = 25'd10129633; rd = 16'd23834; end
        8'd169: begin rb = 25'd10105799; rd = 16'd23723; end
        8'd170: begin rb = 25'd10082076; rd = 16'd23611; end
        8'd171: begin rb = 25'd10058465; rd = 16'd23501; end
        8'd172: begin rb = 25'd10034964; rd = 16'd23392; end
        8'd173: begin rb = 25'd10011572; rd = 16'd23283; end
        8'd174: begin rb = 25'd9988290; rd = 16'd23175; end
        8'd175: begin rb = 25'd9965115; rd = 16'd23067; end
        8'd176: begin rb = 25'd9942047; rd = 16'd22961; end
        8'd177: begin rb = 25'd9919086; rd = 16'd22855; end
        8'd178: begin rb = 25'd9896231; rd = 16'd22750; end
        8'd179: begin rb = 25'd9873482; rd = 16'd22646; end
        8'd180: begin rb = 25'd9850836; rd = 16'd22542; end
        8'd181: begin rb = 25'd9828294; rd = 16'd22439; end
        8'd182: begin rb = 25'd9805855; rd = 16'd22337; end
        8'd183: begin rb = 25'd9783518; rd = 16'd22235; end
        8'd184: begin rb = 25'd9761283; rd = 16'd22134; end
        8'd185: begin rb = 25'd9739149; rd = 16'd22034; end
        8'd186: begin rb = 25'd9717115; rd = 16'd21935; end
        8'd187: begin rb = 25'd9695180; rd = 16'd21836; end
        8'd188: begin rb = 25'd9673344; rd = 16'd21738; end
        8'd189: begin rb = 25'd9651606; rd = 16'd21640; end
        8'd190: begin rb = 25'd9629966; rd = 16'd21544; end
        8'd191: begin rb = 25'd9608422; rd = 16'd21447; end
        8'd192: begin rb = 25'd9586975; rd = 16'd21352; end
        8'd193: begin rb = 25'd9565623; rd = 16'd21257; end
        8'd194: begin rb = 25'd9544366; rd = 16'd21163; end
        8'd195: begin rb = 25'd9523203; rd = 16'd21069; end
        8'd196: begin rb = 25'd9502134; rd = 16'd20976; end
        8'd197: begin rb = 25'd9481159; rd = 16'd20884; end
        8'd198: begin rb = 25'd9460275; rd = 16'd20792; end
        8'd199: begin rb = 25'd9439483; rd = 16'd20701; end
        8'd200: begin rb = 25'd9418782; rd = 16'd20610; end
        8'd201: begin rb = 25'd9398172; rd = 16'd20520; end
        8'd202: begin rb = 25'd9377653; rd = 16'd20431; end
        8'd203: begin rb = 25'd9357222; rd = 16'd20342; end
        8'd204: begin rb = 25'd9336880; rd = 16'd20254; end
        8'd205: begin rb = 25'd9316627; rd = 16'd20166; end
        8'd206: begin rb = 25'd9296461; rd = 16'd20079; end
        8'd207: begin rb = 25'd9276382; rd = 16'd19992; end
        8'd208: begin rb = 25'd9256390; rd = 16'd19906; end
        8'd209: begin rb = 25'd9236484; rd = 16'd19821; end
        8'd210: begin rb = 25'd9216663; rd = 16'd19736; end
        8'd211: begin rb = 25'd9196927; rd = 16'd19652; end
        8'd212: begin rb = 25'd9177276; rd = 16'd19568; end
        8'd213: begin rb = 25'd9157707; rd = 16'd19484; end
        8'd214: begin rb = 25'd9138223; rd = 16'd19402; end
        8'd215: begin rb = 25'd9118822; rd = 16'd19320; end
        8'd216: begin rb = 25'd9099502; rd = 16'd19238; end
        8'd217: begin rb = 25'd9080264; rd = 16'd19157; end
        8'd218: begin rb = 25'd9061107; rd = 16'd19076; end
        8'd219: begin rb = 25'd9042032; rd = 16'd18996; end
        8'd220: begin rb = 25'd9023036; rd = 16'd18916; end
        8'd221: begin rb = 25'd9004119; rd = 16'd18837; end
        8'd222: begin rb = 25'd8985282; rd = 16'd18758; end
        8'd223: begin rb = 25'd8966524; rd = 16'd18680; end
        8'd224: begin rb = 25'd8947844; rd = 16'd18603; end
        8'd225: begin rb = 25'd8929241; rd = 16'd18525; end
        8'd226: begin rb = 25'd8910716; rd = 16'd18449; end
        8'd227: begin rb = 25'd8892267; rd = 16'd18372; end
        8'd228: begin rb = 25'd8873895; rd = 16'd18297; end
        8'd229: begin rb = 25'd8855598; rd = 16'd18221; end
        8'd230: begin rb = 25'd8837377; rd = 16'd18147; end
        8'd231: begin rb = 25'd8819230; rd = 16'd18072; end
        8'd232: begin rb = 25'd8801158; rd = 16'd17998; end
        8'd233: begin rb = 25'd8783160; rd = 16'd17925; end
        8'd234: begin rb = 25'd8765235; rd = 16'd17852; end
        8'd235: begin rb = 25'd8747383; rd = 16'd17779; end
        8'd236: begin rb = 25'd8729604; rd = 16'd17707; end
        8'd237: begin rb = 25'd8711897; rd = 16'd17635; end
        8'd238: begin rb = 25'd8694261; rd = 16'd17564; end
        8'd239: begin rb = 25'd8676697; rd = 16'd17493; end
        8'd240: begin rb = 25'd8659204; rd = 16'd17423; end
        8'd241: begin rb = 25'd8641781; rd = 16'd17353; end
        8'd242: begin rb = 25'd8624428; rd = 16'd17283; end
        8'd243: begin rb = 25'd8607145; rd = 16'd17214; end
        8'd244: begin rb = 25'd8589931; rd = 16'd17146; end
        8'd245: begin rb = 25'd8572785; rd = 16'd17077; end
        8'd246: begin rb = 25'd8555707; rd = 16'd17009; end
        8'd247: begin rb = 25'd8538698; rd = 16'd16942; end
        8'd248: begin rb = 25'd8521756; rd = 16'd16875; end
        8'd249: begin rb = 25'd8504882; rd = 16'd16808; end
        8'd250: begin rb = 25'd8488074; rd = 16'd16742; end
        8'd251: begin rb = 25'd8471332; rd = 16'd16676; end
        8'd252: begin rb = 25'd8454656; rd = 16'd16610; end
        8'd253: begin rb = 25'd8438046; rd = 16'd16545; end
        8'd254: begin rb = 25'd8421500; rd = 16'd16480; end
        8'd255: begin rb = 25'd8405020; rd = 16'd16416; end
        default: begin rb = 25'd0; rd = 16'd0; end
    endcase
end
wire [30:0] rp = rd * low;
wire [30:0] rr = rp + 31'd16384;
assign y = rb - {9'd0, rr[30:15]};
endmodule
module tm_s(input wire signed [26:0] a, input wire signed [24:0] b, input wire flip, output wire signed [51:0] p);

wire [26:0] bx = {{2{b[24]}}, b};
wire [27:0] a1 = {a[26], a};
wire [27:0] a2 = {a, 1'b0};
wire [2:0] g0 = {bx[1], bx[0], 1'b0};
wire one0 = (g0 == 3'b001) || (g0 == 3'b010) || (g0 == 3'b101) || (g0 == 3'b110);
wire two0 = (g0 == 3'b011) || (g0 == 3'b100);
wire neg0 = (one0 || two0) && (g0[2] ^ flip);
wire [27:0] s0 = ({28{one0}} & a1) | ({28{two0}} & a2);
wire [27:0] x0 = neg0 ? ~s0 : s0;
wire [27:0] e0 = {~x0[27], x0[26:0]};
wire [53:0] k0 = {26'd0, e0[27:21], 21'd0};
wire [2:0] g1 = {bx[3], bx[2], bx[1]};
wire one1 = (g1 == 3'b001) || (g1 == 3'b010) || (g1 == 3'b101) || (g1 == 3'b110);
wire two1 = (g1 == 3'b011) || (g1 == 3'b100);
wire neg1 = (one1 || two1) && (g1[2] ^ flip);
wire [27:0] s1 = ({28{one1}} & a1) | ({28{two1}} & a2);
wire [27:0] x1 = neg1 ? ~s1 : s1;
wire [27:0] e1 = {~x1[27], x1[26:0]};
wire [53:0] k1 = {24'd0, e1[27:19], 21'd0};
wire [2:0] g2 = {bx[5], bx[4], bx[3]};
wire one2 = (g2 == 3'b001) || (g2 == 3'b010) || (g2 == 3'b101) || (g2 == 3'b110);
wire two2 = (g2 == 3'b011) || (g2 == 3'b100);
wire neg2 = (one2 || two2) && (g2[2] ^ flip);
wire [27:0] s2 = ({28{one2}} & a1) | ({28{two2}} & a2);
wire [27:0] x2 = neg2 ? ~s2 : s2;
wire [27:0] e2 = {~x2[27], x2[26:0]};
wire [53:0] k2 = {22'd0, e2[27:17], 21'd0};
wire [2:0] g3 = {bx[7], bx[6], bx[5]};
wire one3 = (g3 == 3'b001) || (g3 == 3'b010) || (g3 == 3'b101) || (g3 == 3'b110);
wire two3 = (g3 == 3'b011) || (g3 == 3'b100);
wire neg3 = (one3 || two3) && (g3[2] ^ flip);
wire [27:0] s3 = ({28{one3}} & a1) | ({28{two3}} & a2);
wire [27:0] x3 = neg3 ? ~s3 : s3;
wire [27:0] e3 = {~x3[27], x3[26:0]};
wire [53:0] k3 = {20'd0, e3[27:15], 21'd0};
wire [2:0] g4 = {bx[9], bx[8], bx[7]};
wire one4 = (g4 == 3'b001) || (g4 == 3'b010) || (g4 == 3'b101) || (g4 == 3'b110);
wire two4 = (g4 == 3'b011) || (g4 == 3'b100);
wire neg4 = (one4 || two4) && (g4[2] ^ flip);
wire [27:0] s4 = ({28{one4}} & a1) | ({28{two4}} & a2);
wire [27:0] x4 = neg4 ? ~s4 : s4;
wire [27:0] e4 = {~x4[27], x4[26:0]};
wire [53:0] k4 = {18'd0, e4[27:13], 21'd0};
wire [2:0] g5 = {bx[11], bx[10], bx[9]};
wire one5 = (g5 == 3'b001) || (g5 == 3'b010) || (g5 == 3'b101) || (g5 == 3'b110);
wire two5 = (g5 == 3'b011) || (g5 == 3'b100);
wire neg5 = (one5 || two5) && (g5[2] ^ flip);
wire [27:0] s5 = ({28{one5}} & a1) | ({28{two5}} & a2);
wire [27:0] x5 = neg5 ? ~s5 : s5;
wire [27:0] e5 = {~x5[27], x5[26:0]};
wire [53:0] k5 = {16'd0, e5[27:11], 21'd0};
wire [2:0] g6 = {bx[13], bx[12], bx[11]};
wire one6 = (g6 == 3'b001) || (g6 == 3'b010) || (g6 == 3'b101) || (g6 == 3'b110);
wire two6 = (g6 == 3'b011) || (g6 == 3'b100);
wire neg6 = (one6 || two6) && (g6[2] ^ flip);
wire [27:0] s6 = ({28{one6}} & a1) | ({28{two6}} & a2);
wire [27:0] x6 = neg6 ? ~s6 : s6;
wire [27:0] e6 = {~x6[27], x6[26:0]};
wire [53:0] k6 = {14'd0, e6[27:9], 21'd0};
wire [2:0] g7 = {bx[15], bx[14], bx[13]};
wire one7 = (g7 == 3'b001) || (g7 == 3'b010) || (g7 == 3'b101) || (g7 == 3'b110);
wire two7 = (g7 == 3'b011) || (g7 == 3'b100);
wire neg7 = (one7 || two7) && (g7[2] ^ flip);
wire [27:0] s7 = ({28{one7}} & a1) | ({28{two7}} & a2);
wire [27:0] x7 = neg7 ? ~s7 : s7;
wire [27:0] e7 = {~x7[27], x7[26:0]};
wire [53:0] k7 = {12'd0, e7[27:7], 21'd0};
wire [2:0] g8 = {bx[17], bx[16], bx[15]};
wire one8 = (g8 == 3'b001) || (g8 == 3'b010) || (g8 == 3'b101) || (g8 == 3'b110);
wire two8 = (g8 == 3'b011) || (g8 == 3'b100);
wire neg8 = (one8 || two8) && (g8[2] ^ flip);
wire [27:0] s8 = ({28{one8}} & a1) | ({28{two8}} & a2);
wire [27:0] x8 = neg8 ? ~s8 : s8;
wire [27:0] e8 = {~x8[27], x8[26:0]};
wire [53:0] k8 = {10'd0, e8[27:5], 21'd0};
wire [2:0] g9 = {bx[19], bx[18], bx[17]};
wire one9 = (g9 == 3'b001) || (g9 == 3'b010) || (g9 == 3'b101) || (g9 == 3'b110);
wire two9 = (g9 == 3'b011) || (g9 == 3'b100);
wire neg9 = (one9 || two9) && (g9[2] ^ flip);
wire [27:0] s9 = ({28{one9}} & a1) | ({28{two9}} & a2);
wire [27:0] x9 = neg9 ? ~s9 : s9;
wire [27:0] e9 = {~x9[27], x9[26:0]};
wire [53:0] k9 = {8'd0, e9[27:3], 21'd0};
wire [2:0] g10 = {bx[21], bx[20], bx[19]};
wire one10 = (g10 == 3'b001) || (g10 == 3'b010) || (g10 == 3'b101) || (g10 == 3'b110);
wire two10 = (g10 == 3'b011) || (g10 == 3'b100);
wire neg10 = (one10 || two10) && (g10[2] ^ flip);
wire [27:0] s10 = ({28{one10}} & a1) | ({28{two10}} & a2);
wire [27:0] x10 = neg10 ? ~s10 : s10;
wire [27:0] e10 = {~x10[27], x10[26:0]};
wire [53:0] k10 = {6'd0, e10[27:1], 21'd0};
wire [2:0] g11 = {bx[23], bx[22], bx[21]};
wire one11 = (g11 == 3'b001) || (g11 == 3'b010) || (g11 == 3'b101) || (g11 == 3'b110);
wire two11 = (g11 == 3'b011) || (g11 == 3'b100);
wire neg11 = (one11 || two11) && (g11[2] ^ flip);
wire [27:0] s11 = ({28{one11}} & a1) | ({28{two11}} & a2);
wire [27:0] x11 = neg11 ? ~s11 : s11;
wire [27:0] e11 = {~x11[27], x11[26:0]};
wire [53:0] k11 = {4'd0, e11[27:0], 22'd0};
wire [2:0] g12 = {bx[25], bx[24], bx[23]};
wire one12 = (g12 == 3'b001) || (g12 == 3'b010) || (g12 == 3'b101) || (g12 == 3'b110);
wire two12 = (g12 == 3'b011) || (g12 == 3'b100);
wire neg12 = (one12 || two12) && (g12[2] ^ flip);
wire [27:0] s12 = ({28{one12}} & a1) | ({28{two12}} & a2);
wire [27:0] x12 = neg12 ? ~s12 : s12;
wire [27:0] e12 = {~x12[27], x12[26:0]};
wire [53:0] k12 = {2'd0, e12[27:0], 24'd0};
wire [53:0] cor = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, neg12, 1'b0, neg11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
wire [53:0] tot = k0 + k1 + k2 + k3 + k4 + k5 + k6 + k7 + k8 + k9 + k10 + k11 + k12 + cor + 54'd15011998813126656;
assign p = $signed({tot[51:21], 21'd0});
endmodule
module tm_v(input wire signed [22:0] a, input wire signed [20:0] b, output wire signed [43:0] p);

wire [22:0] bx = {{2{b[20]}}, b};
wire [23:0] a1 = {a[22], a};
wire [23:0] a2 = {a, 1'b0};
wire [2:0] g0 = {bx[1], bx[0], 1'b0};
wire one0 = (g0 == 3'b001) || (g0 == 3'b010) || (g0 == 3'b101) || (g0 == 3'b110);
wire two0 = (g0 == 3'b011) || (g0 == 3'b100);
wire neg0 = g0[2] && !(g0 == 3'b111);
wire [23:0] s0 = ({24{one0}} & a1) | ({24{two0}} & a2);
wire [23:0] x0 = neg0 ? ~s0 : s0;
wire [23:0] e0 = {~x0[23], x0[22:0]};
wire [45:0] k0 = {22'd0, e0[23:18], 18'd0};
wire [2:0] g1 = {bx[3], bx[2], bx[1]};
wire one1 = (g1 == 3'b001) || (g1 == 3'b010) || (g1 == 3'b101) || (g1 == 3'b110);
wire two1 = (g1 == 3'b011) || (g1 == 3'b100);
wire neg1 = g1[2] && !(g1 == 3'b111);
wire [23:0] s1 = ({24{one1}} & a1) | ({24{two1}} & a2);
wire [23:0] x1 = neg1 ? ~s1 : s1;
wire [23:0] e1 = {~x1[23], x1[22:0]};
wire [45:0] k1 = {20'd0, e1[23:16], 18'd0};
wire [2:0] g2 = {bx[5], bx[4], bx[3]};
wire one2 = (g2 == 3'b001) || (g2 == 3'b010) || (g2 == 3'b101) || (g2 == 3'b110);
wire two2 = (g2 == 3'b011) || (g2 == 3'b100);
wire neg2 = g2[2] && !(g2 == 3'b111);
wire [23:0] s2 = ({24{one2}} & a1) | ({24{two2}} & a2);
wire [23:0] x2 = neg2 ? ~s2 : s2;
wire [23:0] e2 = {~x2[23], x2[22:0]};
wire [45:0] k2 = {18'd0, e2[23:14], 18'd0};
wire [2:0] g3 = {bx[7], bx[6], bx[5]};
wire one3 = (g3 == 3'b001) || (g3 == 3'b010) || (g3 == 3'b101) || (g3 == 3'b110);
wire two3 = (g3 == 3'b011) || (g3 == 3'b100);
wire neg3 = g3[2] && !(g3 == 3'b111);
wire [23:0] s3 = ({24{one3}} & a1) | ({24{two3}} & a2);
wire [23:0] x3 = neg3 ? ~s3 : s3;
wire [23:0] e3 = {~x3[23], x3[22:0]};
wire [45:0] k3 = {16'd0, e3[23:12], 18'd0};
wire [2:0] g4 = {bx[9], bx[8], bx[7]};
wire one4 = (g4 == 3'b001) || (g4 == 3'b010) || (g4 == 3'b101) || (g4 == 3'b110);
wire two4 = (g4 == 3'b011) || (g4 == 3'b100);
wire neg4 = g4[2] && !(g4 == 3'b111);
wire [23:0] s4 = ({24{one4}} & a1) | ({24{two4}} & a2);
wire [23:0] x4 = neg4 ? ~s4 : s4;
wire [23:0] e4 = {~x4[23], x4[22:0]};
wire [45:0] k4 = {14'd0, e4[23:10], 18'd0};
wire [2:0] g5 = {bx[11], bx[10], bx[9]};
wire one5 = (g5 == 3'b001) || (g5 == 3'b010) || (g5 == 3'b101) || (g5 == 3'b110);
wire two5 = (g5 == 3'b011) || (g5 == 3'b100);
wire neg5 = g5[2] && !(g5 == 3'b111);
wire [23:0] s5 = ({24{one5}} & a1) | ({24{two5}} & a2);
wire [23:0] x5 = neg5 ? ~s5 : s5;
wire [23:0] e5 = {~x5[23], x5[22:0]};
wire [45:0] k5 = {12'd0, e5[23:8], 18'd0};
wire [2:0] g6 = {bx[13], bx[12], bx[11]};
wire one6 = (g6 == 3'b001) || (g6 == 3'b010) || (g6 == 3'b101) || (g6 == 3'b110);
wire two6 = (g6 == 3'b011) || (g6 == 3'b100);
wire neg6 = g6[2] && !(g6 == 3'b111);
wire [23:0] s6 = ({24{one6}} & a1) | ({24{two6}} & a2);
wire [23:0] x6 = neg6 ? ~s6 : s6;
wire [23:0] e6 = {~x6[23], x6[22:0]};
wire [45:0] k6 = {10'd0, e6[23:6], 18'd0};
wire [2:0] g7 = {bx[15], bx[14], bx[13]};
wire one7 = (g7 == 3'b001) || (g7 == 3'b010) || (g7 == 3'b101) || (g7 == 3'b110);
wire two7 = (g7 == 3'b011) || (g7 == 3'b100);
wire neg7 = g7[2] && !(g7 == 3'b111);
wire [23:0] s7 = ({24{one7}} & a1) | ({24{two7}} & a2);
wire [23:0] x7 = neg7 ? ~s7 : s7;
wire [23:0] e7 = {~x7[23], x7[22:0]};
wire [45:0] k7 = {8'd0, e7[23:4], 18'd0};
wire [2:0] g8 = {bx[17], bx[16], bx[15]};
wire one8 = (g8 == 3'b001) || (g8 == 3'b010) || (g8 == 3'b101) || (g8 == 3'b110);
wire two8 = (g8 == 3'b011) || (g8 == 3'b100);
wire neg8 = g8[2] && !(g8 == 3'b111);
wire [23:0] s8 = ({24{one8}} & a1) | ({24{two8}} & a2);
wire [23:0] x8 = neg8 ? ~s8 : s8;
wire [23:0] e8 = {~x8[23], x8[22:0]};
wire [45:0] k8 = {6'd0, e8[23:2], 18'd0};
wire [2:0] g9 = {bx[19], bx[18], bx[17]};
wire one9 = (g9 == 3'b001) || (g9 == 3'b010) || (g9 == 3'b101) || (g9 == 3'b110);
wire two9 = (g9 == 3'b011) || (g9 == 3'b100);
wire neg9 = g9[2] && !(g9 == 3'b111);
wire [23:0] s9 = ({24{one9}} & a1) | ({24{two9}} & a2);
wire [23:0] x9 = neg9 ? ~s9 : s9;
wire [23:0] e9 = {~x9[23], x9[22:0]};
wire [45:0] k9 = {4'd0, e9[23:0], 18'd0};
wire [2:0] g10 = {bx[21], bx[20], bx[19]};
wire one10 = (g10 == 3'b001) || (g10 == 3'b010) || (g10 == 3'b101) || (g10 == 3'b110);
wire two10 = (g10 == 3'b011) || (g10 == 3'b100);
wire neg10 = g10[2] && !(g10 == 3'b111);
wire [23:0] s10 = ({24{one10}} & a1) | ({24{two10}} & a2);
wire [23:0] x10 = neg10 ? ~s10 : s10;
wire [23:0] e10 = {~x10[23], x10[22:0]};
wire [45:0] k10 = {2'd0, e10[23:0], 20'd0};
wire [45:0] cor = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, neg10, 1'b0, neg9, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
wire [45:0] tot = k0 + k1 + k2 + k3 + k4 + k5 + k6 + k7 + k8 + k9 + k10 + cor + 46'd58640623992832;
assign p = $signed({tot[43:18], 18'd0});
endmodule
module tm_h(input wire signed [28:0] a, input wire signed [25:0] b, input wire [54:0] c, output wire signed [54:0] p);

wire [27:0] bx = {{2{b[25]}}, b};
wire [29:0] a1 = {a[28], a};
wire [29:0] a2 = {a, 1'b0};
wire [2:0] g0 = {bx[1], bx[0], 1'b0};
wire one0 = (g0 == 3'b001) || (g0 == 3'b010) || (g0 == 3'b101) || (g0 == 3'b110);
wire two0 = (g0 == 3'b011) || (g0 == 3'b100);
wire neg0 = g0[2] && !(g0 == 3'b111);
wire [29:0] s0 = ({30{one0}} & a1) | ({30{two0}} & a2);
wire [29:0] x0 = neg0 ? ~s0 : s0;
wire [29:0] e0 = {~x0[29], x0[28:0]};
wire [56:0] k0 = {27'd0, e0[29:21], 21'd0};
wire [2:0] g1 = {bx[3], bx[2], bx[1]};
wire one1 = (g1 == 3'b001) || (g1 == 3'b010) || (g1 == 3'b101) || (g1 == 3'b110);
wire two1 = (g1 == 3'b011) || (g1 == 3'b100);
wire neg1 = g1[2] && !(g1 == 3'b111);
wire [29:0] s1 = ({30{one1}} & a1) | ({30{two1}} & a2);
wire [29:0] x1 = neg1 ? ~s1 : s1;
wire [29:0] e1 = {~x1[29], x1[28:0]};
wire [56:0] k1 = {25'd0, e1[29:19], 21'd0};
wire [2:0] g2 = {bx[5], bx[4], bx[3]};
wire one2 = (g2 == 3'b001) || (g2 == 3'b010) || (g2 == 3'b101) || (g2 == 3'b110);
wire two2 = (g2 == 3'b011) || (g2 == 3'b100);
wire neg2 = g2[2] && !(g2 == 3'b111);
wire [29:0] s2 = ({30{one2}} & a1) | ({30{two2}} & a2);
wire [29:0] x2 = neg2 ? ~s2 : s2;
wire [29:0] e2 = {~x2[29], x2[28:0]};
wire [56:0] k2 = {23'd0, e2[29:17], 21'd0};
wire [2:0] g3 = {bx[7], bx[6], bx[5]};
wire one3 = (g3 == 3'b001) || (g3 == 3'b010) || (g3 == 3'b101) || (g3 == 3'b110);
wire two3 = (g3 == 3'b011) || (g3 == 3'b100);
wire neg3 = g3[2] && !(g3 == 3'b111);
wire [29:0] s3 = ({30{one3}} & a1) | ({30{two3}} & a2);
wire [29:0] x3 = neg3 ? ~s3 : s3;
wire [29:0] e3 = {~x3[29], x3[28:0]};
wire [56:0] k3 = {21'd0, e3[29:15], 21'd0};
wire [2:0] g4 = {bx[9], bx[8], bx[7]};
wire one4 = (g4 == 3'b001) || (g4 == 3'b010) || (g4 == 3'b101) || (g4 == 3'b110);
wire two4 = (g4 == 3'b011) || (g4 == 3'b100);
wire neg4 = g4[2] && !(g4 == 3'b111);
wire [29:0] s4 = ({30{one4}} & a1) | ({30{two4}} & a2);
wire [29:0] x4 = neg4 ? ~s4 : s4;
wire [29:0] e4 = {~x4[29], x4[28:0]};
wire [56:0] k4 = {19'd0, e4[29:13], 21'd0};
wire [2:0] g5 = {bx[11], bx[10], bx[9]};
wire one5 = (g5 == 3'b001) || (g5 == 3'b010) || (g5 == 3'b101) || (g5 == 3'b110);
wire two5 = (g5 == 3'b011) || (g5 == 3'b100);
wire neg5 = g5[2] && !(g5 == 3'b111);
wire [29:0] s5 = ({30{one5}} & a1) | ({30{two5}} & a2);
wire [29:0] x5 = neg5 ? ~s5 : s5;
wire [29:0] e5 = {~x5[29], x5[28:0]};
wire [56:0] k5 = {17'd0, e5[29:11], 21'd0};
wire [2:0] g6 = {bx[13], bx[12], bx[11]};
wire one6 = (g6 == 3'b001) || (g6 == 3'b010) || (g6 == 3'b101) || (g6 == 3'b110);
wire two6 = (g6 == 3'b011) || (g6 == 3'b100);
wire neg6 = g6[2] && !(g6 == 3'b111);
wire [29:0] s6 = ({30{one6}} & a1) | ({30{two6}} & a2);
wire [29:0] x6 = neg6 ? ~s6 : s6;
wire [29:0] e6 = {~x6[29], x6[28:0]};
wire [56:0] k6 = {15'd0, e6[29:9], 21'd0};
wire [2:0] g7 = {bx[15], bx[14], bx[13]};
wire one7 = (g7 == 3'b001) || (g7 == 3'b010) || (g7 == 3'b101) || (g7 == 3'b110);
wire two7 = (g7 == 3'b011) || (g7 == 3'b100);
wire neg7 = g7[2] && !(g7 == 3'b111);
wire [29:0] s7 = ({30{one7}} & a1) | ({30{two7}} & a2);
wire [29:0] x7 = neg7 ? ~s7 : s7;
wire [29:0] e7 = {~x7[29], x7[28:0]};
wire [56:0] k7 = {13'd0, e7[29:7], 21'd0};
wire [2:0] g8 = {bx[17], bx[16], bx[15]};
wire one8 = (g8 == 3'b001) || (g8 == 3'b010) || (g8 == 3'b101) || (g8 == 3'b110);
wire two8 = (g8 == 3'b011) || (g8 == 3'b100);
wire neg8 = g8[2] && !(g8 == 3'b111);
wire [29:0] s8 = ({30{one8}} & a1) | ({30{two8}} & a2);
wire [29:0] x8 = neg8 ? ~s8 : s8;
wire [29:0] e8 = {~x8[29], x8[28:0]};
wire [56:0] k8 = {11'd0, e8[29:5], 21'd0};
wire [2:0] g9 = {bx[19], bx[18], bx[17]};
wire one9 = (g9 == 3'b001) || (g9 == 3'b010) || (g9 == 3'b101) || (g9 == 3'b110);
wire two9 = (g9 == 3'b011) || (g9 == 3'b100);
wire neg9 = g9[2] && !(g9 == 3'b111);
wire [29:0] s9 = ({30{one9}} & a1) | ({30{two9}} & a2);
wire [29:0] x9 = neg9 ? ~s9 : s9;
wire [29:0] e9 = {~x9[29], x9[28:0]};
wire [56:0] k9 = {9'd0, e9[29:3], 21'd0};
wire [2:0] g10 = {bx[21], bx[20], bx[19]};
wire one10 = (g10 == 3'b001) || (g10 == 3'b010) || (g10 == 3'b101) || (g10 == 3'b110);
wire two10 = (g10 == 3'b011) || (g10 == 3'b100);
wire neg10 = g10[2] && !(g10 == 3'b111);
wire [29:0] s10 = ({30{one10}} & a1) | ({30{two10}} & a2);
wire [29:0] x10 = neg10 ? ~s10 : s10;
wire [29:0] e10 = {~x10[29], x10[28:0]};
wire [56:0] k10 = {7'd0, e10[29:1], 21'd0};
wire [2:0] g11 = {bx[23], bx[22], bx[21]};
wire one11 = (g11 == 3'b001) || (g11 == 3'b010) || (g11 == 3'b101) || (g11 == 3'b110);
wire two11 = (g11 == 3'b011) || (g11 == 3'b100);
wire neg11 = g11[2] && !(g11 == 3'b111);
wire [29:0] s11 = ({30{one11}} & a1) | ({30{two11}} & a2);
wire [29:0] x11 = neg11 ? ~s11 : s11;
wire [29:0] e11 = {~x11[29], x11[28:0]};
wire [56:0] k11 = {5'd0, e11[29:0], 22'd0};
wire [2:0] g12 = {bx[25], bx[24], bx[23]};
wire one12 = (g12 == 3'b001) || (g12 == 3'b010) || (g12 == 3'b101) || (g12 == 3'b110);
wire two12 = (g12 == 3'b011) || (g12 == 3'b100);
wire neg12 = g12[2] && !(g12 == 3'b111);
wire [29:0] s12 = ({30{one12}} & a1) | ({30{two12}} & a2);
wire [29:0] x12 = neg12 ? ~s12 : s12;
wire [29:0] e12 = {~x12[29], x12[28:0]};
wire [56:0] k12 = {3'd0, e12[29:0], 24'd0};
wire [56:0] cor = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, neg12, 1'b0, neg11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
wire [56:0] ca = {{2{c[54]}}, c[54:21], 21'd0};
wire [56:0] tot = k0 + k1 + k2 + k3 + k4 + k5 + k6 + k7 + k8 + k9 + k10 + k11 + k12 + ca + cor + 57'd132105589258977280;
assign p = $signed({tot[54:21], 21'd0});
endmodule
module tm_p01(input wire signed [26:0] a, input wire signed [23:0] b, output wire signed [50:0] p);

wire [25:0] bx = {{2{b[23]}}, b};
wire [27:0] a1 = {a[26], a};
wire [27:0] a2 = {a, 1'b0};
wire [2:0] g0 = {bx[1], bx[0], 1'b0};
wire one0 = (g0 == 3'b001) || (g0 == 3'b010) || (g0 == 3'b101) || (g0 == 3'b110);
wire two0 = (g0 == 3'b011) || (g0 == 3'b100);
wire neg0 = g0[2] && !(g0 == 3'b111);
wire [27:0] s0 = ({28{one0}} & a1) | ({28{two0}} & a2);
wire [27:0] x0 = neg0 ? ~s0 : s0;
wire [27:0] e0 = {~x0[27], x0[26:0]};
wire [52:0] k0 = {25'd0, e0[27:21], 21'd0};
wire [2:0] g1 = {bx[3], bx[2], bx[1]};
wire one1 = (g1 == 3'b001) || (g1 == 3'b010) || (g1 == 3'b101) || (g1 == 3'b110);
wire two1 = (g1 == 3'b011) || (g1 == 3'b100);
wire neg1 = g1[2] && !(g1 == 3'b111);
wire [27:0] s1 = ({28{one1}} & a1) | ({28{two1}} & a2);
wire [27:0] x1 = neg1 ? ~s1 : s1;
wire [27:0] e1 = {~x1[27], x1[26:0]};
wire [52:0] k1 = {23'd0, e1[27:19], 21'd0};
wire [2:0] g2 = {bx[5], bx[4], bx[3]};
wire one2 = (g2 == 3'b001) || (g2 == 3'b010) || (g2 == 3'b101) || (g2 == 3'b110);
wire two2 = (g2 == 3'b011) || (g2 == 3'b100);
wire neg2 = g2[2] && !(g2 == 3'b111);
wire [27:0] s2 = ({28{one2}} & a1) | ({28{two2}} & a2);
wire [27:0] x2 = neg2 ? ~s2 : s2;
wire [27:0] e2 = {~x2[27], x2[26:0]};
wire [52:0] k2 = {21'd0, e2[27:17], 21'd0};
wire [2:0] g3 = {bx[7], bx[6], bx[5]};
wire one3 = (g3 == 3'b001) || (g3 == 3'b010) || (g3 == 3'b101) || (g3 == 3'b110);
wire two3 = (g3 == 3'b011) || (g3 == 3'b100);
wire neg3 = g3[2] && !(g3 == 3'b111);
wire [27:0] s3 = ({28{one3}} & a1) | ({28{two3}} & a2);
wire [27:0] x3 = neg3 ? ~s3 : s3;
wire [27:0] e3 = {~x3[27], x3[26:0]};
wire [52:0] k3 = {19'd0, e3[27:15], 21'd0};
wire [2:0] g4 = {bx[9], bx[8], bx[7]};
wire one4 = (g4 == 3'b001) || (g4 == 3'b010) || (g4 == 3'b101) || (g4 == 3'b110);
wire two4 = (g4 == 3'b011) || (g4 == 3'b100);
wire neg4 = g4[2] && !(g4 == 3'b111);
wire [27:0] s4 = ({28{one4}} & a1) | ({28{two4}} & a2);
wire [27:0] x4 = neg4 ? ~s4 : s4;
wire [27:0] e4 = {~x4[27], x4[26:0]};
wire [52:0] k4 = {17'd0, e4[27:13], 21'd0};
wire [2:0] g5 = {bx[11], bx[10], bx[9]};
wire one5 = (g5 == 3'b001) || (g5 == 3'b010) || (g5 == 3'b101) || (g5 == 3'b110);
wire two5 = (g5 == 3'b011) || (g5 == 3'b100);
wire neg5 = g5[2] && !(g5 == 3'b111);
wire [27:0] s5 = ({28{one5}} & a1) | ({28{two5}} & a2);
wire [27:0] x5 = neg5 ? ~s5 : s5;
wire [27:0] e5 = {~x5[27], x5[26:0]};
wire [52:0] k5 = {15'd0, e5[27:11], 21'd0};
wire [2:0] g6 = {bx[13], bx[12], bx[11]};
wire one6 = (g6 == 3'b001) || (g6 == 3'b010) || (g6 == 3'b101) || (g6 == 3'b110);
wire two6 = (g6 == 3'b011) || (g6 == 3'b100);
wire neg6 = g6[2] && !(g6 == 3'b111);
wire [27:0] s6 = ({28{one6}} & a1) | ({28{two6}} & a2);
wire [27:0] x6 = neg6 ? ~s6 : s6;
wire [27:0] e6 = {~x6[27], x6[26:0]};
wire [52:0] k6 = {13'd0, e6[27:9], 21'd0};
wire [2:0] g7 = {bx[15], bx[14], bx[13]};
wire one7 = (g7 == 3'b001) || (g7 == 3'b010) || (g7 == 3'b101) || (g7 == 3'b110);
wire two7 = (g7 == 3'b011) || (g7 == 3'b100);
wire neg7 = g7[2] && !(g7 == 3'b111);
wire [27:0] s7 = ({28{one7}} & a1) | ({28{two7}} & a2);
wire [27:0] x7 = neg7 ? ~s7 : s7;
wire [27:0] e7 = {~x7[27], x7[26:0]};
wire [52:0] k7 = {11'd0, e7[27:7], 21'd0};
wire [2:0] g8 = {bx[17], bx[16], bx[15]};
wire one8 = (g8 == 3'b001) || (g8 == 3'b010) || (g8 == 3'b101) || (g8 == 3'b110);
wire two8 = (g8 == 3'b011) || (g8 == 3'b100);
wire neg8 = g8[2] && !(g8 == 3'b111);
wire [27:0] s8 = ({28{one8}} & a1) | ({28{two8}} & a2);
wire [27:0] x8 = neg8 ? ~s8 : s8;
wire [27:0] e8 = {~x8[27], x8[26:0]};
wire [52:0] k8 = {9'd0, e8[27:5], 21'd0};
wire [2:0] g9 = {bx[19], bx[18], bx[17]};
wire one9 = (g9 == 3'b001) || (g9 == 3'b010) || (g9 == 3'b101) || (g9 == 3'b110);
wire two9 = (g9 == 3'b011) || (g9 == 3'b100);
wire neg9 = g9[2] && !(g9 == 3'b111);
wire [27:0] s9 = ({28{one9}} & a1) | ({28{two9}} & a2);
wire [27:0] x9 = neg9 ? ~s9 : s9;
wire [27:0] e9 = {~x9[27], x9[26:0]};
wire [52:0] k9 = {7'd0, e9[27:3], 21'd0};
wire [2:0] g10 = {bx[21], bx[20], bx[19]};
wire one10 = (g10 == 3'b001) || (g10 == 3'b010) || (g10 == 3'b101) || (g10 == 3'b110);
wire two10 = (g10 == 3'b011) || (g10 == 3'b100);
wire neg10 = g10[2] && !(g10 == 3'b111);
wire [27:0] s10 = ({28{one10}} & a1) | ({28{two10}} & a2);
wire [27:0] x10 = neg10 ? ~s10 : s10;
wire [27:0] e10 = {~x10[27], x10[26:0]};
wire [52:0] k10 = {5'd0, e10[27:1], 21'd0};
wire [2:0] g11 = {bx[23], bx[22], bx[21]};
wire one11 = (g11 == 3'b001) || (g11 == 3'b010) || (g11 == 3'b101) || (g11 == 3'b110);
wire two11 = (g11 == 3'b011) || (g11 == 3'b100);
wire neg11 = g11[2] && !(g11 == 3'b111);
wire [27:0] s11 = ({28{one11}} & a1) | ({28{two11}} & a2);
wire [27:0] x11 = neg11 ? ~s11 : s11;
wire [27:0] e11 = {~x11[27], x11[26:0]};
wire [52:0] k11 = {3'd0, e11[27:0], 22'd0};
wire [52:0] cor = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, neg11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
wire [52:0] tot = k0 + k1 + k2 + k3 + k4 + k5 + k6 + k7 + k8 + k9 + k10 + k11 + cor + 53'd8256599372070912;
assign p = $signed({tot[50:21], 21'd0});
endmodule
module tm_pa(input wire signed [31:0] a, input wire signed [25:0] b, input wire flip, input wire [57:0] c, output wire signed [57:0] p);

wire [27:0] bx = {{2{b[25]}}, b};
wire [32:0] a1 = {a[31], a};
wire [32:0] a2 = {a, 1'b0};
wire [2:0] g0 = {bx[1], bx[0], 1'b0};
wire one0 = (g0 == 3'b001) || (g0 == 3'b010) || (g0 == 3'b101) || (g0 == 3'b110);
wire two0 = (g0 == 3'b011) || (g0 == 3'b100);
wire neg0 = (one0 || two0) && (g0[2] ^ flip);
wire [32:0] s0 = ({33{one0}} & a1) | ({33{two0}} & a2);
wire [32:0] x0 = neg0 ? ~s0 : s0;
wire [32:0] e0 = {~x0[32], x0[31:0]};
wire [59:0] k0 = {27'd0, e0[32:21], 21'd0};
wire [2:0] g1 = {bx[3], bx[2], bx[1]};
wire one1 = (g1 == 3'b001) || (g1 == 3'b010) || (g1 == 3'b101) || (g1 == 3'b110);
wire two1 = (g1 == 3'b011) || (g1 == 3'b100);
wire neg1 = (one1 || two1) && (g1[2] ^ flip);
wire [32:0] s1 = ({33{one1}} & a1) | ({33{two1}} & a2);
wire [32:0] x1 = neg1 ? ~s1 : s1;
wire [32:0] e1 = {~x1[32], x1[31:0]};
wire [59:0] k1 = {25'd0, e1[32:19], 21'd0};
wire [2:0] g2 = {bx[5], bx[4], bx[3]};
wire one2 = (g2 == 3'b001) || (g2 == 3'b010) || (g2 == 3'b101) || (g2 == 3'b110);
wire two2 = (g2 == 3'b011) || (g2 == 3'b100);
wire neg2 = (one2 || two2) && (g2[2] ^ flip);
wire [32:0] s2 = ({33{one2}} & a1) | ({33{two2}} & a2);
wire [32:0] x2 = neg2 ? ~s2 : s2;
wire [32:0] e2 = {~x2[32], x2[31:0]};
wire [59:0] k2 = {23'd0, e2[32:17], 21'd0};
wire [2:0] g3 = {bx[7], bx[6], bx[5]};
wire one3 = (g3 == 3'b001) || (g3 == 3'b010) || (g3 == 3'b101) || (g3 == 3'b110);
wire two3 = (g3 == 3'b011) || (g3 == 3'b100);
wire neg3 = (one3 || two3) && (g3[2] ^ flip);
wire [32:0] s3 = ({33{one3}} & a1) | ({33{two3}} & a2);
wire [32:0] x3 = neg3 ? ~s3 : s3;
wire [32:0] e3 = {~x3[32], x3[31:0]};
wire [59:0] k3 = {21'd0, e3[32:15], 21'd0};
wire [2:0] g4 = {bx[9], bx[8], bx[7]};
wire one4 = (g4 == 3'b001) || (g4 == 3'b010) || (g4 == 3'b101) || (g4 == 3'b110);
wire two4 = (g4 == 3'b011) || (g4 == 3'b100);
wire neg4 = (one4 || two4) && (g4[2] ^ flip);
wire [32:0] s4 = ({33{one4}} & a1) | ({33{two4}} & a2);
wire [32:0] x4 = neg4 ? ~s4 : s4;
wire [32:0] e4 = {~x4[32], x4[31:0]};
wire [59:0] k4 = {19'd0, e4[32:13], 21'd0};
wire [2:0] g5 = {bx[11], bx[10], bx[9]};
wire one5 = (g5 == 3'b001) || (g5 == 3'b010) || (g5 == 3'b101) || (g5 == 3'b110);
wire two5 = (g5 == 3'b011) || (g5 == 3'b100);
wire neg5 = (one5 || two5) && (g5[2] ^ flip);
wire [32:0] s5 = ({33{one5}} & a1) | ({33{two5}} & a2);
wire [32:0] x5 = neg5 ? ~s5 : s5;
wire [32:0] e5 = {~x5[32], x5[31:0]};
wire [59:0] k5 = {17'd0, e5[32:11], 21'd0};
wire [2:0] g6 = {bx[13], bx[12], bx[11]};
wire one6 = (g6 == 3'b001) || (g6 == 3'b010) || (g6 == 3'b101) || (g6 == 3'b110);
wire two6 = (g6 == 3'b011) || (g6 == 3'b100);
wire neg6 = (one6 || two6) && (g6[2] ^ flip);
wire [32:0] s6 = ({33{one6}} & a1) | ({33{two6}} & a2);
wire [32:0] x6 = neg6 ? ~s6 : s6;
wire [32:0] e6 = {~x6[32], x6[31:0]};
wire [59:0] k6 = {15'd0, e6[32:9], 21'd0};
wire [2:0] g7 = {bx[15], bx[14], bx[13]};
wire one7 = (g7 == 3'b001) || (g7 == 3'b010) || (g7 == 3'b101) || (g7 == 3'b110);
wire two7 = (g7 == 3'b011) || (g7 == 3'b100);
wire neg7 = (one7 || two7) && (g7[2] ^ flip);
wire [32:0] s7 = ({33{one7}} & a1) | ({33{two7}} & a2);
wire [32:0] x7 = neg7 ? ~s7 : s7;
wire [32:0] e7 = {~x7[32], x7[31:0]};
wire [59:0] k7 = {13'd0, e7[32:7], 21'd0};
wire [2:0] g8 = {bx[17], bx[16], bx[15]};
wire one8 = (g8 == 3'b001) || (g8 == 3'b010) || (g8 == 3'b101) || (g8 == 3'b110);
wire two8 = (g8 == 3'b011) || (g8 == 3'b100);
wire neg8 = (one8 || two8) && (g8[2] ^ flip);
wire [32:0] s8 = ({33{one8}} & a1) | ({33{two8}} & a2);
wire [32:0] x8 = neg8 ? ~s8 : s8;
wire [32:0] e8 = {~x8[32], x8[31:0]};
wire [59:0] k8 = {11'd0, e8[32:5], 21'd0};
wire [2:0] g9 = {bx[19], bx[18], bx[17]};
wire one9 = (g9 == 3'b001) || (g9 == 3'b010) || (g9 == 3'b101) || (g9 == 3'b110);
wire two9 = (g9 == 3'b011) || (g9 == 3'b100);
wire neg9 = (one9 || two9) && (g9[2] ^ flip);
wire [32:0] s9 = ({33{one9}} & a1) | ({33{two9}} & a2);
wire [32:0] x9 = neg9 ? ~s9 : s9;
wire [32:0] e9 = {~x9[32], x9[31:0]};
wire [59:0] k9 = {9'd0, e9[32:3], 21'd0};
wire [2:0] g10 = {bx[21], bx[20], bx[19]};
wire one10 = (g10 == 3'b001) || (g10 == 3'b010) || (g10 == 3'b101) || (g10 == 3'b110);
wire two10 = (g10 == 3'b011) || (g10 == 3'b100);
wire neg10 = (one10 || two10) && (g10[2] ^ flip);
wire [32:0] s10 = ({33{one10}} & a1) | ({33{two10}} & a2);
wire [32:0] x10 = neg10 ? ~s10 : s10;
wire [32:0] e10 = {~x10[32], x10[31:0]};
wire [59:0] k10 = {7'd0, e10[32:1], 21'd0};
wire [2:0] g11 = {bx[23], bx[22], bx[21]};
wire one11 = (g11 == 3'b001) || (g11 == 3'b010) || (g11 == 3'b101) || (g11 == 3'b110);
wire two11 = (g11 == 3'b011) || (g11 == 3'b100);
wire neg11 = (one11 || two11) && (g11[2] ^ flip);
wire [32:0] s11 = ({33{one11}} & a1) | ({33{two11}} & a2);
wire [32:0] x11 = neg11 ? ~s11 : s11;
wire [32:0] e11 = {~x11[32], x11[31:0]};
wire [59:0] k11 = {5'd0, e11[32:0], 22'd0};
wire [2:0] g12 = {bx[25], bx[24], bx[23]};
wire one12 = (g12 == 3'b001) || (g12 == 3'b010) || (g12 == 3'b101) || (g12 == 3'b110);
wire two12 = (g12 == 3'b011) || (g12 == 3'b100);
wire neg12 = (one12 || two12) && (g12[2] ^ flip);
wire [32:0] s12 = ({33{one12}} & a1) | ({33{two12}} & a2);
wire [32:0] x12 = neg12 ? ~s12 : s12;
wire [32:0] e12 = {~x12[32], x12[31:0]};
wire [59:0] k12 = {3'd0, e12[32:0], 24'd0};
wire [59:0] cor = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, neg12, 1'b0, neg11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
wire [59:0] ca = {{2{c[57]}}, c[57:21], 21'd0};
wire [59:0] tot = k0 + k1 + k2 + k3 + k4 + k5 + k6 + k7 + k8 + k9 + k10 + k11 + k12 + ca + cor + 60'd1056844713998417920;
assign p = $signed({tot[57:21], 21'd0});
endmodule
module tm_p3f(input wire signed [24:0] a, input wire signed [24:0] b, input wire flip, output wire signed [49:0] p);

wire [26:0] bx = {{2{b[24]}}, b};
wire [25:0] a1 = {a[24], a};
wire [25:0] a2 = {a, 1'b0};
wire [2:0] g0 = {bx[1], bx[0], 1'b0};
wire one0 = (g0 == 3'b001) || (g0 == 3'b010) || (g0 == 3'b101) || (g0 == 3'b110);
wire two0 = (g0 == 3'b011) || (g0 == 3'b100);
wire neg0 = (one0 || two0) && (g0[2] ^ flip);
wire [25:0] s0 = ({26{one0}} & a1) | ({26{two0}} & a2);
wire [25:0] x0 = neg0 ? ~s0 : s0;
wire [25:0] e0 = {~x0[25], x0[24:0]};
wire [51:0] k0 = {26'd0, e0[25:21], 21'd0};
wire [2:0] g1 = {bx[3], bx[2], bx[1]};
wire one1 = (g1 == 3'b001) || (g1 == 3'b010) || (g1 == 3'b101) || (g1 == 3'b110);
wire two1 = (g1 == 3'b011) || (g1 == 3'b100);
wire neg1 = (one1 || two1) && (g1[2] ^ flip);
wire [25:0] s1 = ({26{one1}} & a1) | ({26{two1}} & a2);
wire [25:0] x1 = neg1 ? ~s1 : s1;
wire [25:0] e1 = {~x1[25], x1[24:0]};
wire [51:0] k1 = {24'd0, e1[25:19], 21'd0};
wire [2:0] g2 = {bx[5], bx[4], bx[3]};
wire one2 = (g2 == 3'b001) || (g2 == 3'b010) || (g2 == 3'b101) || (g2 == 3'b110);
wire two2 = (g2 == 3'b011) || (g2 == 3'b100);
wire neg2 = (one2 || two2) && (g2[2] ^ flip);
wire [25:0] s2 = ({26{one2}} & a1) | ({26{two2}} & a2);
wire [25:0] x2 = neg2 ? ~s2 : s2;
wire [25:0] e2 = {~x2[25], x2[24:0]};
wire [51:0] k2 = {22'd0, e2[25:17], 21'd0};
wire [2:0] g3 = {bx[7], bx[6], bx[5]};
wire one3 = (g3 == 3'b001) || (g3 == 3'b010) || (g3 == 3'b101) || (g3 == 3'b110);
wire two3 = (g3 == 3'b011) || (g3 == 3'b100);
wire neg3 = (one3 || two3) && (g3[2] ^ flip);
wire [25:0] s3 = ({26{one3}} & a1) | ({26{two3}} & a2);
wire [25:0] x3 = neg3 ? ~s3 : s3;
wire [25:0] e3 = {~x3[25], x3[24:0]};
wire [51:0] k3 = {20'd0, e3[25:15], 21'd0};
wire [2:0] g4 = {bx[9], bx[8], bx[7]};
wire one4 = (g4 == 3'b001) || (g4 == 3'b010) || (g4 == 3'b101) || (g4 == 3'b110);
wire two4 = (g4 == 3'b011) || (g4 == 3'b100);
wire neg4 = (one4 || two4) && (g4[2] ^ flip);
wire [25:0] s4 = ({26{one4}} & a1) | ({26{two4}} & a2);
wire [25:0] x4 = neg4 ? ~s4 : s4;
wire [25:0] e4 = {~x4[25], x4[24:0]};
wire [51:0] k4 = {18'd0, e4[25:13], 21'd0};
wire [2:0] g5 = {bx[11], bx[10], bx[9]};
wire one5 = (g5 == 3'b001) || (g5 == 3'b010) || (g5 == 3'b101) || (g5 == 3'b110);
wire two5 = (g5 == 3'b011) || (g5 == 3'b100);
wire neg5 = (one5 || two5) && (g5[2] ^ flip);
wire [25:0] s5 = ({26{one5}} & a1) | ({26{two5}} & a2);
wire [25:0] x5 = neg5 ? ~s5 : s5;
wire [25:0] e5 = {~x5[25], x5[24:0]};
wire [51:0] k5 = {16'd0, e5[25:11], 21'd0};
wire [2:0] g6 = {bx[13], bx[12], bx[11]};
wire one6 = (g6 == 3'b001) || (g6 == 3'b010) || (g6 == 3'b101) || (g6 == 3'b110);
wire two6 = (g6 == 3'b011) || (g6 == 3'b100);
wire neg6 = (one6 || two6) && (g6[2] ^ flip);
wire [25:0] s6 = ({26{one6}} & a1) | ({26{two6}} & a2);
wire [25:0] x6 = neg6 ? ~s6 : s6;
wire [25:0] e6 = {~x6[25], x6[24:0]};
wire [51:0] k6 = {14'd0, e6[25:9], 21'd0};
wire [2:0] g7 = {bx[15], bx[14], bx[13]};
wire one7 = (g7 == 3'b001) || (g7 == 3'b010) || (g7 == 3'b101) || (g7 == 3'b110);
wire two7 = (g7 == 3'b011) || (g7 == 3'b100);
wire neg7 = (one7 || two7) && (g7[2] ^ flip);
wire [25:0] s7 = ({26{one7}} & a1) | ({26{two7}} & a2);
wire [25:0] x7 = neg7 ? ~s7 : s7;
wire [25:0] e7 = {~x7[25], x7[24:0]};
wire [51:0] k7 = {12'd0, e7[25:7], 21'd0};
wire [2:0] g8 = {bx[17], bx[16], bx[15]};
wire one8 = (g8 == 3'b001) || (g8 == 3'b010) || (g8 == 3'b101) || (g8 == 3'b110);
wire two8 = (g8 == 3'b011) || (g8 == 3'b100);
wire neg8 = (one8 || two8) && (g8[2] ^ flip);
wire [25:0] s8 = ({26{one8}} & a1) | ({26{two8}} & a2);
wire [25:0] x8 = neg8 ? ~s8 : s8;
wire [25:0] e8 = {~x8[25], x8[24:0]};
wire [51:0] k8 = {10'd0, e8[25:5], 21'd0};
wire [2:0] g9 = {bx[19], bx[18], bx[17]};
wire one9 = (g9 == 3'b001) || (g9 == 3'b010) || (g9 == 3'b101) || (g9 == 3'b110);
wire two9 = (g9 == 3'b011) || (g9 == 3'b100);
wire neg9 = (one9 || two9) && (g9[2] ^ flip);
wire [25:0] s9 = ({26{one9}} & a1) | ({26{two9}} & a2);
wire [25:0] x9 = neg9 ? ~s9 : s9;
wire [25:0] e9 = {~x9[25], x9[24:0]};
wire [51:0] k9 = {8'd0, e9[25:3], 21'd0};
wire [2:0] g10 = {bx[21], bx[20], bx[19]};
wire one10 = (g10 == 3'b001) || (g10 == 3'b010) || (g10 == 3'b101) || (g10 == 3'b110);
wire two10 = (g10 == 3'b011) || (g10 == 3'b100);
wire neg10 = (one10 || two10) && (g10[2] ^ flip);
wire [25:0] s10 = ({26{one10}} & a1) | ({26{two10}} & a2);
wire [25:0] x10 = neg10 ? ~s10 : s10;
wire [25:0] e10 = {~x10[25], x10[24:0]};
wire [51:0] k10 = {6'd0, e10[25:1], 21'd0};
wire [2:0] g11 = {bx[23], bx[22], bx[21]};
wire one11 = (g11 == 3'b001) || (g11 == 3'b010) || (g11 == 3'b101) || (g11 == 3'b110);
wire two11 = (g11 == 3'b011) || (g11 == 3'b100);
wire neg11 = (one11 || two11) && (g11[2] ^ flip);
wire [25:0] s11 = ({26{one11}} & a1) | ({26{two11}} & a2);
wire [25:0] x11 = neg11 ? ~s11 : s11;
wire [25:0] e11 = {~x11[25], x11[24:0]};
wire [51:0] k11 = {4'd0, e11[25:0], 22'd0};
wire [2:0] g12 = {bx[25], bx[24], bx[23]};
wire one12 = (g12 == 3'b001) || (g12 == 3'b010) || (g12 == 3'b101) || (g12 == 3'b110);
wire two12 = (g12 == 3'b011) || (g12 == 3'b100);
wire neg12 = (one12 || two12) && (g12[2] ^ flip);
wire [25:0] s12 = ({26{one12}} & a1) | ({26{two12}} & a2);
wire [25:0] x12 = neg12 ? ~s12 : s12;
wire [25:0] e12 = {~x12[25], x12[24:0]};
wire [51:0] k12 = {2'd0, e12[25:0], 24'd0};
wire [51:0] cor = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, neg12, 1'b0, neg11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
wire [51:0] tot = k0 + k1 + k2 + k3 + k4 + k5 + k6 + k7 + k8 + k9 + k10 + k11 + k12 + cor + 52'd3752999711145984;
assign p = $signed({tot[49:21], 21'd0});
endmodule
module tm_t1f(input wire signed [24:0] a, input wire signed [26:0] b, input wire flip, output wire signed [51:0] p);

wire [28:0] bx = {{2{b[26]}}, b};
wire [25:0] a1 = {a[24], a};
wire [25:0] a2 = {a, 1'b0};
wire [2:0] g0 = {bx[1], bx[0], 1'b0};
wire one0 = (g0 == 3'b001) || (g0 == 3'b010) || (g0 == 3'b101) || (g0 == 3'b110);
wire two0 = (g0 == 3'b011) || (g0 == 3'b100);
wire neg0 = (one0 || two0) && (g0[2] ^ flip);
wire [25:0] s0 = ({26{one0}} & a1) | ({26{two0}} & a2);
wire [25:0] x0 = neg0 ? ~s0 : s0;
wire [25:0] e0 = {~x0[25], x0[24:0]};
wire [53:0] k0 = {28'd0, e0[25:21], 21'd0};
wire [2:0] g1 = {bx[3], bx[2], bx[1]};
wire one1 = (g1 == 3'b001) || (g1 == 3'b010) || (g1 == 3'b101) || (g1 == 3'b110);
wire two1 = (g1 == 3'b011) || (g1 == 3'b100);
wire neg1 = (one1 || two1) && (g1[2] ^ flip);
wire [25:0] s1 = ({26{one1}} & a1) | ({26{two1}} & a2);
wire [25:0] x1 = neg1 ? ~s1 : s1;
wire [25:0] e1 = {~x1[25], x1[24:0]};
wire [53:0] k1 = {26'd0, e1[25:19], 21'd0};
wire [2:0] g2 = {bx[5], bx[4], bx[3]};
wire one2 = (g2 == 3'b001) || (g2 == 3'b010) || (g2 == 3'b101) || (g2 == 3'b110);
wire two2 = (g2 == 3'b011) || (g2 == 3'b100);
wire neg2 = (one2 || two2) && (g2[2] ^ flip);
wire [25:0] s2 = ({26{one2}} & a1) | ({26{two2}} & a2);
wire [25:0] x2 = neg2 ? ~s2 : s2;
wire [25:0] e2 = {~x2[25], x2[24:0]};
wire [53:0] k2 = {24'd0, e2[25:17], 21'd0};
wire [2:0] g3 = {bx[7], bx[6], bx[5]};
wire one3 = (g3 == 3'b001) || (g3 == 3'b010) || (g3 == 3'b101) || (g3 == 3'b110);
wire two3 = (g3 == 3'b011) || (g3 == 3'b100);
wire neg3 = (one3 || two3) && (g3[2] ^ flip);
wire [25:0] s3 = ({26{one3}} & a1) | ({26{two3}} & a2);
wire [25:0] x3 = neg3 ? ~s3 : s3;
wire [25:0] e3 = {~x3[25], x3[24:0]};
wire [53:0] k3 = {22'd0, e3[25:15], 21'd0};
wire [2:0] g4 = {bx[9], bx[8], bx[7]};
wire one4 = (g4 == 3'b001) || (g4 == 3'b010) || (g4 == 3'b101) || (g4 == 3'b110);
wire two4 = (g4 == 3'b011) || (g4 == 3'b100);
wire neg4 = (one4 || two4) && (g4[2] ^ flip);
wire [25:0] s4 = ({26{one4}} & a1) | ({26{two4}} & a2);
wire [25:0] x4 = neg4 ? ~s4 : s4;
wire [25:0] e4 = {~x4[25], x4[24:0]};
wire [53:0] k4 = {20'd0, e4[25:13], 21'd0};
wire [2:0] g5 = {bx[11], bx[10], bx[9]};
wire one5 = (g5 == 3'b001) || (g5 == 3'b010) || (g5 == 3'b101) || (g5 == 3'b110);
wire two5 = (g5 == 3'b011) || (g5 == 3'b100);
wire neg5 = (one5 || two5) && (g5[2] ^ flip);
wire [25:0] s5 = ({26{one5}} & a1) | ({26{two5}} & a2);
wire [25:0] x5 = neg5 ? ~s5 : s5;
wire [25:0] e5 = {~x5[25], x5[24:0]};
wire [53:0] k5 = {18'd0, e5[25:11], 21'd0};
wire [2:0] g6 = {bx[13], bx[12], bx[11]};
wire one6 = (g6 == 3'b001) || (g6 == 3'b010) || (g6 == 3'b101) || (g6 == 3'b110);
wire two6 = (g6 == 3'b011) || (g6 == 3'b100);
wire neg6 = (one6 || two6) && (g6[2] ^ flip);
wire [25:0] s6 = ({26{one6}} & a1) | ({26{two6}} & a2);
wire [25:0] x6 = neg6 ? ~s6 : s6;
wire [25:0] e6 = {~x6[25], x6[24:0]};
wire [53:0] k6 = {16'd0, e6[25:9], 21'd0};
wire [2:0] g7 = {bx[15], bx[14], bx[13]};
wire one7 = (g7 == 3'b001) || (g7 == 3'b010) || (g7 == 3'b101) || (g7 == 3'b110);
wire two7 = (g7 == 3'b011) || (g7 == 3'b100);
wire neg7 = (one7 || two7) && (g7[2] ^ flip);
wire [25:0] s7 = ({26{one7}} & a1) | ({26{two7}} & a2);
wire [25:0] x7 = neg7 ? ~s7 : s7;
wire [25:0] e7 = {~x7[25], x7[24:0]};
wire [53:0] k7 = {14'd0, e7[25:7], 21'd0};
wire [2:0] g8 = {bx[17], bx[16], bx[15]};
wire one8 = (g8 == 3'b001) || (g8 == 3'b010) || (g8 == 3'b101) || (g8 == 3'b110);
wire two8 = (g8 == 3'b011) || (g8 == 3'b100);
wire neg8 = (one8 || two8) && (g8[2] ^ flip);
wire [25:0] s8 = ({26{one8}} & a1) | ({26{two8}} & a2);
wire [25:0] x8 = neg8 ? ~s8 : s8;
wire [25:0] e8 = {~x8[25], x8[24:0]};
wire [53:0] k8 = {12'd0, e8[25:5], 21'd0};
wire [2:0] g9 = {bx[19], bx[18], bx[17]};
wire one9 = (g9 == 3'b001) || (g9 == 3'b010) || (g9 == 3'b101) || (g9 == 3'b110);
wire two9 = (g9 == 3'b011) || (g9 == 3'b100);
wire neg9 = (one9 || two9) && (g9[2] ^ flip);
wire [25:0] s9 = ({26{one9}} & a1) | ({26{two9}} & a2);
wire [25:0] x9 = neg9 ? ~s9 : s9;
wire [25:0] e9 = {~x9[25], x9[24:0]};
wire [53:0] k9 = {10'd0, e9[25:3], 21'd0};
wire [2:0] g10 = {bx[21], bx[20], bx[19]};
wire one10 = (g10 == 3'b001) || (g10 == 3'b010) || (g10 == 3'b101) || (g10 == 3'b110);
wire two10 = (g10 == 3'b011) || (g10 == 3'b100);
wire neg10 = (one10 || two10) && (g10[2] ^ flip);
wire [25:0] s10 = ({26{one10}} & a1) | ({26{two10}} & a2);
wire [25:0] x10 = neg10 ? ~s10 : s10;
wire [25:0] e10 = {~x10[25], x10[24:0]};
wire [53:0] k10 = {8'd0, e10[25:1], 21'd0};
wire [2:0] g11 = {bx[23], bx[22], bx[21]};
wire one11 = (g11 == 3'b001) || (g11 == 3'b010) || (g11 == 3'b101) || (g11 == 3'b110);
wire two11 = (g11 == 3'b011) || (g11 == 3'b100);
wire neg11 = (one11 || two11) && (g11[2] ^ flip);
wire [25:0] s11 = ({26{one11}} & a1) | ({26{two11}} & a2);
wire [25:0] x11 = neg11 ? ~s11 : s11;
wire [25:0] e11 = {~x11[25], x11[24:0]};
wire [53:0] k11 = {6'd0, e11[25:0], 22'd0};
wire [2:0] g12 = {bx[25], bx[24], bx[23]};
wire one12 = (g12 == 3'b001) || (g12 == 3'b010) || (g12 == 3'b101) || (g12 == 3'b110);
wire two12 = (g12 == 3'b011) || (g12 == 3'b100);
wire neg12 = (one12 || two12) && (g12[2] ^ flip);
wire [25:0] s12 = ({26{one12}} & a1) | ({26{two12}} & a2);
wire [25:0] x12 = neg12 ? ~s12 : s12;
wire [25:0] e12 = {~x12[25], x12[24:0]};
wire [53:0] k12 = {4'd0, e12[25:0], 24'd0};
wire [2:0] g13 = {bx[27], bx[26], bx[25]};
wire one13 = (g13 == 3'b001) || (g13 == 3'b010) || (g13 == 3'b101) || (g13 == 3'b110);
wire two13 = (g13 == 3'b011) || (g13 == 3'b100);
wire neg13 = (one13 || two13) && (g13[2] ^ flip);
wire [25:0] s13 = ({26{one13}} & a1) | ({26{two13}} & a2);
wire [25:0] x13 = neg13 ? ~s13 : s13;
wire [25:0] e13 = {~x13[25], x13[24:0]};
wire [53:0] k13 = {2'd0, e13[25:0], 26'd0};
wire [53:0] cor = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, neg13, 1'b0, neg12, 1'b0, neg11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
wire [53:0] tot = k0 + k1 + k2 + k3 + k4 + k5 + k6 + k7 + k8 + k9 + k10 + k11 + k12 + k13 + cor + 54'd15011998779572224;
assign p = $signed({tot[51:21], 21'd0});
endmodule
module tm_ul(input wire signed [26:0] a, input wire signed [14:0] b, output wire signed [41:0] p);

wire [16:0] bx = {{2{b[14]}}, b};
wire [27:0] a1 = {a[26], a};
wire [27:0] a2 = {a, 1'b0};
wire [2:0] g0 = {bx[1], bx[0], 1'b0};
wire one0 = (g0 == 3'b001) || (g0 == 3'b010) || (g0 == 3'b101) || (g0 == 3'b110);
wire two0 = (g0 == 3'b011) || (g0 == 3'b100);
wire neg0 = g0[2] && !(g0 == 3'b111);
wire [27:0] s0 = ({28{one0}} & a1) | ({28{two0}} & a2);
wire [27:0] x0 = neg0 ? ~s0 : s0;
wire [27:0] e0 = {~x0[27], x0[26:0]};
wire [43:0] k0 = {16'd0, e0[27:23], 23'd0};
wire [2:0] g1 = {bx[3], bx[2], bx[1]};
wire one1 = (g1 == 3'b001) || (g1 == 3'b010) || (g1 == 3'b101) || (g1 == 3'b110);
wire two1 = (g1 == 3'b011) || (g1 == 3'b100);
wire neg1 = g1[2] && !(g1 == 3'b111);
wire [27:0] s1 = ({28{one1}} & a1) | ({28{two1}} & a2);
wire [27:0] x1 = neg1 ? ~s1 : s1;
wire [27:0] e1 = {~x1[27], x1[26:0]};
wire [43:0] k1 = {14'd0, e1[27:21], 23'd0};
wire [2:0] g2 = {bx[5], bx[4], bx[3]};
wire one2 = (g2 == 3'b001) || (g2 == 3'b010) || (g2 == 3'b101) || (g2 == 3'b110);
wire two2 = (g2 == 3'b011) || (g2 == 3'b100);
wire neg2 = g2[2] && !(g2 == 3'b111);
wire [27:0] s2 = ({28{one2}} & a1) | ({28{two2}} & a2);
wire [27:0] x2 = neg2 ? ~s2 : s2;
wire [27:0] e2 = {~x2[27], x2[26:0]};
wire [43:0] k2 = {12'd0, e2[27:19], 23'd0};
wire [2:0] g3 = {bx[7], bx[6], bx[5]};
wire one3 = (g3 == 3'b001) || (g3 == 3'b010) || (g3 == 3'b101) || (g3 == 3'b110);
wire two3 = (g3 == 3'b011) || (g3 == 3'b100);
wire neg3 = g3[2] && !(g3 == 3'b111);
wire [27:0] s3 = ({28{one3}} & a1) | ({28{two3}} & a2);
wire [27:0] x3 = neg3 ? ~s3 : s3;
wire [27:0] e3 = {~x3[27], x3[26:0]};
wire [43:0] k3 = {10'd0, e3[27:17], 23'd0};
wire [2:0] g4 = {bx[9], bx[8], bx[7]};
wire one4 = (g4 == 3'b001) || (g4 == 3'b010) || (g4 == 3'b101) || (g4 == 3'b110);
wire two4 = (g4 == 3'b011) || (g4 == 3'b100);
wire neg4 = g4[2] && !(g4 == 3'b111);
wire [27:0] s4 = ({28{one4}} & a1) | ({28{two4}} & a2);
wire [27:0] x4 = neg4 ? ~s4 : s4;
wire [27:0] e4 = {~x4[27], x4[26:0]};
wire [43:0] k4 = {8'd0, e4[27:15], 23'd0};
wire [2:0] g5 = {bx[11], bx[10], bx[9]};
wire one5 = (g5 == 3'b001) || (g5 == 3'b010) || (g5 == 3'b101) || (g5 == 3'b110);
wire two5 = (g5 == 3'b011) || (g5 == 3'b100);
wire neg5 = g5[2] && !(g5 == 3'b111);
wire [27:0] s5 = ({28{one5}} & a1) | ({28{two5}} & a2);
wire [27:0] x5 = neg5 ? ~s5 : s5;
wire [27:0] e5 = {~x5[27], x5[26:0]};
wire [43:0] k5 = {6'd0, e5[27:13], 23'd0};
wire [2:0] g6 = {bx[13], bx[12], bx[11]};
wire one6 = (g6 == 3'b001) || (g6 == 3'b010) || (g6 == 3'b101) || (g6 == 3'b110);
wire two6 = (g6 == 3'b011) || (g6 == 3'b100);
wire neg6 = g6[2] && !(g6 == 3'b111);
wire [27:0] s6 = ({28{one6}} & a1) | ({28{two6}} & a2);
wire [27:0] x6 = neg6 ? ~s6 : s6;
wire [27:0] e6 = {~x6[27], x6[26:0]};
wire [43:0] k6 = {4'd0, e6[27:11], 23'd0};
wire [2:0] g7 = {bx[15], bx[14], bx[13]};
wire one7 = (g7 == 3'b001) || (g7 == 3'b010) || (g7 == 3'b101) || (g7 == 3'b110);
wire two7 = (g7 == 3'b011) || (g7 == 3'b100);
wire neg7 = g7[2] && !(g7 == 3'b111);
wire [27:0] s7 = ({28{one7}} & a1) | ({28{two7}} & a2);
wire [27:0] x7 = neg7 ? ~s7 : s7;
wire [27:0] e7 = {~x7[27], x7[26:0]};
wire [43:0] k7 = {2'd0, e7[27:9], 23'd0};
wire [43:0] cor = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
wire [43:0] tot = k0 + k1 + k2 + k3 + k4 + k5 + k6 + k7 + cor + 44'd14660233330688;
assign p = $signed({tot[41:23], 23'd0});
endmodule
module tm_ud(input wire signed [27:0] a, input wire signed [13:0] b, output wire signed [41:0] p);

wire [15:0] bx = {{2{b[13]}}, b};
wire [28:0] a1 = {a[27], a};
wire [28:0] a2 = {a, 1'b0};
wire [2:0] g0 = {bx[1], bx[0], 1'b0};
wire one0 = (g0 == 3'b001) || (g0 == 3'b010) || (g0 == 3'b101) || (g0 == 3'b110);
wire two0 = (g0 == 3'b011) || (g0 == 3'b100);
wire neg0 = g0[2] && !(g0 == 3'b111);
wire [28:0] s0 = ({29{one0}} & a1) | ({29{two0}} & a2);
wire [28:0] x0 = neg0 ? ~s0 : s0;
wire [28:0] e0 = {~x0[28], x0[27:0]};
wire [43:0] k0 = {15'd0, e0[28:22], 22'd0};
wire [2:0] g1 = {bx[3], bx[2], bx[1]};
wire one1 = (g1 == 3'b001) || (g1 == 3'b010) || (g1 == 3'b101) || (g1 == 3'b110);
wire two1 = (g1 == 3'b011) || (g1 == 3'b100);
wire neg1 = g1[2] && !(g1 == 3'b111);
wire [28:0] s1 = ({29{one1}} & a1) | ({29{two1}} & a2);
wire [28:0] x1 = neg1 ? ~s1 : s1;
wire [28:0] e1 = {~x1[28], x1[27:0]};
wire [43:0] k1 = {13'd0, e1[28:20], 22'd0};
wire [2:0] g2 = {bx[5], bx[4], bx[3]};
wire one2 = (g2 == 3'b001) || (g2 == 3'b010) || (g2 == 3'b101) || (g2 == 3'b110);
wire two2 = (g2 == 3'b011) || (g2 == 3'b100);
wire neg2 = g2[2] && !(g2 == 3'b111);
wire [28:0] s2 = ({29{one2}} & a1) | ({29{two2}} & a2);
wire [28:0] x2 = neg2 ? ~s2 : s2;
wire [28:0] e2 = {~x2[28], x2[27:0]};
wire [43:0] k2 = {11'd0, e2[28:18], 22'd0};
wire [2:0] g3 = {bx[7], bx[6], bx[5]};
wire one3 = (g3 == 3'b001) || (g3 == 3'b010) || (g3 == 3'b101) || (g3 == 3'b110);
wire two3 = (g3 == 3'b011) || (g3 == 3'b100);
wire neg3 = g3[2] && !(g3 == 3'b111);
wire [28:0] s3 = ({29{one3}} & a1) | ({29{two3}} & a2);
wire [28:0] x3 = neg3 ? ~s3 : s3;
wire [28:0] e3 = {~x3[28], x3[27:0]};
wire [43:0] k3 = {9'd0, e3[28:16], 22'd0};
wire [2:0] g4 = {bx[9], bx[8], bx[7]};
wire one4 = (g4 == 3'b001) || (g4 == 3'b010) || (g4 == 3'b101) || (g4 == 3'b110);
wire two4 = (g4 == 3'b011) || (g4 == 3'b100);
wire neg4 = g4[2] && !(g4 == 3'b111);
wire [28:0] s4 = ({29{one4}} & a1) | ({29{two4}} & a2);
wire [28:0] x4 = neg4 ? ~s4 : s4;
wire [28:0] e4 = {~x4[28], x4[27:0]};
wire [43:0] k4 = {7'd0, e4[28:14], 22'd0};
wire [2:0] g5 = {bx[11], bx[10], bx[9]};
wire one5 = (g5 == 3'b001) || (g5 == 3'b010) || (g5 == 3'b101) || (g5 == 3'b110);
wire two5 = (g5 == 3'b011) || (g5 == 3'b100);
wire neg5 = g5[2] && !(g5 == 3'b111);
wire [28:0] s5 = ({29{one5}} & a1) | ({29{two5}} & a2);
wire [28:0] x5 = neg5 ? ~s5 : s5;
wire [28:0] e5 = {~x5[28], x5[27:0]};
wire [43:0] k5 = {5'd0, e5[28:12], 22'd0};
wire [2:0] g6 = {bx[13], bx[12], bx[11]};
wire one6 = (g6 == 3'b001) || (g6 == 3'b010) || (g6 == 3'b101) || (g6 == 3'b110);
wire two6 = (g6 == 3'b011) || (g6 == 3'b100);
wire neg6 = g6[2] && !(g6 == 3'b111);
wire [28:0] s6 = ({29{one6}} & a1) | ({29{two6}} & a2);
wire [28:0] x6 = neg6 ? ~s6 : s6;
wire [28:0] e6 = {~x6[28], x6[27:0]};
wire [43:0] k6 = {3'd0, e6[28:10], 22'd0};
wire [43:0] cor = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
wire [43:0] tot = k0 + k1 + k2 + k3 + k4 + k5 + k6 + cor + 44'd16126272602112;
assign p = $signed({tot[41:22], 22'd0});
endmodule


module cs_input_kvw(
    input wire [31:0] K,
    input wire [31:0] V,
    input wire [31:0] W,
    output wire [27:0] k,
    output wire signed [22:0] v,
    output wire signed [23:0] w
);


function [27:0] cvt_k;
    input [31:0] x;
    reg [23:0] m;
    reg [7:0] ex;
    reg [8:0] sh;
    reg [24:0] tmp,rounded,mag,payload;
    reg [2:0] tag;
    begin
        m=(x[30:23]==8'd0) ? {1'b0,x[22:0]} : {1'b1,x[22:0]};
        ex=(x[30:23]==8'd0) ? 8'd1 : x[30:23];
        if(ex>=8'd130) begin
            sh={1'b0,ex}-9'd130;
            mag={1'b0,m}; tag=sh[2:0];
        end else begin
            sh=9'd130-{1'b0,ex};
            tmp=sh>9'd24 ? 25'd0 : {1'b0,m}>>(sh-9'd1);
            rounded=tmp+25'd1;
            mag={1'b0,rounded[24:1]}; tag=3'd0;
        end
        payload={x[31], mag[23:0]};
        cvt_k={tag,payload};
    end
endfunction

function [22:0] cvt_v;
    input [31:0] x;
    reg [23:0] m;
    reg [7:0] ex;
    reg [8:0] sh;
    reg [24:0] tmp;
    reg [24:0] rounded;
    reg [22:0] mag;
    begin
        m = (x[30:23] == 8'd0) ? {1'b0,x[22:0]} : {1'b1,x[22:0]};
        ex = (x[30:23] == 8'd0) ? 8'd1 : x[30:23];
        sh = 9'd128 - {1'b0,ex};
        tmp = sh > 9'd24 ? 25'd0 : {1'b0,m} >> (sh - 9'd1);
        rounded = tmp + 25'd1;
        mag = rounded[23:1];
        cvt_v = x[31] ? (~mag + 23'd1) : mag;
    end
endfunction

function [23:0] cvt_w;
    input [31:0] x;
    reg [23:0] m;
    reg [7:0] ex;
    reg [8:0] sh;
    reg [24:0] tmp;
    reg [24:0] rounded;
    reg [23:0] mag;
    begin
        m = (x[30:23] == 8'd0) ? {1'b0,x[22:0]} : {1'b1,x[22:0]};
        ex = (x[30:23] == 8'd0) ? 8'd1 : x[30:23];
        sh = 9'd127 - {1'b0,ex};
        tmp = sh > 9'd24 ? 25'd0 : {1'b0,m} >> (sh - 9'd1);
        rounded = tmp + 25'd1;
        mag = rounded[24:1];
        cvt_w = x[31] ? (~mag + 24'd1) : mag;
    end
endfunction
assign k=cvt_k(K);
assign v=cvt_v(V);
assign w=cvt_w(W);
endmodule
module cs_exp(input wire [23:0] f, output wire [19:0] m);

reg [19:0] eb; reg [12:0] ed;
always @(*) begin
    case (f[23:17])
        7'd0: begin eb = 20'd524287; ed = 13'd2847; end
        7'd1: begin eb = 20'd527134; ed = 13'd2862; end
        7'd2: begin eb = 20'd529996; ed = 13'd2878; end
        7'd3: begin eb = 20'd532874; ed = 13'd2893; end
        7'd4: begin eb = 20'd535768; ed = 13'd2909; end
        7'd5: begin eb = 20'd538677; ed = 13'd2925; end
        7'd6: begin eb = 20'd541602; ed = 13'd2941; end
        7'd7: begin eb = 20'd544542; ed = 13'd2957; end
        7'd8: begin eb = 20'd547499; ed = 13'd2973; end
        7'd9: begin eb = 20'd550472; ed = 13'd2989; end
        7'd10: begin eb = 20'd553461; ed = 13'd3005; end
        7'd11: begin eb = 20'd556466; ed = 13'd3022; end
        7'd12: begin eb = 20'd559488; ed = 13'd3038; end
        7'd13: begin eb = 20'd562526; ed = 13'd3054; end
        7'd14: begin eb = 20'd565580; ed = 13'd3071; end
        7'd15: begin eb = 20'd568651; ed = 13'd3088; end
        7'd16: begin eb = 20'd571739; ed = 13'd3104; end
        7'd17: begin eb = 20'd574844; ed = 13'd3121; end
        7'd18: begin eb = 20'd577965; ed = 13'd3138; end
        7'd19: begin eb = 20'd581103; ed = 13'd3155; end
        7'd20: begin eb = 20'd584259; ed = 13'd3172; end
        7'd21: begin eb = 20'd587431; ed = 13'd3190; end
        7'd22: begin eb = 20'd590621; ed = 13'd3207; end
        7'd23: begin eb = 20'd593828; ed = 13'd3224; end
        7'd24: begin eb = 20'd597052; ed = 13'd3242; end
        7'd25: begin eb = 20'd600294; ed = 13'd3260; end
        7'd26: begin eb = 20'd603554; ed = 13'd3277; end
        7'd27: begin eb = 20'd606831; ed = 13'd3295; end
        7'd28: begin eb = 20'd610126; ed = 13'd3313; end
        7'd29: begin eb = 20'd613439; ed = 13'd3331; end
        7'd30: begin eb = 20'd616770; ed = 13'd3349; end
        7'd31: begin eb = 20'd620119; ed = 13'd3367; end
        7'd32: begin eb = 20'd623486; ed = 13'd3385; end
        7'd33: begin eb = 20'd626871; ed = 13'd3404; end
        7'd34: begin eb = 20'd630275; ed = 13'd3422; end
        7'd35: begin eb = 20'd633698; ed = 13'd3441; end
        7'd36: begin eb = 20'd637138; ed = 13'd3460; end
        7'd37: begin eb = 20'd640598; ed = 13'd3478; end
        7'd38: begin eb = 20'd644077; ed = 13'd3497; end
        7'd39: begin eb = 20'd647574; ed = 13'd3516; end
        7'd40: begin eb = 20'd651090; ed = 13'd3535; end
        7'd41: begin eb = 20'd654625; ed = 13'd3555; end
        7'd42: begin eb = 20'd658180; ed = 13'd3574; end
        7'd43: begin eb = 20'd661754; ed = 13'd3593; end
        7'd44: begin eb = 20'd665347; ed = 13'd3613; end
        7'd45: begin eb = 20'd668960; ed = 13'd3632; end
        7'd46: begin eb = 20'd672592; ed = 13'd3652; end
        7'd47: begin eb = 20'd676244; ed = 13'd3672; end
        7'd48: begin eb = 20'd679916; ed = 13'd3692; end
        7'd49: begin eb = 20'd683608; ed = 13'd3712; end
        7'd50: begin eb = 20'd687320; ed = 13'd3732; end
        7'd51: begin eb = 20'd691052; ed = 13'd3752; end
        7'd52: begin eb = 20'd694804; ed = 13'd3773; end
        7'd53: begin eb = 20'd698577; ed = 13'd3793; end
        7'd54: begin eb = 20'd702370; ed = 13'd3814; end
        7'd55: begin eb = 20'd706184; ed = 13'd3835; end
        7'd56: begin eb = 20'd710019; ed = 13'd3855; end
        7'd57: begin eb = 20'd713874; ed = 13'd3876; end
        7'd58: begin eb = 20'd717750; ed = 13'd3897; end
        7'd59: begin eb = 20'd721648; ed = 13'd3918; end
        7'd60: begin eb = 20'd725566; ed = 13'd3940; end
        7'd61: begin eb = 20'd729506; ed = 13'd3961; end
        7'd62: begin eb = 20'd733467; ed = 13'd3983; end
        7'd63: begin eb = 20'd737450; ed = 13'd4004; end
        7'd64: begin eb = 20'd741454; ed = 13'd4026; end
        7'd65: begin eb = 20'd745480; ed = 13'd4048; end
        7'd66: begin eb = 20'd749528; ed = 13'd4070; end
        7'd67: begin eb = 20'd753598; ed = 13'd4092; end
        7'd68: begin eb = 20'd757690; ed = 13'd4114; end
        7'd69: begin eb = 20'd761804; ed = 13'd4137; end
        7'd70: begin eb = 20'd765940; ed = 13'd4159; end
        7'd71: begin eb = 20'd770099; ed = 13'd4182; end
        7'd72: begin eb = 20'd774281; ed = 13'd4204; end
        7'd73: begin eb = 20'd778485; ed = 13'd4227; end
        7'd74: begin eb = 20'd782712; ed = 13'd4250; end
        7'd75: begin eb = 20'd786962; ed = 13'd4273; end
        7'd76: begin eb = 20'd791236; ed = 13'd4296; end
        7'd77: begin eb = 20'd795532; ed = 13'd4320; end
        7'd78: begin eb = 20'd799851; ed = 13'd4343; end
        7'd79: begin eb = 20'd804194; ed = 13'd4367; end
        7'd80: begin eb = 20'd808561; ed = 13'd4390; end
        7'd81: begin eb = 20'd812952; ed = 13'd4414; end
        7'd82: begin eb = 20'd817366; ed = 13'd4438; end
        7'd83: begin eb = 20'd821804; ed = 13'd4462; end
        7'd84: begin eb = 20'd826266; ed = 13'd4487; end
        7'd85: begin eb = 20'd830753; ed = 13'd4511; end
        7'd86: begin eb = 20'd835264; ed = 13'd4535; end
        7'd87: begin eb = 20'd839799; ed = 13'd4560; end
        7'd88: begin eb = 20'd844359; ed = 13'd4585; end
        7'd89: begin eb = 20'd848944; ed = 13'd4610; end
        7'd90: begin eb = 20'd853554; ed = 13'd4635; end
        7'd91: begin eb = 20'd858188; ed = 13'd4660; end
        7'd92: begin eb = 20'd862848; ed = 13'd4685; end
        7'd93: begin eb = 20'd867533; ed = 13'd4711; end
        7'd94: begin eb = 20'd872244; ed = 13'd4736; end
        7'd95: begin eb = 20'd876980; ed = 13'd4762; end
        7'd96: begin eb = 20'd881742; ed = 13'd4788; end
        7'd97: begin eb = 20'd886530; ed = 13'd4814; end
        7'd98: begin eb = 20'd891344; ed = 13'd4840; end
        7'd99: begin eb = 20'd896184; ed = 13'd4866; end
        7'd100: begin eb = 20'd901050; ed = 13'd4893; end
        7'd101: begin eb = 20'd905943; ed = 13'd4919; end
        7'd102: begin eb = 20'd910862; ed = 13'd4946; end
        7'd103: begin eb = 20'd915807; ed = 13'd4973; end
        7'd104: begin eb = 20'd920780; ed = 13'd5000; end
        7'd105: begin eb = 20'd925780; ed = 13'd5027; end
        7'd106: begin eb = 20'd930807; ed = 13'd5054; end
        7'd107: begin eb = 20'd935861; ed = 13'd5082; end
        7'd108: begin eb = 20'd940943; ed = 13'd5109; end
        7'd109: begin eb = 20'd946052; ed = 13'd5137; end
        7'd110: begin eb = 20'd951189; ed = 13'd5165; end
        7'd111: begin eb = 20'd956354; ed = 13'd5193; end
        7'd112: begin eb = 20'd961547; ed = 13'd5221; end
        7'd113: begin eb = 20'd966768; ed = 13'd5249; end
        7'd114: begin eb = 20'd972017; ed = 13'd5278; end
        7'd115: begin eb = 20'd977295; ed = 13'd5307; end
        7'd116: begin eb = 20'd982602; ed = 13'd5335; end
        7'd117: begin eb = 20'd987938; ed = 13'd5364; end
        7'd118: begin eb = 20'd993302; ed = 13'd5394; end
        7'd119: begin eb = 20'd998695; ed = 13'd5423; end
        7'd120: begin eb = 20'd1004118; ed = 13'd5452; end
        7'd121: begin eb = 20'd1009570; ed = 13'd5482; end
        7'd122: begin eb = 20'd1015052; ed = 13'd5512; end
        7'd123: begin eb = 20'd1020564; ed = 13'd5542; end
        7'd124: begin eb = 20'd1026105; ed = 13'd5572; end
        7'd125: begin eb = 20'd1031677; ed = 13'd5602; end
        7'd126: begin eb = 20'd1037279; ed = 13'd5632; end
        7'd127: begin eb = 20'd1042911; ed = 13'd5663; end
        default: begin eb = 20'd0; ed = 0; end
    endcase
end
wire [23:0] ep = ed * f[16:6];
wire [23:0] er = ep + 24'd1024;
wire [20:0] raw = {1'b0, eb} + er[23:11];
assign m = raw[20] ? 20'hFFFFF : raw[19:0];
endmodule

module cs_cvtq(input wire [31:0] x, output wire signed [26:0] q);
function [26:0] cvt_q;
    input [31:0] x;
    reg [23:0] m;
    reg [7:0] ex;
    reg [8:0] sh;
    reg [56:0] prod;
    reg [31:0] top, shifted;
    reg [32:0] rounded;
    reg [26:0] mag;
    begin
        m = (x[30:23] == 8'd0) ? {1'b0,x[22:0]} : {1'b1,x[22:0]};
        ex = (x[30:23] == 8'd0) ? 8'd1 : x[30:23];
        prod = ({33'd0,m} << 32) + ({33'd0,m} << 26) + ({33'd0,m} << 24) + ({33'd0,m} << 21) + ({33'd0,m} << 19) - ({33'd0,m} << 13) - ({33'd0,m} << 10) + ({33'd0,m} << 5) + ({33'd0,m} << 2) - {33'd0,m};
        top = prod[56:25];
        sh = 9'd130 - {1'b0,ex};
        shifted = sh >= 9'd32 ? 32'd0 : top >> sh;
        rounded = {1'b0,shifted} + 33'd1;
        mag = rounded[27:1];
        cvt_q = x[31] ? (~mag + 27'd1) : mag;
    end
endfunction
assign q = cvt_q(x);
endmodule
