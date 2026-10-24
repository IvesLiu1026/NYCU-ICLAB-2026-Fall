module JPEGLENC (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       in_valid,
    input  wire [7:0] in_data,
    output reg        out_valid,
    output reg  [7:0] out_data
);
    localparam [10:0] RING_FIRST = 11'd128;
    localparam [10:0] RING_LAST  = 11'd1359;

    function [6:0] lbrot;
        input [6:0] x; input [3:0] r;
        reg   [6:0] t0, t1, t2;
        begin
            t0    = r[0] ? {x[2:0],  x[6:3]}  : x;
            t1    = r[1] ? {t0[5:0], t0[6]}   : t0;
            t2    = r[2] ? {t1[4:0], t1[6:5]} : t1;
            lbrot = r[3] ? {t2[2:0], t2[6:3]} : t2;
        end
    endfunction

    function [2:0] ordy;
        input [2:0] pos;
        begin
            ordy[2] = pos[2] ? (pos[1] | ~pos[0]) : (pos[1] & ~pos[0]);
            ordy[1] = pos[2] ? pos[0] : pos[1];
            ordy[0] = pos[0] ? (~pos[2] | pos[1]) : (pos[2] & pos[1]);
        end
    endfunction

    wire        img_end;

    reg         act;
    reg  [14:0] gc;
    wire        inp_done = gc[14];
    wire        od = gc[0];
    wire        ev = ~gc[0];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act <= 1'b0; gc <= 15'd0;
        end else if (img_end) begin
            act <= 1'b0; gc <= 15'd0;
        end else begin
            if (in_valid) act <= 1'b1;
            if (act || in_valid) gc <= gc + 15'd1;
        end
    end

    reg         sck;
    always @(negedge clk) sck <= act & ~sck;

    reg  [7:0]  h;
    reg  [63:0] sr;
    always @(posedge clk) begin
        if (ev) h <= in_data;
        else    sr <= {in_data, h, sr[63:16]};
    end

    reg         dct_on, dct_done, bubbled;
    reg  [7:0]  bidx;
    reg  [3:0]  ridx;
    reg  [4:0]  bub;
    reg  [1:0]  ab;
    reg         cacc;
    reg  [7:0]  cref;
    reg  [10:0] wp, rp, occ;
    reg         occ_nz;
    reg  [63:0] pw0, pw1;
    reg         v0, v1;
    reg         prefetched, outph, fl_d;
    reg  [3:0]  ocnt;
    reg  [63:0] ob;

    reg         sCS, sWEB, sDIsel;
    reg  [10:0] sA;
    reg         sDR, sOR, sWR, sLast;
    reg         sTP, sTPar;
    reg  [2:0]  sTY;
    reg         tDR, tOR, tLast;
    reg         tTP, tTPar;
    reg  [2:0]  tTY;
    reg         cap_r, ocap;

    wire        bz     = (bub == 5'd0);
    wire        n_pix  = ev & (gc[2:1] == 2'b11) & ~gc[14];
    wire        n_dsl  = ev & ~gc[1] & dct_on & ~dct_done;
    wire        n_abc  = (ridx == 4'd9) & (bidx[7:4] == 4'hF) & cacc;
    wire        n_ab   = n_dsl & bz & n_abc;
    wire        n_dct  = n_dsl & bz & ~(n_abc & (bidx[3:0] == 4'hF));

    wire [3:0]  n_rbx  = bidx[3:0] + 4'd1;
    wire [2:0]  n_ry   = n_abc ? 3'd0 : ordy(ridx[2:0]);
    wire [6:0]  n_lbp  = lbrot(gc[9:3], gc[13:10]);
    wire [6:0]  n_lbd  = lbrot({ordy(ridx[2:0]), bidx[3:0]}, bidx[7:4]);
    wire [6:0]  n_lba  = {n_rbx[2:0], 3'd0, n_rbx[3]};
    reg         k_pix, k_dsl, k_dct, k_ab;
    reg  [6:0]  k_lb;
    reg         k_tp, k_tpar;
    reg  [2:0]  k_ty;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            k_pix <= 1'b0; k_dsl <= 1'b0; k_dct <= 1'b0; k_ab <= 1'b0;
        end else begin
            k_pix <= n_pix; k_dsl <= n_dsl; k_dct <= n_dct; k_ab <= n_ab;
        end
    end
    always @(posedge clk) begin
        k_lb   <= n_pix ? n_lbp : (n_abc ? n_lba : n_lbd);
        k_tp   <= ridx[3] & ~n_abc;
        k_ty   <= n_ry;
        k_tpar <= bidx[0] ^ n_abc;
    end

    wire        fslot   = od & ~k_pix & ~k_dct;
    wire        frest   = sWR ? v1 : v0;
    wire        ocnt_le5 = ~ocnt[3] & ~(ocnt[2] & ocnt[1]);

    wire        want_out = occ_nz & ~sOR & ~tOR & (outph ? ocnt_le5 : ~prefetched);
    wire        go_out   = fslot & want_out;
    wire        go_wr    = fslot & ~want_out & frest;

    wire        rd_last  = fl_d & ~frest & (occ == 11'd1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sCS <= 1'b0; sWEB <= 1'b1; sDIsel <= 1'b0; sA <= 11'd0;
            sDR <= 1'b0; sOR <= 1'b0; sWR <= 1'b0;
        end else if (od) begin
            sCS    <= k_pix | k_dct | go_out | go_wr;
            sWEB   <= ~(k_pix | go_wr);
            sDIsel <= k_pix;
            sA     <= (k_pix | k_dct) ? {4'd0, k_lb} : (go_out ? rp : wp);
            sDR    <= k_dct;
            sOR    <= go_out;
            sWR    <= go_wr;
        end
    end
    always @(posedge clk) begin
        if (od) begin
            sTP <= k_tp; sTY <= k_ty; sTPar <= k_tpar; sLast <= rd_last;
        end
    end

    wire [63:0] mem_do;
    JPEGLENC_SRAM u_sram (.CK(sck), .CS(sCS), .OE(1'b1), .A(sA), .DI(sDIsel ? sr : pw0),
                          .WEB({8{sWEB}}), .DO(mem_do));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tDR <= 1'b0; tOR <= 1'b0; cap_r <= 1'b0; ocap <= 1'b0;
        end else begin
            if (od) begin tDR <= sDR; tOR <= sOR; end

            cap_r <= ev & tDR & ~n_ab;
            ocap  <= ev & tOR;
        end
    end
    always @(posedge clk) begin
        if (od) begin
            tTP <= sTP; tTY <= sTY; tTPar <= sTPar; tLast <= sLast;
        end
    end

    wire [63:0] dq;
    reg         cap_d, cap_dp, cap_dy0;
    wire        rowflat = (dq[15:8] == dq[7:0]) & (dq[23:16] == dq[7:0]) & (dq[31:24] == dq[7:0])
                        & (dq[39:32] == dq[7:0]) & (dq[47:40] == dq[7:0]) & (dq[55:48] == dq[7:0])
                        & (dq[63:56] == dq[7:0]);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cap_d <= 1'b0;
        else        cap_d <= cap_r;
    end
    always @(posedge clk) begin
        cap_dp  <= tTP;
        cap_dy0 <= (tTY == 3'd0);
        if (cap_d && !cap_dp && cap_dy0) cref <= dq[7:0];
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cacc <= 1'b0;
        else if (cap_d && !cap_dp) cacc <= rowflat & (cap_dy0 | (cacc & (dq[7:0] == cref)));
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dct_on <= 1'b0; dct_done <= 1'b0; bubbled <= 1'b0; bidx <= 8'd0; ridx <= 4'd0;
            bub <= 5'd0; ab <= 2'b00;
        end else if (img_end) begin
            dct_on <= 1'b0; dct_done <= 1'b0; bubbled <= 1'b0; bidx <= 8'd0; ridx <= 4'd0;
            bub <= 5'd0; ab <= 2'b00;
        end else begin
            if (gc == 15'd875) dct_on <= 1'b1;
            if (k_dsl) begin
                if (!bz) bub <= bub - 5'd1;
                else if (k_ab) begin

                    if (bidx[0]) ab[1] <= 1'b1; else ab[0] <= 1'b1;
                    if (bidx == 8'd255) dct_done <= 1'b1;
                    else begin
                        bidx <= bidx + 8'd1;
                        ridx <= 4'd1;
                        if (bidx[0]) ab[0] <= 1'b0; else ab[1] <= 1'b0;
                    end
                end else begin
                    if (ridx == 4'd0) begin
                        if (bidx[0]) ab[1] <= 1'b0; else ab[0] <= 1'b0;
                    end
                    ridx <= ridx + 4'd1;
                    if (ridx == 4'd15) begin
                        bidx <= bidx + 8'd1;
                        if (bidx == 8'd255) dct_done <= 1'b1;
                        if (!bubbled && occ[10] && (bidx < 8'd239)) begin
                            bubbled <= 1'b1;
                            bub <= 5'd28;
                        end
                    end
                end
            end
        end
    end

    wire        pk_v;
    wire [63:0] pk_word;
    wire        flushed;
    wire [3:0]  last_nb;
    wire        fpop = sWR & od;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v0 <= 1'b0; v1 <= 1'b0;
        end else begin
            if (fpop) begin
                if (v1) v1 <= pk_v;
                else    v0 <= pk_v;
            end else if (pk_v) begin
                if (v0) v1 <= 1'b1;
                else    v0 <= 1'b1;
            end
        end
    end
    always @(posedge clk) begin
        if (fpop | (pk_v & ~v0)) pw0 <= (fpop & v1) ? pw1 : pk_word;
        if (pk_v & (fpop ? v1 : v0)) pw1 <= pk_word;
    end

    wire [10:0] wp_n = (wp == RING_LAST) ? RING_FIRST : wp + 11'd1;
    wire [10:0] rp_n = (rp == RING_LAST) ? RING_FIRST : rp + 11'd1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wp <= RING_FIRST; rp <= RING_FIRST; occ <= 11'd0; occ_nz <= 1'b0;
        end else if (img_end) begin
            wp <= RING_FIRST; rp <= RING_FIRST; occ <= 11'd0; occ_nz <= 1'b0;
        end else if (go_wr) begin
            wp <= wp_n; occ <= occ + 11'd1; occ_nz <= 1'b1;
        end else if (go_out) begin
            rp <= rp_n; occ <= occ - 11'd1; occ_nz <= (occ != 11'd1);
        end
    end

    wire        pop = inp_done & (ocnt != 4'd0);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prefetched <= 1'b0; outph <= 1'b0; fl_d <= 1'b0;
        end else if (img_end) begin
            prefetched <= 1'b0; outph <= 1'b0; fl_d <= 1'b0;
        end else begin
            if (go_out) prefetched <= 1'b1;
            if (gc == 15'd16380) outph <= 1'b1;
            fl_d <= flushed;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)    ocnt <= 4'd0;
        else if (ocap) ocnt <= tLast ? last_nb : 4'd8;
        else if (pop)  ocnt <= ocnt - 4'd1;
    end
    always @(posedge clk) begin
        if (ocap)     ob <= mem_do;
        else if (pop) ob[63:8] <= ob[55:0];
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0; out_data <= 8'd0;
        end else begin
            out_valid <= pop;
            out_data  <= pop ? ob[63:56] : 8'd0;
        end
    end

    assign img_end = inp_done & dct_done & fl_d & ~occ_nz & ~v0 & ~sOR & ~tOR & (ocnt == 4'd0);

    wire        r_v;
    wire [2:0]  r_u, r_y;
    wire        r_par;
    wire signed [18:0] r_val;
    JPEGLENC_ROW u_row (
        .clk(clk), .rst_n(rst_n), .cap(cap_r), .cap_p(tTP), .cap_y(tTY), .cap_par(tTPar),
        .do_word(mem_do), .dq(dq), .r_v(r_v), .r_u(r_u), .r_y(r_y), .r_par(r_par), .r_val(r_val));

    wire        q_wr;
    wire [2:0]  q_u;
    wire        q_par;
    wire [63:0] q_col;
    JPEGLENC_COL u_col (
        .clk(clk), .rst_n(rst_n), .r_v(r_v), .r_u(r_u), .r_y(r_y), .r_par(r_par), .r_val(r_val),
        .q_wr(q_wr), .q_u(q_u), .q_par(q_par), .q_col(q_col));

    JPEGLENC_ENT u_ent (
        .clk(clk), .rst_n(rst_n), .clr(img_end), .wr(q_wr), .wu(q_u), .wpar(q_par), .wq(q_col), .ab(ab),
        .pk_v(pk_v), .pk_word(pk_word), .flushed(flushed), .last_nb(last_nb));
endmodule

module JPEGLENC_ROW (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               cap,
    input  wire               cap_p,
    input  wire [2:0]         cap_y,
    input  wire               cap_par,
    input  wire [63:0]        do_word,
    output reg  [63:0]        dq,
    output reg                r_v,
    output reg  [2:0]         r_u,
    output reg  [2:0]         r_y,
    output reg                r_par,
    output reg  signed [18:0] r_val
);

    reg         act;
    reg  [1:0]  st;
    reg         wp;
    reg  [2:0]  wy;
    reg         wpar;
    always @(posedge clk) if (cap) dq <= do_word;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin act <= 1'b0; st <= 2'd0; wp <= 1'b0; wy <= 3'd0; wpar <= 1'b0; end
        else if (cap) begin act <= 1'b1; st <= 2'd0; wp <= cap_p; wy <= cap_y; wpar <= cap_par; end
        else begin
            st <= st + 2'd1;
            if (st == 2'd3) act <= 1'b0;
        end
    end

    wire [2:0]  un  = cap ? {cap_p, 2'd0} : {wp, st + 2'd1};
    wire [1:0]  pn  = un[2:1];
    wire        hbn = un[0];
    reg         na1, na2, na3, c0;
    always @(posedge clk) begin
        na1 <= hbn ? (pn != 2'd0) : (pn == 2'd2);
        na2 <= hbn ? (pn == 2'd1) : (pn == 2'd2);
        na3 <= ~(pn[0] ^ hbn);
        c0  <= hbn | (pn == 2'd2);
    end
    wire [2:0]  u   = {wp, st};
    wire [1:0]  p   = u[2:1];
    wire        hb  = u[0];

    function [8:0] lane;
        input [7:0] a; input [7:0] b; input na; input nb; input c;
        reg   [8:0] t;
        begin
            t = {1'b0, a ^ {8{na}}} + {1'b0, b ^ {8{nb}}} + {8'd0, c};
            lane = {~t[8], t[7:0]};
        end
    endfunction
    wire [8:0] s0 = lane(dq[7:0],   dq[63:56], 1'b0, hb,       c0);
    wire [8:0] s1 = lane(dq[15:8],  dq[55:48], na1,  na1 ^ hb, na1 | hb);
    wire [8:0] s2 = lane(dq[23:16], dq[47:40], na2,  na2 ^ hb, na2 | hb);
    wire [8:0] s3 = lane(dq[31:24], dq[39:32], na3,  na3 ^ hb, na3 | hb);
    wire       sw03 = p[0] | !hb;
    reg  [8:0] x03, y03, x12, y12;
    reg  [2:0] b1_u, b1_y;
    reg        b1_v, b1_par;
    always @(posedge clk) begin
        x03 <= sw03 ? s0 : s3;
        y03 <= sw03 ? s3 : s0;
        x12 <= p[1] ? s2 : s1;
        y12 <= p[1] ? s1 : s2;
        b1_u <= u; b1_y <= wy; b1_par <= wpar;
    end
    always @(posedge clk or negedge rst_n) if (!rst_n) b1_v <= 1'b0; else b1_v <= act;

    wire [1:0] p1 = b1_u[2:1];
    wire       h1 = b1_u[0];
    wire       g03 = h1 & ~(p1[0] ^ p1[1]);
    wire       h03 = h1 &  (p1[0] ^ p1[1]);
    wire       g12 = h1 &  (p1[0] ^ p1[1]);
    wire       h12 = h1 & ~(p1[0] ^ p1[1]);
    wire       m0  = !h1 & !p1[0];
    wire       m2  = !h1 &  p1[0];
    wire       e4  = !h1 & (p1 == 2'd2);

    wire [8:0] l1 = p1[1] ? y12 : x12;
    wire [8:0] l2 = p1[1] ? x12 : y12;
    wire [8:0] ny03 = ~y03, ny12 = ~y12;
    wire [11:0] v1 = ({12{g03}} & {x03, 3'd0}) | ({12{h03}} & {{2{x03[8]}}, x03, 1'b0}) | ({12{m0}} & {{3{l1[8]}}, l1});
    wire [9:0]  v2 = g03 ? {x03, 1'b0} : {x03[8], x03};
    wire [9:0]  v3 = h03 ? {y03, 1'b0} : {ny03[8], ny03};
    wire [10:0] v4 = {11{m0}} & {{2{l2[8]}}, l2};
    wire [12:0] ra = {1'b0, ~v1[11], v1[10:0]};
    wire [12:0] rb = {3'd0, ~v2[9], v2[8:0]};
    wire [12:0] rc = {3'd0, ~v3[9], v3[8:0]};
    wire [12:0] rd = {2'd0, ~v4[10], v4[9:0]};
    wire [12:0] w1s = ({12{g12}} & {x12, 3'd0}) | ({12{h12}} & {{2{x12[8]}}, x12, 1'b0});
    wire [10:0] w2 = g12 ? {x12[8], x12, 1'b0} : {{2{x12[8]}}, x12};
    wire [10:0] w3 = h12 ? {y12[8], y12, 1'b0} : {{2{ny12[8]}}, ny12};
    wire [12:0] re = {1'b0, ~w1s[11], w1s[10:0]};
    wire [12:0] rf = {2'd0, ~w2[10], w2[9:0]};
    wire [12:0] rg = {2'd0, ~w3[10], w3[9:0]};

    wire [12:0] s1a = ra ^ rb ^ rc;
    wire [12:0] c1a = {((ra & rb) | (ra & rc) | (rb & rc)), 1'b0} ;
    wire [12:0] s03 = s1a ^ c1a ^ rd;
    wire [12:0] c03 = {((s1a & c1a) | (s1a & rd) | (c1a & rd)), 1'b0};
    wire [12:0] s12 = re ^ rf ^ rg;
    wire [12:0] c12 = {((re & rf) | (re & rg) | (rf & rg)), 1'b0};
    wire        sel03a = ~(p1[0] ^ p1[1]);
    reg  [12:0] k03s, k03c, k12s, k12c;
    reg         k03i, k12i;
    reg  [8:0]  kb0;
    reg  [2:0]  b2_u, b2_y;
    reg         b2_v, b2_par;
    always @(posedge clk) begin
        k03s <= s03; k03c <= c03; k03i <= g03 | m2 | e4;
        k12s <= s12; k12c <= c12; k12i <= g12 | m2;
        kb0 <= sel03a ? y03 : y12;
        b2_u <= b1_u; b2_y <= b1_y; b2_par <= b1_par;
    end
    always @(posedge clk or negedge rst_n) if (!rst_n) b2_v <= 1'b0; else b2_v <= b1_v;

    wire [12:0] q03s = k03s + k03c + {12'd0, k03i};
    wire [12:0] q12s = k12s + k12c + {12'd0, k12i};
    wire [12:0] q03 = {~q03s[12], q03s[11:0]};
    wire [12:0] q12 = {~q12s[12], q12s[11:0]};
    wire [1:0]  p2 = b2_u[2:1];
    wire        h2 = b2_u[0];
    wire        sel03 = ~(p2[0] ^ p2[1]);
    wire        gsel  = h2 ? sel03 : ~(p2[0] & p2[1]);
    wire        hs12  = h2 ? sel03 : (p2 == 2'd1);
    reg  signed [8:0]  b0;
    reg  signed [12:0] g;
    reg  signed [11:0] h;
    reg  [2:0]  b_u, b_y;
    reg         b_v, b_par;
    always @(posedge clk) begin
        b0 <= kb0;
        g  <= gsel ? q03 : q12;
        h  <= hs12 ? q12[11:0] : q03[11:0];
        b_u <= b2_u; b_y <= b2_y; b_par <= b2_par;
    end
    always @(posedge clk or negedge rst_n) if (!rst_n) b_v <= 1'b0; else b_v <= b2_v;

    wire co  = b_u[0];
    wire cm2 = !b_u[0] &  b_u[1];
    wire cm0 = !b_u[0] & !b_u[1];
    wire signed [11:0] ng = ~{g[10], g[10:0]};
    wire signed [12:0] nh = ~h;
    wire [10:0] cs0 = co ? {{2{b0[8]}}, b0} : g[10:0];
    wire [18:0] cu0 = {~cs0[10], cs0[9:0], 8'd0};
    wire [11:0] cs1 = cm0 ? ng : h;
    wire [18:0] cu1 = {1'b0, ~cs1[11], cs1[10:0], 6'd0};
    wire [13:0] cs2 = cm2 ? {h, 2'd0} : {{2{h[11]}}, h};
    wire [18:0] cu2 = {2'd0, ~cs2[13], cs2[12:0], 3'd0};
    wire [12:0] cs3 = co ? g : {ng[10:0], 2'd0};
    wire [18:0] cu3 = {4'd0, ~cs3[12], cs3[11:0], 2'd0};
    wire [12:0] cs4 = co ? g : {ng, 1'b0};
    wire [18:0] cu4 = {6'd0, ~cs4[12], cs4[11:0]};
    wire [12:0] cs5 = co ? nh : cm2 ? {h, 1'b0} : 13'd0;
    wire [18:0] cu5 = {6'd0, ~cs5[12], cs5[11:0]};
    wire [10:0] cs6 = co ? 11'd0 : ng[10:0];
    wire [18:0] cu6 = {8'd0, ~cs6[10], cs6[9:0]};
    localparam integer KF = -(262144 + 131072 + 65536 + 16384 + 4096 + 4096 + 1024);
    localparam [18:0] KO = KF + 1, KM2 = KF + 16 + 2 + 1, KM0 = KF + 64 + 16 + 2 + 1;
    wire [18:0] kk = co ? KO : cm2 ? KM2 : KM0;

    wire [18:0] x1s = cu0 ^ cu1 ^ cu2, x1c = {((cu0 & cu1) | (cu0 & cu2) | (cu1 & cu2)), 1'b0};
    wire [18:0] x2s = cu3 ^ cu4 ^ cu5, x2c = {((cu3 & cu4) | (cu3 & cu5) | (cu4 & cu5)), 1'b0};
    wire [18:0] y1s = x1s ^ x1c ^ x2s, y1c = {((x1s & x1c) | (x1s & x2s) | (x1c & x2s)), 1'b0};
    wire [18:0] y2s = x2c ^ cu6 ^ kk,  y2c = {((x2c & cu6) | (x2c & kk) | (cu6 & kk)), 1'b0};
    wire [18:0] z1s = y1s ^ y1c ^ y2s, z1c = {((y1s & y1c) | (y1s & y2s) | (y1c & y2s)), 1'b0};
    reg  [18:0] t3a, t3b, t3c;
    reg  [2:0]  c_u, c_y;
    reg         c_v, c_par;
    always @(posedge clk) begin
        t3a <= z1s; t3b <= z1c; t3c <= y2c;
        c_u <= b_u; c_y <= b_y; c_par <= b_par;
    end
    always @(posedge clk or negedge rst_n) if (!rst_n) c_v <= 1'b0; else c_v <= b_v;

    wire [18:0] fs = t3a ^ t3b ^ t3c, fc = {((t3a & t3b) | (t3a & t3c) | (t3b & t3c)), 1'b0};
    always @(posedge clk) begin
        r_val <= fs + fc;
        r_u <= c_u; r_y <= c_y; r_par <= c_par;
    end
    always @(posedge clk or negedge rst_n) if (!rst_n) r_v <= 1'b0; else r_v <= c_v;
endmodule

module JPEGLENC_COL (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               r_v,
    input  wire [2:0]         r_u,
    input  wire [2:0]         r_y,
    input  wire               r_par,
    input  wire signed [18:0] r_val,
    output reg                q_wr,
    output reg  [2:0]         q_u,
    output reg                q_par,
    output wire [63:0]        q_col
);

    reg        l_v, c_v, e_v, f_v, l_par, c_par, e_par, f_par;
    reg  [2:0] l_u, c_u, e_u, f_u;
    reg        l_s0, l_s1237, l_s456, l_s0246, l_s1256, l_s0236, l_s4567, l_s7;
    reg        c_s0, c_s1237, c_s456, c_s0246, c_s1256, c_s0236, c_s4567, c_s7;
    reg        e_s7, f_s7;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l_v <= 1'b0; c_v <= 1'b0; e_v <= 1'b0; f_v <= 1'b0;
            l_par <= 1'b0; c_par <= 1'b0; e_par <= 1'b0; f_par <= 1'b0;
        end else begin
            l_v <= r_v; c_v <= l_v; e_v <= c_v; f_v <= e_v;
            l_par <= r_par; c_par <= l_par; e_par <= c_par; f_par <= e_par;
        end
    end
    reg  [7:0] f_uh;
    always @(posedge clk) f_uh <= 8'd1 << e_u;
    always @(posedge clk) begin
        l_u <= r_u; c_u <= l_u; e_u <= c_u; f_u <= e_u;
        l_s0 <= (r_y == 3'd0);
        l_s1237 <= (r_y == 3'd1) | (r_y == 3'd2) | (r_y == 3'd3) | (r_y == 3'd7);
        l_s456 <= (r_y == 3'd4) | (r_y == 3'd5) | (r_y == 3'd6);
        l_s0246 <= (r_y == 3'd0) | (r_y == 3'd2) | (r_y == 3'd4) | (r_y == 3'd6);
        l_s1256 <= (r_y == 3'd1) | (r_y == 3'd2) | (r_y == 3'd5) | (r_y == 3'd6);
        l_s0236 <= (r_y == 3'd0) | (r_y == 3'd2) | (r_y == 3'd3) | (r_y == 3'd6);
        l_s4567 <= (r_y == 3'd4) | (r_y == 3'd5) | (r_y == 3'd6) | (r_y == 3'd7);
        l_s7 <= (r_y == 3'd7);
        c_s0 <= l_s0; c_s1237 <= l_s1237; c_s456 <= l_s456; c_s0246 <= l_s0246; c_s1256 <= l_s1256;
        c_s0236 <= l_s0236; c_s4567 <= l_s4567; c_s7 <= l_s7;
        e_s7 <= c_s7; f_s7 <= e_s7;
    end

    reg signed [18:0] l_r;
    reg signed [20:0] l_5;
    always @(posedge clk) begin
        l_r <= r_val;
        l_5 <= r_val + (r_val <<< 2);
    end

    wire signed [26:0] mn251 = l_5 - (l_r <<< 8);
    wire signed [23:0] m25   = (l_5 <<< 2) + l_5;
    wire signed [22:0] mn19  = l_r - (l_5 <<< 2);
    reg  [18:0] u_r;
    reg  [20:0] u_5;
    reg  [26:0] u_n251;
    reg  [23:0] u_25;
    reg  [22:0] u_n19;
    always @(posedge clk) begin
        u_r    <= {~l_r[18], l_r[17:0]};
        u_5    <= {~l_5[20], l_5[19:0]};
        u_n251 <= {~mn251[26], mn251[25:0]};
        u_25   <= {~m25[23], m25[22:0]};
        u_n19  <= {~mn19[22], mn19[21:0]};
    end

    wire [28:0] opa0 = {2'd0, u_25, 3'd0};                       wire [28:0] opb0 = {6'd0, u_n19};
    wire [28:0] opa1 = {2'd0, u_n251 ^ {27{c_s0246}}};
    wire [28:0] opa2 = {2'd0, u_r, 8'd0};                        wire [28:0] opb2 = {6'd0, u_n19};
    wire [28:0] opa3 = {2'd0, u_n251};                           wire [28:0] opb3 = ~{5'd0, u_n19, 1'b0};
    wire [28:0] opa4 = {2'd0, {u_25, 3'd0} ^ {27{c_s1256}}};     wire [28:0] opb4 = {6'd0, u_n19} ^ {29{c_s1256}};
    wire [28:0] opa5 = {3'd0, {4'd0, u_5, 1'b0} ^ {26{c_s0236}}}; wire [28:0] opb5 = {3'd0, u_n19, 3'd0} ^ {29{c_s0236}};
    wire [28:0] opa6 = {3'd0, u_25, 2'd0};                       wire [28:0] opb6 = ~{8'd0, u_r, 1'b0};
    wire [28:0] opa7 = {4'd0, {u_25, 1'b0} ^ {25{c_s4567}}};
    wire        i0 = 1'b0, i2 = 1'b0, i3 = 1'b1, i4 = c_s1256, i5 = c_s0236, i6 = 1'b1;
    reg  [28:0] a0 [0:7];
    reg  [28:0] a1 [0:7];
    reg  [28:0] a2 [0:7];
    reg  [28:0] a3 [0:7];
    reg  [7:0]  c0;
    wire [28:0] n0 = ({29{l_s0}} & 29'h1e000000) | ({29{~l_s0}} & a2[0]);
    wire [28:0] n1 = ({29{l_s0}} & 29'h12000003) | ({29{l_s1237}} & a2[5]) | ({29{l_s456}} & a2[1]);
    wire [28:0] n2 = ({29{l_s1237}} & ~a2[6]) | ({29{l_s456}} & a2[2]);
    wire [28:0] n3 = ({29{l_s0}} & 29'h12000002) | ({29{l_s1237}} & ~a2[1]) | ({29{l_s456}} & ~a2[3]);
    wire [28:0] n4 = ({29{l_s0}} & 29'h0000004) | ({29{~l_s0}} & a2[4]);
    wire [28:0] n5 = ({29{l_s0}} & 29'h12000003) | ({29{l_s1237}} & a2[7]) | ({29{l_s456}} & a2[5]);
    wire [28:0] n6 = ({29{l_s1237}} & a2[2]) | ({29{l_s456}} & a2[6]);
    wire [28:0] n7 = ({29{l_s0}} & 29'h12000003) | ({29{l_s1237}} & a2[3]) | ({29{l_s456}} & a2[7]);
    wire [28:0] b0 = a3[0];
    wire [28:0] ss0 = b0 ^ opa0 ^ opb0;
    wire [28:0] cc0 = {((b0[27:0] & opa0[27:0]) | (b0[27:0] & opb0[27:0]) | (opa0[27:0] & opb0[27:0])), i0};
    wire [15:0] lo0 = {1'b0, ss0[14:0]} + {1'b0, cc0[14:0]};
    wire [13:0] hi0 = ss0[28:15] + cc0[28:15];
    wire [28:0] b1 = a3[1];
    wire [15:0] lo1 = {1'b0, b1[14:0]} + {1'b0, opa1[14:0]};
    wire [13:0] hi1 = b1[28:15] + opa1[28:15];
    wire [28:0] b2 = a3[2];
    wire [28:0] ss2 = b2 ^ opa2 ^ opb2;
    wire [28:0] cc2 = {((b2[27:0] & opa2[27:0]) | (b2[27:0] & opb2[27:0]) | (opa2[27:0] & opb2[27:0])), i2};
    wire [15:0] lo2 = {1'b0, ss2[14:0]} + {1'b0, cc2[14:0]};
    wire [13:0] hi2 = ss2[28:15] + cc2[28:15];
    wire [28:0] b3 = a3[3];
    wire [28:0] ss3 = b3 ^ opa3 ^ opb3;
    wire [28:0] cc3 = {((b3[27:0] & opa3[27:0]) | (b3[27:0] & opb3[27:0]) | (opa3[27:0] & opb3[27:0])), i3};
    wire [15:0] lo3 = {1'b0, ss3[14:0]} + {1'b0, cc3[14:0]};
    wire [13:0] hi3 = ss3[28:15] + cc3[28:15];
    wire [28:0] b4 = a3[4];
    wire [28:0] ss4 = b4 ^ opa4 ^ opb4;
    wire [28:0] cc4 = {((b4[27:0] & opa4[27:0]) | (b4[27:0] & opb4[27:0]) | (opa4[27:0] & opb4[27:0])), i4};
    wire [15:0] lo4 = {1'b0, ss4[14:0]} + {1'b0, cc4[14:0]};
    wire [13:0] hi4 = ss4[28:15] + cc4[28:15];
    wire [28:0] b5 = a3[5];
    wire [28:0] ss5 = b5 ^ opa5 ^ opb5;
    wire [28:0] cc5 = {((b5[27:0] & opa5[27:0]) | (b5[27:0] & opb5[27:0]) | (opa5[27:0] & opb5[27:0])), i5};
    wire [15:0] lo5 = {1'b0, ss5[14:0]} + {1'b0, cc5[14:0]};
    wire [13:0] hi5 = ss5[28:15] + cc5[28:15];
    wire [28:0] b6 = a3[6];
    wire [28:0] ss6 = b6 ^ opa6 ^ opb6;
    wire [28:0] cc6 = {((b6[27:0] & opa6[27:0]) | (b6[27:0] & opb6[27:0]) | (opa6[27:0] & opb6[27:0])), i6};
    wire [15:0] lo6 = {1'b0, ss6[14:0]} + {1'b0, cc6[14:0]};
    wire [13:0] hi6 = ss6[28:15] + cc6[28:15];
    wire [28:0] b7 = a3[7];
    wire [15:0] lo7 = {1'b0, b7[14:0]} + {1'b0, opa7[14:0]};
    wire [13:0] hi7 = b7[28:15] + opa7[28:15];
    integer va;
    always @(posedge clk) begin
        a3[0] <= n0;
        a3[1] <= n1;
        a3[2] <= n2;
        a3[3] <= n3;
        a3[4] <= n4;
        a3[5] <= n5;
        a3[6] <= n6;
        a3[7] <= n7;
    end
    always @(posedge clk) begin
        a0[0] <= {hi0, lo0[14:0]}; c0[0] <= lo0[15];
        a0[1] <= {hi1, lo1[14:0]}; c0[1] <= lo1[15];
        a0[2] <= {hi2, lo2[14:0]}; c0[2] <= lo2[15];
        a0[3] <= {hi3, lo3[14:0]}; c0[3] <= lo3[15];
        a0[4] <= {hi4, lo4[14:0]}; c0[4] <= lo4[15];
        a0[5] <= {hi5, lo5[14:0]}; c0[5] <= lo5[15];
        a0[6] <= {hi6, lo6[14:0]}; c0[6] <= lo6[15];
        a0[7] <= {hi7, lo7[14:0]}; c0[7] <= lo7[15];
        for (va = 0; va < 8; va = va + 1) begin
            a1[va] <= {a0[va][28:15] + {13'd0, c0[va]}, a0[va][14:0]};
            a2[va] <= a1[va];
        end
    end

    reg  [7:0] qhs [0:7];
    reg  [7:0] qi;
    wire [28:0] qa0 = a1[0];
    wire [10:0] qh0 = qa0[28:18];
    wire        qs0_3 = f_uh[1] || f_uh[2];
    wire [10:0] qx0_3 = $signed(qh0) >>> 3;
    wire        qs0_4 = f_uh[0] || f_uh[3];
    wire [10:0] qx0_4 = $signed(qh0) >>> 4;
    wire        qs0_5 = f_uh[4] || f_uh[5];
    wire [10:0] qx0_5 = $signed(qh0) >>> 5;
    wire        qs0_6 = f_uh[6] || f_uh[7];
    wire [10:0] qx0_6 = $signed(qh0) >>> 6;
    wire [7:0]  qhs0_n = ({8{qs0_3}} & qx0_3[7:0]) | ({8{qs0_4}} & qx0_4[7:0]) | ({8{qs0_5}} & qx0_5[7:0]) | ({8{qs0_6}} & qx0_6[7:0]);
    wire        qdp0 = ~qa0[28] & qa0[17];
    wire        qdn0 = qa0[28] & ~(qa0[17] & (|qa0[16:0]));
    wire        qt0 = (qs0_3 & qh0[2]) | (qs0_4 & qh0[3]) | (qs0_5 & qh0[4]) | (qs0_6 & qh0[5]);
    wire        qz0 = (qs0_3 & (qh0[1:0] == 2'd0)) | (qs0_4 & (qh0[2:0] == 3'd0)) | (qs0_5 & (qh0[3:0] == 4'd0)) | (qs0_6 & (qh0[4:0] == 5'd0));
    wire        qo0 = (qs0_3 & (&qh0[1:0])) | (qs0_4 & (&qh0[2:0])) | (qs0_5 & (&qh0[3:0])) | (qs0_6 & (&qh0[4:0]));
    wire        qi0_n = qt0 ? ~(qdn0 & qz0) : (qdp0 & qo0);
    wire [28:0] qa1 = a1[1];
    wire [10:0] qh1 = qa1[28:18];
    wire        qs1_4 = f_uh[0] || f_uh[1] || f_uh[2] || f_uh[3];
    wire [10:0] qx1_4 = $signed(qh1) >>> 4;
    wire        qs1_5 = f_uh[4];
    wire [10:0] qx1_5 = $signed(qh1) >>> 5;
    wire        qs1_6 = f_uh[5] || f_uh[6] || f_uh[7];
    wire [10:0] qx1_6 = $signed(qh1) >>> 6;
    wire [7:0]  qhs1_n = ({8{qs1_4}} & qx1_4[7:0]) | ({8{qs1_5}} & qx1_5[7:0]) | ({8{qs1_6}} & qx1_6[7:0]);
    wire        qdp1 = ~qa1[28] & qa1[17];
    wire        qdn1 = qa1[28] & ~(qa1[17] & (|qa1[16:0]));
    wire        qt1 = (qs1_4 & qh1[3]) | (qs1_5 & qh1[4]) | (qs1_6 & qh1[5]);
    wire        qz1 = (qs1_4 & (qh1[2:0] == 3'd0)) | (qs1_5 & (qh1[3:0] == 4'd0)) | (qs1_6 & (qh1[4:0] == 5'd0));
    wire        qo1 = (qs1_4 & (&qh1[2:0])) | (qs1_5 & (&qh1[3:0])) | (qs1_6 & (&qh1[4:0]));
    wire        qi1_n = qt1 ? ~(qdn1 & qz1) : (qdp1 & qo1);
    wire [28:0] qa2 = a1[2];
    wire [10:0] qh2 = qa2[28:18];
    wire        qs2_4 = f_uh[0] || f_uh[1] || f_uh[2];
    wire [10:0] qx2_4 = $signed(qh2) >>> 4;
    wire        qs2_5 = f_uh[3] || f_uh[4];
    wire [10:0] qx2_5 = $signed(qh2) >>> 5;
    wire        qs2_6 = f_uh[5] || f_uh[6] || f_uh[7];
    wire [10:0] qx2_6 = $signed(qh2) >>> 6;
    wire [7:0]  qhs2_n = ({8{qs2_4}} & qx2_4[7:0]) | ({8{qs2_5}} & qx2_5[7:0]) | ({8{qs2_6}} & qx2_6[7:0]);
    wire        qdp2 = ~qa2[28] & qa2[17];
    wire        qdn2 = qa2[28] & ~(qa2[17] & (|qa2[16:0]));
    wire        qt2 = (qs2_4 & qh2[3]) | (qs2_5 & qh2[4]) | (qs2_6 & qh2[5]);
    wire        qz2 = (qs2_4 & (qh2[2:0] == 3'd0)) | (qs2_5 & (qh2[3:0] == 4'd0)) | (qs2_6 & (qh2[4:0] == 5'd0));
    wire        qo2 = (qs2_4 & (&qh2[2:0])) | (qs2_5 & (&qh2[3:0])) | (qs2_6 & (&qh2[4:0]));
    wire        qi2_n = qt2 ? ~(qdn2 & qz2) : (qdp2 & qo2);
    wire [28:0] qa3 = a1[3];
    wire [10:0] qh3 = qa3[28:18];
    wire        qs3_4 = f_uh[0] || f_uh[1] || f_uh[2];
    wire [10:0] qx3_4 = $signed(qh3) >>> 4;
    wire        qs3_5 = f_uh[3];
    wire [10:0] qx3_5 = $signed(qh3) >>> 5;
    wire        qs3_6 = f_uh[4] || f_uh[5] || f_uh[6] || f_uh[7];
    wire [10:0] qx3_6 = $signed(qh3) >>> 6;
    wire [7:0]  qhs3_n = ({8{qs3_4}} & qx3_4[7:0]) | ({8{qs3_5}} & qx3_5[7:0]) | ({8{qs3_6}} & qx3_6[7:0]);
    wire        qdp3 = ~qa3[28] & qa3[17];
    wire        qdn3 = qa3[28] & ~(qa3[17] & (|qa3[16:0]));
    wire        qt3 = (qs3_4 & qh3[3]) | (qs3_5 & qh3[4]) | (qs3_6 & qh3[5]);
    wire        qz3 = (qs3_4 & (qh3[2:0] == 3'd0)) | (qs3_5 & (qh3[3:0] == 4'd0)) | (qs3_6 & (qh3[4:0] == 5'd0));
    wire        qo3 = (qs3_4 & (&qh3[2:0])) | (qs3_5 & (&qh3[3:0])) | (qs3_6 & (&qh3[4:0]));
    wire        qi3_n = qt3 ? ~(qdn3 & qz3) : (qdp3 & qo3);
    wire [28:0] qa4 = a1[4];
    wire [10:0] qh4 = qa4[28:18];
    wire        qs4_4 = f_uh[0] || f_uh[1];
    wire [10:0] qx4_4 = $signed(qh4) >>> 4;
    wire        qs4_5 = f_uh[2];
    wire [10:0] qx4_5 = $signed(qh4) >>> 5;
    wire        qs4_6 = f_uh[3] || f_uh[4] || f_uh[7];
    wire [10:0] qx4_6 = $signed(qh4) >>> 6;
    wire        qs4_7 = f_uh[5] || f_uh[6];
    wire [10:0] qx4_7 = $signed(qh4) >>> 7;
    wire [7:0]  qhs4_n = ({8{qs4_4}} & qx4_4[7:0]) | ({8{qs4_5}} & qx4_5[7:0]) | ({8{qs4_6}} & qx4_6[7:0]) | ({8{qs4_7}} & qx4_7[7:0]);
    wire        qdp4 = ~qa4[28] & qa4[17];
    wire        qdn4 = qa4[28] & ~(qa4[17] & (|qa4[16:0]));
    wire        qt4 = (qs4_4 & qh4[3]) | (qs4_5 & qh4[4]) | (qs4_6 & qh4[5]) | (qs4_7 & qh4[6]);
    wire        qz4 = (qs4_4 & (qh4[2:0] == 3'd0)) | (qs4_5 & (qh4[3:0] == 4'd0)) | (qs4_6 & (qh4[4:0] == 5'd0)) | (qs4_7 & (qh4[5:0] == 6'd0));
    wire        qo4 = (qs4_4 & (&qh4[2:0])) | (qs4_5 & (&qh4[3:0])) | (qs4_6 & (&qh4[4:0])) | (qs4_7 & (&qh4[5:0]));
    wire        qi4_n = qt4 ? ~(qdn4 & qz4) : (qdp4 & qo4);
    wire [28:0] qa5 = a1[5];
    wire [10:0] qh5 = qa5[28:18];
    wire        qs5_5 = f_uh[0] || f_uh[1];
    wire [10:0] qx5_5 = $signed(qh5) >>> 5;
    wire        qs5_6 = f_uh[2] || f_uh[3] || f_uh[4];
    wire [10:0] qx5_6 = $signed(qh5) >>> 6;
    wire        qs5_7 = f_uh[5] || f_uh[6] || f_uh[7];
    wire [10:0] qx5_7 = $signed(qh5) >>> 7;
    wire [7:0]  qhs5_n = ({8{qs5_5}} & qx5_5[7:0]) | ({8{qs5_6}} & qx5_6[7:0]) | ({8{qs5_7}} & qx5_7[7:0]);
    wire        qdp5 = ~qa5[28] & qa5[17];
    wire        qdn5 = qa5[28] & ~(qa5[17] & (|qa5[16:0]));
    wire        qt5 = (qs5_5 & qh5[4]) | (qs5_6 & qh5[5]) | (qs5_7 & qh5[6]);
    wire        qz5 = (qs5_5 & (qh5[3:0] == 4'd0)) | (qs5_6 & (qh5[4:0] == 5'd0)) | (qs5_7 & (qh5[5:0] == 6'd0));
    wire        qo5 = (qs5_5 & (&qh5[3:0])) | (qs5_6 & (&qh5[4:0])) | (qs5_7 & (&qh5[5:0]));
    wire        qi5_n = qt5 ? ~(qdn5 & qz5) : (qdp5 & qo5);
    wire [28:0] qa6 = a1[6];
    wire [10:0] qh6 = qa6[28:18];
    wire        qs6_6 = f_uh[0] || f_uh[1] || f_uh[2] || f_uh[3];
    wire [10:0] qx6_6 = $signed(qh6) >>> 6;
    wire        qs6_7 = f_uh[4] || f_uh[5] || f_uh[6] || f_uh[7];
    wire [10:0] qx6_7 = $signed(qh6) >>> 7;
    wire [7:0]  qhs6_n = ({8{qs6_6}} & qx6_6[7:0]) | ({8{qs6_7}} & qx6_7[7:0]);
    wire        qdp6 = ~qa6[28] & qa6[17];
    wire        qdn6 = qa6[28] & ~(qa6[17] & (|qa6[16:0]));
    wire        qt6 = (qs6_6 & qh6[5]) | (qs6_7 & qh6[6]);
    wire        qz6 = (qs6_6 & (qh6[4:0] == 5'd0)) | (qs6_7 & (qh6[5:0] == 6'd0));
    wire        qo6 = (qs6_6 & (&qh6[4:0])) | (qs6_7 & (&qh6[5:0]));
    wire        qi6_n = qt6 ? ~(qdn6 & qz6) : (qdp6 & qo6);
    wire [28:0] qa7 = a1[7];
    wire [10:0] qh7 = qa7[28:18];
    wire        qs7_6 = f_uh[0];
    wire [10:0] qx7_6 = $signed(qh7) >>> 6;
    wire        qs7_7 = f_uh[1] || f_uh[2] || f_uh[3] || f_uh[4] || f_uh[5] || f_uh[6] || f_uh[7];
    wire [10:0] qx7_7 = $signed(qh7) >>> 7;
    wire [7:0]  qhs7_n = ({8{qs7_6}} & qx7_6[7:0]) | ({8{qs7_7}} & qx7_7[7:0]);
    wire        qdp7 = ~qa7[28] & qa7[17];
    wire        qdn7 = qa7[28] & ~(qa7[17] & (|qa7[16:0]));
    wire        qt7 = (qs7_6 & qh7[5]) | (qs7_7 & qh7[6]);
    wire        qz7 = (qs7_6 & (qh7[4:0] == 5'd0)) | (qs7_7 & (qh7[5:0] == 6'd0));
    wire        qo7 = (qs7_6 & (&qh7[4:0])) | (qs7_7 & (&qh7[5:0]));
    wire        qi7_n = qt7 ? ~(qdn7 & qz7) : (qdp7 & qo7);
    always @(posedge clk) begin
        qhs[0] <= qhs0_n; qi[0] <= qi0_n;
        qhs[1] <= qhs1_n; qi[1] <= qi1_n;
        qhs[2] <= qhs2_n; qi[2] <= qi2_n;
        qhs[3] <= qhs3_n; qi[3] <= qi3_n;
        qhs[4] <= qhs4_n; qi[4] <= qi4_n;
        qhs[5] <= qhs5_n; qi[5] <= qi5_n;
        qhs[6] <= qhs6_n; qi[6] <= qi6_n;
        qhs[7] <= qhs7_n; qi[7] <= qi7_n;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin q_wr <= 1'b0; q_u <= 3'd0; q_par <= 1'b0; end
        else begin q_wr <= f_v && f_s7; q_u <= f_u; q_par <= f_par; end
    end

    assign q_col = {qhs[7] + {7'd0, qi[7]}, qhs[6] + {7'd0, qi[6]}, qhs[5] + {7'd0, qi[5]}, qhs[4] + {7'd0, qi[4]}, qhs[3] + {7'd0, qi[3]}, qhs[2] + {7'd0, qi[2]}, qhs[1] + {7'd0, qi[1]}, qhs[0] + {7'd0, qi[0]}};
endmodule

module JPEGLENC_ENT (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clr,
    input  wire        wr,
    input  wire [2:0]  wu,
    input  wire        wpar,
    input  wire [63:0] wq,
    input  wire [1:0]  ab,
    output reg         pk_v,
    output reg  [63:0] pk_word,
    output reg         flushed,
    output wire [3:0]  last_nb
);

    function [27:0] ac_rfld;
        input [6:0] rs;
        begin
            case (rs)
                7'h00: ac_rfld = 28'h00000A4;
                7'h01: ac_rfld = 28'h00000C3;
                7'h02: ac_rfld = 28'h0000104;
                7'h03: ac_rfld = 28'h0000306;
                7'h04: ac_rfld = 28'h0000808;
                7'h05: ac_rfld = 28'h000140A;
                7'h06: ac_rfld = 28'h000380D;
                7'h07: ac_rfld = 28'h000700F;
                7'h09: ac_rfld = 28'h00000C5;
                7'h0A: ac_rfld = 28'h0000207;
                7'h0B: ac_rfld = 28'h000060A;
                7'h0C: ac_rfld = 28'h000120D;
                7'h0D: ac_rfld = 28'h0002410;
                7'h0E: ac_rfld = 28'h003D816;
                7'h0F: ac_rfld = 28'h007A017;
                7'h11: ac_rfld = 28'h00000C6;
                7'h12: ac_rfld = 28'h000030A;
                7'h13: ac_rfld = 28'h000080D;
                7'h14: ac_rfld = 28'h0001610;
                7'h15: ac_rfld = 28'h001D815;
                7'h16: ac_rfld = 28'h003A816;
                7'h17: ac_rfld = 28'h0074017;
                7'h19: ac_rfld = 28'h0000147;
                7'h1A: ac_rfld = 28'h000040B;
                7'h1B: ac_rfld = 28'h0000A0F;
                7'h1C: ac_rfld = 28'h000E014;
                7'h1D: ac_rfld = 28'h001BC15;
                7'h1E: ac_rfld = 28'h0037016;
                7'h1F: ac_rfld = 28'h006D017;
                7'h21: ac_rfld = 28'h0000107;
                7'h22: ac_rfld = 28'h000038C;
                7'h23: ac_rfld = 28'h0006913;
                7'h24: ac_rfld = 28'h000D014;
                7'h25: ac_rfld = 28'h0019C15;
                7'h26: ac_rfld = 28'h0033016;
                7'h27: ac_rfld = 28'h0065017;
                7'h29: ac_rfld = 28'h0000148;
                7'h2A: ac_rfld = 28'h000040D;
                7'h2B: ac_rfld = 28'h0006113;
                7'h2C: ac_rfld = 28'h000C014;
                7'h2D: ac_rfld = 28'h0017C15;
                7'h2E: ac_rfld = 28'h002F016;
                7'h2F: ac_rfld = 28'h005D017;
                7'h31: ac_rfld = 28'h0000108;
                7'h32: ac_rfld = 28'h000048E;
                7'h33: ac_rfld = 28'h0005913;
                7'h34: ac_rfld = 28'h000B014;
                7'h35: ac_rfld = 28'h0015C15;
                7'h36: ac_rfld = 28'h002B016;
                7'h37: ac_rfld = 28'h0055017;
                7'h39: ac_rfld = 28'h0000149;
                7'h3A: ac_rfld = 28'h000040E;
                7'h3B: ac_rfld = 28'h0005113;
                7'h3C: ac_rfld = 28'h000A014;
                7'h3D: ac_rfld = 28'h0013C15;
                7'h3E: ac_rfld = 28'h0027016;
                7'h3F: ac_rfld = 28'h004D017;
                7'h41: ac_rfld = 28'h00001CA;
                7'h42: ac_rfld = 28'h0001F91;
                7'h43: ac_rfld = 28'h0004913;
                7'h44: ac_rfld = 28'h0009014;
                7'h45: ac_rfld = 28'h0011C15;
                7'h46: ac_rfld = 28'h0023016;
                7'h47: ac_rfld = 28'h0045017;
                7'h49: ac_rfld = 28'h000018A;
                7'h4A: ac_rfld = 28'h0002092;
                7'h4B: ac_rfld = 28'h0004013;
                7'h4C: ac_rfld = 28'h0007E14;
                7'h4D: ac_rfld = 28'h000F815;
                7'h4E: ac_rfld = 28'h001E816;
                7'h4F: ac_rfld = 28'h003C017;
                7'h51: ac_rfld = 28'h000014A;
                7'h52: ac_rfld = 28'h0001C12;
                7'h53: ac_rfld = 28'h0003713;
                7'h54: ac_rfld = 28'h0006C14;
                7'h55: ac_rfld = 28'h000D415;
                7'h56: ac_rfld = 28'h001A016;
                7'h57: ac_rfld = 28'h0033017;
                7'h59: ac_rfld = 28'h000018B;
                7'h5A: ac_rfld = 28'h0001792;
                7'h5B: ac_rfld = 28'h0002E13;
                7'h5C: ac_rfld = 28'h0005A14;
                7'h5D: ac_rfld = 28'h000B015;
                7'h5E: ac_rfld = 28'h0015816;
                7'h5F: ac_rfld = 28'h002A017;
                7'h61: ac_rfld = 28'h000014B;
                7'h62: ac_rfld = 28'h0001312;
                7'h63: ac_rfld = 28'h0002513;
                7'h64: ac_rfld = 28'h0004814;
                7'h65: ac_rfld = 28'h0008C15;
                7'h66: ac_rfld = 28'h0011016;
                7'h67: ac_rfld = 28'h0021017;
                7'h69: ac_rfld = 28'h00001CC;
                7'h6A: ac_rfld = 28'h0000E92;
                7'h6B: ac_rfld = 28'h0001C13;
                7'h6C: ac_rfld = 28'h0003614;
                7'h6D: ac_rfld = 28'h0006815;
                7'h6E: ac_rfld = 28'h000C816;
                7'h6F: ac_rfld = 28'h0018017;
                7'h71: ac_rfld = 28'h0000511;
                7'h72: ac_rfld = 28'h0000992;
                7'h73: ac_rfld = 28'h0001213;
                7'h74: ac_rfld = 28'h0002214;
                7'h75: ac_rfld = 28'h0004015;
                7'h76: ac_rfld = 28'h0007816;
                7'h77: ac_rfld = 28'h000E017;
                7'h78: ac_rfld = 28'h00000CB;
                7'h79: ac_rfld = 28'h0000291;
                7'h7A: ac_rfld = 28'h0000492;
                7'h7B: ac_rfld = 28'h0000813;
                7'h7C: ac_rfld = 28'h0000E14;
                7'h7D: ac_rfld = 28'h0001815;
                7'h7E: ac_rfld = 28'h0002816;
                7'h7F: ac_rfld = 28'h0004017;
                default: ac_rfld = 28'h0000000;
            endcase
        end
    endfunction

    function [27:0] dc_rfld;
        input [3:0] cat;
        begin
            dc_rfld = cat[3] ? 28'h000200E : (cat[2] ? (cat[1] ? (cat[0] ? 28'h000100C : 28'h000080A) : (cat[0] ? 28'h0000408 : 28'h0000407)) : (cat[1] ? (cat[0] ? 28'h0000306 : 28'h0000205) : (cat[0] ? 28'h0000144 : 28'h0000062)));
        end
    endfunction

    reg  [7:0] kh, kl;
    reg        e_on;
    reg        e_pend;
    reg        e_par;
    reg  [7:0] e_lfsr;
    wire       c0   = wr && (wu == 3'd0);
    wire       ek63 = kh[7] & kl[7];

    wire       blk255 = (e_lfsr == 8'd0) && e_par;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            kh <= 8'd1; kl <= 8'd1; e_on <= 1'b0; e_pend <= 1'b0; e_par <= 1'b0; e_lfsr <= 8'd0;
        end else begin
            kl <= c0 ? 8'b0100_0000 : {kl[6:0], kl[7]};
            kh <= c0 ? 8'b0010_0000 : (kl[7] ? {kh[6:0], kh[7]} : kh);
            if (c0) e_pend <= 1'b1;
            else if (ek63) e_pend <= 1'b0;
            if (ek63) e_on <= e_pend;
            if (e_on && ek63) begin
                e_par <= ~e_par;
                if (!blk255) e_lfsr <= {e_lfsr[6:0], ~(e_lfsr[7] ^ e_lfsr[5] ^ e_lfsr[4] ^ e_lfsr[3])};
            end
        end
    end

    wire       k0_e0  = kh[0] & kl[0];
    wire       p0_e1  = kh[0] & kl[1];
    wire       p0     = kh[0] & kl[2];
    wire       p1     = kh[0] & kl[3];
    wire       p63    = kh[0] & kl[1];
    wire       k16    = (|kh[7:3]) | (kh[2] & (|kl[7:2])) | (kh[0] & (kl[0] | kl[1]));

    reg        e_ab;
    always @(posedge clk) if (k0_e0) e_ab <= e_par ? ab[1] : ab[0];

    wire [7:0] rq;
    JPEGLENC_QBUF u_qbuf (.clk(clk), .wr(wr), .wu(wu), .wpar(wpar), .wq(wq), .rkh(kh), .rkl(kl),
                          .rpar(e_par), .rq(rq));

    reg  [7:0] nzq;
    reg  [2:0] nz_u;
    reg        nz_wr;
    integer vn;
    always @(posedge clk) begin
        for (vn = 0; vn < 8; vn = vn + 1) nzq[vn] <= (wq[8*vn +: 8] != 8'd0);
        nz_u <= wu;
    end

    always @(posedge clk) nz_wr <= wr;

    wire [7:0] thr = {3'b111, |nz_u, nz_u[2] | nz_u[1], nz_u[2] | (nz_u[1] & nz_u[0]),
                      nz_u[2] & (nz_u[1] | nz_u[0]), nz_u[2] & nz_u[1]};
    wire [7:0] nzm = nzq & thr;

    wire       fa1s = nzm[0] ^ nzm[1] ^ nzm[2];
    wire       fa1c = (nzm[0] & nzm[1]) | (nzm[2] & (nzm[0] ^ nzm[1]));
    wire       fa2s = nzm[3] ^ nzm[4] ^ nzm[5];
    wire       fa2c = (nzm[3] & nzm[4]) | (nzm[5] & (nzm[3] ^ nzm[4]));
    wire       ha3s = nzm[6] ^ nzm[7];
    wire       ha3c = nzm[6] & nzm[7];
    wire       fa4c = (fa1s & fa2s) | (ha3s & (fa1s ^ fa2s));
    wire       fa5s = fa1c ^ fa2c ^ ha3c;
    wire       fa5c = (fa1c & fa2c) | (ha3c & (fa1c ^ fa2c));
    wire [3:0] pc   = {fa5c & fa5s & fa4c, fa5c ^ (fa5s & fa4c), fa5s ^ fa4c, fa1s ^ fa2s ^ ha3s};
    reg  [3:0] pc_r;
    reg        pwr, pu0, pu7;
    always @(posedge clk) begin
        pc_r <= pc; pwr <= nz_wr; pu0 <= (nz_u == 3'd0); pu7 <= (nz_u == 3'd7);
    end
    reg  [5:0] nzc, rem;
    wire [5:0] nsum = (pu0 ? 6'd0 : nzc) + {2'b0, pc_r};
    wire       ld   = pwr && pu7;
    wire       rz   = ld ? ((nzc == 6'd0) && (pc_r == 4'd0)) : (rem == 6'd0);
    always @(posedge clk) begin
        if (pwr) nzc <= nsum;
    end

    reg  [7:0] q1;
    reg        v1;
    always @(posedge clk) q1 <= rq;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) v1 <= 1'b0;
        else v1 <= e_on;
    end
    reg  signed [7:0] prev_dc;
    wire [8:0] dcd = {q1[7], q1} - {prev_dc[7], prev_dc};
    reg  [8:0] x2;
    reg        v2;
    always @(posedge clk) x2 <= p0_e1 ? dcd : {q1[7], q1};
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) prev_dc <= 8'sd0;
        else if (clr) prev_dc <= 8'sd0;
        else if (v1 && p0_e1) prev_dc <= q1;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) v2 <= 1'b0;
        else v2 <= v1;
    end

    wire        s2   = x2[8];
    wire [7:0]  y2   = x2[7:0] ^ {8{s2}};
    wire [7:0]  smr;
    assign smr[0] = (|y2) | s2;
    genvar gi;
    generate for (gi = 1; gi < 8; gi = gi + 1) begin : g_smr
        assign smr[gi] = (|y2[7:gi]) | (s2 & (&y2[gi-1:0]));
    end endgenerate
    wire [3:0]  sz    = {smr[7], smr[3] & ~smr[7], (smr[1] & ~smr[3]) | (smr[5] & ~smr[7]),
                         (smr[0] & ~smr[1]) | (smr[2] & ~smr[3]) | (smr[4] & ~smr[5]) | (smr[6] & ~smr[7])};

    wire [7:0]  xm1   = x2[7:0] - 8'd1;
    wire [7:0]  zamp  = s2 ? ~xm1 : (~x2[7:0] & smr);
    wire        zero2 = (x2 == 9'd0);

    reg         dc3;
    reg  [3:0]  run3, sz3;
    reg  [7:0]  za3;
    reg         e3v;
    reg         e_stop;
    wire        rr    = dc3 || (sz3 != 4'd0);
    wire [3:0]  run   = rr ? 4'd0 : run3 + 4'd1;
    wire        r15   = !rr && (run3 == 4'd14);
    wire        zrl   = !p0 && zero2 && r15 && !rz;
    wire        eeob  = !p0 && zero2 && k16 && rz;
    wire        ab1   = p1 && e_ab;
    wire        eob   = eeob || ab1;
    wire        emit  = v2 && !e_stop && (p0 || !zero2 || zrl || eob);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) e_stop <= 1'b0;
        else if (p63) e_stop <= 1'b0;
        else if (v2 && eob) e_stop <= 1'b1;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) e3v <= 1'b0;
        else e3v <= emit;
    end
    always @(posedge clk) rem <= ld ? nsum : (zero2 ? rem : rem - 6'd1);

    always @(posedge clk) begin
        dc3 <= p0; run3 <= eob ? 4'd0 : run; sz3 <= ab1 ? 4'd0 : sz; za3 <= ab1 ? 8'd0 : zamp;
    end

    reg  [22:0] zr4;
    reg  [4:0]  fl4;
    reg         e4v;
    wire [27:0] hx  = dc3 ? dc_rfld(sz3) : ac_rfld({run3, sz3[2:0]});
    always @(posedge clk) begin
        zr4 <= hx[27:5] | {15'd0, za3}; fl4 <= hx[4:0];
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) e4v <= 1'b0;
        else e4v <= e3v;
    end

    reg  [4:0]  fs;
    reg         si;
    wire [5:0]  nfs = {1'b0, fs} + {1'b0, fl4};
    wire [29:0] yv  = {zr4, 7'd0} >> nfs[2:0];
    reg  [29:0] y5;
    reg  [2:0]  eb5;
    reg         si5;
    reg         e5v;
    always @(posedge clk) begin
        y5 <= yv; eb5 <= nfs[5:3]; si5 <= si;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fs <= 5'd0; si <= 1'b0; e5v <= 1'b0;
        end else if (clr) begin
            fs <= 5'd0; si <= 1'b0; e5v <= 1'b0;
        end else begin
            e5v <= e4v;
            if (e4v) begin fs <= nfs[4:0]; si <= si ^ nfs[5]; end
        end
    end

    reg  [31:0] cz;
    reg         e_last;
    reg         e_done;
    reg         fdone;
    wire [6:0]  bs  = {7{e5v}} & {eb5 == 3'd6, eb5 == 3'd5, eb5 == 3'd4, eb5 == 3'd3, eb5 == 3'd2,
                                  eb5 == 3'd1, eb5 == 3'd0};
    wire [54:0] zsh = ({55{bs[0]}} & {y5[6:0], 48'd0}) | ({55{bs[1]}} & {y5[14:0], 40'd0}) |
                      ({55{bs[2]}} & {y5[22:0], 32'd0}) | ({55{bs[3]}} & {1'b0, y5, 24'd0}) |
                      ({55{bs[4]}} & {9'd0, y5, 16'd0}) | ({55{bs[5]}} & {17'd0, y5, 8'd0}) |
                      ({55{bs[6]}} & {25'd0, y5});
    wire [54:0] zw  = {cz, 23'd0} | zsh;
    wire [31:0] hi  = zw[54:23];
    wire        seg = e5v && eb5[2];
    wire        wemp = !si && (fs == 5'd0);

    wire        flush_now = e_done && !fdone && !e3v && !e4v && !e5v;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cz <= 32'd0;
        else cz <= (seg || flush_now) ? {zw[22:0], 9'd0} : hi;
    end
    always @(posedge clk) begin
        if ((seg && !si5) || (flush_now && !si)) pk_word[63:32] <= ~hi;
        if ((seg && si5) || (flush_now && si)) pk_word[31:0] <= ~hi;
        else if (flush_now) pk_word[31:0] <= 32'hFFFF_FFFF;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pk_v <= 1'b0;
        else pk_v <= (seg && si5) || (flush_now && !wemp);
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            e_last <= 1'b0; e_done <= 1'b0; fdone <= 1'b0; flushed <= 1'b0;
        end else if (clr) begin
            e_last <= 1'b0; e_done <= 1'b0; fdone <= 1'b0; flushed <= 1'b0;
        end else begin
            if (e_on && blk255 && p0) e_last <= 1'b1;
            if (v2 && e_last && (eob || p63)) e_done <= 1'b1;
            if (flush_now) fdone <= 1'b1;
            flushed <= fdone;
        end
    end

    wire [3:0]  lnb = {1'b0, si, 2'b00} + {2'b00, fs[4:3]} + {3'd0, fs[2:0] != 3'd0};
    assign last_nb = flushed ? (wemp ? 4'd8 : lnb) : 4'd0;
endmodule

module JPEGLENC_QBUF (
    input  wire        clk,
    input  wire        wr,
    input  wire [2:0]  wu,
    input  wire        wpar,
    input  wire [63:0] wq,
    input  wire [7:0]  rkh,
    input  wire [7:0]  rkl,
    input  wire        rpar,
    output wire [7:0]  rq
);
    wire [7:0] wc, wc0, wc1;
    genvar gu;
    generate for (gu = 0; gu < 8; gu = gu + 1) begin : g_wc
        assign wc[gu]   = wr && (wu == gu);
        assign wc0[gu]  = wr && (wu == gu) && !wpar;
        assign wc1[gu]  = wr && (wu == gu) && wpar;
    end endgenerate
    reg [3:0] l0;
    reg [3:0] l1;
    reg [3:0] l2;
    reg [3:0] l3;
    reg [3:0] l4;
    reg [3:0] l5;
    reg [3:0] l6;
    reg [3:0] l7;
    reg [3:0] l8;
    reg [3:0] l9;
    reg [3:0] l10;
    reg [3:0] l11;
    reg [3:0] l12;
    reg [3:0] l13;
    reg [3:0] l14;
    reg [3:0] l15;
    reg [3:0] l16;
    reg [3:0] l17;
    reg [3:0] l18;
    reg [3:0] l19;
    reg [3:0] l20;
    reg [3:0] l21;
    reg [3:0] l22;
    reg [3:0] l23;
    reg [3:0] l24;
    reg [3:0] l25;
    reg [3:0] l26;
    reg [3:0] l27;
    reg [3:0] l28;
    reg [3:0] l29;
    reg [3:0] l30;
    reg [3:0] l31;
    reg [3:0] l32;
    reg [3:0] l33;
    reg [3:0] l34;
    reg [3:0] l35;
    reg [3:0] l36;
    reg [3:0] l37;
    reg [3:0] l38;
    reg [3:0] l39;
    reg [3:0] l40;
    reg [3:0] l41;
    reg [3:0] l42;
    reg [3:0] l43;
    reg [3:0] l44;
    reg [3:0] l45;
    reg [3:0] l46;
    reg [2:0] h0;
    reg [1:0] h1;
    reg [2:0] h2;
    reg [3:0] h3;
    reg [0:0] h4;
    reg [0:0] h5;
    reg [2:0] h6;
    reg [0:0] h7;
    reg [3:0] h8;
    reg [0:0] h9;
    reg [0:0] h10;
    reg [1:0] h11;
    reg [1:0] h12;
    reg [0:0] h13;
    reg [0:0] h14;
    reg [0:0] h15;
    reg [2:0] h16;
    reg [0:0] h17;
    reg [0:0] h18;
    reg [2:0] h19;
    reg [1:0] h20;
    reg [2:0] h21;
    reg [2:0] h22;
    reg [2:0] h23;
    reg [2:0] h24;
    reg [2:0] h25;
    reg [2:0] h26;
    reg [3:0] h27;
    reg [3:0] h28;
    reg [1:0] h29;
    reg [2:0] h30;
    always @(posedge clk) if (wc[1] | wc[4] | wc[5] | wc[7]) l0 <= wq[3:0];
    always @(posedge clk) if (wc[0]) l1 <= wq[51:48];
    always @(posedge clk) if (wc[2] | wc[4]) l2 <= !wu[1] ? wq[43:40] : wq[3:0];
    always @(posedge clk) if (wc[2]) l3 <= wq[27:24];
    always @(posedge clk) if (wc0[3] | wc1[2]) l4 <= !wu[0] ? wq[59:56] : wq[43:40];
    always @(posedge clk) if (wc[0] | wc[4]) l5 <= wq[35:32];
    always @(posedge clk) if (wc[1] | wc[6]) l6 <= wq[19:16];
    always @(posedge clk) if (wc[0] | wc[7]) l7 <= wq[19:16];
    always @(posedge clk) if (wc[2]) l8 <= wq[51:48];
    always @(posedge clk) if (wc[4]) l9 <= wq[59:56];
    always @(posedge clk) if (wc[6]) l10 <= wq[35:32];
    always @(posedge clk) if (wc[1]) l11 <= wq[35:32];
    always @(posedge clk) if (wc[1]) l12 <= wq[51:48];
    always @(posedge clk) if (wc[2] | wc[4]) l13 <= wq[19:16];
    always @(posedge clk) if (wc[3]) l14 <= wq[51:48];
    always @(posedge clk) if (wc[2]) l15 <= wq[43:40];
    always @(posedge clk) if (wc[0]) l16 <= wq[43:40];
    always @(posedge clk) if (wc[3] | wc[6]) l17 <= wq[3:0];
    always @(posedge clk) if (wc[0] | wc[4]) l18 <= wu[2] ? wq[27:24] : wq[3:0];
    always @(posedge clk) if (wc[1] | wc[5]) l19 <= wq[11:8];
    always @(posedge clk) if (wc[3]) l20 <= wq[27:24];
    always @(posedge clk) if (wc[7]) l21 <= wq[43:40];
    always @(posedge clk) if (wc[3] | wc[6]) l22 <= wq[11:8];
    always @(posedge clk) if (wc[7]) l23 <= wq[35:32];
    always @(posedge clk) if (wc[6]) l24 <= wq[43:40];
    always @(posedge clk) if (wc[1] | wc[6]) l25 <= wq[27:24];
    always @(posedge clk) if (wc[1]) l26 <= wq[43:40];
    always @(posedge clk) if (wc[5]) l27 <= wq[59:56];
    always @(posedge clk) if (wc[0]) l28 <= wq[59:56];
    always @(posedge clk) if (wc[3]) l29 <= wq[35:32];
    always @(posedge clk) if (wc[0] | wc[5]) l30 <= wu[0] ? wq[35:32] : wq[11:8];
    always @(posedge clk) if (wc1[3] | wc0[2]) l31 <= !wu[0] ? wq[59:56] : wq[43:40];
    always @(posedge clk) if (wc[0] | wc[5]) l32 <= wq[27:24];
    always @(posedge clk) if (wc[7]) l33 <= wq[59:56];
    always @(posedge clk) if (wc[5]) l34 <= wq[43:40];
    always @(posedge clk) if (wc0[5] | wc1[3]) l35 <= wu[1] ? wq[59:56] : wq[19:16];
    always @(posedge clk) if (wc[6]) l36 <= wq[59:56];
    always @(posedge clk) if (wc[6]) l37 <= wq[51:48];
    always @(posedge clk) if (wc[4]) l38 <= wq[51:48];
    always @(posedge clk) if (wc1[5] | wc0[3]) l39 <= wu[1] ? wq[59:56] : wq[19:16];
    always @(posedge clk) if (wc[2]) l40 <= wq[35:32];
    always @(posedge clk) if (wc[1]) l41 <= wq[59:56];
    always @(posedge clk) if (wc[7]) l42 <= wq[51:48];
    always @(posedge clk) if (wc[7]) l43 <= wq[27:24];
    always @(posedge clk) if (wc[5]) l44 <= wq[51:48];
    always @(posedge clk) if (wc[3]) l45 <= wq[19:16];
    always @(posedge clk) if (wc[2] | wc[4] | wc[7]) l46 <= wq[11:8];
    always @(posedge clk) if (wc[1] | wc[4]) h0 <= wq[30:28];
    always @(posedge clk) if (wc[3]) h1 <= wq[29:28];
    always @(posedge clk) if (wc[2] | wc[4] | wc[7]) h2 <= wq[14:12];
    always @(posedge clk) if (wc[0] | wc[4] | wc[5] | wc[6]) h3 <= wq[7:4];
    always @(posedge clk) if (wc[0]) h4 <= wq[52:52];
    always @(posedge clk) if (wc[0]) h5 <= wq[60:60];
    always @(posedge clk) if (wc[2]) h6 <= wq[30:28];
    always @(posedge clk) if (wc[3]) h7 <= wq[36:36];
    always @(posedge clk) if (wc[0] | wc[4]) h8 <= wq[39:36];
    always @(posedge clk) if (wc[2]) h9 <= wq[44:44];
    always @(posedge clk) if (wc[3]) h10 <= wq[44:44];
    always @(posedge clk) if (wc[1]) h11 <= wq[45:44];
    always @(posedge clk) if (wc[2]) h12 <= wq[37:36];
    always @(posedge clk) if (wc[3]) h13 <= wq[52:52];
    always @(posedge clk) if (wc[7]) h14 <= wq[28:28];
    always @(posedge clk) if (wc[7]) h15 <= wq[36:36];
    always @(posedge clk) if (wc[3] | wc[4]) h16 <= !wu[0] ? wq[46:44] : wq[6:4];
    always @(posedge clk) if (wc[1]) h17 <= wq[52:52];
    always @(posedge clk) if (wc[2]) h18 <= wq[52:52];
    always @(posedge clk) if (wc[2] | wc[7]) h19 <= wq[22:20];
    always @(posedge clk) if (wc[0]) h20 <= wq[45:44];
    always @(posedge clk) if (wc[1] | wc[6]) h21 <= wq[22:20];
    always @(posedge clk) if (wc[0] | wc[4]) h22 <= wq[22:20];
    always @(posedge clk) if (wc[1]) h23 <= wq[38:36];
    always @(posedge clk) if (wc[0] | wc[5]) h24 <= wq[30:28];
    always @(posedge clk) if (wc[3] | wc[5]) h25 <= !wu[1] ? wq[22:20] : wq[14:12];
    always @(posedge clk) if (wc[0] | wc[6]) h26 <= wq[14:12];
    always @(posedge clk) if (wc[1] | wc[7]) h27 <= wq[7:4];
    always @(posedge clk) if (wc[2] | wc[6]) h28 <= wu[2] ? wq[31:28] : wq[7:4];
    always @(posedge clk) if (wc[3]) h29 <= wq[21:20];
    always @(posedge clk) if (wc[1] | wc[5]) h30 <= wq[14:12];
    wire [63:0] dk;
    genvar gk;
    generate for (gk = 0; gk < 64; gk = gk + 1) begin : g_dk
        assign dk[gk] = rkh[gk / 8] & rkl[gk % 8];
    end endgenerate
    wire rl0 = |{dk[1], dk[14], dk[15], dk[28]};
    wire rl1 = dk[21];
    wire rl2 = |{dk[5], dk[46]};
    wire rl3 = dk[18];
    wire rl4 = |{(dk[48] & rpar), (dk[38] & !rpar)};
    wire rl5 = |{dk[10], dk[39]};
    wire rl6 = |{dk[8], dk[41]};
    wire rl7 = |{dk[3], dk[43]};
    wire rl8 = dk[37];
    wire rl9 = dk[57];
    wire rl10 = dk[52];
    wire rl11 = dk[19];
    wire rl12 = dk[34];
    wire rl13 = |{dk[12], dk[25]};
    wire rl14 = dk[47];
    wire rl15 = dk[33];
    wire rl16 = dk[20];
    wire rl17 = |{dk[6], dk[27]};
    wire rl18 = |{dk[0], dk[31]};
    wire rl19 = |{dk[4], dk[26]};
    wire rl20 = dk[24];
    wire rl21 = dk[60];
    wire rl22 = |{dk[13], dk[29]};
    wire rl23 = dk[54];
    wire rl24 = dk[55];
    wire rl25 = |{dk[11], dk[44]};
    wire rl26 = dk[22];
    wire rl27 = dk[58];
    wire rl28 = dk[35];
    wire rl29 = dk[32];
    wire rl30 = |{dk[2], dk[45]};
    wire rl31 = |{(dk[48] & !rpar), (dk[38] & rpar)};
    wire rl32 = |{dk[9], dk[40]};
    wire rl33 = dk[63];
    wire rl34 = dk[51];
    wire rl35 = |{(dk[49] & rpar), (dk[30] & !rpar)};
    wire rl36 = dk[62];
    wire rl37 = dk[59];
    wire rl38 = dk[50];
    wire rl39 = |{(dk[49] & !rpar), (dk[30] & rpar)};
    wire rl40 = dk[23];
    wire rl41 = dk[36];
    wire rl42 = dk[61];
    wire rl43 = dk[53];
    wire rl44 = dk[56];
    wire rl45 = dk[17];
    wire rl46 = |{dk[7], dk[16], dk[42]};
    wire rh0 = |{dk[11], dk[31]};
    wire rh1 = dk[24];
    wire rh2 = |{dk[7], dk[16], dk[42]};
    wire rh3 = |{dk[0], dk[14], dk[15], dk[27]};
    wire rh4 = dk[21];
    wire rh5 = dk[35];
    wire rh6 = dk[18];
    wire rh7 = dk[32];
    wire rh8 = |{dk[10], dk[39]};
    wire rh9 = dk[33];
    wire rh10 = dk[38];
    wire rh11 = dk[22];
    wire rh12 = dk[23];
    wire rh13 = dk[47];
    wire rh14 = dk[53];
    wire rh15 = dk[54];
    wire rh16 = |{dk[6], dk[46]};
    wire rh17 = dk[34];
    wire rh18 = dk[37];
    wire rh19 = |{dk[12], dk[43]};
    wire rh20 = dk[20];
    wire rh21 = |{dk[8], dk[41]};
    wire rh22 = |{dk[3], dk[25]};
    wire rh23 = dk[19];
    wire rh24 = |{dk[9], dk[40]};
    wire rh25 = |{dk[13], dk[30]};
    wire rh26 = |{dk[2], dk[29]};
    wire rh27 = |{dk[1], dk[28]};
    wire rh28 = |{dk[5], dk[44]};
    wire rh29 = dk[17];
    wire rh30 = |{dk[4], dk[26]};
    wire [3:0] lb;
    wire [3:0] hb;
    assign lb[0] = |{(rl0 & l0[0]), (rl1 & l1[0]), (rl2 & l2[0]), (rl3 & l3[0]), (rl4 & l4[0]), (rl5 & l5[0]), (rl6 & l6[0]), (rl7 & l7[0]), (rl8 & l8[0]), (rl9 & l9[0]), (rl10 & l10[0]), (rl11 & l11[0]), (rl12 & l12[0]), (rl13 & l13[0]), (rl14 & l14[0]), (rl15 & l15[0]), (rl16 & l16[0]), (rl17 & l17[0]), (rl18 & l18[0]), (rl19 & l19[0]), (rl20 & l20[0]), (rl21 & l21[0]), (rl22 & l22[0]), (rl23 & l23[0]), (rl24 & l24[0]), (rl25 & l25[0]), (rl26 & l26[0]), (rl27 & l27[0]), (rl28 & l28[0]), (rl29 & l29[0]), (rl30 & l30[0]), (rl31 & l31[0]), (rl32 & l32[0]), (rl33 & l33[0]), (rl34 & l34[0]), (rl35 & l35[0]), (rl36 & l36[0]), (rl37 & l37[0]), (rl38 & l38[0]), (rl39 & l39[0]), (rl40 & l40[0]), (rl41 & l41[0]), (rl42 & l42[0]), (rl43 & l43[0]), (rl44 & l44[0]), (rl45 & l45[0]), (rl46 & l46[0])};
    assign lb[1] = |{(rl0 & l0[1]), (rl1 & l1[1]), (rl2 & l2[1]), (rl3 & l3[1]), (rl4 & l4[1]), (rl5 & l5[1]), (rl6 & l6[1]), (rl7 & l7[1]), (rl8 & l8[1]), (rl9 & l9[1]), (rl10 & l10[1]), (rl11 & l11[1]), (rl12 & l12[1]), (rl13 & l13[1]), (rl14 & l14[1]), (rl15 & l15[1]), (rl16 & l16[1]), (rl17 & l17[1]), (rl18 & l18[1]), (rl19 & l19[1]), (rl20 & l20[1]), (rl21 & l21[1]), (rl22 & l22[1]), (rl23 & l23[1]), (rl24 & l24[1]), (rl25 & l25[1]), (rl26 & l26[1]), (rl27 & l27[1]), (rl28 & l28[1]), (rl29 & l29[1]), (rl30 & l30[1]), (rl31 & l31[1]), (rl32 & l32[1]), (rl33 & l33[1]), (rl34 & l34[1]), (rl35 & l35[1]), (rl36 & l36[1]), (rl37 & l37[1]), (rl38 & l38[1]), (rl39 & l39[1]), (rl40 & l40[1]), (rl41 & l41[1]), (rl42 & l42[1]), (rl43 & l43[1]), (rl44 & l44[1]), (rl45 & l45[1]), (rl46 & l46[1])};
    assign lb[2] = |{(rl0 & l0[2]), (rl1 & l1[2]), (rl2 & l2[2]), (rl3 & l3[2]), (rl4 & l4[2]), (rl5 & l5[2]), (rl6 & l6[2]), (rl7 & l7[2]), (rl8 & l8[2]), (rl9 & l9[2]), (rl10 & l10[2]), (rl11 & l11[2]), (rl12 & l12[2]), (rl13 & l13[2]), (rl14 & l14[2]), (rl15 & l15[2]), (rl16 & l16[2]), (rl17 & l17[2]), (rl18 & l18[2]), (rl19 & l19[2]), (rl20 & l20[2]), (rl21 & l21[2]), (rl22 & l22[2]), (rl23 & l23[2]), (rl24 & l24[2]), (rl25 & l25[2]), (rl26 & l26[2]), (rl27 & l27[2]), (rl28 & l28[2]), (rl29 & l29[2]), (rl30 & l30[2]), (rl31 & l31[2]), (rl32 & l32[2]), (rl33 & l33[2]), (rl34 & l34[2]), (rl35 & l35[2]), (rl36 & l36[2]), (rl37 & l37[2]), (rl38 & l38[2]), (rl39 & l39[2]), (rl40 & l40[2]), (rl41 & l41[2]), (rl42 & l42[2]), (rl43 & l43[2]), (rl44 & l44[2]), (rl45 & l45[2]), (rl46 & l46[2])};
    assign lb[3] = |{(rl0 & l0[3]), (rl1 & l1[3]), (rl2 & l2[3]), (rl3 & l3[3]), (rl4 & l4[3]), (rl5 & l5[3]), (rl6 & l6[3]), (rl7 & l7[3]), (rl8 & l8[3]), (rl9 & l9[3]), (rl10 & l10[3]), (rl11 & l11[3]), (rl12 & l12[3]), (rl13 & l13[3]), (rl14 & l14[3]), (rl15 & l15[3]), (rl16 & l16[3]), (rl17 & l17[3]), (rl18 & l18[3]), (rl19 & l19[3]), (rl20 & l20[3]), (rl21 & l21[3]), (rl22 & l22[3]), (rl23 & l23[3]), (rl24 & l24[3]), (rl25 & l25[3]), (rl26 & l26[3]), (rl27 & l27[3]), (rl28 & l28[3]), (rl29 & l29[3]), (rl30 & l30[3]), (rl31 & l31[3]), (rl32 & l32[3]), (rl33 & l33[3]), (rl34 & l34[3]), (rl35 & l35[3]), (rl36 & l36[3]), (rl37 & l37[3]), (rl38 & l38[3]), (rl39 & l39[3]), (rl40 & l40[3]), (rl41 & l41[3]), (rl42 & l42[3]), (rl43 & l43[3]), (rl44 & l44[3]), (rl45 & l45[3]), (rl46 & l46[3])};
    assign hb[0] = |{(rh0 & h0[0]), (rh1 & h1[0]), (rh2 & h2[0]), (rh3 & h3[0]), (rh4 & h4[0]), (rh5 & h5[0]), (rh6 & h6[0]), (rh7 & h7[0]), (rh8 & h8[0]), (rh9 & h9[0]), (rh10 & h10[0]), (rh11 & h11[0]), (rh12 & h12[0]), (rh13 & h13[0]), (rh14 & h14[0]), (rh15 & h15[0]), (rh16 & h16[0]), (rh17 & h17[0]), (rh18 & h18[0]), (rh19 & h19[0]), (rh20 & h20[0]), (rh21 & h21[0]), (rh22 & h22[0]), (rh23 & h23[0]), (rh24 & h24[0]), (rh25 & h25[0]), (rh26 & h26[0]), (rh27 & h27[0]), (rh28 & h28[0]), (rh29 & h29[0]), (rh30 & h30[0])};
    assign hb[1] = |{(rh0 & h0[1]), (rh1 & h1[1]), (rh2 & h2[1]), (rh3 & h3[1]), (rh4 & h4[0]), (rh5 & h5[0]), (rh6 & h6[1]), (rh7 & h7[0]), (rh8 & h8[1]), (rh9 & h9[0]), (rh10 & h10[0]), (rh11 & h11[1]), (rh12 & h12[1]), (rh13 & h13[0]), (rh14 & h14[0]), (rh15 & h15[0]), (rh16 & h16[1]), (rh17 & h17[0]), (rh18 & h18[0]), (rh19 & h19[1]), (rh20 & h20[1]), (rh21 & h21[1]), (rh22 & h22[1]), (rh23 & h23[1]), (rh24 & h24[1]), (rh25 & h25[1]), (rh26 & h26[1]), (rh27 & h27[1]), (rh28 & h28[1]), (rh29 & h29[1]), (rh30 & h30[1])};
    assign hb[2] = |{(rh0 & h0[2]), (rh1 & h1[1]), (rh2 & h2[2]), (rh3 & h3[2]), (rh4 & h4[0]), (rh5 & h5[0]), (rh6 & h6[2]), (rh7 & h7[0]), (rh8 & h8[2]), (rh9 & h9[0]), (rh10 & h10[0]), (rh11 & h11[1]), (rh12 & h12[1]), (rh13 & h13[0]), (rh14 & h14[0]), (rh15 & h15[0]), (rh16 & h16[2]), (rh17 & h17[0]), (rh18 & h18[0]), (rh19 & h19[2]), (rh20 & h20[1]), (rh21 & h21[2]), (rh22 & h22[2]), (rh23 & h23[2]), (rh24 & h24[2]), (rh25 & h25[2]), (rh26 & h26[2]), (rh27 & h27[2]), (rh28 & h28[2]), (rh29 & h29[1]), (rh30 & h30[2])};
    assign hb[3] = |{(rh0 & h0[2]), (rh1 & h1[1]), (rh2 & h2[2]), (rh3 & h3[3]), (rh4 & h4[0]), (rh5 & h5[0]), (rh6 & h6[2]), (rh7 & h7[0]), (rh8 & h8[3]), (rh9 & h9[0]), (rh10 & h10[0]), (rh11 & h11[1]), (rh12 & h12[1]), (rh13 & h13[0]), (rh14 & h14[0]), (rh15 & h15[0]), (rh16 & h16[2]), (rh17 & h17[0]), (rh18 & h18[0]), (rh19 & h19[2]), (rh20 & h20[1]), (rh21 & h21[2]), (rh22 & h22[2]), (rh23 & h23[2]), (rh24 & h24[2]), (rh25 & h25[2]), (rh26 & h26[2]), (rh27 & h27[3]), (rh28 & h28[3]), (rh29 & h29[1]), (rh30 & h30[2])};
    wire hv = |{rkh[0], rkh[1], rkh[2], rkh[3], (rkh[4] & |{rkl[0], rkl[1], rkl[2], rkl[3], rkl[5], rkl[6], rkl[7]}), (rkh[5] & |{rkl[0], rkl[1], rkl[2], rkl[3], rkl[4], rkl[6], rkl[7]}), (rkh[6] & |{rkl[5], rkl[6]})};
    assign rq = {hv ? hb : {4{lb[3]}}, lb};
endmodule

module JPEGLENC_SRAM (CK, CS, OE, A, DI, WEB, DO);

input CK, CS, OE;
input [10:0] A;
input [63:0] DI;
input [7:0] WEB;
output [63:0] DO;
SU_1360X64_b8_m1 u_mem (
    .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .A4(A[4]), .A5(A[5]), .A6(A[6]), .A7(A[7]),
    .A8(A[8]), .A9(A[9]), .A10(A[10]), .DI0(DI[0]), .DI1(DI[1]), .DI2(DI[2]), .DI3(DI[3]), .DI4(DI[4]),
    .DI5(DI[5]), .DI6(DI[6]), .DI7(DI[7]), .DI8(DI[8]), .DI9(DI[9]), .DI10(DI[10]), .DI11(DI[11]), .DI12(DI[12]),
    .DI13(DI[13]), .DI14(DI[14]), .DI15(DI[15]), .DI16(DI[16]), .DI17(DI[17]), .DI18(DI[18]), .DI19(DI[19]), .DI20(DI[20]),
    .DI21(DI[21]), .DI22(DI[22]), .DI23(DI[23]), .DI24(DI[24]), .DI25(DI[25]), .DI26(DI[26]), .DI27(DI[27]), .DI28(DI[28]),
    .DI29(DI[29]), .DI30(DI[30]), .DI31(DI[31]), .DI32(DI[32]), .DI33(DI[33]), .DI34(DI[34]), .DI35(DI[35]), .DI36(DI[36]),
    .DI37(DI[37]), .DI38(DI[38]), .DI39(DI[39]), .DI40(DI[40]), .DI41(DI[41]), .DI42(DI[42]), .DI43(DI[43]), .DI44(DI[44]),
    .DI45(DI[45]), .DI46(DI[46]), .DI47(DI[47]), .DI48(DI[48]), .DI49(DI[49]), .DI50(DI[50]), .DI51(DI[51]), .DI52(DI[52]),
    .DI53(DI[53]), .DI54(DI[54]), .DI55(DI[55]), .DI56(DI[56]), .DI57(DI[57]), .DI58(DI[58]), .DI59(DI[59]), .DI60(DI[60]),
    .DI61(DI[61]), .DI62(DI[62]), .DI63(DI[63]), .DO0(DO[0]), .DO1(DO[1]), .DO2(DO[2]), .DO3(DO[3]), .DO4(DO[4]),
    .DO5(DO[5]), .DO6(DO[6]), .DO7(DO[7]), .DO8(DO[8]), .DO9(DO[9]), .DO10(DO[10]), .DO11(DO[11]), .DO12(DO[12]),
    .DO13(DO[13]), .DO14(DO[14]), .DO15(DO[15]), .DO16(DO[16]), .DO17(DO[17]), .DO18(DO[18]), .DO19(DO[19]), .DO20(DO[20]),
    .DO21(DO[21]), .DO22(DO[22]), .DO23(DO[23]), .DO24(DO[24]), .DO25(DO[25]), .DO26(DO[26]), .DO27(DO[27]), .DO28(DO[28]),
    .DO29(DO[29]), .DO30(DO[30]), .DO31(DO[31]), .DO32(DO[32]), .DO33(DO[33]), .DO34(DO[34]), .DO35(DO[35]), .DO36(DO[36]),
    .DO37(DO[37]), .DO38(DO[38]), .DO39(DO[39]), .DO40(DO[40]), .DO41(DO[41]), .DO42(DO[42]), .DO43(DO[43]), .DO44(DO[44]),
    .DO45(DO[45]), .DO46(DO[46]), .DO47(DO[47]), .DO48(DO[48]), .DO49(DO[49]), .DO50(DO[50]), .DO51(DO[51]), .DO52(DO[52]),
    .DO53(DO[53]), .DO54(DO[54]), .DO55(DO[55]), .DO56(DO[56]), .DO57(DO[57]), .DO58(DO[58]), .DO59(DO[59]), .DO60(DO[60]),
    .DO61(DO[61]), .DO62(DO[62]), .DO63(DO[63]), .WEB0(WEB[0]), .WEB1(WEB[1]), .WEB2(WEB[2]), .WEB3(WEB[3]), .WEB4(WEB[4]),
    .WEB5(WEB[5]), .WEB6(WEB[6]), .WEB7(WEB[7]), .CK(CK), .CS(CS), .OE(OE)
);
endmodule
