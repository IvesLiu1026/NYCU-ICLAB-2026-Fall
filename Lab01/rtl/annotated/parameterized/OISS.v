// OISS - annotated parameterized release
// Method: bounded-wait threshold DP with shared prefix arithmetic.
// Selected parameterized implementation: shared prefix arithmetic and stable compaction.
// The detailed English comments in this file were written by AI.
// Executable RTL is copied unchanged from the measured reference below.
// Removing full-line comments restores the reference byte for byte.
// Compile only one OISS source at a time.
//
// Reading map: decode -> hazards -> groups/ranks -> compaction ->
// latency prefixes -> two-chain threshold DP / single-chain offsets ->
// winning witness -> original instruction identifiers.
// Every block is combinational. A DP state is a set of wires, not a
// register or a clock cycle. Ex_cycle counts scheduled-program cycles;
// the physical evaluation period is a separate synthesis constraint.
// Reference source: rtl/parameterized/OISS.v
// Reference SHA256: 49021f4eb3a9d1b0989b81b97641e84b918c85dfe3ac0916442443db7b3afb57
//
//
// INTERFACE AND ASSUMPTIONS
// Instruction i occupies bits 12*i +: 12, packed as opcode/rs/rt/rd.
// Latency field k occupies bits 6*k +: 6 and belongs to opcode k.
// Output slot i contains the original instruction ID, not its chain rank.
// Issue starts at zero with one issue per cycle; hazard predecessors must
// finish before successors issue. Legal graphs are empty, one ordered chain
// with independent work, or two disjoint ordered chains covering all entries.
// This readable source is independently tuned: it is not a textual folding
// of every frontend or tie choice in the best unrolled implementation.
//
module OISS(
    input [95:0] Inst_seq_I,
    input [47:0] Inst_latency_I,
    output [23:0] Inst_order_O,
    output [8:0] Ex_cycle
);
//
// SMALL COMBINATIONAL HELPERS
// population counts up to eight members. population3 is used where the count
// is at most seven, while population2 is a narrower helper. Function loops
// elaborate into logic; they do not execute over multiple clock cycles.
//
    function [3:0] population;
        input [7:0] bits;
        integer index;
        begin
            population = 4'd0;
            for (index = 0; index < 8; index = index + 1)
                population = population + {3'd0, bits[index]};
        end
    endfunction

    function [2:0] population3;
        input [7:0] bits;
        integer index;
        begin
            population3 = 3'd0;
            for (index = 0; index < 8; index = index + 1)
                population3 = population3 + {2'd0, bits[index]};
        end
    endfunction

    function [1:0] population2;
        input [7:0] bits;
        integer index;
        begin
            population2 = 2'd0;
            for (index = 0; index < 8; index = index + 1)
                population2 = population2 + {1'b0, bits[index]};
        end
    endfunction

//
// ONE-HOT POPULATION OF THREE OBSERVED MASK BITS
// Bit k is true exactly when k inputs are true. The output decoder uses
// this one-hot count to select a chain ID directly, avoiding an extra
// binary-count-to-mux decode between the winner mask and the output.
//
    function [3:0] population_hot;
        input [2:0] bits;
        begin
            population_hot[0] = !(|bits);
            population_hot[1] = (bits[0] && !bits[1] && !bits[2]) ||
                (!bits[0] && bits[1] && !bits[2]) || (!bits[0] && !bits[1] && bits[2]);
            population_hot[2] = (!bits[0] && bits[1] && bits[2]) ||
                (bits[0] && !bits[1] && bits[2]) || (bits[0] && bits[1] && !bits[2]);
            population_hot[3] = &bits;
        end
    endfunction

//
// SMALL-THRESHOLD SIGNED COMPARISON
// difference is a 10-bit two's-complement subtraction of unsigned prefixes.
// The caller supplies a small compile-time integer threshold (-6..7).
// Inspect sign/high bits before the low three-bit comparison. For a negative
// threshold, a nonnegative difference always passes; a negative difference
// close enough to zero has all high magnitude bits set in two's complement.
//
    function at_least;
        input [9:0] difference;
        input integer threshold;
        begin
            if (threshold == 0)
                at_least = !difference[9];
            else if (threshold > 0)
                at_least = !difference[9] &&
                    ((|difference[8:3]) || difference[2:0] >= threshold[2:0]);
            else
                at_least = !difference[9] ||
                    ((&difference[8:3]) && difference[2:0] >= threshold[2:0]);
        end
    endfunction

//
// FINAL SCORE PLUS WITNESS
// Bits 14:8 encode C<=base+t for t=0..6; bits 7:0 hold an attaining mask.
// OR of monotone feasibility vectors represents the minimum cost. Choose
// the right witness only if it contributes a newly feasible threshold;
// left wins ties. This helper controls final selection, not DP-site ties.
//
    function [14:0] choose_schedule;
        input [14:0] left;
        input [14:0] right;
        begin
            choose_schedule[14:8] = left[14:8] | right[14:8];
            choose_schedule[7:0] = (|(right[14:8] & ~left[14:8]))
                ? right[7:0] : left[7:0];
        end
    endfunction

//
// SIGNAL MAP AND DOMAIN-SPECIALIZED WIDTHS
// dependency/connected describe the original graph; member_a and group_rank
// name compact positions. a/b_latency and a/b_identifier retain both the
// timing data and its original ID. a/b_prefix remove common intrinsic work.
// Seven final thresholds and eight mask bits are packed into 15-bit finalists.
// Legal ranges justify narrowed opcode fields and the constant JUMP latency.
//
    wire [18:0] unused_latency = {Inst_latency_I[47:42], Inst_latency_I[41:39], Inst_latency_I[35:34], Inst_latency_I[29:28], Inst_latency_I[11:9], Inst_latency_I[5:3]};
    wire [5:0] opcode_latency [0:7];
    wire [2:0] opcode [0:7], source_s [0:7], source_t [0:7], destination [0:7];
    wire [2:0] opcode_priority [0:7], priority_key [0:7], group_rank [0:7];
    wire [5:0] latency [0:7], a_latency [0:7], b_latency [0:7];
    wire [2:0] a_identifier [0:7], b_identifier [0:7];
    wire [7:0] writes, reads_pair, reads_store, connected, chain_turn;
    wire [7:0] first_group, member_a, dependency [0:7];
    wire [3:0] group_size, count_a;
    wire other_chain, swap_groups;
    wire priority_md, priority_ls, priority_ab, priority_ac, priority_bc;
    wire [1:0] low_priority [0:2];
    wire [8:0] a_prefix [0:4], b_prefix [0:6];
    wire [9:0] total_difference;
    wire total_positive;
    wire [8:0] dual_base, dual_cost, single_cost;
    wire [7:0] dual_mask, single_mask, best_mask;
    wire [14:0] finalist [0:17], selected_schedule;
    wire [6:0] best_threshold;
    wire [2:0] dual_extra;
    wire [7:0] chain_active;
    wire [6:0] large_latency;
    wire [3:0] low_pair [0:2];
    wire [4:0] low_tail, low_quad;
    wire [5:0] low_prefix [0:7];
    wire [2:0] chain_excess [0:7], free_start [0:5];
    wire [6:0] latency_pair [2:3];
    wire [7:0] latency_quad;
    wire [8:0] chain_total, chain_completion;
    wire [6:0] deficit [0:5];
    wire [5:0] deficit_negative, deficit_small, independent, offset_bad;
    wire [2:0] single_offset, single_count;
    wire [7:0] chain_position [0:7];
    wire [2:0] tail_a_identifier [0:3], tail_b_identifier [0:3];
    wire [2:0] last_a, last_b;
    genvar i, j, g, d, e, t, k, q;

//
// LEGAL OPCODE LATENCIES
// ADD/SUB 1..5, MUL 20..40, DIV 30..50, LOAD/STORE 6..10,
// BRANCH 2..4, JUMP 1. Ignored high input bits are not meaningful for legal
// inputs. These expressions must not be reused for unrestricted latencies.
//
    assign opcode_latency[0] = {3'd0, Inst_latency_I[0 +: 3]};
    assign opcode_latency[1] = {3'd0, Inst_latency_I[6 +: 3]};
    assign opcode_latency[2] = Inst_latency_I[12 +: 6];
    assign opcode_latency[3] = Inst_latency_I[18 +: 6];
    assign opcode_latency[4] = {2'd0, Inst_latency_I[24 +: 4]};
    assign opcode_latency[5] = {2'd0, Inst_latency_I[30 +: 4]};
    assign opcode_latency[6] = {3'd0, Inst_latency_I[36 +: 3]};
    assign opcode_latency[7] = 6'd1;

//
// SHARED PRIORITY RANKS
// Disjoint legal ranges fix most latency ordering; compare only MUL/DIV,
// LOAD/STORE and the ADD/SUB/BRANCH cluster. Larger keys issue first among
// independent work. Equal-latency opcodes can have a deterministic key order
// without changing cost. The selected source puts later IDs first when
// independent priority keys themselves are equal.
//
    assign priority_md = Inst_latency_I[12 +: 6] > Inst_latency_I[18 +: 6];
    assign priority_ls = Inst_latency_I[24 +: 4] > Inst_latency_I[30 +: 4];
    assign priority_ab = Inst_latency_I[0 +: 3] > Inst_latency_I[6 +: 3];
    assign priority_ac = Inst_latency_I[0 +: 3] > Inst_latency_I[36 +: 3];
    assign priority_bc = Inst_latency_I[6 +: 3] > Inst_latency_I[36 +: 3];
    assign low_priority[0] = 2'd1 + {1'b0, priority_ab} + {1'b0, priority_ac};
    assign low_priority[1] = 2'd1 + {1'b0, !priority_ab} + {1'b0, priority_bc};
    assign low_priority[2] = 2'd1 + {1'b0, !priority_ac} + {1'b0, !priority_bc};
    assign opcode_priority[0] = {1'b0, low_priority[0]};
    assign opcode_priority[1] = {1'b0, low_priority[1]};
    assign opcode_priority[2] = {2'b11, priority_md};
    assign opcode_priority[3] = {2'b11, !priority_md};
    assign opcode_priority[4] = {2'b10, priority_ls};
    assign opcode_priority[5] = {2'b10, !priority_ls};
    assign opcode_priority[6] = {1'b0, low_priority[2]};
    assign opcode_priority[7] = 3'd0;

    generate
//
// DECODE, HAZARDS AND WITHIN-GROUP RANK
// Writes: arithmetic or LOAD to rd. Pair reads: arithmetic or BRANCH rs/rt.
// STORE reads rd. Register 0 is ordinary. Only j<i can be a predecessor.
// incident combines both directions so any hazard marks a chain member.
//
        for (i = 0; i < 8; i = i + 1) begin : decode
            wire [5:0] latency_term [0:7];
            wire [2:0] priority_term [0:7];
            wire [7:0] incident, preceding;
            assign {opcode[i], source_s[i], source_t[i], destination[i]} =
                Inst_seq_I[12*i +: 12];
            assign writes[i] = opcode[i] <= 3'd4;
            assign reads_pair[i] = !opcode[i][2] || opcode[i] == 3'd6;
            assign reads_store[i] = opcode[i] == 3'd5;
            for (j = 0; j < 8; j = j + 1) begin : inputs
                assign latency_term[j] = {6{opcode[i] == j}} & opcode_latency[j];
                assign priority_term[j] = {3{opcode[i] == j}} & opcode_priority[j];
                if (j < i) begin : predecessor
//
// RAW, WAR AND WAW
// The first term covers an earlier write read by this instruction, the
// second an earlier read overwritten here. Equal destination fields cover
// two writes and either STORE-read/write ordering. This is the course
// register-access contract; LOAD/STORE are not modeled as a memory system.
//
                    assign dependency[i][j] =
                        (writes[j] && reads_pair[i] &&
                         (destination[j] == source_s[i] || destination[j] == source_t[i])) ||
                        (writes[i] && reads_pair[j] &&
                         (destination[i] == source_s[j] || destination[i] == source_t[j])) ||
                        ((destination[i] == destination[j]) &&
                         ((writes[i] && writes[j]) || (writes[j] && reads_store[i]) ||
                          (writes[i] && reads_store[j])));
                end else begin : not_predecessor
                    assign dependency[i][j] = 1'b0;
                end
                assign incident[j] = (j < i) ? dependency[i][j] : dependency[j][i];
                if (i == j) begin : same_instruction
                    assign preceding[j] = 1'b0;
                end else begin : another_instruction
//
// RANK POLICY FOR THIS SOURCE
// Chain entries count only original earlier members. In the independent
// group, count strictly longer earlier keys and longer-or-equal later keys.
// Thus equal independent keys put later IDs first.
// The unrolled release instead prepares ranks before normalized membership
// selection and keeps earlier-first equal keys.
//
                    assign preceding[j] = (member_a[j] == member_a[i]) &&
                        ((member_a[i] || other_chain) ? (j < i) :
                         ((j < i) ? priority_key[j] > priority_key[i] :
                                    priority_key[j] >= priority_key[i]));
                end
            end
            assign latency[i] = latency_term[0] | latency_term[1] | latency_term[2] |
                latency_term[3] | latency_term[4] | latency_term[5] | latency_term[6] | latency_term[7];
            assign priority_key[i] = priority_term[0] | priority_term[1] | priority_term[2] |
                priority_term[3] | priority_term[4] | priority_term[5] | priority_term[6] | priority_term[7];
            assign connected[i] = |incident;
            assign group_rank[i] = population3(preceding);
            if (i == 0) begin : first_instruction
                assign chain_turn[i] = 1'b0;
                assign first_group[i] = connected[i];
            end else begin : next_instruction
//
// CHAIN PARITY
// Under the guaranteed graph shape, adjacent connected instructions lacking
// an edge mark a switch between the two chains. Prefix XOR recovers the
// group label. Isolated instructions are excluded from first_group.
//
                assign chain_turn[i] = connected[i] && connected[i-1] && !dependency[i][i-1];
                assign first_group[i] = connected[i] && !(^chain_turn[i:1]);
            end
        end
//
// RANK-INDEXED B COMPACTION
// g is fixed to the B side. Mask and OR the entry whose rank matches each
// output slot, carrying latency and original ID together. A uses the shift
// network below; B retains this network because independent work is sorted
// by priority rather than by original program position.
//
        for (g = 1; g < 2; g = g + 1) begin : compact_group
            for (i = 0; i < 8; i = i + 1) begin : slot
                wire [5:0] latency_term [0:7];
                wire [2:0] identifier_term [0:7];
                wire [5:0] selected_latency;
                wire [2:0] selected_identifier;
                for (j = 0; j < 8; j = j + 1) begin : input_slot
                    wire selected;
                    assign selected = (member_a[j] == (g == 0)) && group_rank[j] == i;
                    assign latency_term[j] = {6{selected}} & latency[j];
                    assign identifier_term[j] = {3{selected}} & j;
                end
                assign selected_latency = latency_term[0] | latency_term[1] | latency_term[2] |
                    latency_term[3] | latency_term[4] | latency_term[5] | latency_term[6] | latency_term[7];
                assign selected_identifier = identifier_term[0] | identifier_term[1] | identifier_term[2] |
                    identifier_term[3] | identifier_term[4] | identifier_term[5] | identifier_term[6] | identifier_term[7];
                assign b_latency[i] = selected_latency;
                assign b_identifier[i] = selected_identifier;
            end
        end
    endgenerate
    generate
//
// ORDER-PRESERVING A COMPACTION
// Each member carries the number of nonmembers before it as slot_amount.
// Moving it left by that amount produces its packed rank. Three stages
// conditionally shift by 1,2,4 positions using the corresponding amount bit.
// Members preserve relative order and cannot collide. k=0 loads entries;
// k=1..3 are combinational routing stages, not pipeline stages.
//
        for (k = 0; k <= 3; k = k + 1) begin : compress_a
            for (q = 0; q < 8; q = q + 1) begin : slot
                wire [5:0] slot_latency;
                wire [2:0] slot_identifier, slot_amount;
                wire slot_valid;
                if (k == 0) begin : source
                    assign slot_valid = member_a[q];
                    assign slot_latency = latency[q];
                    assign slot_identifier = q;
                    assign slot_amount = population3(~member_a & ((8'd1 << q) - 8'd1));
                end else if (q + (1 << (k-1)) < 8) begin : stage
                    wire take;
                    assign take = compress_a[k-1].slot[q + (1 << (k-1))].slot_valid &&
                        compress_a[k-1].slot[q + (1 << (k-1))].slot_amount[k-1];
                    assign slot_valid = take ||
                        (compress_a[k-1].slot[q].slot_valid && !compress_a[k-1].slot[q].slot_amount[k-1]);
                    assign slot_latency = take ? compress_a[k-1].slot[q + (1 << (k-1))].slot_latency
                                               : compress_a[k-1].slot[q].slot_latency;
                    assign slot_identifier = take ? compress_a[k-1].slot[q + (1 << (k-1))].slot_identifier
                                                  : compress_a[k-1].slot[q].slot_identifier;
                    assign slot_amount = take ? compress_a[k-1].slot[q + (1 << (k-1))].slot_amount
                                              : compress_a[k-1].slot[q].slot_amount;
                end else begin : boundary
                    assign slot_valid = compress_a[k-1].slot[q].slot_valid &&
                        !compress_a[k-1].slot[q].slot_amount[k-1];
                    assign slot_latency = compress_a[k-1].slot[q].slot_latency;
                    assign slot_identifier = compress_a[k-1].slot[q].slot_identifier;
                    assign slot_amount = compress_a[k-1].slot[q].slot_amount;
                end
            end
        end
//
// ZERO PAD EMPTY SLOTS
// Invalid shifted entries must contribute zero latency and zero ID. The
// fixed prefix arrays can then include padded entries without changing a
// shorter chain's total. unused_shift names amount bits no longer consumed.
//
        for (i = 0; i < 8; i = i + 1) begin : chain_a
            wire [5:0] unused_shift;
            assign a_latency[i] = {6{compress_a[3].slot[i].slot_valid}} & compress_a[3].slot[i].slot_latency;
            assign a_identifier[i] = {3{compress_a[3].slot[i].slot_valid}} & compress_a[3].slot[i].slot_identifier;
            assign unused_shift = {compress_a[1].slot[i].slot_amount[0],
                compress_a[2].slot[i].slot_amount[1:0], compress_a[3].slot[i].slot_amount};
        end
    endgenerate
//
// NORMALIZE CHAIN SIZE
// When there are two real chains, make A the smaller one (2..4 entries).
// With only one chain, A can have up to eight entries and B is independent.
// With no hazards, A is empty and B contains all eight sorted instructions.
//
    assign group_size = population(first_group);
    assign other_chain = |chain_turn;
    assign swap_groups = other_chain && group_size > 4'd4;
    assign member_a = first_group ^ {8{swap_groups}};
    assign count_a = swap_groups ? 4'd8 - group_size : group_size;

//
// INTRINSIC PREFIX SUMS AND SHARED ARITHMETIC
// a_prefix[i] sums the first i A latencies; b_prefix[j] is analogous.
// Nine bits are sufficient for the legal totals. Zero-padded slots let
// a_prefix[4]/b_prefix[6] serve as the two-chain totals after normalization.
// The single-chain engine reuses a_prefix[4] and adds slots 4..7 separately.
//
    wire [8:0] ud_pa_0;
    wire [8:0] ud_pa_1;
    wire [8:0] ud_pa_2;
    wire [8:0] ud_pa_3;
    wire [8:0] ud_pa_4;
    assign a_prefix[0] = ud_pa_0;
    assign a_prefix[1] = ud_pa_1;
    assign a_prefix[2] = ud_pa_2;
    assign a_prefix[3] = ud_pa_3;
    assign a_prefix[4] = ud_pa_4;
    assign ud_pa_0 = 9'd0;
    assign ud_pa_1 = {3'd0, a_latency[0]};
//
// TWO-BIT CARRY GROUPS
// p=left XOR right, g=left AND right; each sum bit is p XOR its incoming
// carry. Expand carry within two-bit groups and feed group boundaries
// forward. Prefix pair sums are shared. The source keeps these explicit
// equations to express the carry grouping directly.
//
    wire [8:0] prefix_a_pair_2_left = {3'd0, a_latency[0]};
    wire [8:0] prefix_a_pair_2_right = {3'd0, a_latency[1]};
    wire [8:0] prefix_a_pair_2_p = prefix_a_pair_2_left ^ prefix_a_pair_2_right;
    wire [7:0] prefix_a_pair_2_g = prefix_a_pair_2_left[7:0] & prefix_a_pair_2_right[7:0];
    wire prefix_a_pair_2_c0 = 1'b0;
    wire prefix_a_pair_2_c1 = (prefix_a_pair_2_g[0]) || (prefix_a_pair_2_c0 && prefix_a_pair_2_p[0]);
    wire prefix_a_pair_2_c2 = (prefix_a_pair_2_g[0] && prefix_a_pair_2_p[1]) || (prefix_a_pair_2_g[1]) || (prefix_a_pair_2_c0 && prefix_a_pair_2_p[0] && prefix_a_pair_2_p[1]);
    wire prefix_a_pair_2_c3 = (prefix_a_pair_2_g[2]) || (prefix_a_pair_2_c2 && prefix_a_pair_2_p[2]);
    wire prefix_a_pair_2_c4 = (prefix_a_pair_2_g[2] && prefix_a_pair_2_p[3]) || (prefix_a_pair_2_g[3]) || (prefix_a_pair_2_c2 && prefix_a_pair_2_p[2] && prefix_a_pair_2_p[3]);
    wire prefix_a_pair_2_c5 = (prefix_a_pair_2_g[4]) || (prefix_a_pair_2_c4 && prefix_a_pair_2_p[4]);
    wire prefix_a_pair_2_c6 = (prefix_a_pair_2_g[4] && prefix_a_pair_2_p[5]) || (prefix_a_pair_2_g[5]) || (prefix_a_pair_2_c4 && prefix_a_pair_2_p[4] && prefix_a_pair_2_p[5]);
    wire prefix_a_pair_2_c7 = (prefix_a_pair_2_g[6]) || (prefix_a_pair_2_c6 && prefix_a_pair_2_p[6]);
    wire prefix_a_pair_2_c8 = (prefix_a_pair_2_g[6] && prefix_a_pair_2_p[7]) || (prefix_a_pair_2_g[7]) || (prefix_a_pair_2_c6 && prefix_a_pair_2_p[6] && prefix_a_pair_2_p[7]);
    wire [8:0] prefix_a_pair_2 = prefix_a_pair_2_p ^ {prefix_a_pair_2_c8, prefix_a_pair_2_c7, prefix_a_pair_2_c6, prefix_a_pair_2_c5, prefix_a_pair_2_c4, prefix_a_pair_2_c3, prefix_a_pair_2_c2, prefix_a_pair_2_c1, prefix_a_pair_2_c0};
    wire [8:0] prefix_a_sum_2_left = ud_pa_0;
    wire [8:0] prefix_a_sum_2_right = prefix_a_pair_2;
    wire [8:0] prefix_a_sum_2_p = prefix_a_sum_2_left ^ prefix_a_sum_2_right;
    wire [7:0] prefix_a_sum_2_g = prefix_a_sum_2_left[7:0] & prefix_a_sum_2_right[7:0];
    wire prefix_a_sum_2_c0 = 1'b0;
    wire prefix_a_sum_2_c1 = (prefix_a_sum_2_g[0]) || (prefix_a_sum_2_c0 && prefix_a_sum_2_p[0]);
    wire prefix_a_sum_2_c2 = (prefix_a_sum_2_g[0] && prefix_a_sum_2_p[1]) || (prefix_a_sum_2_g[1]) || (prefix_a_sum_2_c0 && prefix_a_sum_2_p[0] && prefix_a_sum_2_p[1]);
    wire prefix_a_sum_2_c3 = (prefix_a_sum_2_g[2]) || (prefix_a_sum_2_c2 && prefix_a_sum_2_p[2]);
    wire prefix_a_sum_2_c4 = (prefix_a_sum_2_g[2] && prefix_a_sum_2_p[3]) || (prefix_a_sum_2_g[3]) || (prefix_a_sum_2_c2 && prefix_a_sum_2_p[2] && prefix_a_sum_2_p[3]);
    wire prefix_a_sum_2_c5 = (prefix_a_sum_2_g[4]) || (prefix_a_sum_2_c4 && prefix_a_sum_2_p[4]);
    wire prefix_a_sum_2_c6 = (prefix_a_sum_2_g[4] && prefix_a_sum_2_p[5]) || (prefix_a_sum_2_g[5]) || (prefix_a_sum_2_c4 && prefix_a_sum_2_p[4] && prefix_a_sum_2_p[5]);
    wire prefix_a_sum_2_c7 = (prefix_a_sum_2_g[6]) || (prefix_a_sum_2_c6 && prefix_a_sum_2_p[6]);
    wire prefix_a_sum_2_c8 = (prefix_a_sum_2_g[6] && prefix_a_sum_2_p[7]) || (prefix_a_sum_2_g[7]) || (prefix_a_sum_2_c6 && prefix_a_sum_2_p[6] && prefix_a_sum_2_p[7]);
    wire [8:0] prefix_a_sum_2 = prefix_a_sum_2_p ^ {prefix_a_sum_2_c8, prefix_a_sum_2_c7, prefix_a_sum_2_c6, prefix_a_sum_2_c5, prefix_a_sum_2_c4, prefix_a_sum_2_c3, prefix_a_sum_2_c2, prefix_a_sum_2_c1, prefix_a_sum_2_c0};
    assign ud_pa_2 = prefix_a_sum_2;
    wire [8:0] prefix_a_sum_3_left = ud_pa_2;
    wire [8:0] prefix_a_sum_3_right = {3'd0, a_latency[2]};
    wire [8:0] prefix_a_sum_3_p = prefix_a_sum_3_left ^ prefix_a_sum_3_right;
    wire [7:0] prefix_a_sum_3_g = prefix_a_sum_3_left[7:0] & prefix_a_sum_3_right[7:0];
    wire prefix_a_sum_3_c0 = 1'b0;
    wire prefix_a_sum_3_c1 = (prefix_a_sum_3_g[0]) || (prefix_a_sum_3_c0 && prefix_a_sum_3_p[0]);
    wire prefix_a_sum_3_c2 = (prefix_a_sum_3_g[0] && prefix_a_sum_3_p[1]) || (prefix_a_sum_3_g[1]) || (prefix_a_sum_3_c0 && prefix_a_sum_3_p[0] && prefix_a_sum_3_p[1]);
    wire prefix_a_sum_3_c3 = (prefix_a_sum_3_g[2]) || (prefix_a_sum_3_c2 && prefix_a_sum_3_p[2]);
    wire prefix_a_sum_3_c4 = (prefix_a_sum_3_g[2] && prefix_a_sum_3_p[3]) || (prefix_a_sum_3_g[3]) || (prefix_a_sum_3_c2 && prefix_a_sum_3_p[2] && prefix_a_sum_3_p[3]);
    wire prefix_a_sum_3_c5 = (prefix_a_sum_3_g[4]) || (prefix_a_sum_3_c4 && prefix_a_sum_3_p[4]);
    wire prefix_a_sum_3_c6 = (prefix_a_sum_3_g[4] && prefix_a_sum_3_p[5]) || (prefix_a_sum_3_g[5]) || (prefix_a_sum_3_c4 && prefix_a_sum_3_p[4] && prefix_a_sum_3_p[5]);
    wire prefix_a_sum_3_c7 = (prefix_a_sum_3_g[6]) || (prefix_a_sum_3_c6 && prefix_a_sum_3_p[6]);
    wire prefix_a_sum_3_c8 = (prefix_a_sum_3_g[6] && prefix_a_sum_3_p[7]) || (prefix_a_sum_3_g[7]) || (prefix_a_sum_3_c6 && prefix_a_sum_3_p[6] && prefix_a_sum_3_p[7]);
    wire [8:0] prefix_a_sum_3 = prefix_a_sum_3_p ^ {prefix_a_sum_3_c8, prefix_a_sum_3_c7, prefix_a_sum_3_c6, prefix_a_sum_3_c5, prefix_a_sum_3_c4, prefix_a_sum_3_c3, prefix_a_sum_3_c2, prefix_a_sum_3_c1, prefix_a_sum_3_c0};
    assign ud_pa_3 = prefix_a_sum_3;
    wire [8:0] prefix_a_pair_4_left = {3'd0, a_latency[2]};
    wire [8:0] prefix_a_pair_4_right = {3'd0, a_latency[3]};
    wire [8:0] prefix_a_pair_4_p = prefix_a_pair_4_left ^ prefix_a_pair_4_right;
    wire [7:0] prefix_a_pair_4_g = prefix_a_pair_4_left[7:0] & prefix_a_pair_4_right[7:0];
    wire prefix_a_pair_4_c0 = 1'b0;
    wire prefix_a_pair_4_c1 = (prefix_a_pair_4_g[0]) || (prefix_a_pair_4_c0 && prefix_a_pair_4_p[0]);
    wire prefix_a_pair_4_c2 = (prefix_a_pair_4_g[0] && prefix_a_pair_4_p[1]) || (prefix_a_pair_4_g[1]) || (prefix_a_pair_4_c0 && prefix_a_pair_4_p[0] && prefix_a_pair_4_p[1]);
    wire prefix_a_pair_4_c3 = (prefix_a_pair_4_g[2]) || (prefix_a_pair_4_c2 && prefix_a_pair_4_p[2]);
    wire prefix_a_pair_4_c4 = (prefix_a_pair_4_g[2] && prefix_a_pair_4_p[3]) || (prefix_a_pair_4_g[3]) || (prefix_a_pair_4_c2 && prefix_a_pair_4_p[2] && prefix_a_pair_4_p[3]);
    wire prefix_a_pair_4_c5 = (prefix_a_pair_4_g[4]) || (prefix_a_pair_4_c4 && prefix_a_pair_4_p[4]);
    wire prefix_a_pair_4_c6 = (prefix_a_pair_4_g[4] && prefix_a_pair_4_p[5]) || (prefix_a_pair_4_g[5]) || (prefix_a_pair_4_c4 && prefix_a_pair_4_p[4] && prefix_a_pair_4_p[5]);
    wire prefix_a_pair_4_c7 = (prefix_a_pair_4_g[6]) || (prefix_a_pair_4_c6 && prefix_a_pair_4_p[6]);
    wire prefix_a_pair_4_c8 = (prefix_a_pair_4_g[6] && prefix_a_pair_4_p[7]) || (prefix_a_pair_4_g[7]) || (prefix_a_pair_4_c6 && prefix_a_pair_4_p[6] && prefix_a_pair_4_p[7]);
    wire [8:0] prefix_a_pair_4 = prefix_a_pair_4_p ^ {prefix_a_pair_4_c8, prefix_a_pair_4_c7, prefix_a_pair_4_c6, prefix_a_pair_4_c5, prefix_a_pair_4_c4, prefix_a_pair_4_c3, prefix_a_pair_4_c2, prefix_a_pair_4_c1, prefix_a_pair_4_c0};
    wire [8:0] prefix_a_sum_4_left = ud_pa_2;
    wire [8:0] prefix_a_sum_4_right = prefix_a_pair_4;
    wire [8:0] prefix_a_sum_4_p = prefix_a_sum_4_left ^ prefix_a_sum_4_right;
    wire [7:0] prefix_a_sum_4_g = prefix_a_sum_4_left[7:0] & prefix_a_sum_4_right[7:0];
    wire prefix_a_sum_4_c0 = 1'b0;
    wire prefix_a_sum_4_c1 = (prefix_a_sum_4_g[0]) || (prefix_a_sum_4_c0 && prefix_a_sum_4_p[0]);
    wire prefix_a_sum_4_c2 = (prefix_a_sum_4_g[0] && prefix_a_sum_4_p[1]) || (prefix_a_sum_4_g[1]) || (prefix_a_sum_4_c0 && prefix_a_sum_4_p[0] && prefix_a_sum_4_p[1]);
    wire prefix_a_sum_4_c3 = (prefix_a_sum_4_g[2]) || (prefix_a_sum_4_c2 && prefix_a_sum_4_p[2]);
    wire prefix_a_sum_4_c4 = (prefix_a_sum_4_g[2] && prefix_a_sum_4_p[3]) || (prefix_a_sum_4_g[3]) || (prefix_a_sum_4_c2 && prefix_a_sum_4_p[2] && prefix_a_sum_4_p[3]);
    wire prefix_a_sum_4_c5 = (prefix_a_sum_4_g[4]) || (prefix_a_sum_4_c4 && prefix_a_sum_4_p[4]);
    wire prefix_a_sum_4_c6 = (prefix_a_sum_4_g[4] && prefix_a_sum_4_p[5]) || (prefix_a_sum_4_g[5]) || (prefix_a_sum_4_c4 && prefix_a_sum_4_p[4] && prefix_a_sum_4_p[5]);
    wire prefix_a_sum_4_c7 = (prefix_a_sum_4_g[6]) || (prefix_a_sum_4_c6 && prefix_a_sum_4_p[6]);
    wire prefix_a_sum_4_c8 = (prefix_a_sum_4_g[6] && prefix_a_sum_4_p[7]) || (prefix_a_sum_4_g[7]) || (prefix_a_sum_4_c6 && prefix_a_sum_4_p[6] && prefix_a_sum_4_p[7]);
    wire [8:0] prefix_a_sum_4 = prefix_a_sum_4_p ^ {prefix_a_sum_4_c8, prefix_a_sum_4_c7, prefix_a_sum_4_c6, prefix_a_sum_4_c5, prefix_a_sum_4_c4, prefix_a_sum_4_c3, prefix_a_sum_4_c2, prefix_a_sum_4_c1, prefix_a_sum_4_c0};
    assign ud_pa_4 = prefix_a_sum_4;
//
// B PREFIX BANK
// Repeat the same arithmetic for up to six B entries. Prefix differences
// are computed later from these shared values, rather than rebuilding sums
// in every candidate schedule.
//
    wire [8:0] ud_pb_0;
    wire [8:0] ud_pb_1;
    wire [8:0] ud_pb_2;
    wire [8:0] ud_pb_3;
    wire [8:0] ud_pb_4;
    wire [8:0] ud_pb_5;
    wire [8:0] ud_pb_6;
    assign b_prefix[0] = ud_pb_0;
    assign b_prefix[1] = ud_pb_1;
    assign b_prefix[2] = ud_pb_2;
    assign b_prefix[3] = ud_pb_3;
    assign b_prefix[4] = ud_pb_4;
    assign b_prefix[5] = ud_pb_5;
    assign b_prefix[6] = ud_pb_6;
    assign ud_pb_0 = 9'd0;
    assign ud_pb_1 = {3'd0, b_latency[0]};
    wire [8:0] prefix_b_pair_2_left = {3'd0, b_latency[0]};
    wire [8:0] prefix_b_pair_2_right = {3'd0, b_latency[1]};
    wire [8:0] prefix_b_pair_2_p = prefix_b_pair_2_left ^ prefix_b_pair_2_right;
    wire [7:0] prefix_b_pair_2_g = prefix_b_pair_2_left[7:0] & prefix_b_pair_2_right[7:0];
    wire prefix_b_pair_2_c0 = 1'b0;
    wire prefix_b_pair_2_c1 = (prefix_b_pair_2_g[0]) || (prefix_b_pair_2_c0 && prefix_b_pair_2_p[0]);
    wire prefix_b_pair_2_c2 = (prefix_b_pair_2_g[0] && prefix_b_pair_2_p[1]) || (prefix_b_pair_2_g[1]) || (prefix_b_pair_2_c0 && prefix_b_pair_2_p[0] && prefix_b_pair_2_p[1]);
    wire prefix_b_pair_2_c3 = (prefix_b_pair_2_g[2]) || (prefix_b_pair_2_c2 && prefix_b_pair_2_p[2]);
    wire prefix_b_pair_2_c4 = (prefix_b_pair_2_g[2] && prefix_b_pair_2_p[3]) || (prefix_b_pair_2_g[3]) || (prefix_b_pair_2_c2 && prefix_b_pair_2_p[2] && prefix_b_pair_2_p[3]);
    wire prefix_b_pair_2_c5 = (prefix_b_pair_2_g[4]) || (prefix_b_pair_2_c4 && prefix_b_pair_2_p[4]);
    wire prefix_b_pair_2_c6 = (prefix_b_pair_2_g[4] && prefix_b_pair_2_p[5]) || (prefix_b_pair_2_g[5]) || (prefix_b_pair_2_c4 && prefix_b_pair_2_p[4] && prefix_b_pair_2_p[5]);
    wire prefix_b_pair_2_c7 = (prefix_b_pair_2_g[6]) || (prefix_b_pair_2_c6 && prefix_b_pair_2_p[6]);
    wire prefix_b_pair_2_c8 = (prefix_b_pair_2_g[6] && prefix_b_pair_2_p[7]) || (prefix_b_pair_2_g[7]) || (prefix_b_pair_2_c6 && prefix_b_pair_2_p[6] && prefix_b_pair_2_p[7]);
    wire [8:0] prefix_b_pair_2 = prefix_b_pair_2_p ^ {prefix_b_pair_2_c8, prefix_b_pair_2_c7, prefix_b_pair_2_c6, prefix_b_pair_2_c5, prefix_b_pair_2_c4, prefix_b_pair_2_c3, prefix_b_pair_2_c2, prefix_b_pair_2_c1, prefix_b_pair_2_c0};
    wire [8:0] prefix_b_sum_2_left = ud_pb_0;
    wire [8:0] prefix_b_sum_2_right = prefix_b_pair_2;
    wire [8:0] prefix_b_sum_2_p = prefix_b_sum_2_left ^ prefix_b_sum_2_right;
    wire [7:0] prefix_b_sum_2_g = prefix_b_sum_2_left[7:0] & prefix_b_sum_2_right[7:0];
    wire prefix_b_sum_2_c0 = 1'b0;
    wire prefix_b_sum_2_c1 = (prefix_b_sum_2_g[0]) || (prefix_b_sum_2_c0 && prefix_b_sum_2_p[0]);
    wire prefix_b_sum_2_c2 = (prefix_b_sum_2_g[0] && prefix_b_sum_2_p[1]) || (prefix_b_sum_2_g[1]) || (prefix_b_sum_2_c0 && prefix_b_sum_2_p[0] && prefix_b_sum_2_p[1]);
    wire prefix_b_sum_2_c3 = (prefix_b_sum_2_g[2]) || (prefix_b_sum_2_c2 && prefix_b_sum_2_p[2]);
    wire prefix_b_sum_2_c4 = (prefix_b_sum_2_g[2] && prefix_b_sum_2_p[3]) || (prefix_b_sum_2_g[3]) || (prefix_b_sum_2_c2 && prefix_b_sum_2_p[2] && prefix_b_sum_2_p[3]);
    wire prefix_b_sum_2_c5 = (prefix_b_sum_2_g[4]) || (prefix_b_sum_2_c4 && prefix_b_sum_2_p[4]);
    wire prefix_b_sum_2_c6 = (prefix_b_sum_2_g[4] && prefix_b_sum_2_p[5]) || (prefix_b_sum_2_g[5]) || (prefix_b_sum_2_c4 && prefix_b_sum_2_p[4] && prefix_b_sum_2_p[5]);
    wire prefix_b_sum_2_c7 = (prefix_b_sum_2_g[6]) || (prefix_b_sum_2_c6 && prefix_b_sum_2_p[6]);
    wire prefix_b_sum_2_c8 = (prefix_b_sum_2_g[6] && prefix_b_sum_2_p[7]) || (prefix_b_sum_2_g[7]) || (prefix_b_sum_2_c6 && prefix_b_sum_2_p[6] && prefix_b_sum_2_p[7]);
    wire [8:0] prefix_b_sum_2 = prefix_b_sum_2_p ^ {prefix_b_sum_2_c8, prefix_b_sum_2_c7, prefix_b_sum_2_c6, prefix_b_sum_2_c5, prefix_b_sum_2_c4, prefix_b_sum_2_c3, prefix_b_sum_2_c2, prefix_b_sum_2_c1, prefix_b_sum_2_c0};
    assign ud_pb_2 = prefix_b_sum_2;
    wire [8:0] prefix_b_sum_3_left = ud_pb_2;
    wire [8:0] prefix_b_sum_3_right = {3'd0, b_latency[2]};
    wire [8:0] prefix_b_sum_3_p = prefix_b_sum_3_left ^ prefix_b_sum_3_right;
    wire [7:0] prefix_b_sum_3_g = prefix_b_sum_3_left[7:0] & prefix_b_sum_3_right[7:0];
    wire prefix_b_sum_3_c0 = 1'b0;
    wire prefix_b_sum_3_c1 = (prefix_b_sum_3_g[0]) || (prefix_b_sum_3_c0 && prefix_b_sum_3_p[0]);
    wire prefix_b_sum_3_c2 = (prefix_b_sum_3_g[0] && prefix_b_sum_3_p[1]) || (prefix_b_sum_3_g[1]) || (prefix_b_sum_3_c0 && prefix_b_sum_3_p[0] && prefix_b_sum_3_p[1]);
    wire prefix_b_sum_3_c3 = (prefix_b_sum_3_g[2]) || (prefix_b_sum_3_c2 && prefix_b_sum_3_p[2]);
    wire prefix_b_sum_3_c4 = (prefix_b_sum_3_g[2] && prefix_b_sum_3_p[3]) || (prefix_b_sum_3_g[3]) || (prefix_b_sum_3_c2 && prefix_b_sum_3_p[2] && prefix_b_sum_3_p[3]);
    wire prefix_b_sum_3_c5 = (prefix_b_sum_3_g[4]) || (prefix_b_sum_3_c4 && prefix_b_sum_3_p[4]);
    wire prefix_b_sum_3_c6 = (prefix_b_sum_3_g[4] && prefix_b_sum_3_p[5]) || (prefix_b_sum_3_g[5]) || (prefix_b_sum_3_c4 && prefix_b_sum_3_p[4] && prefix_b_sum_3_p[5]);
    wire prefix_b_sum_3_c7 = (prefix_b_sum_3_g[6]) || (prefix_b_sum_3_c6 && prefix_b_sum_3_p[6]);
    wire prefix_b_sum_3_c8 = (prefix_b_sum_3_g[6] && prefix_b_sum_3_p[7]) || (prefix_b_sum_3_g[7]) || (prefix_b_sum_3_c6 && prefix_b_sum_3_p[6] && prefix_b_sum_3_p[7]);
    wire [8:0] prefix_b_sum_3 = prefix_b_sum_3_p ^ {prefix_b_sum_3_c8, prefix_b_sum_3_c7, prefix_b_sum_3_c6, prefix_b_sum_3_c5, prefix_b_sum_3_c4, prefix_b_sum_3_c3, prefix_b_sum_3_c2, prefix_b_sum_3_c1, prefix_b_sum_3_c0};
    assign ud_pb_3 = prefix_b_sum_3;
    wire [8:0] prefix_b_pair_4_left = {3'd0, b_latency[2]};
    wire [8:0] prefix_b_pair_4_right = {3'd0, b_latency[3]};
    wire [8:0] prefix_b_pair_4_p = prefix_b_pair_4_left ^ prefix_b_pair_4_right;
    wire [7:0] prefix_b_pair_4_g = prefix_b_pair_4_left[7:0] & prefix_b_pair_4_right[7:0];
    wire prefix_b_pair_4_c0 = 1'b0;
    wire prefix_b_pair_4_c1 = (prefix_b_pair_4_g[0]) || (prefix_b_pair_4_c0 && prefix_b_pair_4_p[0]);
    wire prefix_b_pair_4_c2 = (prefix_b_pair_4_g[0] && prefix_b_pair_4_p[1]) || (prefix_b_pair_4_g[1]) || (prefix_b_pair_4_c0 && prefix_b_pair_4_p[0] && prefix_b_pair_4_p[1]);
    wire prefix_b_pair_4_c3 = (prefix_b_pair_4_g[2]) || (prefix_b_pair_4_c2 && prefix_b_pair_4_p[2]);
    wire prefix_b_pair_4_c4 = (prefix_b_pair_4_g[2] && prefix_b_pair_4_p[3]) || (prefix_b_pair_4_g[3]) || (prefix_b_pair_4_c2 && prefix_b_pair_4_p[2] && prefix_b_pair_4_p[3]);
    wire prefix_b_pair_4_c5 = (prefix_b_pair_4_g[4]) || (prefix_b_pair_4_c4 && prefix_b_pair_4_p[4]);
    wire prefix_b_pair_4_c6 = (prefix_b_pair_4_g[4] && prefix_b_pair_4_p[5]) || (prefix_b_pair_4_g[5]) || (prefix_b_pair_4_c4 && prefix_b_pair_4_p[4] && prefix_b_pair_4_p[5]);
    wire prefix_b_pair_4_c7 = (prefix_b_pair_4_g[6]) || (prefix_b_pair_4_c6 && prefix_b_pair_4_p[6]);
    wire prefix_b_pair_4_c8 = (prefix_b_pair_4_g[6] && prefix_b_pair_4_p[7]) || (prefix_b_pair_4_g[7]) || (prefix_b_pair_4_c6 && prefix_b_pair_4_p[6] && prefix_b_pair_4_p[7]);
    wire [8:0] prefix_b_pair_4 = prefix_b_pair_4_p ^ {prefix_b_pair_4_c8, prefix_b_pair_4_c7, prefix_b_pair_4_c6, prefix_b_pair_4_c5, prefix_b_pair_4_c4, prefix_b_pair_4_c3, prefix_b_pair_4_c2, prefix_b_pair_4_c1, prefix_b_pair_4_c0};
    wire [8:0] prefix_b_sum_4_left = ud_pb_2;
    wire [8:0] prefix_b_sum_4_right = prefix_b_pair_4;
    wire [8:0] prefix_b_sum_4_p = prefix_b_sum_4_left ^ prefix_b_sum_4_right;
    wire [7:0] prefix_b_sum_4_g = prefix_b_sum_4_left[7:0] & prefix_b_sum_4_right[7:0];
    wire prefix_b_sum_4_c0 = 1'b0;
    wire prefix_b_sum_4_c1 = (prefix_b_sum_4_g[0]) || (prefix_b_sum_4_c0 && prefix_b_sum_4_p[0]);
    wire prefix_b_sum_4_c2 = (prefix_b_sum_4_g[0] && prefix_b_sum_4_p[1]) || (prefix_b_sum_4_g[1]) || (prefix_b_sum_4_c0 && prefix_b_sum_4_p[0] && prefix_b_sum_4_p[1]);
    wire prefix_b_sum_4_c3 = (prefix_b_sum_4_g[2]) || (prefix_b_sum_4_c2 && prefix_b_sum_4_p[2]);
    wire prefix_b_sum_4_c4 = (prefix_b_sum_4_g[2] && prefix_b_sum_4_p[3]) || (prefix_b_sum_4_g[3]) || (prefix_b_sum_4_c2 && prefix_b_sum_4_p[2] && prefix_b_sum_4_p[3]);
    wire prefix_b_sum_4_c5 = (prefix_b_sum_4_g[4]) || (prefix_b_sum_4_c4 && prefix_b_sum_4_p[4]);
    wire prefix_b_sum_4_c6 = (prefix_b_sum_4_g[4] && prefix_b_sum_4_p[5]) || (prefix_b_sum_4_g[5]) || (prefix_b_sum_4_c4 && prefix_b_sum_4_p[4] && prefix_b_sum_4_p[5]);
    wire prefix_b_sum_4_c7 = (prefix_b_sum_4_g[6]) || (prefix_b_sum_4_c6 && prefix_b_sum_4_p[6]);
    wire prefix_b_sum_4_c8 = (prefix_b_sum_4_g[6] && prefix_b_sum_4_p[7]) || (prefix_b_sum_4_g[7]) || (prefix_b_sum_4_c6 && prefix_b_sum_4_p[6] && prefix_b_sum_4_p[7]);
    wire [8:0] prefix_b_sum_4 = prefix_b_sum_4_p ^ {prefix_b_sum_4_c8, prefix_b_sum_4_c7, prefix_b_sum_4_c6, prefix_b_sum_4_c5, prefix_b_sum_4_c4, prefix_b_sum_4_c3, prefix_b_sum_4_c2, prefix_b_sum_4_c1, prefix_b_sum_4_c0};
    assign ud_pb_4 = prefix_b_sum_4;
    wire [8:0] prefix_b_sum_5_left = ud_pb_4;
    wire [8:0] prefix_b_sum_5_right = {3'd0, b_latency[4]};
    wire [8:0] prefix_b_sum_5_p = prefix_b_sum_5_left ^ prefix_b_sum_5_right;
    wire [7:0] prefix_b_sum_5_g = prefix_b_sum_5_left[7:0] & prefix_b_sum_5_right[7:0];
    wire prefix_b_sum_5_c0 = 1'b0;
    wire prefix_b_sum_5_c1 = (prefix_b_sum_5_g[0]) || (prefix_b_sum_5_c0 && prefix_b_sum_5_p[0]);
    wire prefix_b_sum_5_c2 = (prefix_b_sum_5_g[0] && prefix_b_sum_5_p[1]) || (prefix_b_sum_5_g[1]) || (prefix_b_sum_5_c0 && prefix_b_sum_5_p[0] && prefix_b_sum_5_p[1]);
    wire prefix_b_sum_5_c3 = (prefix_b_sum_5_g[2]) || (prefix_b_sum_5_c2 && prefix_b_sum_5_p[2]);
    wire prefix_b_sum_5_c4 = (prefix_b_sum_5_g[2] && prefix_b_sum_5_p[3]) || (prefix_b_sum_5_g[3]) || (prefix_b_sum_5_c2 && prefix_b_sum_5_p[2] && prefix_b_sum_5_p[3]);
    wire prefix_b_sum_5_c5 = (prefix_b_sum_5_g[4]) || (prefix_b_sum_5_c4 && prefix_b_sum_5_p[4]);
    wire prefix_b_sum_5_c6 = (prefix_b_sum_5_g[4] && prefix_b_sum_5_p[5]) || (prefix_b_sum_5_g[5]) || (prefix_b_sum_5_c4 && prefix_b_sum_5_p[4] && prefix_b_sum_5_p[5]);
    wire prefix_b_sum_5_c7 = (prefix_b_sum_5_g[6]) || (prefix_b_sum_5_c6 && prefix_b_sum_5_p[6]);
    wire prefix_b_sum_5_c8 = (prefix_b_sum_5_g[6] && prefix_b_sum_5_p[7]) || (prefix_b_sum_5_g[7]) || (prefix_b_sum_5_c6 && prefix_b_sum_5_p[6] && prefix_b_sum_5_p[7]);
    wire [8:0] prefix_b_sum_5 = prefix_b_sum_5_p ^ {prefix_b_sum_5_c8, prefix_b_sum_5_c7, prefix_b_sum_5_c6, prefix_b_sum_5_c5, prefix_b_sum_5_c4, prefix_b_sum_5_c3, prefix_b_sum_5_c2, prefix_b_sum_5_c1, prefix_b_sum_5_c0};
    assign ud_pb_5 = prefix_b_sum_5;
    wire [8:0] prefix_b_pair_6_left = {3'd0, b_latency[4]};
    wire [8:0] prefix_b_pair_6_right = {3'd0, b_latency[5]};
    wire [8:0] prefix_b_pair_6_p = prefix_b_pair_6_left ^ prefix_b_pair_6_right;
    wire [7:0] prefix_b_pair_6_g = prefix_b_pair_6_left[7:0] & prefix_b_pair_6_right[7:0];
    wire prefix_b_pair_6_c0 = 1'b0;
    wire prefix_b_pair_6_c1 = (prefix_b_pair_6_g[0]) || (prefix_b_pair_6_c0 && prefix_b_pair_6_p[0]);
    wire prefix_b_pair_6_c2 = (prefix_b_pair_6_g[0] && prefix_b_pair_6_p[1]) || (prefix_b_pair_6_g[1]) || (prefix_b_pair_6_c0 && prefix_b_pair_6_p[0] && prefix_b_pair_6_p[1]);
    wire prefix_b_pair_6_c3 = (prefix_b_pair_6_g[2]) || (prefix_b_pair_6_c2 && prefix_b_pair_6_p[2]);
    wire prefix_b_pair_6_c4 = (prefix_b_pair_6_g[2] && prefix_b_pair_6_p[3]) || (prefix_b_pair_6_g[3]) || (prefix_b_pair_6_c2 && prefix_b_pair_6_p[2] && prefix_b_pair_6_p[3]);
    wire prefix_b_pair_6_c5 = (prefix_b_pair_6_g[4]) || (prefix_b_pair_6_c4 && prefix_b_pair_6_p[4]);
    wire prefix_b_pair_6_c6 = (prefix_b_pair_6_g[4] && prefix_b_pair_6_p[5]) || (prefix_b_pair_6_g[5]) || (prefix_b_pair_6_c4 && prefix_b_pair_6_p[4] && prefix_b_pair_6_p[5]);
    wire prefix_b_pair_6_c7 = (prefix_b_pair_6_g[6]) || (prefix_b_pair_6_c6 && prefix_b_pair_6_p[6]);
    wire prefix_b_pair_6_c8 = (prefix_b_pair_6_g[6] && prefix_b_pair_6_p[7]) || (prefix_b_pair_6_g[7]) || (prefix_b_pair_6_c6 && prefix_b_pair_6_p[6] && prefix_b_pair_6_p[7]);
    wire [8:0] prefix_b_pair_6 = prefix_b_pair_6_p ^ {prefix_b_pair_6_c8, prefix_b_pair_6_c7, prefix_b_pair_6_c6, prefix_b_pair_6_c5, prefix_b_pair_6_c4, prefix_b_pair_6_c3, prefix_b_pair_6_c2, prefix_b_pair_6_c1, prefix_b_pair_6_c0};
    wire [8:0] prefix_b_sum_6_left = ud_pb_4;
    wire [8:0] prefix_b_sum_6_right = prefix_b_pair_6;
    wire [8:0] prefix_b_sum_6_p = prefix_b_sum_6_left ^ prefix_b_sum_6_right;
    wire [7:0] prefix_b_sum_6_g = prefix_b_sum_6_left[7:0] & prefix_b_sum_6_right[7:0];
    wire prefix_b_sum_6_c0 = 1'b0;
    wire prefix_b_sum_6_c1 = (prefix_b_sum_6_g[0]) || (prefix_b_sum_6_c0 && prefix_b_sum_6_p[0]);
    wire prefix_b_sum_6_c2 = (prefix_b_sum_6_g[0] && prefix_b_sum_6_p[1]) || (prefix_b_sum_6_g[1]) || (prefix_b_sum_6_c0 && prefix_b_sum_6_p[0] && prefix_b_sum_6_p[1]);
    wire prefix_b_sum_6_c3 = (prefix_b_sum_6_g[2]) || (prefix_b_sum_6_c2 && prefix_b_sum_6_p[2]);
    wire prefix_b_sum_6_c4 = (prefix_b_sum_6_g[2] && prefix_b_sum_6_p[3]) || (prefix_b_sum_6_g[3]) || (prefix_b_sum_6_c2 && prefix_b_sum_6_p[2] && prefix_b_sum_6_p[3]);
    wire prefix_b_sum_6_c5 = (prefix_b_sum_6_g[4]) || (prefix_b_sum_6_c4 && prefix_b_sum_6_p[4]);
    wire prefix_b_sum_6_c6 = (prefix_b_sum_6_g[4] && prefix_b_sum_6_p[5]) || (prefix_b_sum_6_g[5]) || (prefix_b_sum_6_c4 && prefix_b_sum_6_p[4] && prefix_b_sum_6_p[5]);
    wire prefix_b_sum_6_c7 = (prefix_b_sum_6_g[6]) || (prefix_b_sum_6_c6 && prefix_b_sum_6_p[6]);
    wire prefix_b_sum_6_c8 = (prefix_b_sum_6_g[6] && prefix_b_sum_6_p[7]) || (prefix_b_sum_6_g[7]) || (prefix_b_sum_6_c6 && prefix_b_sum_6_p[6] && prefix_b_sum_6_p[7]);
    wire [8:0] prefix_b_sum_6 = prefix_b_sum_6_p ^ {prefix_b_sum_6_c8, prefix_b_sum_6_c7, prefix_b_sum_6_c6, prefix_b_sum_6_c5, prefix_b_sum_6_c4, prefix_b_sum_6_c3, prefix_b_sum_6_c2, prefix_b_sum_6_c1, prefix_b_sum_6_c0};
    assign ud_pb_6 = prefix_b_sum_6;
    generate
//
// TWO-CHAIN FRONTIER: STATE (i,j,d)
// i and j count issued A/B entries; d is an A-waiting allowance, 0..j.
// threshold[e] means the least attainable B waiting is <=e, for e=0..i.
// For fixed prefixes and allowance, a larger B waiting cannot improve a
// continuation. Store only that minimum, encoded as monotone Boolean bits,
// together with a mask that attains it. Budget d inherits budget d-1.
// The grid and budget dependencies are elaborated combinational logic.
// Positive latencies and one issue per cycle justify the bounded frontier;
// the separate bound on final extra completion is not a per-chain bound.
//
        for (i = 0; i <= 4; i = i + 1) begin : dual_a
            for (j = 0; j <= 6; j = j + 1) begin : dual_b
                if (i+j > 1 && i+j <= 8) begin : state
//
// SHARED PREFIX DIFFERENCE
// PA[i-1]-PB[j-1] determines whether appending A or B respects the next
// issue separation under given waits. The 10-bit subtraction preserves the
// sign; all budgets at the same prefix pair share it.
//
                    if (i > 0 && j > 0 && i+j > 2) begin : timing
                        wire [9:0] difference;
                        assign difference = {1'b0, a_prefix[i-1]} - {1'b0, b_prefix[j-1]};
                    end
                    for (d = 0; d <= j; d = d + 1) begin : budget
                        wire [i:0] threshold;
                        wire [i+j-1:0] mask;
//
// EXACT BOUNDARIES
// One populated axis has no cross-chain waiting. At (1,1) both chains cannot
// issue at zero: d=0 requires B wait 1, while d>=1 permits B wait 0.
// The earliest mask bit is bit 0; 1 means A and 0 means B.
//
                        if (i == 0 || j == 0) begin : axis
                            assign threshold = {(i+1){1'b1}};
                            assign mask = (1 << i) - 1;
                        end else if (i == 1 && j == 1) begin : first_pair
                            assign threshold = (d == 0) ? 2'b10 : 2'b11;
                            assign mask = (d == 0) ? 2'b01 : 2'b10;
                        end else begin : recurrence
//
// APPEND A
// Reuse the (i-1,j,d) witness and append an A bit at the high end.
// A predecessor B threshold e is usable if difference >= e+1-d.
// Cumulative OR retains the best feasible threshold among those bounds.
//
                            wire [i:0] append_a;
                            wire [i+j-1:0] a_mask;
                            assign a_mask = {1'b1, dual_a[i-1].dual_b[j].state.budget[d].mask};
                            for (e = 0; e < i; e = e + 1) begin : a_bound
                                wire valid, cumulative;
                                assign valid = dual_a[i-1].dual_b[j].state.budget[d].threshold[e] &&
                                    at_least(timing.difference, e+1-d);
                                if (e == 0) begin : first_bound
                                    assign cumulative = valid;
                                end else begin : higher_bound
                                    assign cumulative = a_bound[e-1].cumulative || valid;
                                end
                                assign append_a[e] = cumulative;
                            end
                            assign append_a[i] = a_bound[i-1].cumulative;
//
// APPEND B AND COMPARE THE TWO WITNESSES
// Reuse (i,j-1,d) when that budget exists, append a B bit, and require
// difference < e-d. The threshold OR merges feasibility. In this selected
// parameterized source append-A wins only when strictly better, so B wins
// equal A/B scores. That is deliberately different from the unrolled form.
//
                            if (d < j) begin : append_b_choice
                                wire [i:0] append_b;
                                wire [i+j-1:0] b_mask, ab_mask;
                                assign b_mask = {1'b0, dual_a[i].dual_b[j-1].state.budget[d].mask};
                                for (e = 0; e <= i; e = e + 1) begin : b_bound
                                    assign append_b[e] = dual_a[i].dual_b[j-1].state.budget[d].threshold[e] &&
                                        !at_least(timing.difference, e-d);
                                end
                                assign ab_mask = (|(append_a & ~append_b)) ? a_mask : b_mask;
                                if (d == 0) begin : no_smaller_budget
                                    assign mask = ab_mask;
                                end else begin : smaller_budget
//
// INHERIT A SMALLER A-WAITING BUDGET
// For d>0, compare the new A/B score with the already feasible d-1 score.
// The smaller-budget witness wins only if strictly better here; a tie keeps
// the new witness. At d=0 there is no inherited choice. The tie rules
// determine the attaining order while preserving the minimum cost.
//
                                    wire [i:0] ab_threshold;
                                    assign ab_threshold = append_a | append_b;
                                    assign mask = (|(budget[d-1].threshold & ~ab_threshold))
                                        ? budget[d-1].mask : ab_mask;
                                end
                            end else begin : full_a_budget
                                assign mask = (|(budget[d-1].threshold & ~append_a))
                                    ? budget[d-1].mask : a_mask;
                            end
//
// FOLD PROVED CONSTANT FRONTIER BITS
// Allowing all j units of A waiting or all i units of B waiting is feasible.
// With both chains nonempty, d=e=0 is impossible because of the first issue
// conflict. Interior bits combine append-A, append-B and the inherited
// budget. These constants depend on positive latencies and the chain model.
//
                            for (e = 0; e <= i; e = e + 1) begin : exact_boundary
                                if (d == j || e == i) begin : always_feasible
                                    assign threshold[e] = 1'b1;
                                end else if (d == 0 && e == 0) begin : first_issue_conflict
                                    assign threshold[e] = 1'b0;
                                end else begin : computed
                                    if (d == 0) begin : no_smaller_budget
                                        assign threshold[e] = append_a[e] | append_b_choice.append_b[e];
                                    end else begin : smaller_budget
                                        assign threshold[e] = budget[d-1].threshold[e] |
                                            append_a[e] | append_b_choice.append_b[e];
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
//
// FINAL COMPLETION SCORES
// The legal splits give 7+6+5=18 finalists. Set base=max(SA,SB).
// For each budget d and threshold t, require both SA+da<=base+t and
// SB+db<=base+t. total_difference=SA-SB cancels the common intrinsic work.
// count_a gates out finalists of the wrong split. Seven score bits remain
// in this implementation; the bound on the optimum does not bound every candidate.
//
        for (i = 2; i <= 4; i = i + 1) begin : final_chain_size
            localparam B_COUNT = 8-i;
            localparam BASE_INDEX = (i == 2) ? 0 : ((i == 3) ? 7 : 13);
            for (d = 0; d <= B_COUNT; d = d + 1) begin : final_budget
                wire [6:0] score;
                for (t = 0; t <= 6; t = t + 1) begin : extra_delay
                    wire [i:0] a_ready;
                    wire b_ready;
                    for (e = 0; e <= i; e = e + 1) begin : b_bound
                        assign a_ready[e] = (d <= t) &&
                            dual_a[i].dual_b[B_COUNT].state.budget[d].threshold[e] &&
                            at_least(total_difference, e-t);
                    end
                    assign b_ready = dual_a[i].dual_b[B_COUNT].state.budget[d].threshold[(t < i) ? t : i] &&
                        !at_least(total_difference, t-d+1);
                    assign score[t] = (count_a == i) && (total_positive ? (|a_ready) : b_ready);
                end
                assign finalist[BASE_INDEX+d] = {score, dual_a[i].dual_b[B_COUNT].state.budget[d].mask};
            end
        end
    endgenerate
//
// COMMON BASE AND FINAL TOURNAMENT
// Prefixes include only zero padding beyond the valid entries, so these
// fixed array endpoints equal actual two-chain totals. The balanced tree
// carries both the minimum score and an attaining full eight-bit mask.
//
    assign total_difference = {1'b0, a_prefix[4]} - {1'b0, b_prefix[6]};
    assign total_positive = !total_difference[9];
    assign dual_base = total_positive ? a_prefix[4] : b_prefix[6];
    assign selected_schedule = choose_schedule(
        choose_schedule(
            choose_schedule(
                choose_schedule(
                    finalist[0],
                    finalist[1]),
                choose_schedule(
                    finalist[2],
                    finalist[3])),
            choose_schedule(
                choose_schedule(
                    finalist[4],
                    finalist[5]),
                choose_schedule(
                    finalist[6],
                    choose_schedule(
                        finalist[7],
                        finalist[8])))),
        choose_schedule(
            choose_schedule(
                choose_schedule(
                    finalist[9],
                    finalist[10]),
                choose_schedule(
                    finalist[11],
                    finalist[12])),
            choose_schedule(
                choose_schedule(
                    finalist[13],
                    finalist[14]),
                choose_schedule(
                    finalist[15],
                    choose_schedule(
                        finalist[16],
                        finalist[17])))));
    assign best_threshold = selected_schedule[14:8];
    assign dual_mask = selected_schedule[7:0];
//
// DECODE THE FIRST FEASIBLE EXTRA DELAY
// Monotone score bits form a thermometer encoding. The explicit equations
// recover the first true index; adding it to base yields Ex_cycle for the
// two-chain case. A legal input has a feasible threshold within this width.
//
    assign dual_extra = {!best_threshold[3],
        ((!best_threshold[1] && best_threshold[3]) || !best_threshold[5]),
        ((!best_threshold[0] && best_threshold[1]) || (!best_threshold[2] && best_threshold[3]) ||
         (!best_threshold[4] && best_threshold[5]) || !best_threshold[6])};
    assign dual_cost = dual_base + {6'd0, dual_extra};

//
// SINGLE-CHAIN SLOT COUNTS
// In a no-idle A schedule, PA[i]-i counts spare issue positions before A[i].
// Only values through seven matter. Small balanced low-bit sums calculate
// them unless any prefix latency is >=8, which already saturates the count.
// These low sums are for slot counts, not for total completion arithmetic.
//
    assign low_prefix[0] = 6'd0;
    assign low_prefix[1] = {3'd0, a_latency[0][2:0]};
    assign low_prefix[2] = {2'd0, low_pair[0]};
    assign low_prefix[3] = {2'd0, low_pair[0]} + {3'd0, a_latency[2][2:0]};
    assign low_quad = {1'b0, low_pair[0]} + {1'b0, low_pair[1]};
    assign low_prefix[4] = {1'b0, low_quad};
    assign low_prefix[5] = {1'b0, low_quad} + {3'd0, a_latency[4][2:0]};
    assign low_prefix[6] = {1'b0, low_quad} + {2'd0, low_pair[2]};
    assign low_tail = {1'b0, low_pair[2]} + {2'd0, a_latency[6][2:0]};
    assign low_prefix[7] = {1'b0, low_quad} + {1'b0, low_tail};
    assign chain_excess[0] = 3'd0;
    generate
        for (i = 0; i < 3; i = i + 1) begin : low_latency_pair
            assign low_pair[i] = {1'b0, a_latency[2*i][2:0]} + {1'b0, a_latency[2*i+1][2:0]};
        end
//
// PLACE EACH CHAIN ENTRY IN THE ORDER MASK
// For chain offset d and k independent entries, its issue-order position is
// i+min(d+excess[i],k). Active entries set one A bit. This is an instruction
// position, not an execution time. When A is empty all positions are gated
// away, including the modulo-eight single_count value used below.
//
        for (i = 0; i < 8; i = i + 1) begin : chain_entry
            wire [3:0] waited;
            wire [2:0] gap, position;
            assign chain_active[i] = count_a > i;
            if (i < 7) begin : prefix_latency
                assign large_latency[i] = |a_latency[i][5:3];
            end
            if (i > 0) begin : prefix_excess
                assign chain_excess[i] = ((|large_latency[i-1:0]) || low_prefix[i] >= i+7)
                    ? 3'd7 : (low_prefix[i][2:0] - i);
            end
            assign waited = {1'b0, single_offset} + {1'b0, chain_excess[i]};
            assign gap = (waited >= {1'b0, single_count}) ? single_count : waited[2:0];
            assign position = i + gap;
            assign chain_position[i] = chain_active[i] ? (8'b1 << position) : 8'd0;
        end
//
// FREE SLOTS IN THE ZERO-OFFSET CHAIN CALENDAR
// Count active chain entries whose spare-slot count is <=t. Independent
// entry t then issues at t+count. A monotone hit vector makes the count
// a small direct encoder rather than a general population-count network.
//
        for (t = 0; t < 6; t = t + 1) begin : free_issue_time
            wire [6:0] hit;
            wire [2:0] count;
            assign hit[0] = chain_active[0];
            for (i = 1; i < 7; i = i + 1) begin : prefix_hit
                assign hit[i] = chain_active[i] && chain_excess[i] <= t;
            end
            assign count = {hit[3], ((hit[1] && !hit[3]) || hit[5]),
                ((hit[0] && !hit[1]) || (hit[2] && !hit[3]) || (hit[4] && !hit[5]) || hit[6])};
            assign free_start[t] = t + count;
        end
        for (i = 2; i < 4; i = i + 1) begin : chain_sum_pair
            assign latency_pair[i] = {1'b0, a_latency[2*i]} + {1'b0, a_latency[2*i+1]};
        end
//
// COMPLETION DEFICITS
// To fit independent latency Bj at relative issue time s before A finishes,
// require SA-Bj>=s. Preserve the sign and whether that deficit is small;
// inspect the high total bits so a large SA cannot wrap into a false small
// deficit when the subtraction uses only the low six bits.
//
        for (j = 0; j < 6; j = j + 1) begin : independent_entry
            assign independent[j] = count_a < 8-j;
            assign deficit[j] = {1'b0, chain_total[5:0]} - {1'b0, b_latency[j]};
            assign deficit_negative[j] = !(|chain_total[8:6]) && deficit[j][6];
            assign deficit_small[j] = !(|chain_total[8:7]) &&
                (chain_total[6] == deficit[j][6]) && !(|deficit[j][5:3]);
        end
//
// BOUNDED INITIAL-OFFSET SEARCH
// The first d independent entries issue before the chain. For j>=d,
// issue time is d+free_start[j-d]; comparing with SA+d cancels d.
// offset_bad[d] says some remaining independent entry cannot fit by then.
// A nonempty chain leaves at most six independent entries, so test 0..5
// and use offset 6 if all fail. The flags are monotone across d.
//
        for (d = 0; d < 6; d = d + 1) begin : offset_test
            wire [5:0] late;
            for (j = 0; j < 6; j = j + 1) begin : completion
                if (j >= d) begin : follows_chain
                    assign late[j] = independent[j] && (deficit_negative[j] ||
                        (deficit_small[j] && deficit[j][2:0] < free_start[j-d]));
                end else begin : precedes_chain
                    assign late[j] = 1'b0;
                end
            end
            assign offset_bad[d] = |late;
        end
//
// INDEPENDENT COMPLETION BOUND
// B is sorted by descending latency, so max_j(j+Bj) is its earliest possible
// completion without chain interference. A balanced maximum tree computes
// this bound. Six bits suffice: legal Bj<=50 and j<=7. With no chain this
// gives the exact answer for all eight independent instructions.
//
        for (i = 15; i >= 1; i = i - 1) begin : independent_maximum
            wire [5:0] value;
            if (i >= 8) begin : leaf
                assign value = b_latency[i-8] + (i-8);
            end else begin : branch
                assign value = (independent_maximum[2*i].value >= independent_maximum[2*i+1].value)
                    ? independent_maximum[2*i].value : independent_maximum[2*i+1].value;
            end
        end
    endgenerate
//
// REUSE THE ALREADY COMPUTED PREFIX
// Sum A slots 4..7 and add a_prefix[4] instead of rebuilding slots 0..3.
// Encode the first good offset, then take max(SA+offset, independent bound).
// The offset construction attains this completion. single_count stores
// 8-count_a modulo eight; its wrapped empty-chain case has no active A bits.
//
    assign latency_quad = {1'b0, latency_pair[2]} + {1'b0, latency_pair[3]};
    assign chain_total = a_prefix[4] + {1'b0, latency_quad};
    assign single_offset = {offset_bad[3], ((offset_bad[1] && !offset_bad[3]) || offset_bad[5]),
        ((offset_bad[0] && !offset_bad[1]) || (offset_bad[2] && !offset_bad[3]) ||
         (offset_bad[4] && !offset_bad[5]))};
    assign chain_completion = chain_total + {6'd0, single_offset};
    assign single_cost = (chain_completion >= {3'd0, independent_maximum[1].value})
        ? chain_completion : {3'd0, independent_maximum[1].value};
    assign single_count = 3'd0 - count_a[2:0];
    assign single_mask = chain_position[0] | chain_position[1] | chain_position[2] | chain_position[3] |
        chain_position[4] | chain_position[5] | chain_position[6] | chain_position[7];
//
// MATCH COST AND WITNESS TO THE GRAPH CLASS
// other_chain selects the DP only for two actual chains. The other engine
// handles one chain or an empty graph. Select mask and completion together.
//
    assign best_mask = other_chain ? dual_mask : single_mask;
    assign Ex_cycle = other_chain ? dual_cost : single_cost;
    assign last_a = count_a[2:0] - 3'd1;
    assign last_b = 3'd7 - count_a[2:0];
    generate
//
// PREPARE TAIL IDENTIFIERS
// Index each compact group backward from its last valid member. Output
// slots in the upper half use suffix counts, limiting their count width.
// Modulo indices for absent group entries are never selected by a legal mask.
//
        for (i = 0; i < 4; i = i + 1) begin : reverse_identifiers
            wire [2:0] a_index, b_index;
            assign a_index = last_a - i;
            assign b_index = last_b - i;
            assign tail_a_identifier[i] = a_identifier[a_index];
            assign tail_b_identifier[i] = b_identifier[b_index];
        end
//
// DECODE THE ATTAINING MASK INTO ORIGINAL INSTRUCTION IDs
// Slots 0..3 count prior mask bits and index from the head; slots 4..7 count
// later mask bits and index backward from the tail. OBSERVED is at most 3.
// The A count selects an A identifier, the complementary B count selects B,
// and best_mask[i] gates the chosen group. A one-hot count drives masked ORs
// directly. This preserves the returned witness rather than sorting IDs
// after the cost has already been chosen.
//
        for (i = 0; i < 8; i = i + 1) begin : output_order
            localparam OBSERVED = (i < 4) ? i : 7-i;
            wire [2:0] bits;
            wire [3:0] count_select;
            wire [2:0] a_term [0:3], b_term [0:3];
            if (i < 4) begin : prefix
                assign bits = best_mask[2:0] & (3'b111 >> (3-i));
            end else begin : suffix
                assign bits = best_mask[7:5] >> (i-4);
            end
            assign count_select = population_hot(bits);
            for (j = 0; j < 4; j = j + 1) begin : choice
                if (j <= OBSERVED) begin : reachable
                    wire a_select, b_select;
                    assign a_select = best_mask[i] && count_select[j];
                    assign b_select = !best_mask[i] && count_select[OBSERVED-j];
                    if (i < 4) begin : forward
                        assign a_term[j] = {3{a_select}} & a_identifier[j];
                        assign b_term[j] = {3{b_select}} & b_identifier[j];
                    end else begin : reverse
                        assign a_term[j] = {3{a_select}} & tail_a_identifier[j];
                        assign b_term[j] = {3{b_select}} & tail_b_identifier[j];
                    end
                end else begin : unused_slot
                    assign a_term[j] = 3'd0;
                    assign b_term[j] = 3'd0;
                end
            end
            assign Inst_order_O[3*i +: 3] =
                a_term[0] | a_term[1] | a_term[2] | a_term[3] |
                b_term[0] | b_term[1] | b_term[2] | b_term[3];
        end
    endgenerate
endmodule
