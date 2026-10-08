// One initialized pointer bit and factored one-hot array write selectors.
// One initialized address-feedback bit; all shot/update equations retained.
// Boolean cached frontier transitions and constant-offset addresses.
// Cache frontier boundaries after native critical-path review.
// Independent state-area experiment: frontier_both.
// Exact qualified-parent binary shadows with three cached comparisons.
// Source-bound candidate: hybrid_color (dae7d with parallel binary head colors for outputs and plans).
// Same storage, write network and compaction sequencer as head_write_mask 0cd1fbfd;
// reads are decoupled from the cascade decision.
`timescale 1ns/10ps
// ZUMA decoupled-read dense zipper (Verilog-2005).
//
// Storage is the dense logical ring col[0..live-1] in an even bank
// ce[m] = col[2m] and an odd bank co[m] = col[2m+1].  A legal ring has no
// same-color run of three, so every cascade level is decided by the two
// junction beads and their outward neighbours.
//
// The beads a cascade can visit form two fixed streams: col[ks], col[ks-1],
// ... to the left of the shot and col[ks+1], col[ks+2], ... to the right
// (cyclic).  Each side keeps its two head beads in registers and a fetch
// pointer that always addresses the two beads behind them.  A decision only
// compares the registered heads; the consumed count (0, 1 or 2) selects the
// new heads from the old ones and the fetched pair, and advances the pointer
// by the same count.  No array read sits inside the level-to-level loop.
//
// Schedule (identical latencies to the selected parent):
//   S_L1   fetches the first pair per side and registers it together with the
//          first-level color comparisons.
//   S_DEC  decides level 1 from those flags.  A no-elimination shot and a
//          provably single-level shot drive their only beat combinationally
//          in this cycle; otherwise the zipper starts.
//   S_ZIP  tests one further level per cycle from the FIFO heads; the stop
//          cycle drives beat 1 combinationally.
//   S_OUTP replays beat 2 from a captured result and later beats from the
//          FIFO, refilled from the level-3 head positions.
// Insertion and compaction (shift-right-by-one / shift-left-by-three with
// re-insertion of over-removed survivors) are the parent's; the write address
// is registered one cycle ahead.
module ZUMA (
    input clk,
    input rst_n,
    input in_valid,
    /* verilator lint_off UNUSEDSIGNAL */
    input [7:0] ring_len,
    /* verilator lint_on UNUSEDSIGNAL */
    input [2:0] in_color,
    input shot_valid,
    input [2:0] shot_color,
    input [7:0] shot_pos,
    output out_valid,
    output [6:0] chain_num,
    output [2:0] elim_color,
    output [8:0] elim_cnt
);
    localparam [2:0] S_IDLE = 3'd0, S_LOAD = 3'd1, S_L1 = 3'd2, S_DEC = 3'd3,
                     S_ZIP = 3'd4, S_OUTP = 3'd5, S_CMP = 3'd6, S_INS = 3'd7;

    reg [2:0] state;
    reg hl0, hl1, hl2; // cached logical frontier boundaries
    reg hr0, hre1, hre2; // cached logical frontier boundaries
    reg dec_q, zip_q;            // state == S_DEC / S_ZIP
    reg iv_q;
    reg [2:0] ic_q;
    reg [2:0] ce [0:127];
    reg [2:0] co [0:127];
    reg [8:0] live;
    reg [2:0] tail;
    reg [2:0] c;
    reg pend;
    // Fetch pointers: left pair (p, p-1), right pair (q, q+1).
    reg [7:0] p, q;
    reg [6:0] re;
    reg [2:0] lo_hi, lo_low;
    reg lo_bit3;
    wire [6:0] lo = {lo_hi, lo_bit3, lo_low};
    reg [7:0] dc_le, dc_lo, dc_ro, dc_re;
    // Seam flags of the pointers: p == 0, p == 1, q == live-1, q == live-2,
    // and (first fetch only) q == live.
    reg pz, p1, qe, qe2, ovr1;
    // Head windows, one-hot colors: head (hdL0/hdR0) and next bead (hdL1/hdR1);
    // wnew marks an empty window.
    reg jq, neqL, neqR; // cached logical comparisons of the four binary shadows
    reg [5:0] fcL, fcR;          // binary colors captured alongside each one-hot pair
    reg wnew;
    reg t1_q;                    // deferred tail update of a single-beat stop
    reg lf_q;                    // first load cycle of a game
    // First-level comparisons and ring-size flags.
    // First-level flags, each already including live >= 2: both junction
    // beads match the shot (A), the left run matches (B), the right run (C).
    reg bA, bB, bC, nq11, le4_q;
    // Junction frontiers, remaining beads, level count.
    reg [8:0] rem;
    reg [6:0] lvl;
    reg head_q;
    reg [2:0] res2c;
    reg res2f;
    reg [7:0] snl, snr;
    // Registered output burst.
    reg ov_q;
    reg rem3_q, lvl1_q, lvl3_q, cmp_q, lb_q, ins_q;
    reg srem_nz, nin_nz;
    reg [6:0] cnq;
    reg b2q;
    reg rep_q;
    // Compaction plan and write address.
    reg [7:0] tp_q;
    reg [8:0] srem;
    reg [1:0] nin, aft2;
    reg tiny_q, tail_up;
    reg [2:0] qa, qb, tail_nx;

    function [7:0] dec_col;
        input [2:0] address;
        integer dc_i;
        begin
            for (dc_i = 0; dc_i < 8; dc_i = dc_i + 1)
                dec_col[dc_i] = (address == dc_i[2:0]);
        end
    endfunction
    function [7:0] rot_dn;
        input [7:0] v;
        rot_dn = {v[0], v[7:1]};
    endfunction
    function [7:0] rot_up;
        input [7:0] v;
        rot_up = {v[6:0], v[7]};
    endfunction
    // Odd word holding col[x] or col[x-1]; even word holding col[x] or col[x+1].
    function [6:0] lo_of;
        input [7:0] x;
        lo_of = x[7:1] - {6'd0, ~x[0]};
    endfunction
    function [6:0] re_of;
        input [7:0] x;
        re_of = x[7:1] + {6'd0, x[0]};
    endfunction
    // ------------------------------------------------------------------
    // Read network: one even and one odd 128:1 read per side
    // ------------------------------------------------------------------
    reg [2:0] rd_le_group [0:15];
    reg [2:0] rd_lo_group [0:15];
    reg [2:0] rd_re_group [0:15];
    reg [2:0] rd_ro_group [0:15];
    integer rg, rw;
    always @(*) begin
        for (rg = 0; rg < 16; rg = rg + 1) begin
            rd_le_group[rg] = 3'd0;
            rd_lo_group[rg] = 3'd0;
            rd_re_group[rg] = 3'd0;
            rd_ro_group[rg] = 3'd0;
            for (rw = 0; rw < 8; rw = rw + 1) begin
                rd_le_group[rg] = rd_le_group[rg] | ({3{dc_le[rw]}} & ce[rg*8+rw]);
                rd_lo_group[rg] = rd_lo_group[rg] | ({3{dc_lo[rw]}} & co[rg*8+rw]);
                rd_re_group[rg] = rd_re_group[rg] | ({3{dc_re[rw]}} & ce[rg*8+rw]);
                rd_ro_group[rg] = rd_ro_group[rg] | ({3{dc_ro[rw]}} & co[rg*8+rw]);
            end
        end
    end
    wire [2:0] rd_le = rd_le_group[p[7:4]];
    wire [2:0] rd_lo = rd_lo_group[lo[6:3]];
    wire [2:0] rd_re = rd_re_group[re[6:3]];
    wire [2:0] rd_ro = rd_ro_group[q[7:4]];

    wire pz_b = pz, p1_b = p1, qe_b = qe, qe2_b = qe2;

    // Fetched pairs.  col[-1] is the registered tail; col[live] and col[live+1]
    // are the fixed head slots.  ovr1 marks a first fetch at q == live.
    wire [2:0] r1w = (live == 9'd1) ? ce[0] : co[0];
    wire [2:0] fL0 = p[0] ? rd_lo : rd_le;
    wire [2:0] fL1 = pz_b ? tail : (p[0] ? rd_le : rd_lo);
    wire [2:0] fR0 = ovr1 ? ce[0] : (q[0] ? rd_ro : rd_re);
    wire [2:0] fR1 = ovr1 ? r1w : (qe_b ? ce[0] : (q[0] ? rd_re : rd_ro));

    // ------------------------------------------------------------------
    // Decisions
    // ------------------------------------------------------------------
    wire [7:0] e1 = live[7:0] - 8'd1;
    // Clamped so a one-bead ring keeps a valid address.
    wire [7:0] e2 = (live <= 9'd1) ? 8'd0 : (live[7:0] - 8'd2);
    wire st_l1 = (state == S_L1);
    wire st_outp = (state == S_OUTP);

    // Level 1 from the S_L1 comparisons.
    wire caseA = bA;
    wire caseB = bB & ~bA;
    wire caseC = bC & ~bA;
    wire elim1 = bA | bB | bC;
    wire fast = le4_q | (bA & nq11);

    // Zipper level from the FIFO heads.
    // Comparisons are cached with the binary head updates.
    wire [2:0] cL = fcL[2:0], cLL = fcL[5:3], cR = fcR[2:0], cRR = fcR[5:3];
    wire jeq = jq;
    wire eL = ~neqL;
    wire eR = ~neqR;
    wire e44 = eL & eR;
    wire ex = rem3_q & jeq & (eL | eR);

    wire beat_dec = dec_q & (~elim1 | fast);
    wire beat_zip = zip_q & ~ex;
    wire beat_el = (dec_q & elim1 & fast) | beat_zip;
    wire cnt4 = rep_q ? e44 : (b2q & res2f);
    wire cnt3 = (rep_q ? ~e44 : (b2q & ~res2f)) | beat_el;
    assign out_valid = ov_q | beat_dec | beat_zip;
    assign chain_num = cnq | ({7{beat_zip}} & lvl) | {6'd0, dec_q & elim1 & fast};
    assign elim_color = (rep_q ? cL : ({3{b2q}} & res2c)) | ({3{beat_el}} & c);
    assign elim_cnt = {6'd0, cnt4, cnt3, cnt3};

    // Consumed beads per side (one-hot 1/2): level 1 by case, later levels by
    // run length; a zipper level is consumed only when it exists.
    wire zgo = zip_q & rem3_q & jeq;
    wire kL2 = (dec_q & caseB) | (zgo & eL) | (rep_q & eL);
    wire kL1 = (dec_q & caseA) | (zgo & ~eL & eR) | (rep_q & ~eL);
    wire kR2 = (dec_q & caseC) | (zgo & eR) | (rep_q & eR);
    wire kR1 = (dec_q & caseA) | (zgo & ~eR & eL) | (rep_q & ~eR);

    // The fetch window is two beads behind the left frontier.
    wire [7:0] hl = wnew ? p : (hl0 ? 8'd0 : (hl1 ? 8'd1 : (p + 8'd2)));
    // The fetch window is two beads ahead of the right frontier.
    wire [7:0] hr = wnew ? (ovr1 ? 8'd0 : q) :
                   (hr0 ? 8'd0 : (hre1 ? e1 : (hre2 ? e2 : (q - 8'd2))));
    // Frontier update (cyclic, seam handled with fixed offsets from live).
    wire [7:0] hlp1 = wnew ? (hl + 8'd1) : (hl0 ? 8'd1 : (hl1 ? 8'd2 : (p + 8'd3)));
    // rem >= 3 after this level, from rem >= 5/6/7 now.
    wire rem3_nj = e44 ? (rem >= 9'd7) : ((eL | eR) ? (rem >= 9'd6) : (rem >= 9'd5));
    // A removed bead at logical 0 means the deleted interval wraps the seam.
    wire head_hit = ((kL1 | kL2) & hl0) | (kL2 & hl1) |
                    ((kR1 | kR2) & hr0) | (kR2 & hre1);
    wire [8:0] rem_m2 = rem - 9'd2, rem_m3 = rem - 9'd3, rem_m4 = rem - 9'd4;
    wire [8:0] rem_nj = e44 ? rem_m4 : ((eL | eR) ? rem_m3 : rem_m2);

    // Single-level close of a case-A shot on five or more beads (hl = ks,
    // hr = ks+1): survivors col[ks-1], col[ks+2], col[ks+3] are FIFO entry L1,
    // R1 and the current right fetch.
    wire wrapf = hl0 | hr0;
    wire [1:0] aft_fast = wrapf ? 2'd2 : (hre1 ? 2'd0 : (hre2 ? 2'd1 : 2'd2));
    wire [1:0] fast_nin = (aft_fast == 2'd0) ? 2'd0 : (hr0 ? 2'd2 : 2'd1);
    wire reach_f = wrapf | hre1;
    // Two to four beads: every survivor is one of the first-level beads.
    wire live3 = (live == 9'd3), live4 = (live == 9'd4);
    wire [2:0] fL0q = cL, fL1q = cLL, fR0q = cR, fR1q = cRR;
    wire [2:0] cLT = caseA ? fL1q : (caseB ? (live4 ? fR1q : fR0q) : fL0q);
    wire [2:0] cRT = live3 ? cLT : (caseA ? fR1q : (caseB ? fR0q : fL1q));
    // New left frontier at logical 0 (hl = ks here; only rings of 3-4 beads).
    wire lzT = caseA ? hl1 : (caseB ? hl2 : hl0);

    // Compaction plan at a later zipper stop (hl/hr are the survivors).
    wire tiny = (rem <= 9'd2);
    wire [8:0] arcL = live - rem;
    wire reach_end = head_q | hr0;
    wire [8:0] shiftS = head_q ? {1'b0, hr} : arcL;
    wire [1:0] aft_min = head_q ? 2'd2 : (hr0 ? 2'd0 : (hre1 ? 2'd1 : 2'd2));
    wire [7:0] ca_n = head_q ? 8'd0 : hlp1;
    wire [2:0] qa_n = tiny ? (hl0 ? cR : cL) : cR;
    wire [2:0] qb_n = tiny ? (hl0 ? cL : cR) : cRR;
    wire [2:0] tail_nx_n = tiny ? ((rem == 9'd2) ? (hl0 ? cR : cL) : cL) : cL;
    wire tail_up_n = tiny ? (rem != 9'd0) : reach_end;

    // ------------------------------------------------------------------
    // Fetch pointers and FIFOs
    // ------------------------------------------------------------------
    wire fetching = st_l1 | dec_q | zip_q | st_outp;
    wire restore = zip_q & ~ex & lvl3_q;
    // Pointer step per side: two when (re)loading an empty window.
    wire aL2 = wnew | kL2, aL1 = ~wnew & kL1;
    wire aR2 = wnew | kR2, aR1 = ~wnew & kR1;

    // Left pair (p, p-1): even word p>>1, odd word lo.  A one-bead step
    // moves only the word of the bead that leaves; the seam jumps use fixed
    // offsets from live.
    wire [6:0] lo_e1 = lo_of(e1), lo_e2 = lo_of(e2);
    wire wrapL = (pz_b & (aL1 | aL2)) | (p1_b & aL2);
    wire endL2 = pz_b & aL2;
    wire [7:0] p_end = endL2 ? e2 : e1;
    wire [6:0] lo_end = endL2 ? lo_e2 : lo_e1;
    wire stepE = aL2 | (aL1 & ~p[0]);
    wire stepO = aL2 | (aL1 & p[0]);
    wire [7:0] p_adv = wrapL ? p_end : (aL2 ? (p - 8'd2) : (aL1 ? (p - 8'd1) : p));
    wire [6:0] lo_adv = wrapL ? lo_end : (stepO ? (lo - 7'd1) : lo);
    wire [7:0] dle_adv = wrapL ? dec_col(p_end[3:1]) : (stepE ? rot_dn(dc_le) : dc_le);
    wire [7:0] dlo_adv = wrapL ? dec_col(lo_end[2:0]) : (stepO ? rot_dn(dc_lo) : dc_lo);
    // Right pair (q, q+1): odd word q>>1, even word re.
    wire wrapR = (qe_b & (aR1 | aR2)) | (qe2_b & aR2) | (ovr1 & aR2);
    wire qwr0 = (qe_b & aR1) | (~qe_b & qe2_b & aR2);
    wire qwr1 = qe_b & aR2;
    wire [7:0] q_wr = qwr0 ? 8'd0 : (qwr1 ? 8'd1 : 8'd2);
    wire stepOR = aR2 | (aR1 & q[0]);
    wire stepER = aR2 | (aR1 & ~q[0]);
    wire [7:0] q_adv = wrapR ? q_wr : (aR2 ? (q + 8'd2) : (aR1 ? (q + 8'd1) : q));
    wire [6:0] re_wr = re_of(q_wr);
    wire [6:0] re_adv = wrapR ? re_wr : (stepER ? (re + 7'd1) : re);
    wire [7:0] dro_adv = wrapR ? dec_col(q_wr[3:1]) : (stepOR ? rot_up(dc_ro) : dc_ro);
    wire [7:0] dre_adv = wrapR ? dec_col(re_wr[2:0]) : (stepER ? rot_up(dc_re) : dc_re);
    // Next seam flags selected from comparisons of the current pointers.
    wire pis2 = (p == 8'd2), pis3 = (p == 8'd3);
    wire qm3 = ({1'b0, q} == live - 9'd3), qm4 = ({1'b0, q} == live - 9'd4);
    wire lv1 = (live == 9'd1), lv2 = (live == 9'd2), lv3 = (live == 9'd3), lv4 = (live == 9'd4);
    wire le2 = (live <= 9'd2);              // e2 == 0 (clamped)
    wire pz_adv = wrapL ? (endL2 ? le2 : lv1) : (aL2 ? pis2 : (aL1 ? p1_b : pz_b));
    wire p1_adv = wrapL ? (endL2 ? lv3 : lv2) : (aL2 ? pis3 : (aL1 ? pis2 : p1_b));
    wire qe_adv = wrapR ? (qwr0 ? lv1 : (qwr1 ? lv2 : lv3)) :
                  (aR2 ? qm3 : (aR1 ? qe2_b : qe_b));
    wire qe2_adv = wrapR ? (qwr0 ? le2 : (qwr1 ? lv3 : lv4)) :
                   (aR2 ? qm4 : (aR1 ? qm3 : qe2_b));

    // Replay restart at the level-3 heads.
    wire [6:0] lo_s = lo_of(snl), re_s = re_of(snr);

    // Shot capture straight from the ports with lookahead increments.
    // Port values are don't-care outside their valid cycles; gating keeps
    // gate-level X off the capture logic.
    wire [7:0] sp = shot_pos & {8{shot_valid}};
    wire [2:0] sc = shot_color & {3{shot_valid}};
    wire [7:0] sp_and = {&sp[6:0], &sp[5:0], &sp[4:0], &sp[3:0], &sp[2:0], &sp[1:0], sp[0], 1'b1};
    wire [7:0] sp_inc = sp ^ sp_and;                       // shot_pos + 1
    wire [6:0] sh = sp[7:1];
    wire [6:0] sh_and = {&sh[5:0], &sh[4:0], &sh[3:0], &sh[2:0], &sh[1:0], sh[0], 1'b1};
    wire [6:0] sh_nor = {~|sh[5:0], ~|sh[4:0], ~|sh[3:0], ~|sh[2:0], ~|sh[1:0], ~sh[0], 1'b1};
    wire [6:0] sh_inc = sh ^ sh_and;
    wire [6:0] sh_dec = sh ^ sh_nor;
    wire [7:0] dle_in = dec_col(sp[3:1]);
    wire shot_take = shot_valid & ((state == S_IDLE) | (state == S_LOAD) |
                                   (state == S_CMP) | (state == S_INS));

    wire [6:0] lo_shot = sp[0] ? sh : sh_dec;
    // Initialize only the feedback bit implicated by the native X controls.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) lo_bit3 <= 1'b0;
        else if (!iv_q) begin
            if (shot_take) lo_bit3 <= lo_shot[3];
            else if (restore) lo_bit3 <= lo_s[3];
            else if (fetching) lo_bit3 <= lo_adv[3];
        end
    end
    always @(posedge clk) begin
        if (!iv_q) begin
            if (shot_take) begin
                p <= sp;
                {lo_hi,lo_low} <= {lo_shot[6:4],lo_shot[2:0]};
                dc_le <= dle_in;
                dc_lo <= sp[0] ? dle_in : rot_dn(dle_in);
                q <= sp_inc;
                re <= sh_inc;
                dc_ro <= sp[0] ? rot_up(dle_in) : dle_in;
                dc_re <= rot_up(dle_in);
                pz <= (sp == 8'd0);
                p1 <= (sp == 8'd1);
                qe <= ({1'b0, sp} == live - 9'd2);     // q = shot_pos+1 == live-1
                qe2 <= ({1'b0, sp} == live - 9'd3);
                ovr1 <= ({1'b0, sp} == live - 9'd1);   // q == live
            end else if (restore) begin
                p <= snl; {lo_hi,lo_low} <= {lo_s[6:4],lo_s[2:0]};
                dc_le <= dec_col(snl[3:1]);
                dc_lo <= dec_col(lo_s[2:0]);
                pz <= (snl == 8'd0); p1 <= (snl == 8'd1);
                q <= snr; re <= re_s;
                dc_ro <= dec_col(snr[3:1]);
                dc_re <= dec_col(re_s[2:0]);
                qe <= ({1'b0, snr} == live - 9'd1);
                qe2 <= ({1'b0, snr} == live - 9'd2);
                ovr1 <= 1'b0;
            end else if (fetching) begin
                p <= p_adv; {lo_hi,lo_low} <= {lo_adv[6:4],lo_adv[2:0]}; dc_le <= dle_adv; dc_lo <= dlo_adv;
                pz <= pz_adv; p1 <= p1_adv;
                q <= q_adv; re <= re_adv; dc_ro <= dro_adv; dc_re <= dre_adv;
                qe <= qe_adv; qe2 <= qe2_adv;
                if (aR2) ovr1 <= 1'b0;
            end
        end
    end

    // Head windows.  Registers that reach the combinational outputs or the
    // pointer logic are reset so gate-level simulation never sees X there.
    wire [5:0] next_fcL = aL2 ? {fL1, fL0} : (aL1 ? {fL0, fcL[5:3]} : fcL);
    wire [5:0] next_fcR = aR2 ? {fR1, fR0} : (aR1 ? {fR0, fcR[5:3]} : fcR);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
             
            fcL <= 6'd0; fcR <= 6'd0;
            jq <= 1'b0; neqL <= 1'b1; neqR <= 1'b1;
             
            wnew <= 1'b0;
        end else if (!iv_q) begin
            if (shot_take) begin
                 
                fcL <= 6'd0; fcR <= 6'd0;
            jq <= 1'b0; neqL <= 1'b1; neqR <= 1'b1;
                 
                wnew <= 1'b1;
            end else if (restore)
                wnew <= 1'b1;
            else if (fetching) begin
                // New heads: keep, drop one (next + fetched), or take the pair.
                fcL <= next_fcL;
                fcR <= next_fcR;
                jq <= (next_fcL[2:0] == next_fcR[2:0]);
                neqL <= ~(next_fcL[2:0] == next_fcL[5:3]);
                neqR <= ~(next_fcR[2:0] == next_fcR[5:3]);
                
                
                
                
                wnew <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bA <= 1'b0;
            bB <= 1'b0;
            bC <= 1'b0;
            nq11 <= 1'b0;
            le4_q <= 1'b0;
        end else if (st_l1) begin
            bA <= (live >= 9'd2) & (fL0 == c) & (fR0 == c);
            bB <= (live >= 9'd2) & (fL0 == c) & (fL1 == c);
            bC <= (live >= 9'd2) & (fR0 == c) & (fR1 == c);
            nq11 <= (fL1 != fR1);
            le4_q <= (live <= 9'd4);
        end
    end

    // ------------------------------------------------------------------
    // Compaction step control (parent logic)
    // ------------------------------------------------------------------
    wire last_beat = lb_q;
    wire cmp_act = cmp_q | last_beat;
    wire sh_step = cmp_act & srem_nz;
    wire in_step = cmp_act & ~srem_nz & nin_nz;
    wire fast_w = dec_q & elim1 & fast;
    wire wr_rb = (last_beat & tiny_q) | (fast_w & le4_q & (live >= 9'd3));
    wire [8:0] srem_x = srem;
    wire [1:0] aft2_x = aft2;
    wire [1:0] over = 2'd3 - srem_x[1:0];
    wire [1:0] nin_after_sh = (srem_x >= 9'd3) ? 2'd0 : ((over < aft2_x) ? over : aft2_x);
    wire last_step = (sh_step & (nin_after_sh == 2'd0) & (srem_x <= 9'd3)) |
                     (in_step & (nin == 2'd1)) |
                     (cmp_act & ~srem_nz & ~nin_nz);
    wire [2:0] ins_col = (nin == 2'd2) ? qb : qa;

    // Write datapath control; the address is registered one cycle ahead.
    wire load_first = iv_q & (state != S_LOAD);
    wire load_more = iv_q & (state == S_LOAD);
    wire do_ins = ins_q;
    wire wr_ins = load_first | load_more | do_ins | in_step;
    wire wr_shf = (sh_step | (fast_w & ~le4_q)) & ~iv_q;
    wire [7:0] tp = tp_q;
    wire [2:0] wcolor = (load_first | load_more) ? ic_q : (do_ins ? c : ins_col);

    always @(posedge clk) begin
        if (in_valid)
            tp_q <= iv_q ? (load_first ? 8'd1 : (live[7:0] + 8'd1)) : 8'd0;
        else if (!iv_q) begin
            if (st_l1) tp_q <= (pz_b | ovr1) ? 8'd0 : p;               // case-A close
            else if (dec_q) begin
                if (!elim1) tp_q <= (live == 9'd0) ? 8'd0 : hlp1;      // insertion
            end else if (zip_q & ~ex) tp_q <= ca_n;
        end
    end

    // Factor the exact write selectors over 4 high and 64 low addresses.
    reg [3:0] hi_gt, hi_eq;
    reg [63:0] lo_ge, lo_gt, lo_eq;
    integer dh, dl;
    always @(*) begin
        for (dh = 0; dh < 4; dh = dh + 1) begin
            hi_gt[dh] = (dh > {30'd0, tp[7:6]});
            hi_eq[dh] = (dh == {30'd0, tp[7:6]});
        end
        for (dl = 0; dl < 64; dl = dl + 1) begin
            lo_ge[dl] = (dl >= {26'd0, tp[5:0]});
            lo_gt[dl] = (dl > {26'd0, tp[5:0]});
            lo_eq[dl] = (dl == {26'd0, tp[5:0]});
        end
    end
    wire wr_any = wr_ins | wr_shf;
    wire shf_only = wr_shf & ~wr_ins;
    wire ins_up = wr_ins & ~lf_q;
    wire [3:0] g_ins = {4{wr_ins}} & hi_eq;
    wire [3:0] g_upg = {4{ins_up}} & hi_gt, g_upe = {4{ins_up}} & hi_eq;
    wire [3:0] g_dng = {4{shf_only}} & hi_gt, g_dne = {4{shf_only}} & hi_eq;
    wire [3:0] g_wrg = {4{wr_any}} & hi_gt, g_wre = {4{wr_any}} & hi_eq;
    reg [255:0] s_up, s_dn, s_hold, s_ins;
    integer hh, ll;
    always @(*) begin
        for (hh = 0; hh < 4; hh = hh + 1)
            for (ll = 0; ll < 64; ll = ll + 1) begin
                s_ins[hh*64 + ll] = g_ins[hh] & lo_eq[ll];
                s_up[hh*64 + ll] = g_upg[hh] | (g_upe[hh] & lo_gt[ll]);
                s_dn[hh*64 + ll] = g_dng[hh] | (g_dne[hh] & lo_ge[ll]);
                s_hold[hh*64 + ll] = ~(g_wrg[hh] | (g_wre[hh] & lo_ge[ll]));
            end
    end

    // ------------------------------------------------------------------
    // Bead array (no reset; the first load of each game fills every slot)
    // ------------------------------------------------------------------
    wire [2:0] rb_e = dec_q ? (lzT ? cLT : cRT) : qb;
    wire [2:0] rb_o = dec_q ? (lzT ? cRT : cLT) : qa;
    // Each slot's next value is one AND-OR of four one-hot terms: hold, the
    // inserted color (the insertion slot), the lower neighbour (insertion
    // shifts the rest up by one) and the bead three above (compaction step).
    genvar wi;
    generate
        for (wi = 0; wi < 128; wi = wi + 1) begin: mem_word
            wire ke = s_hold[2*wi], ko = s_hold[2*wi+1];
            wire se = s_ins[2*wi], so = s_ins[2*wi+1];
            wire he = s_up[2*wi], ho = s_up[2*wi+1];
            wire de = s_dn[2*wi], doo = s_dn[2*wi+1];
            wire [2:0] pe = (wi == 0) ? 3'd0 : co[(wi == 0) ? 0 : wi-1];
            wire [2:0] po = ce[wi];
            wire [2:0] ne = (wi >= 127) ? 3'd0 : co[(wi >= 127) ? 0 : wi+1];
            wire [2:0] no_o = (wi >= 126) ? 3'd0 : ce[(wi >= 126) ? 0 : wi+2];
            wire [2:0] nxe = ({3{ke}} & ce[wi]) | ({3{se}} & wcolor) | ({3{he}} & pe) | ({3{de}} & ne);
            wire [2:0] nxo = ({3{ko}} & co[wi]) | ({3{so}} & wcolor) | ({3{ho}} & po) | ({3{doo}} & no_o);
            always @(posedge clk) begin
                ce[wi] <= ((wi == 0) && wr_rb) ? rb_e : nxe;
                co[wi] <= ((wi == 0) && wr_rb) ? rb_o : nxo;
            end
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) iv_q <= 1'b0;
        else iv_q <= in_valid;
    end
    always @(posedge clk) ic_q <= in_color & {3{in_valid}};

    // ------------------------------------------------------------------
    // Control
    // ------------------------------------------------------------------
    reg [2:0] state_n;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lf_q <= 1'b0;
            dec_q <= 1'b0;
            zip_q <= 1'b0;
            cmp_q <= 1'b0;
            ins_q <= 1'b0;
            lb_q <= 1'b0;
        end else begin
            lf_q <= in_valid & ~iv_q;
            dec_q <= ~iv_q & st_l1;
            zip_q <= ~iv_q & ((dec_q & elim1 & ~fast) | (zip_q & ex));
            cmp_q <= (state_n == S_CMP);
            ins_q <= ~iv_q & dec_q & ~elim1;
            // The next cycle is the last replayed beat.
            lb_q <= ~iv_q & (lvl == 7'd2) & ((zip_q & ~ex & ~lvl1_q) | (st_outp & ~lb_q));
        end
    end

    always @(*) begin
        state_n = state;
        if (iv_q) state_n = S_LOAD;
        else case (state)
            S_LOAD, S_IDLE, S_INS: state_n = shot_valid ? S_L1 : S_IDLE;
            S_L1: state_n = S_DEC;
            S_DEC: state_n = !elim1 ? S_INS :
                             (fast ? ((le4_q | (fast_nin == 2'd0)) ? S_IDLE : S_CMP) : S_ZIP);
            S_ZIP: state_n = ex ? S_ZIP : (lvl1_q ? S_CMP : S_OUTP);
            S_OUTP: state_n = last_beat ? (last_step ? S_IDLE : S_CMP) : S_OUTP;
            S_CMP: state_n = last_step ? ((shot_valid | pend) ? S_L1 : S_IDLE) : S_CMP;
            default: state_n = S_IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            ov_q <= 1'b0;
            cnq <= 7'd0;
            b2q <= 1'b0;
            rep_q <= 1'b0;
            c <= 3'd0;
            res2c <= 3'd0;
            res2f <= 1'b0;
            snl <= 8'd0;
            snr <= 8'd0;
            rem <= 9'd0;
            head_q <= 1'b0;
            aft2 <= 2'd0;
            qa <= 3'd0;
            qb <= 3'd0;
            tail_nx <= 3'd0;
            live <= 9'd0;
            pend <= 1'b0;
            lvl <= 7'd0;
            lvl1_q <= 1'b0;
            lvl3_q <= 1'b0;
            rem3_q <= 1'b0;
            srem <= 9'd0;
            srem_nz <= 1'b0;
            nin <= 2'd0;
            nin_nz <= 1'b0;
            tiny_q <= 1'b0;
            tail_up <= 1'b0;
            t1_q <= 1'b0;
        end else begin
            state <= state_n;
            if (t1_q) begin
                tail <= tail_nx;
                t1_q <= 1'b0;
            end
            // Loading has absolute priority: a new game discards everything.
            if (iv_q) begin
                live <= load_first ? 9'd1 : (live + 9'd1);
                tail <= ic_q;
                pend <= 1'b0;
                srem <= 9'd0;
                srem_nz <= 1'b0;
                nin <= 2'd0;
                nin_nz <= 1'b0;
                ov_q <= 1'b0;
                cnq <= 7'd0;
                b2q <= 1'b0;
                rep_q <= 1'b0;
            end else begin
                if (zip_q) begin
                    // Speculative survivor capture during counting only.
                    qa <= qa_n;
                    qb <= qb_n;
                    tail_nx <= tail_nx_n;
                    if (lvl == 7'd2) begin
                        snl <= hl;
                        snr <= hr;
                    end
                end
                case (state)
                    S_LOAD, S_IDLE, S_INS: if (shot_valid) c <= sc;
                    S_DEC: begin
                        if (!elim1) begin
                            // Insert in the next cycle; the live/tail view is final now.
                            live <= live + 9'd1;
                            if ((live == 9'd0) | hr0) tail <= c;
                        end else if (fast) begin
                            live <= live - 9'd2;
                            srem <= 9'd0;
                            srem_nz <= 1'b0;
                            if (le4_q) begin
                                nin <= 2'd0;
                                nin_nz <= 1'b0;
                                if (live >= 9'd3) tail <= live4 ? (lzT ? cRT : cLT) : cLT;
                            end else begin
                                // The first shift happens on this edge (wr_shf).
                                nin <= fast_nin;
                                nin_nz <= (fast_nin != 2'd0);
                                aft2 <= aft_fast;
                                qa <= fR1q;
                                qb <= fR0;
                                if (reach_f) tail <= fL1q;
                            end
                        end else begin
                            lvl <= 7'd1;
                            lvl1_q <= 1'b1;
                            lvl3_q <= 1'b0;
                            rem <= live - 9'd2;
                            rem3_q <= ~le4_q;
                            head_q <= head_hit;
                        end
                    end
                    S_ZIP: begin
                        if (ex) begin
                            lvl <= lvl + 7'd1;
                            lvl1_q <= 1'b0;
                            lvl3_q <= (lvl >= 7'd2);
                            rem <= rem_nj;
                            rem3_q <= rem3_nj;
                            if (head_hit) head_q <= 1'b1;
                            if (lvl == 7'd1) begin res2c <= cL; res2f <= e44; end
                        end else begin
                            tiny_q <= tiny & (rem != 9'd0);
                            srem <= tiny ? 9'd0 : shiftS;
                            srem_nz <= ~tiny & (shiftS != 9'd0);
                            nin <= 2'd0;
                            nin_nz <= 1'b0;
                            aft2 <= aft_min;
                            tail_up <= tail_up_n;
                        end
                        if (!ex & lvl1_q) begin
                            // Single beat: compaction starts in the next cycle;
                            // the tail (captured in tail_nx now) follows then.
                            live <= rem;
                            t1_q <= tail_up_n;
                        end else if (!ex) begin
                            ov_q <= 1'b1;
                            cnq <= lvl;
                            b2q <= 1'b1;
                            lvl <= lvl - 7'd1;
                            lvl1_q <= (lvl == 7'd2);
                        end
                    end
                    S_OUTP: begin
                        if (!last_beat) begin
                            lvl <= lvl - 7'd1;
                            lvl1_q <= (lvl == 7'd2);
                            b2q <= 1'b0;
                            rep_q <= 1'b1;
                        end else begin
                            ov_q <= 1'b0;
                            cnq <= 7'd0;
                            b2q <= 1'b0;
                            rep_q <= 1'b0;
                            live <= rem;
                            if (tail_up) tail <= tail_nx;
                        end
                    end
                    S_CMP: begin
                        if (shot_valid) c <= sc;
                        if (last_step) pend <= 1'b0;
                        else if (shot_valid) pend <= 1'b1;
                    end
                    default: begin end
                endcase
                // Compaction step bookkeeping (also fires in the last beat cycle).
                if (sh_step) begin
                    srem <= (srem_x >= 9'd3) ? (srem_x - 9'd3) : 9'd0;
                    srem_nz <= (srem_x > 9'd3);
                    nin <= nin_after_sh;
                    nin_nz <= (nin_after_sh != 2'd0);
                end else if (in_step) begin
                    nin <= nin - 2'd1;
                    nin_nz <= (nin == 2'd2);
                end
            end
        end
    end

    // Keep live arithmetic off current-cycle boundary decisions.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hr0 <= 1'b1; hre1 <= 1'b0; hre2 <= 1'b1;
            hl0 <= 1'b1; hl1 <= 1'b0; hl2 <= 1'b0;
        end else if (!iv_q) begin
            if (st_l1) begin
                hr0 <= (q == 8'd0) | ovr1;
                hre1 <= ovr1 ? lv1 : qe_b;
                hre2 <= ovr1 ? le2 : qe2_b;
                hl0 <= pz_b; hl1 <= p1_b; hl2 <= pis2;
            end else if ((dec_q & elim1 & ~fast) | (zip_q & ex)) begin
                hr0 <= kR2 ? hre2 : (kR1 ? hre1 : hr0);
                hre1 <= kR2 ? qe_b : (kR1 ? hre2 : hre1);
                hre2 <= kR2 ? qe2_b : (kR1 ? qe_b : hre2);
                hl0 <= kL2 ? hl2 : (kL1 ? hl1 : hl0);
                hl1 <= kL2 ? p1_b : (kL1 ? hl2 : hl1);
                hl2 <= kL2 ? pis2 : (kL1 ? p1_b : hl2);
            end
        end
    end
endmodule
