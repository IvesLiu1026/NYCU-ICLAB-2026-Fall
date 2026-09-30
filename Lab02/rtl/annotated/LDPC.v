// Reading copy of the selected half-parallel decoder.
// The executable Verilog below is byte-identical after removing added full-line comments.
// Eight check-node lanes cover 64 checks in eight steps per iteration.
// See docs/ARCHITECTURE.md for the physical bank layout and docs/NUMERICAL_MODEL.md for exact arithmetic.
module LDPC(
    input wire clk,
    input wire rst_n,
    input wire in_mode_valid,
    input wire in_mode,
    input wire in_data_valid,
    input wire [5:0] in_data,
    output wire out_valid,
    output wire [7:0] out_data,
    output wire out_warn
);
reg out_valid_r;
reg [7:0] out_data_r;
reg out_warn_r;
wire done_now;

// WAIT captures the schedule mode; LOAD accepts 128 channel LLRs.
// DEC rotates an eight-step one-hot schedule; OUT serializes 128 posterior words.
// Completion is also visible combinationally through done_now to avoid an extra output-start cycle.
localparam [1:0] S_WAIT = 2'd0;
localparam [1:0] S_LOAD = 2'd1;
localparam [1:0] S_DEC = 2'd2;
localparam [1:0] S_OUT = 2'd3;

reg [1:0] state;
reg mode;
reg [6:0] idx;
reg [2:0] slot;
reg [7:0] slot_mask;
reg [3:0] iteration;
reg pending;
reg warn;
// posterior supplies check inputs. In flooding it retains the iteration-start values.
// snapshot accumulates the live posterior and supplies syndrome/output data.
// Layered mode keeps the two banks equal, so each later layer sees earlier updates.
// Their 128 words are stored in step-dependent edge order, not permanent variable-index order.
// Datapath arrays are intentionally not reset: a complete input transaction initializes them.
reg signed [7:0] posterior [0:127];
reg signed [7:0] snapshot [0:127];
// Each of eight lanes has one expanded 42-bit head: seven signed 6-bit operands -R_old.
// Seven 19-bit tail records retain two normalized minima, a 3-bit argmin and six outgoing signs.
// The seventh outgoing sign is reconstructed from parity; it adds no tail storage bit.
// Head expansion occurs at a register boundary, ahead of the next edge arithmetic.
reg [41:0] ring [0:7];
reg [18:0] ring_tail [0:55];
wire [63:0] syndrome;
wire syndrome_zero;
wire decoding;
wire loading;
wire clearing;
wire done;
wire abort;
wire update;
wire serial_shift;
wire signed [7:0] in_word;
wire signed [7:0] out_word;
wire signed [7:0] wval [0:127];
wire [4:0] node_first [0:7];
wire [4:0] node_second [0:7];
wire [2:0] node_index [0:7];
wire [5:0] node_signs [0:7];
wire [7:0] upd_sel;
wire lupd;
wire [7:0] lw_sel;
wire [7:0] lh_sel;
wire early;
wire load_shift;

// Return min(abs(value),31) for a signed 8-bit value, including -128.
// The sign used by the check node is still taken from the original value.
// Only the V2C magnitude is clipped; the posterior update must keep its full signed 8-bit sum.
function [4:0] saturated_magnitude;
    input signed [7:0] value;
    reg [4:0] low_abs;
    reg outside;
    begin
        low_abs = value[7] ? (~value[4:0] + 5'd1) : value[4:0];
        outside = value[7] ? ((value[6:5] != 2'b11) ||
            (value[4:0] == 5'd0)) : (|value[6:5]);
        saturated_magnitude = outside ? 5'd31 : low_abs;
    end
endfunction
// For m in 0..31, compute floor((3*m+2)/4): nearest rounding with halfway cases upward.
// The two subtractions implement m-floor(m/4)-(m mod 4 == 3).
// The largest normalized magnitude is 23.
function [4:0] normalized_min;
    input [4:0] value;
    begin
        normalized_min = value - {2'b00, value[4:2]} -
            {4'b0000, &value[1:0]};
    end
endfunction
// Stable ranking of seven magnitudes: the lower edge index wins every equality.
// Bits 0..6 select the first minimum; bits 7..13 select the second minimum.
// Each edge counts how many values precede it in that total order.
// Rank zero selects the first value; rank one selects the second.
// The count-equals-one predicate is factored across two groups of three comparisons.
// Equal minimum values still produce distinct, deterministic first and second selectors.
function [13:0] minimum_flags;
    input [34:0] values;
    reg [4:0] first_value;
    reg [4:0] second_value;
    reg [2:0] selected_index;
    reg order_0_1;
    reg order_0_2;
    reg order_0_3;
    reg order_0_4;
    reg order_0_5;
    reg order_0_6;
    reg order_1_2;
    reg order_1_3;
    reg order_1_4;
    reg order_1_5;
    reg order_1_6;
    reg order_2_3;
    reg order_2_4;
    reg order_2_5;
    reg order_2_6;
    reg order_3_4;
    reg order_3_5;
    reg order_3_6;
    reg order_4_5;
    reg order_4_6;
    reg order_5_6;
    reg [5:0] lower_0;
    reg first_0;
    reg second_0;
    reg [1:0] zero_0;
    reg [1:0] single_0;
    reg [5:0] lower_1;
    reg first_1;
    reg second_1;
    reg [1:0] zero_1;
    reg [1:0] single_1;
    reg [5:0] lower_2;
    reg first_2;
    reg second_2;
    reg [1:0] zero_2;
    reg [1:0] single_2;
    reg [5:0] lower_3;
    reg first_3;
    reg second_3;
    reg [1:0] zero_3;
    reg [1:0] single_3;
    reg [5:0] lower_4;
    reg first_4;
    reg second_4;
    reg [1:0] zero_4;
    reg [1:0] single_4;
    reg [5:0] lower_5;
    reg first_5;
    reg second_5;
    reg [1:0] zero_5;
    reg [1:0] single_5;
    reg [5:0] lower_6;
    reg first_6;
    reg second_6;
    reg [1:0] zero_6;
    reg [1:0] single_6;
    begin
        order_0_1 = values[4:0] <= values[9:5];
        order_0_2 = values[4:0] <= values[14:10];
        order_0_3 = values[4:0] <= values[19:15];
        order_0_4 = values[4:0] <= values[24:20];
        order_0_5 = values[4:0] <= values[29:25];
        order_0_6 = values[4:0] <= values[34:30];
        order_1_2 = values[9:5] <= values[14:10];
        order_1_3 = values[9:5] <= values[19:15];
        order_1_4 = values[9:5] <= values[24:20];
        order_1_5 = values[9:5] <= values[29:25];
        order_1_6 = values[9:5] <= values[34:30];
        order_2_3 = values[14:10] <= values[19:15];
        order_2_4 = values[14:10] <= values[24:20];
        order_2_5 = values[14:10] <= values[29:25];
        order_2_6 = values[14:10] <= values[34:30];
        order_3_4 = values[19:15] <= values[24:20];
        order_3_5 = values[19:15] <= values[29:25];
        order_3_6 = values[19:15] <= values[34:30];
        order_4_5 = values[24:20] <= values[29:25];
        order_4_6 = values[24:20] <= values[34:30];
        order_5_6 = values[29:25] <= values[34:30];
        lower_0 = {~order_0_1, ~order_0_2, ~order_0_3, ~order_0_4, ~order_0_5, ~order_0_6};
        first_0 = ~|lower_0;
        zero_0[0] = ~(lower_0[0] | lower_0[1] | lower_0[2]);
        single_0[0] = (lower_0[0] & ~lower_0[1] & ~lower_0[2]) |
            (~lower_0[0] & lower_0[1] & ~lower_0[2]) | (~lower_0[0] & ~lower_0[1] & lower_0[2]);
        zero_0[1] = ~(lower_0[3] | lower_0[4] | lower_0[5]);
        single_0[1] = (lower_0[3] & ~lower_0[4] & ~lower_0[5]) |
            (~lower_0[3] & lower_0[4] & ~lower_0[5]) | (~lower_0[3] & ~lower_0[4] & lower_0[5]);
        second_0 = (single_0[0] & zero_0[1]) | (zero_0[0] & single_0[1]);
        lower_1 = {order_0_1, ~order_1_2, ~order_1_3, ~order_1_4, ~order_1_5, ~order_1_6};
        first_1 = ~|lower_1;
        zero_1[0] = ~(lower_1[0] | lower_1[1] | lower_1[2]);
        single_1[0] = (lower_1[0] & ~lower_1[1] & ~lower_1[2]) |
            (~lower_1[0] & lower_1[1] & ~lower_1[2]) | (~lower_1[0] & ~lower_1[1] & lower_1[2]);
        zero_1[1] = ~(lower_1[3] | lower_1[4] | lower_1[5]);
        single_1[1] = (lower_1[3] & ~lower_1[4] & ~lower_1[5]) |
            (~lower_1[3] & lower_1[4] & ~lower_1[5]) | (~lower_1[3] & ~lower_1[4] & lower_1[5]);
        second_1 = (single_1[0] & zero_1[1]) | (zero_1[0] & single_1[1]);
        lower_2 = {order_0_2, order_1_2, ~order_2_3, ~order_2_4, ~order_2_5, ~order_2_6};
        first_2 = ~|lower_2;
        zero_2[0] = ~(lower_2[0] | lower_2[1] | lower_2[2]);
        single_2[0] = (lower_2[0] & ~lower_2[1] & ~lower_2[2]) |
            (~lower_2[0] & lower_2[1] & ~lower_2[2]) | (~lower_2[0] & ~lower_2[1] & lower_2[2]);
        zero_2[1] = ~(lower_2[3] | lower_2[4] | lower_2[5]);
        single_2[1] = (lower_2[3] & ~lower_2[4] & ~lower_2[5]) |
            (~lower_2[3] & lower_2[4] & ~lower_2[5]) | (~lower_2[3] & ~lower_2[4] & lower_2[5]);
        second_2 = (single_2[0] & zero_2[1]) | (zero_2[0] & single_2[1]);
        lower_3 = {order_0_3, order_1_3, order_2_3, ~order_3_4, ~order_3_5, ~order_3_6};
        first_3 = ~|lower_3;
        zero_3[0] = ~(lower_3[0] | lower_3[1] | lower_3[2]);
        single_3[0] = (lower_3[0] & ~lower_3[1] & ~lower_3[2]) |
            (~lower_3[0] & lower_3[1] & ~lower_3[2]) | (~lower_3[0] & ~lower_3[1] & lower_3[2]);
        zero_3[1] = ~(lower_3[3] | lower_3[4] | lower_3[5]);
        single_3[1] = (lower_3[3] & ~lower_3[4] & ~lower_3[5]) |
            (~lower_3[3] & lower_3[4] & ~lower_3[5]) | (~lower_3[3] & ~lower_3[4] & lower_3[5]);
        second_3 = (single_3[0] & zero_3[1]) | (zero_3[0] & single_3[1]);
        lower_4 = {order_0_4, order_1_4, order_2_4, order_3_4, ~order_4_5, ~order_4_6};
        first_4 = ~|lower_4;
        zero_4[0] = ~(lower_4[0] | lower_4[1] | lower_4[2]);
        single_4[0] = (lower_4[0] & ~lower_4[1] & ~lower_4[2]) |
            (~lower_4[0] & lower_4[1] & ~lower_4[2]) | (~lower_4[0] & ~lower_4[1] & lower_4[2]);
        zero_4[1] = ~(lower_4[3] | lower_4[4] | lower_4[5]);
        single_4[1] = (lower_4[3] & ~lower_4[4] & ~lower_4[5]) |
            (~lower_4[3] & lower_4[4] & ~lower_4[5]) | (~lower_4[3] & ~lower_4[4] & lower_4[5]);
        second_4 = (single_4[0] & zero_4[1]) | (zero_4[0] & single_4[1]);
        lower_5 = {order_0_5, order_1_5, order_2_5, order_3_5, order_4_5, ~order_5_6};
        first_5 = ~|lower_5;
        zero_5[0] = ~(lower_5[0] | lower_5[1] | lower_5[2]);
        single_5[0] = (lower_5[0] & ~lower_5[1] & ~lower_5[2]) |
            (~lower_5[0] & lower_5[1] & ~lower_5[2]) | (~lower_5[0] & ~lower_5[1] & lower_5[2]);
        zero_5[1] = ~(lower_5[3] | lower_5[4] | lower_5[5]);
        single_5[1] = (lower_5[3] & ~lower_5[4] & ~lower_5[5]) |
            (~lower_5[3] & lower_5[4] & ~lower_5[5]) | (~lower_5[3] & ~lower_5[4] & lower_5[5]);
        second_5 = (single_5[0] & zero_5[1]) | (zero_5[0] & single_5[1]);
        lower_6 = {order_0_6, order_1_6, order_2_6, order_3_6, order_4_6, order_5_6};
        first_6 = ~|lower_6;
        zero_6[0] = ~(lower_6[0] | lower_6[1] | lower_6[2]);
        single_6[0] = (lower_6[0] & ~lower_6[1] & ~lower_6[2]) |
            (~lower_6[0] & lower_6[1] & ~lower_6[2]) | (~lower_6[0] & ~lower_6[1] & lower_6[2]);
        zero_6[1] = ~(lower_6[3] | lower_6[4] | lower_6[5]);
        single_6[1] = (lower_6[3] & ~lower_6[4] & ~lower_6[5]) |
            (~lower_6[3] & lower_6[4] & ~lower_6[5]) | (~lower_6[3] & ~lower_6[4] & lower_6[5]);
        second_6 = (single_6[0] & zero_6[1]) | (zero_6[0] & single_6[1]);
        first_value = ({5{first_0}} & values[4:0]) |
            ({5{first_1}} & values[9:5]) |
            ({5{first_2}} & values[14:10]) |
            ({5{first_3}} & values[19:15]) |
            ({5{first_4}} & values[24:20]) |
            ({5{first_5}} & values[29:25]) |
            ({5{first_6}} & values[34:30]);
        second_value = ({5{second_0}} & values[4:0]) |
            ({5{second_1}} & values[9:5]) |
            ({5{second_2}} & values[14:10]) |
            ({5{second_3}} & values[19:15]) |
            ({5{second_4}} & values[24:20]) |
            ({5{second_5}} & values[29:25]) |
            ({5{second_6}} & values[34:30]);
        selected_index[0] = first_1 | first_3 | first_5;
        selected_index[1] = first_2 | first_3 | first_6;
        selected_index[2] = first_4 | first_5 | first_6;
        minimum_flags = {second_6, second_5, second_4, second_3, second_2, second_1, second_0,
            first_6, first_5, first_4, first_3, first_2, first_1, first_0};
    end
endfunction
function signed [7:0] add_mag_op;
    input [7:0] value;
    input [4:0] magnitude;
    input negative;
    begin
        add_mag_op = value + ({3'b000, magnitude} ^ {8{negative}}) + {7'd0, negative};
    end
endfunction
function signed [7:0] add3_op;
    input [7:0] value;
    input [4:0] mag_a;
    input neg_a;
    input [4:0] mag_b;
    input neg_b;
    begin
        add3_op = value + ({3'b000, mag_a} ^ {8{neg_a}}) + ({3'b000, mag_b} ^ {8{neg_b}}) + {7'd0, neg_a} + {7'd0, neg_b};
    end
endfunction

// Sign-extend the stored 6-bit -R_old operand before adding it to a signed 8-bit bank word.
// The function result keeps Verilog 8-bit two's-complement semantics.
function signed [7:0] add_n_op;
    input [7:0] value;
    input [5:0] operand;
    begin
        add_n_op = value + {{2{operand[5]}}, operand};
    end
endfunction
// Update the live posterior as L - R_old + R_new.
// R_new is reconstructed from magnitude plus sign using bitwise inversion and the carry bit.
// No six-bit saturation is inserted into this posterior arithmetic.
function signed [7:0] add3n_op;
    input [7:0] value;
    input [5:0] operand;
    input [4:0] magnitude;
    input negative;
    begin
        add3n_op = value + {{2{operand[5]}}, operand} + ({3'b000, magnitude} ^ {8{negative}}) + {7'd0, negative};
    end
endfunction
// slot_mask selects one of eight step layouts. The first step overlaps the final input cycle.
// The final channel word is not needed by the active first half of layer zero.
// pending marks a completed iteration; syndrome is checked only at this boundary.
// lupd updates the check-source bank every layered step, or at a flooding iteration boundary.
// Serial input/output shifts are included in lupd so both banks preserve their required alignment.
assign decoding = state == S_DEC;
assign loading = state == S_LOAD && in_data_valid;
assign early = state == S_LOAD && slot_mask[0];
assign load_shift = loading && !slot_mask[0];
assign clearing = state == S_LOAD && !early;
assign syndrome_zero = ~|syndrome;
assign done = pending && (syndrome_zero || iteration == 4'd8);
assign abort = decoding && done;
assign update = decoding && !abort;
assign done_now = decoding && done;
assign out_valid = out_valid_r | done_now;
assign out_data = done_now ? snapshot[112] : out_data_r;
assign out_warn = done_now ? !syndrome_zero : out_warn_r;
assign in_word = {{2{in_data[5]}}, in_data};
assign out_word = snapshot[113];
assign serial_shift = load_shift || done_now || (state == S_OUT);
assign upd_sel = slot_mask & {8{~serial_shift}};
assign lupd = mode || slot_mask[7] || serial_shift;
assign lw_sel = upd_sel & {8{lupd}};
assign lh_sel = upd_sel & {8{~lupd}};

// Eight lanes are reused for the two halves of each of four layers.
// Each lane processes seven edges; variables within one layer belong to disjoint checks.
// A fixed permutation between steps brings the next 56 active variables to slots 0..55.
genvar n;
genvar e;
generate
    for (n = 0; n < 8; n = n + 1) begin: G_NODE
        wire [4:0] magnitude [0:6];
        wire [6:0] negative;
        wire [6:0] raw_signs;
        wire [13:0] flags;
        wire [4:0] normal [0:6];
        wire [4:0] norm_first;
        wire [4:0] norm_second;
        wire [2:0] index3;
        wire [6:0] tail_signs;
        // Seven outgoing signs have even parity because each is total_parity XOR its own input sign.
        // Thus XOR of the six saved outgoing signs reconstructs the omitted seventh sign.
        assign tail_signs = {^ring_tail[7 * n][18:13], ring_tail[7 * n][18:13]};
        wire [5:0] head_p1;
        wire [5:0] head_n1;
        wire [5:0] head_p2;
        wire [5:0] head_n2;
        assign head_p1 = {1'b0, ring_tail[7 * n][4:0]};
        assign head_n1 = 6'd0 - head_p1;
        assign head_p2 = {1'b0, ring_tail[7 * n][9:5]};
        assign head_n2 = 6'd0 - head_p2;
        // Convert the oldest compact record into next-cycle edge operands; rotate seven tail entries.
        // During loading, clearing forces zero records into the ring until the first decode step.
        always @(posedge clk) begin
            ring[n] <= {(tail_signs[6] ? ((ring_tail[7 * n][12:10] == 3'd6) ? head_p2 : head_p1) : ((ring_tail[7 * n][12:10] == 3'd6) ? head_n2 : head_n1)),
                (tail_signs[5] ? ((ring_tail[7 * n][12:10] == 3'd5) ? head_p2 : head_p1) : ((ring_tail[7 * n][12:10] == 3'd5) ? head_n2 : head_n1)),
                (tail_signs[4] ? ((ring_tail[7 * n][12:10] == 3'd4) ? head_p2 : head_p1) : ((ring_tail[7 * n][12:10] == 3'd4) ? head_n2 : head_n1)),
                (tail_signs[3] ? ((ring_tail[7 * n][12:10] == 3'd3) ? head_p2 : head_p1) : ((ring_tail[7 * n][12:10] == 3'd3) ? head_n2 : head_n1)),
                (tail_signs[2] ? ((ring_tail[7 * n][12:10] == 3'd2) ? head_p2 : head_p1) : ((ring_tail[7 * n][12:10] == 3'd2) ? head_n2 : head_n1)),
                (tail_signs[1] ? ((ring_tail[7 * n][12:10] == 3'd1) ? head_p2 : head_p1) : ((ring_tail[7 * n][12:10] == 3'd1) ? head_n2 : head_n1)),
                (tail_signs[0] ? ((ring_tail[7 * n][12:10] == 3'd0) ? head_p2 : head_p1) : ((ring_tail[7 * n][12:10] == 3'd0) ? head_n2 : head_n1))};
            ring_tail[7 * n + 0] <= ring_tail[7 * n + 1];
            ring_tail[7 * n + 1] <= ring_tail[7 * n + 2];
            ring_tail[7 * n + 2] <= ring_tail[7 * n + 3];
            ring_tail[7 * n + 3] <= ring_tail[7 * n + 4];
            ring_tail[7 * n + 4] <= ring_tail[7 * n + 5];
            ring_tail[7 * n + 5] <= ring_tail[7 * n + 6];
            ring_tail[7 * n + 6] <= {node_signs[n], node_index[n], node_second[n], node_first[n]};
        end
        for (e = 0; e < 7; e = e + 1) begin: G_EDGE
            wire signed [7:0] diff;
            wire [4:0] new_mag;
            wire new_neg;
            assign diff = add_n_op(posterior[7 * n + e], ring[n][6 * e +: 6]);
            assign magnitude[e] = saturated_magnitude(diff);
            assign negative[e] = diff[7];
            assign new_mag = flags[e] ? norm_second : norm_first;
            assign new_neg = raw_signs[e];
            assign wval[7 * n + e] = add3n_op(snapshot[7 * n + e], ring[n][6 * e +: 6], new_mag, new_neg);
        end
        assign flags = minimum_flags({magnitude[6], magnitude[5], magnitude[4], magnitude[3],
            magnitude[2], magnitude[1], magnitude[0]});
        assign normal[0] = normalized_min(magnitude[0]);
        assign normal[1] = normalized_min(magnitude[1]);
        assign normal[2] = normalized_min(magnitude[2]);
        assign normal[3] = normalized_min(magnitude[3]);
        assign normal[4] = normalized_min(magnitude[4]);
        assign normal[5] = normalized_min(magnitude[5]);
        assign normal[6] = normalized_min(magnitude[6]);
        assign norm_first = ({5{flags[0]}} & normal[0]) | ({5{flags[1]}} & normal[1]) | ({5{flags[2]}} & normal[2]) | ({5{flags[3]}} & normal[3]) | ({5{flags[4]}} & normal[4]) | ({5{flags[5]}} & normal[5]) | ({5{flags[6]}} & normal[6]);
        assign norm_second = ({5{flags[7]}} & normal[0]) | ({5{flags[8]}} & normal[1]) | ({5{flags[9]}} & normal[2]) | ({5{flags[10]}} & normal[3]) | ({5{flags[11]}} & normal[4]) | ({5{flags[12]}} & normal[5]) | ({5{flags[13]}} & normal[6]);
        assign index3 = {flags[4] | flags[5] | flags[6], flags[2] | flags[3] | flags[6], flags[1] | flags[3] | flags[5]};
        assign raw_signs = negative ^ {7{^negative}};
        assign node_first[n] = {5{~clearing}} & norm_first;
        assign node_second[n] = {5{~clearing}} & norm_second;
        assign node_index[n] = {3{~clearing}} & index3;
        assign node_signs[n] = {6{~clearing}} & raw_signs[5:0];
    end
endgenerate

// Only slots 0..55 are processed this step.
// The inactive half and absent-column slots pass through the live snapshot unchanged.
assign wval[56] = snapshot[56];
assign wval[57] = snapshot[57];
assign wval[58] = snapshot[58];
assign wval[59] = snapshot[59];
assign wval[60] = snapshot[60];
assign wval[61] = snapshot[61];
assign wval[62] = snapshot[62];
assign wval[63] = snapshot[63];
assign wval[64] = snapshot[64];
assign wval[65] = snapshot[65];
assign wval[66] = snapshot[66];
assign wval[67] = snapshot[67];
assign wval[68] = snapshot[68];
assign wval[69] = snapshot[69];
assign wval[70] = snapshot[70];
assign wval[71] = snapshot[71];
assign wval[72] = snapshot[72];
assign wval[73] = snapshot[73];
assign wval[74] = snapshot[74];
assign wval[75] = snapshot[75];
assign wval[76] = snapshot[76];
assign wval[77] = snapshot[77];
assign wval[78] = snapshot[78];
assign wval[79] = snapshot[79];
assign wval[80] = snapshot[80];
assign wval[81] = snapshot[81];
assign wval[82] = snapshot[82];
assign wval[83] = snapshot[83];
assign wval[84] = snapshot[84];
assign wval[85] = snapshot[85];
assign wval[86] = snapshot[86];
assign wval[87] = snapshot[87];
assign wval[88] = snapshot[88];
assign wval[89] = snapshot[89];
assign wval[90] = snapshot[90];
assign wval[91] = snapshot[91];
assign wval[92] = snapshot[92];
assign wval[93] = snapshot[93];
assign wval[94] = snapshot[94];
assign wval[95] = snapshot[95];
assign wval[96] = snapshot[96];
assign wval[97] = snapshot[97];
assign wval[98] = snapshot[98];
assign wval[99] = snapshot[99];
assign wval[100] = snapshot[100];
assign wval[101] = snapshot[101];
assign wval[102] = snapshot[102];
assign wval[103] = snapshot[103];
assign wval[104] = snapshot[104];
assign wval[105] = snapshot[105];
assign wval[106] = snapshot[106];
assign wval[107] = snapshot[107];
assign wval[108] = snapshot[108];
assign wval[109] = snapshot[109];
assign wval[110] = snapshot[110];
assign wval[111] = snapshot[111];
assign wval[112] = snapshot[112];
assign wval[113] = snapshot[113];
assign wval[114] = snapshot[114];
assign wval[115] = snapshot[115];
assign wval[116] = snapshot[116];
assign wval[117] = snapshot[117];
assign wval[118] = snapshot[118];
assign wval[119] = snapshot[119];
assign wval[120] = snapshot[120];
assign wval[121] = snapshot[121];
assign wval[122] = snapshot[122];
assign wval[123] = snapshot[123];
assign wval[124] = snapshot[124];
assign wval[125] = snapshot[125];
assign wval[126] = snapshot[126];
assign wval[127] = snapshot[127];

// All 64 parity equations read posterior signs in the boundary alignment.
// A zero syndrome ends decoding after at least one full iteration.
// Otherwise the eighth iteration terminates with out_warn asserted.
assign syndrome[0] = ^{snapshot[0][7], snapshot[1][7], snapshot[2][7], snapshot[3][7], snapshot[4][7], snapshot[5][7], snapshot[6][7]};
assign syndrome[1] = ^{snapshot[7][7], snapshot[8][7], snapshot[9][7], snapshot[10][7], snapshot[11][7], snapshot[12][7], snapshot[13][7]};
assign syndrome[2] = ^{snapshot[14][7], snapshot[15][7], snapshot[16][7], snapshot[17][7], snapshot[18][7], snapshot[19][7], snapshot[20][7]};
assign syndrome[3] = ^{snapshot[21][7], snapshot[22][7], snapshot[23][7], snapshot[24][7], snapshot[25][7], snapshot[26][7], snapshot[27][7]};
assign syndrome[4] = ^{snapshot[28][7], snapshot[29][7], snapshot[30][7], snapshot[31][7], snapshot[32][7], snapshot[33][7], snapshot[34][7]};
assign syndrome[5] = ^{snapshot[35][7], snapshot[36][7], snapshot[37][7], snapshot[38][7], snapshot[39][7], snapshot[40][7], snapshot[41][7]};
assign syndrome[6] = ^{snapshot[42][7], snapshot[43][7], snapshot[44][7], snapshot[45][7], snapshot[46][7], snapshot[47][7], snapshot[48][7]};
assign syndrome[7] = ^{snapshot[49][7], snapshot[50][7], snapshot[51][7], snapshot[52][7], snapshot[53][7], snapshot[54][7], snapshot[55][7]};
assign syndrome[8] = ^{snapshot[56][7], snapshot[57][7], snapshot[58][7], snapshot[59][7], snapshot[60][7], snapshot[61][7], snapshot[62][7]};
assign syndrome[9] = ^{snapshot[63][7], snapshot[64][7], snapshot[65][7], snapshot[66][7], snapshot[67][7], snapshot[68][7], snapshot[69][7]};
assign syndrome[10] = ^{snapshot[70][7], snapshot[71][7], snapshot[72][7], snapshot[73][7], snapshot[74][7], snapshot[75][7], snapshot[76][7]};
assign syndrome[11] = ^{snapshot[77][7], snapshot[78][7], snapshot[79][7], snapshot[80][7], snapshot[81][7], snapshot[82][7], snapshot[83][7]};
assign syndrome[12] = ^{snapshot[84][7], snapshot[85][7], snapshot[86][7], snapshot[87][7], snapshot[88][7], snapshot[89][7], snapshot[90][7]};
assign syndrome[13] = ^{snapshot[91][7], snapshot[92][7], snapshot[93][7], snapshot[94][7], snapshot[95][7], snapshot[96][7], snapshot[97][7]};
assign syndrome[14] = ^{snapshot[98][7], snapshot[99][7], snapshot[100][7], snapshot[101][7], snapshot[102][7], snapshot[103][7], snapshot[104][7]};
assign syndrome[15] = ^{snapshot[105][7], snapshot[106][7], snapshot[107][7], snapshot[108][7], snapshot[109][7], snapshot[110][7], snapshot[111][7]};
assign syndrome[16] = ^{snapshot[117][7], snapshot[29][7], snapshot[58][7], snapshot[38][7], snapshot[11][7], snapshot[26][7], snapshot[48][7]};
assign syndrome[17] = ^{snapshot[118][7], snapshot[36][7], snapshot[65][7], snapshot[45][7], snapshot[18][7], snapshot[33][7], snapshot[55][7]};
assign syndrome[18] = ^{snapshot[119][7], snapshot[43][7], snapshot[72][7], snapshot[52][7], snapshot[25][7], snapshot[40][7], snapshot[62][7]};
assign syndrome[19] = ^{snapshot[120][7], snapshot[50][7], snapshot[79][7], snapshot[59][7], snapshot[32][7], snapshot[47][7], snapshot[69][7]};
assign syndrome[20] = ^{snapshot[121][7], snapshot[57][7], snapshot[86][7], snapshot[66][7], snapshot[39][7], snapshot[54][7], snapshot[76][7]};
assign syndrome[21] = ^{snapshot[122][7], snapshot[64][7], snapshot[93][7], snapshot[73][7], snapshot[46][7], snapshot[61][7], snapshot[83][7]};
assign syndrome[22] = ^{snapshot[123][7], snapshot[71][7], snapshot[100][7], snapshot[80][7], snapshot[53][7], snapshot[68][7], snapshot[90][7]};
assign syndrome[23] = ^{snapshot[124][7], snapshot[78][7], snapshot[107][7], snapshot[87][7], snapshot[60][7], snapshot[75][7], snapshot[97][7]};
assign syndrome[24] = ^{snapshot[125][7], snapshot[85][7], snapshot[2][7], snapshot[94][7], snapshot[67][7], snapshot[82][7], snapshot[104][7]};
assign syndrome[25] = ^{snapshot[126][7], snapshot[92][7], snapshot[9][7], snapshot[101][7], snapshot[74][7], snapshot[89][7], snapshot[111][7]};
assign syndrome[26] = ^{snapshot[127][7], snapshot[99][7], snapshot[16][7], snapshot[108][7], snapshot[81][7], snapshot[96][7], snapshot[6][7]};
assign syndrome[27] = ^{snapshot[112][7], snapshot[106][7], snapshot[23][7], snapshot[3][7], snapshot[88][7], snapshot[103][7], snapshot[13][7]};
assign syndrome[28] = ^{snapshot[113][7], snapshot[1][7], snapshot[30][7], snapshot[10][7], snapshot[95][7], snapshot[110][7], snapshot[20][7]};
assign syndrome[29] = ^{snapshot[114][7], snapshot[8][7], snapshot[37][7], snapshot[17][7], snapshot[102][7], snapshot[5][7], snapshot[27][7]};
assign syndrome[30] = ^{snapshot[115][7], snapshot[15][7], snapshot[44][7], snapshot[24][7], snapshot[109][7], snapshot[12][7], snapshot[34][7]};
assign syndrome[31] = ^{snapshot[116][7], snapshot[22][7], snapshot[51][7], snapshot[31][7], snapshot[4][7], snapshot[19][7], snapshot[41][7]};
assign syndrome[32] = ^{snapshot[112][7], snapshot[49][7], snapshot[86][7], snapshot[94][7], snapshot[46][7], snapshot[33][7], snapshot[69][7]};
assign syndrome[33] = ^{snapshot[113][7], snapshot[56][7], snapshot[93][7], snapshot[101][7], snapshot[53][7], snapshot[40][7], snapshot[76][7]};
assign syndrome[34] = ^{snapshot[114][7], snapshot[63][7], snapshot[100][7], snapshot[108][7], snapshot[60][7], snapshot[47][7], snapshot[83][7]};
assign syndrome[35] = ^{snapshot[115][7], snapshot[70][7], snapshot[107][7], snapshot[3][7], snapshot[67][7], snapshot[54][7], snapshot[90][7]};
assign syndrome[36] = ^{snapshot[116][7], snapshot[77][7], snapshot[2][7], snapshot[10][7], snapshot[74][7], snapshot[61][7], snapshot[97][7]};
assign syndrome[37] = ^{snapshot[117][7], snapshot[84][7], snapshot[9][7], snapshot[17][7], snapshot[81][7], snapshot[68][7], snapshot[104][7]};
assign syndrome[38] = ^{snapshot[118][7], snapshot[91][7], snapshot[16][7], snapshot[24][7], snapshot[88][7], snapshot[75][7], snapshot[111][7]};
assign syndrome[39] = ^{snapshot[119][7], snapshot[98][7], snapshot[23][7], snapshot[31][7], snapshot[95][7], snapshot[82][7], snapshot[6][7]};
assign syndrome[40] = ^{snapshot[120][7], snapshot[105][7], snapshot[30][7], snapshot[38][7], snapshot[102][7], snapshot[89][7], snapshot[13][7]};
assign syndrome[41] = ^{snapshot[121][7], snapshot[0][7], snapshot[37][7], snapshot[45][7], snapshot[109][7], snapshot[96][7], snapshot[20][7]};
assign syndrome[42] = ^{snapshot[122][7], snapshot[7][7], snapshot[44][7], snapshot[52][7], snapshot[4][7], snapshot[103][7], snapshot[27][7]};
assign syndrome[43] = ^{snapshot[123][7], snapshot[14][7], snapshot[51][7], snapshot[59][7], snapshot[11][7], snapshot[110][7], snapshot[34][7]};
assign syndrome[44] = ^{snapshot[124][7], snapshot[21][7], snapshot[58][7], snapshot[66][7], snapshot[18][7], snapshot[5][7], snapshot[41][7]};
assign syndrome[45] = ^{snapshot[125][7], snapshot[28][7], snapshot[65][7], snapshot[73][7], snapshot[25][7], snapshot[12][7], snapshot[48][7]};
assign syndrome[46] = ^{snapshot[126][7], snapshot[35][7], snapshot[72][7], snapshot[80][7], snapshot[32][7], snapshot[19][7], snapshot[55][7]};
assign syndrome[47] = ^{snapshot[127][7], snapshot[42][7], snapshot[79][7], snapshot[87][7], snapshot[39][7], snapshot[26][7], snapshot[62][7]};
assign syndrome[48] = ^{snapshot[119][7], snapshot[14][7], snapshot[78][7], snapshot[10][7], snapshot[102][7], snapshot[68][7], snapshot[76][7]};
assign syndrome[49] = ^{snapshot[120][7], snapshot[21][7], snapshot[85][7], snapshot[17][7], snapshot[109][7], snapshot[75][7], snapshot[83][7]};
assign syndrome[50] = ^{snapshot[121][7], snapshot[28][7], snapshot[92][7], snapshot[24][7], snapshot[4][7], snapshot[82][7], snapshot[90][7]};
assign syndrome[51] = ^{snapshot[122][7], snapshot[35][7], snapshot[99][7], snapshot[31][7], snapshot[11][7], snapshot[89][7], snapshot[97][7]};
assign syndrome[52] = ^{snapshot[123][7], snapshot[42][7], snapshot[106][7], snapshot[38][7], snapshot[18][7], snapshot[96][7], snapshot[104][7]};
assign syndrome[53] = ^{snapshot[124][7], snapshot[49][7], snapshot[1][7], snapshot[45][7], snapshot[25][7], snapshot[103][7], snapshot[111][7]};
assign syndrome[54] = ^{snapshot[125][7], snapshot[56][7], snapshot[8][7], snapshot[52][7], snapshot[32][7], snapshot[110][7], snapshot[6][7]};
assign syndrome[55] = ^{snapshot[126][7], snapshot[63][7], snapshot[15][7], snapshot[59][7], snapshot[39][7], snapshot[5][7], snapshot[13][7]};
assign syndrome[56] = ^{snapshot[127][7], snapshot[70][7], snapshot[22][7], snapshot[66][7], snapshot[46][7], snapshot[12][7], snapshot[20][7]};
assign syndrome[57] = ^{snapshot[112][7], snapshot[77][7], snapshot[29][7], snapshot[73][7], snapshot[53][7], snapshot[19][7], snapshot[27][7]};
assign syndrome[58] = ^{snapshot[113][7], snapshot[84][7], snapshot[36][7], snapshot[80][7], snapshot[60][7], snapshot[26][7], snapshot[34][7]};
assign syndrome[59] = ^{snapshot[114][7], snapshot[91][7], snapshot[43][7], snapshot[87][7], snapshot[67][7], snapshot[33][7], snapshot[41][7]};
assign syndrome[60] = ^{snapshot[115][7], snapshot[98][7], snapshot[50][7], snapshot[94][7], snapshot[74][7], snapshot[40][7], snapshot[48][7]};
assign syndrome[61] = ^{snapshot[116][7], snapshot[105][7], snapshot[57][7], snapshot[101][7], snapshot[81][7], snapshot[47][7], snapshot[55][7]};
assign syndrome[62] = ^{snapshot[117][7], snapshot[0][7], snapshot[64][7], snapshot[108][7], snapshot[88][7], snapshot[54][7], snapshot[62][7]};
assign syndrome[63] = ^{snapshot[118][7], snapshot[7][7], snapshot[71][7], snapshot[3][7], snapshot[95][7], snapshot[61][7], snapshot[69][7]};

// The following unrolled equations implement fixed step-dependent permutations.
// snx is the next live snapshot value; the posterior reuses it whenever lupd is true.
// When flooding holds the check-source bank, the lh_sel terms only permute its old words.
// Serial shifts reuse the same wiring for natural-order channel loading and result output.
wire signed [7:0] snx_0;
assign snx_0 = ({8{serial_shift}} & snapshot[7]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[29]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[56]) | ({8{upd_sel[7]}} & wval[103]);
always @(posedge clk) begin
    posterior[0] <= ({8{lupd}} & snx_0) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[29]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[56]) | ({8{lh_sel[7]}} & posterior[103]);
    snapshot[0] <= snx_0;
end
wire signed [7:0] snx_1;
assign snx_1 = ({8{serial_shift}} & snapshot[8]) | ({8{upd_sel[7]}} & wval[41]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[57]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[58]);
always @(posedge clk) begin
    posterior[1] <= ({8{lupd}} & snx_1) | ({8{lh_sel[7]}} & posterior[41]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[57]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[58]);
    snapshot[1] <= snx_1;
end
wire signed [7:0] snx_2;
assign snx_2 = ({8{serial_shift}} & snapshot[9]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[38]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[58]) | ({8{upd_sel[7]}} & wval[122]);
always @(posedge clk) begin
    posterior[2] <= ({8{lupd}} & snx_2) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[38]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[58]) | ({8{lh_sel[7]}} & posterior[122]);
    snapshot[2] <= snx_2;
end
wire signed [7:0] snx_3;
assign snx_3 = ({8{serial_shift}} & snapshot[10]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[11]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[59]) | ({8{upd_sel[7]}} & wval[105]);
always @(posedge clk) begin
    posterior[3] <= ({8{lupd}} & snx_3) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[11]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[59]) | ({8{lh_sel[7]}} & posterior[105]);
    snapshot[3] <= snx_3;
end
wire signed [7:0] snx_4;
assign snx_4 = ({8{serial_shift}} & snapshot[11]) | ({8{upd_sel[7]}} & wval[15]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[26]) | ({8{upd_sel[5]}} & wval[54]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[60]);
always @(posedge clk) begin
    posterior[4] <= ({8{lupd}} & snx_4) | ({8{lh_sel[7]}} & posterior[15]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[26]) | ({8{lh_sel[5]}} & posterior[54]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[60]);
    snapshot[4] <= snx_4;
end
wire signed [7:0] snx_5;
assign snx_5 = ({8{serial_shift}} & snapshot[12]) | ({8{upd_sel[1]}} & wval[48]) | ({8{upd_sel[7]}} & wval[51]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[61]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[83]);
always @(posedge clk) begin
    posterior[5] <= ({8{lupd}} & snx_5) | ({8{lh_sel[1]}} & posterior[48]) | ({8{lh_sel[7]}} & posterior[51]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[61]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[83]);
    snapshot[5] <= snx_5;
end
wire signed [7:0] snx_6;
assign snx_6 = ({8{serial_shift}} & snapshot[13]) | ({8{upd_sel[7]}} & wval[45]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[62]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[125]);
always @(posedge clk) begin
    posterior[6] <= ({8{lupd}} & snx_6) | ({8{lh_sel[7]}} & posterior[45]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[62]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[125]);
    snapshot[6] <= snx_6;
end
wire signed [7:0] snx_7;
assign snx_7 = ({8{serial_shift}} & snapshot[43]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[36]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[63]) | ({8{upd_sel[7]}} & wval[110]);
always @(posedge clk) begin
    posterior[7] <= ({8{lupd}} & snx_7) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[36]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[63]) | ({8{lh_sel[7]}} & posterior[110]);
    snapshot[7] <= snx_7;
end
wire signed [7:0] snx_8;
assign snx_8 = ({8{serial_shift}} & snapshot[15]) | ({8{upd_sel[7]}} & wval[48]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[64]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[65]);
always @(posedge clk) begin
    posterior[8] <= ({8{lupd}} & snx_8) | ({8{lh_sel[7]}} & posterior[48]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[64]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[65]);
    snapshot[8] <= snx_8;
end
wire signed [7:0] snx_9;
assign snx_9 = ({8{serial_shift}} & snapshot[16]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[45]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[65]) | ({8{upd_sel[7]}} & wval[123]);
always @(posedge clk) begin
    posterior[9] <= ({8{lupd}} & snx_9) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[45]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[65]) | ({8{lh_sel[7]}} & posterior[123]);
    snapshot[9] <= snx_9;
end
wire signed [7:0] snx_10;
assign snx_10 = ({8{serial_shift}} & snapshot[17]) | ({8{upd_sel[7]}} & wval[0]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[18]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[66]);
always @(posedge clk) begin
    posterior[10] <= ({8{lupd}} & snx_10) | ({8{lh_sel[7]}} & posterior[0]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[18]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[66]);
    snapshot[10] <= snx_10;
end
wire signed [7:0] snx_11;
assign snx_11 = ({8{serial_shift}} & snapshot[18]) | ({8{upd_sel[7]}} & wval[22]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[33]) | ({8{upd_sel[5]}} & wval[61]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[67]);
always @(posedge clk) begin
    posterior[11] <= ({8{lupd}} & snx_11) | ({8{lh_sel[7]}} & posterior[22]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[33]) | ({8{lh_sel[5]}} & posterior[61]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[67]);
    snapshot[11] <= snx_11;
end
wire signed [7:0] snx_12;
assign snx_12 = ({8{serial_shift}} & snapshot[19]) | ({8{upd_sel[1]}} & wval[55]) | ({8{upd_sel[7]}} & wval[58]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[68]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[90]);
always @(posedge clk) begin
    posterior[12] <= ({8{lupd}} & snx_12) | ({8{lh_sel[1]}} & posterior[55]) | ({8{lh_sel[7]}} & posterior[58]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[68]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[90]);
    snapshot[12] <= snx_12;
end
wire signed [7:0] snx_13;
assign snx_13 = ({8{serial_shift}} & snapshot[20]) | ({8{upd_sel[7]}} & wval[52]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[69]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[126]);
always @(posedge clk) begin
    posterior[13] <= ({8{lupd}} & snx_13) | ({8{lh_sel[7]}} & posterior[52]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[69]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[126]);
    snapshot[13] <= snx_13;
end
wire signed [7:0] snx_14;
assign snx_14 = ({8{serial_shift}} & snapshot[21]) | ({8{upd_sel[7]}} & wval[5]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[43]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[70]);
always @(posedge clk) begin
    posterior[14] <= ({8{lupd}} & snx_14) | ({8{lh_sel[7]}} & posterior[5]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[43]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[70]);
    snapshot[14] <= snx_14;
end
wire signed [7:0] snx_15;
assign snx_15 = ({8{serial_shift}} & snapshot[22]) | ({8{upd_sel[7]}} & wval[55]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[71]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[72]);
always @(posedge clk) begin
    posterior[15] <= ({8{lupd}} & snx_15) | ({8{lh_sel[7]}} & posterior[55]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[71]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[72]);
    snapshot[15] <= snx_15;
end
wire signed [7:0] snx_16;
assign snx_16 = ({8{serial_shift}} & snapshot[23]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[52]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[72]) | ({8{upd_sel[7]}} & wval[124]);
always @(posedge clk) begin
    posterior[16] <= ({8{lupd}} & snx_16) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[52]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[72]) | ({8{lh_sel[7]}} & posterior[124]);
    snapshot[16] <= snx_16;
end
wire signed [7:0] snx_17;
assign snx_17 = ({8{serial_shift}} & snapshot[32]) | ({8{upd_sel[7]}} & wval[7]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[25]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[73]);
always @(posedge clk) begin
    posterior[17] <= ({8{lupd}} & snx_17) | ({8{lh_sel[7]}} & posterior[7]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[25]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[73]);
    snapshot[17] <= snx_17;
end
wire signed [7:0] snx_18;
assign snx_18 = ({8{serial_shift}} & snapshot[25]) | ({8{upd_sel[7]}} & wval[29]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[40]) | ({8{upd_sel[5]}} & wval[68]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[74]);
always @(posedge clk) begin
    posterior[18] <= ({8{lupd}} & snx_18) | ({8{lh_sel[7]}} & posterior[29]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[40]) | ({8{lh_sel[5]}} & posterior[68]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[74]);
    snapshot[18] <= snx_18;
end
wire signed [7:0] snx_19;
assign snx_19 = ({8{serial_shift}} & snapshot[26]) | ({8{upd_sel[1]}} & wval[62]) | ({8{upd_sel[7]}} & wval[65]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[75]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[97]);
always @(posedge clk) begin
    posterior[19] <= ({8{lupd}} & snx_19) | ({8{lh_sel[1]}} & posterior[62]) | ({8{lh_sel[7]}} & posterior[65]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[75]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[97]);
    snapshot[19] <= snx_19;
end
wire signed [7:0] snx_20;
assign snx_20 = ({8{serial_shift}} & snapshot[27]) | ({8{upd_sel[7]}} & wval[59]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[76]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[127]);
always @(posedge clk) begin
    posterior[20] <= ({8{lupd}} & snx_20) | ({8{lh_sel[7]}} & posterior[59]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[76]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[127]);
    snapshot[20] <= snx_20;
end
wire signed [7:0] snx_21;
assign snx_21 = ({8{serial_shift}} & snapshot[28]) | ({8{upd_sel[7]}} & wval[12]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[50]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[77]);
always @(posedge clk) begin
    posterior[21] <= ({8{lupd}} & snx_21) | ({8{lh_sel[7]}} & posterior[12]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[50]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[77]);
    snapshot[21] <= snx_21;
end
wire signed [7:0] snx_22;
assign snx_22 = ({8{serial_shift}} & snapshot[29]) | ({8{upd_sel[7]}} & wval[62]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[78]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[79]);
always @(posedge clk) begin
    posterior[22] <= ({8{lupd}} & snx_22) | ({8{lh_sel[7]}} & posterior[62]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[78]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[79]);
    snapshot[22] <= snx_22;
end
wire signed [7:0] snx_23;
assign snx_23 = ({8{serial_shift}} & snapshot[30]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[59]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[79]) | ({8{upd_sel[7]}} & wval[125]);
always @(posedge clk) begin
    posterior[23] <= ({8{lupd}} & snx_23) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[59]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[79]) | ({8{lh_sel[7]}} & posterior[125]);
    snapshot[23] <= snx_23;
end
wire signed [7:0] snx_24;
assign snx_24 = ({8{serial_shift}} & snapshot[31]) | ({8{upd_sel[7]}} & wval[14]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[32]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[80]);
always @(posedge clk) begin
    posterior[24] <= ({8{lupd}} & snx_24) | ({8{lh_sel[7]}} & posterior[14]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[32]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[80]);
    snapshot[24] <= snx_24;
end
wire signed [7:0] snx_25;
assign snx_25 = ({8{serial_shift}} & snapshot[54]) | ({8{upd_sel[7]}} & wval[36]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[47]) | ({8{upd_sel[5]}} & wval[75]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[81]);
always @(posedge clk) begin
    posterior[25] <= ({8{lupd}} & snx_25) | ({8{lh_sel[7]}} & posterior[36]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[47]) | ({8{lh_sel[5]}} & posterior[75]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[81]);
    snapshot[25] <= snx_25;
end
wire signed [7:0] snx_26;
assign snx_26 = ({8{serial_shift}} & snapshot[33]) | ({8{upd_sel[1]}} & wval[69]) | ({8{upd_sel[7]}} & wval[72]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[82]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[104]);
always @(posedge clk) begin
    posterior[26] <= ({8{lupd}} & snx_26) | ({8{lh_sel[1]}} & posterior[69]) | ({8{lh_sel[7]}} & posterior[72]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[82]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[104]);
    snapshot[26] <= snx_26;
end
wire signed [7:0] snx_27;
assign snx_27 = ({8{serial_shift}} & snapshot[34]) | ({8{upd_sel[7]}} & wval[66]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[83]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[112]);
always @(posedge clk) begin
    posterior[27] <= ({8{lupd}} & snx_27) | ({8{lh_sel[7]}} & posterior[66]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[83]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[112]);
    snapshot[27] <= snx_27;
end
wire signed [7:0] snx_28;
assign snx_28 = ({8{serial_shift}} & snapshot[35]) | ({8{upd_sel[7]}} & wval[19]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[57]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[84]);
always @(posedge clk) begin
    posterior[28] <= ({8{lupd}} & snx_28) | ({8{lh_sel[7]}} & posterior[19]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[57]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[84]);
    snapshot[28] <= snx_28;
end
wire signed [7:0] snx_29;
assign snx_29 = ({8{serial_shift}} & snapshot[36]) | ({8{upd_sel[7]}} & wval[69]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[85]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[86]);
always @(posedge clk) begin
    posterior[29] <= ({8{lupd}} & snx_29) | ({8{lh_sel[7]}} & posterior[69]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[85]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[86]);
    snapshot[29] <= snx_29;
end
wire signed [7:0] snx_30;
assign snx_30 = ({8{serial_shift}} & snapshot[37]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[66]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[86]) | ({8{upd_sel[7]}} & wval[126]);
always @(posedge clk) begin
    posterior[30] <= ({8{lupd}} & snx_30) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[66]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[86]) | ({8{lh_sel[7]}} & posterior[126]);
    snapshot[30] <= snx_30;
end
wire signed [7:0] snx_31;
assign snx_31 = ({8{serial_shift}} & snapshot[38]) | ({8{upd_sel[7]}} & wval[21]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[39]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[87]);
always @(posedge clk) begin
    posterior[31] <= ({8{lupd}} & snx_31) | ({8{lh_sel[7]}} & posterior[21]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[39]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[87]);
    snapshot[31] <= snx_31;
end
wire signed [7:0] snx_32;
assign snx_32 = ({8{serial_shift}} & snapshot[39]) | ({8{upd_sel[7]}} & wval[43]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[54]) | ({8{upd_sel[5]}} & wval[82]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[88]);
always @(posedge clk) begin
    posterior[32] <= ({8{lupd}} & snx_32) | ({8{lh_sel[7]}} & posterior[43]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[54]) | ({8{lh_sel[5]}} & posterior[82]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[88]);
    snapshot[32] <= snx_32;
end
wire signed [7:0] snx_33;
assign snx_33 = ({8{serial_shift}} & snapshot[40]) | ({8{upd_sel[1]}} & wval[76]) | ({8{upd_sel[7]}} & wval[79]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[89]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[111]);
always @(posedge clk) begin
    posterior[33] <= ({8{lupd}} & snx_33) | ({8{lh_sel[1]}} & posterior[76]) | ({8{lh_sel[7]}} & posterior[79]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[89]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[111]);
    snapshot[33] <= snx_33;
end
wire signed [7:0] snx_34;
assign snx_34 = ({8{serial_shift}} & snapshot[41]) | ({8{upd_sel[7]}} & wval[73]) | ({8{((upd_sel[0] & ~early) | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[90]) | ({8{early}} & in_word) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[113]);
always @(posedge clk) begin
    posterior[34] <= ({8{lupd}} & snx_34) | ({8{lh_sel[7]}} & posterior[73]) | ({8{((lh_sel[0] & ~early) | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[90]) | ({8{early}} & in_word) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[113]);
    snapshot[34] <= snx_34;
end
wire signed [7:0] snx_35;
assign snx_35 = ({8{serial_shift}} & snapshot[42]) | ({8{upd_sel[7]}} & wval[26]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[64]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[91]);
always @(posedge clk) begin
    posterior[35] <= ({8{lupd}} & snx_35) | ({8{lh_sel[7]}} & posterior[26]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[64]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[91]);
    snapshot[35] <= snx_35;
end
wire signed [7:0] snx_36;
assign snx_36 = ({8{serial_shift}} & snapshot[100]) | ({8{upd_sel[7]}} & wval[76]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[92]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[93]);
always @(posedge clk) begin
    posterior[36] <= ({8{lupd}} & snx_36) | ({8{lh_sel[7]}} & posterior[76]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[92]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[93]);
    snapshot[36] <= snx_36;
end
wire signed [7:0] snx_37;
assign snx_37 = ({8{serial_shift}} & snapshot[44]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[73]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[93]) | ({8{upd_sel[7]}} & wval[127]);
always @(posedge clk) begin
    posterior[37] <= ({8{lupd}} & snx_37) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[73]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[93]) | ({8{lh_sel[7]}} & posterior[127]);
    snapshot[37] <= snx_37;
end
wire signed [7:0] snx_38;
assign snx_38 = ({8{serial_shift}} & snapshot[45]) | ({8{upd_sel[7]}} & wval[28]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[46]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[94]);
always @(posedge clk) begin
    posterior[38] <= ({8{lupd}} & snx_38) | ({8{lh_sel[7]}} & posterior[28]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[46]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[94]);
    snapshot[38] <= snx_38;
end
wire signed [7:0] snx_39;
assign snx_39 = ({8{serial_shift}} & snapshot[46]) | ({8{upd_sel[7]}} & wval[50]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[61]) | ({8{upd_sel[5]}} & wval[89]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[95]);
always @(posedge clk) begin
    posterior[39] <= ({8{lupd}} & snx_39) | ({8{lh_sel[7]}} & posterior[50]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[61]) | ({8{lh_sel[5]}} & posterior[89]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[95]);
    snapshot[39] <= snx_39;
end
wire signed [7:0] snx_40;
assign snx_40 = ({8{serial_shift}} & snapshot[47]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[6]) | ({8{upd_sel[1]}} & wval[83]) | ({8{upd_sel[7]}} & wval[86]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[96]);
always @(posedge clk) begin
    posterior[40] <= ({8{lupd}} & snx_40) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[6]) | ({8{lh_sel[1]}} & posterior[83]) | ({8{lh_sel[7]}} & posterior[86]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[96]);
    snapshot[40] <= snx_40;
end
wire signed [7:0] snx_41;
assign snx_41 = ({8{serial_shift}} & snapshot[48]) | ({8{upd_sel[7]}} & wval[80]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[97]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[114]);
always @(posedge clk) begin
    posterior[41] <= ({8{lupd}} & snx_41) | ({8{lh_sel[7]}} & posterior[80]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[97]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[114]);
    snapshot[41] <= snx_41;
end
wire signed [7:0] snx_42;
assign snx_42 = ({8{serial_shift}} & snapshot[49]) | ({8{upd_sel[7]}} & wval[33]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[71]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[98]);
always @(posedge clk) begin
    posterior[42] <= ({8{lupd}} & snx_42) | ({8{lh_sel[7]}} & posterior[33]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[71]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[98]);
    snapshot[42] <= snx_42;
end
wire signed [7:0] snx_43;
assign snx_43 = ({8{serial_shift}} & snapshot[50]) | ({8{upd_sel[7]}} & wval[83]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[99]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[100]);
always @(posedge clk) begin
    posterior[43] <= ({8{lupd}} & snx_43) | ({8{lh_sel[7]}} & posterior[83]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[99]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[100]);
    snapshot[43] <= snx_43;
end
wire signed [7:0] snx_44;
assign snx_44 = ({8{serial_shift}} & snapshot[51]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[80]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[100]) | ({8{upd_sel[7]}} & wval[112]);
always @(posedge clk) begin
    posterior[44] <= ({8{lupd}} & snx_44) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[80]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[100]) | ({8{lh_sel[7]}} & posterior[112]);
    snapshot[44] <= snx_44;
end
wire signed [7:0] snx_45;
assign snx_45 = ({8{serial_shift}} & snapshot[52]) | ({8{upd_sel[7]}} & wval[35]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[53]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[101]);
always @(posedge clk) begin
    posterior[45] <= ({8{lupd}} & snx_45) | ({8{lh_sel[7]}} & posterior[35]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[53]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[101]);
    snapshot[45] <= snx_45;
end
wire signed [7:0] snx_46;
assign snx_46 = ({8{serial_shift}} & snapshot[53]) | ({8{upd_sel[7]}} & wval[57]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[68]) | ({8{upd_sel[5]}} & wval[96]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[102]);
always @(posedge clk) begin
    posterior[46] <= ({8{lupd}} & snx_46) | ({8{lh_sel[7]}} & posterior[57]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[68]) | ({8{lh_sel[5]}} & posterior[96]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[102]);
    snapshot[46] <= snx_46;
end
wire signed [7:0] snx_47;
assign snx_47 = ({8{serial_shift}} & snapshot[97]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[13]) | ({8{upd_sel[1]}} & wval[90]) | ({8{upd_sel[7]}} & wval[93]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[103]);
always @(posedge clk) begin
    posterior[47] <= ({8{lupd}} & snx_47) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[13]) | ({8{lh_sel[1]}} & posterior[90]) | ({8{lh_sel[7]}} & posterior[93]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[103]);
    snapshot[47] <= snx_47;
end
wire signed [7:0] snx_48;
assign snx_48 = ({8{serial_shift}} & snapshot[55]) | ({8{upd_sel[7]}} & wval[87]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[104]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[115]);
always @(posedge clk) begin
    posterior[48] <= ({8{lupd}} & snx_48) | ({8{lh_sel[7]}} & posterior[87]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[104]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[115]);
    snapshot[48] <= snx_48;
end
wire signed [7:0] snx_49;
assign snx_49 = ({8{serial_shift}} & snapshot[56]) | ({8{upd_sel[7]}} & wval[40]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[78]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[105]);
always @(posedge clk) begin
    posterior[49] <= ({8{lupd}} & snx_49) | ({8{lh_sel[7]}} & posterior[40]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[78]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[105]);
    snapshot[49] <= snx_49;
end
wire signed [7:0] snx_50;
assign snx_50 = ({8{serial_shift}} & snapshot[57]) | ({8{upd_sel[7]}} & wval[90]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[106]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[107]);
always @(posedge clk) begin
    posterior[50] <= ({8{lupd}} & snx_50) | ({8{lh_sel[7]}} & posterior[90]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[106]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[107]);
    snapshot[50] <= snx_50;
end
wire signed [7:0] snx_51;
assign snx_51 = ({8{serial_shift}} & snapshot[58]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[87]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[107]) | ({8{upd_sel[7]}} & wval[113]);
always @(posedge clk) begin
    posterior[51] <= ({8{lupd}} & snx_51) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[87]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[107]) | ({8{lh_sel[7]}} & posterior[113]);
    snapshot[51] <= snx_51;
end
wire signed [7:0] snx_52;
assign snx_52 = ({8{serial_shift}} & snapshot[59]) | ({8{upd_sel[7]}} & wval[42]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[60]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[108]);
always @(posedge clk) begin
    posterior[52] <= ({8{lupd}} & snx_52) | ({8{lh_sel[7]}} & posterior[42]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[60]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[108]);
    snapshot[52] <= snx_52;
end
wire signed [7:0] snx_53;
assign snx_53 = ({8{serial_shift}} & snapshot[60]) | ({8{upd_sel[7]}} & wval[64]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[75]) | ({8{upd_sel[5]}} & wval[103]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[109]);
always @(posedge clk) begin
    posterior[53] <= ({8{lupd}} & snx_53) | ({8{lh_sel[7]}} & posterior[64]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[75]) | ({8{lh_sel[5]}} & posterior[103]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[109]);
    snapshot[53] <= snx_53;
end
wire signed [7:0] snx_54;
assign snx_54 = ({8{serial_shift}} & snapshot[61]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[20]) | ({8{upd_sel[1]}} & wval[97]) | ({8{upd_sel[7]}} & wval[100]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[110]);
always @(posedge clk) begin
    posterior[54] <= ({8{lupd}} & snx_54) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[20]) | ({8{lh_sel[1]}} & posterior[97]) | ({8{lh_sel[7]}} & posterior[100]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[110]);
    snapshot[54] <= snx_54;
end
wire signed [7:0] snx_55;
assign snx_55 = ({8{serial_shift}} & snapshot[62]) | ({8{upd_sel[7]}} & wval[94]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[111]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[116]);
always @(posedge clk) begin
    posterior[55] <= ({8{lupd}} & snx_55) | ({8{lh_sel[7]}} & posterior[94]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[111]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[116]);
    snapshot[55] <= snx_55;
end
wire signed [7:0] snx_56;
assign snx_56 = ({8{serial_shift}} & snapshot[63]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[0]) | ({8{upd_sel[7]}} & wval[47]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[85]);
always @(posedge clk) begin
    posterior[56] <= ({8{lupd}} & snx_56) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[0]) | ({8{lh_sel[7]}} & posterior[47]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[85]);
    snapshot[56] <= snx_56;
end
wire signed [7:0] snx_57;
assign snx_57 = ({8{serial_shift}} & snapshot[64]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[1]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[2]) | ({8{upd_sel[7]}} & wval[97]);
always @(posedge clk) begin
    posterior[57] <= ({8{lupd}} & snx_57) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[1]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[2]) | ({8{lh_sel[7]}} & posterior[97]);
    snapshot[57] <= snx_57;
end
wire signed [7:0] snx_58;
assign snx_58 = ({8{serial_shift}} & snapshot[65]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[2]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[94]) | ({8{upd_sel[7]}} & wval[114]);
always @(posedge clk) begin
    posterior[58] <= ({8{lupd}} & snx_58) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[2]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[94]) | ({8{lh_sel[7]}} & posterior[114]);
    snapshot[58] <= snx_58;
end
wire signed [7:0] snx_59;
assign snx_59 = ({8{serial_shift}} & snapshot[66]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[3]) | ({8{upd_sel[7]}} & wval[49]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[67]);
always @(posedge clk) begin
    posterior[59] <= ({8{lupd}} & snx_59) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[3]) | ({8{lh_sel[7]}} & posterior[49]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[67]);
    snapshot[59] <= snx_59;
end
wire signed [7:0] snx_60;
assign snx_60 = ({8{serial_shift}} & snapshot[67]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[4]) | ({8{upd_sel[7]}} & wval[71]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[82]) | ({8{upd_sel[5]}} & wval[110]);
always @(posedge clk) begin
    posterior[60] <= ({8{lupd}} & snx_60) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[4]) | ({8{lh_sel[7]}} & posterior[71]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[82]) | ({8{lh_sel[5]}} & posterior[110]);
    snapshot[60] <= snx_60;
end
wire signed [7:0] snx_61;
assign snx_61 = ({8{serial_shift}} & snapshot[68]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[5]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[27]) | ({8{upd_sel[1]}} & wval[104]) | ({8{upd_sel[7]}} & wval[107]);
always @(posedge clk) begin
    posterior[61] <= ({8{lupd}} & snx_61) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[5]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[27]) | ({8{lh_sel[1]}} & posterior[104]) | ({8{lh_sel[7]}} & posterior[107]);
    snapshot[61] <= snx_61;
end
wire signed [7:0] snx_62;
assign snx_62 = ({8{serial_shift}} & snapshot[69]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[6]) | ({8{upd_sel[7]}} & wval[101]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[117]);
always @(posedge clk) begin
    posterior[62] <= ({8{lupd}} & snx_62) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[6]) | ({8{lh_sel[7]}} & posterior[101]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[117]);
    snapshot[62] <= snx_62;
end
wire signed [7:0] snx_63;
assign snx_63 = ({8{serial_shift}} & snapshot[70]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[7]) | ({8{upd_sel[7]}} & wval[54]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[92]);
always @(posedge clk) begin
    posterior[63] <= ({8{lupd}} & snx_63) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[7]) | ({8{lh_sel[7]}} & posterior[54]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[92]);
    snapshot[63] <= snx_63;
end
wire signed [7:0] snx_64;
assign snx_64 = ({8{serial_shift}} & snapshot[71]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[8]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[9]) | ({8{upd_sel[7]}} & wval[104]);
always @(posedge clk) begin
    posterior[64] <= ({8{lupd}} & snx_64) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[8]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[9]) | ({8{lh_sel[7]}} & posterior[104]);
    snapshot[64] <= snx_64;
end
wire signed [7:0] snx_65;
assign snx_65 = ({8{serial_shift}} & snapshot[72]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[9]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[101]) | ({8{upd_sel[7]}} & wval[115]);
always @(posedge clk) begin
    posterior[65] <= ({8{lupd}} & snx_65) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[9]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[101]) | ({8{lh_sel[7]}} & posterior[115]);
    snapshot[65] <= snx_65;
end
wire signed [7:0] snx_66;
assign snx_66 = ({8{serial_shift}} & snapshot[73]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[10]) | ({8{upd_sel[7]}} & wval[56]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[74]);
always @(posedge clk) begin
    posterior[66] <= ({8{lupd}} & snx_66) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[10]) | ({8{lh_sel[7]}} & posterior[56]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[74]);
    snapshot[66] <= snx_66;
end
wire signed [7:0] snx_67;
assign snx_67 = ({8{serial_shift}} & snapshot[74]) | ({8{upd_sel[5]}} & wval[5]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[11]) | ({8{upd_sel[7]}} & wval[78]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[89]);
always @(posedge clk) begin
    posterior[67] <= ({8{lupd}} & snx_67) | ({8{lh_sel[5]}} & posterior[5]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[11]) | ({8{lh_sel[7]}} & posterior[78]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[89]);
    snapshot[67] <= snx_67;
end
wire signed [7:0] snx_68;
assign snx_68 = ({8{serial_shift}} & snapshot[75]) | ({8{upd_sel[7]}} & wval[2]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[12]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[34]) | ({8{upd_sel[1]}} & wval[111]);
always @(posedge clk) begin
    posterior[68] <= ({8{lupd}} & snx_68) | ({8{lh_sel[7]}} & posterior[2]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[12]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[34]) | ({8{lh_sel[1]}} & posterior[111]);
    snapshot[68] <= snx_68;
end
wire signed [7:0] snx_69;
assign snx_69 = ({8{serial_shift}} & snapshot[76]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[13]) | ({8{upd_sel[7]}} & wval[108]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[118]);
always @(posedge clk) begin
    posterior[69] <= ({8{lupd}} & snx_69) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[13]) | ({8{lh_sel[7]}} & posterior[108]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[118]);
    snapshot[69] <= snx_69;
end
wire signed [7:0] snx_70;
assign snx_70 = ({8{serial_shift}} & snapshot[77]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[14]) | ({8{upd_sel[7]}} & wval[61]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[99]);
always @(posedge clk) begin
    posterior[70] <= ({8{lupd}} & snx_70) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[14]) | ({8{lh_sel[7]}} & posterior[61]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[99]);
    snapshot[70] <= snx_70;
end
wire signed [7:0] snx_71;
assign snx_71 = ({8{serial_shift}} & snapshot[78]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[15]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[16]) | ({8{upd_sel[7]}} & wval[111]);
always @(posedge clk) begin
    posterior[71] <= ({8{lupd}} & snx_71) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[15]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[16]) | ({8{lh_sel[7]}} & posterior[111]);
    snapshot[71] <= snx_71;
end
wire signed [7:0] snx_72;
assign snx_72 = ({8{serial_shift}} & snapshot[79]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[16]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[108]) | ({8{upd_sel[7]}} & wval[116]);
always @(posedge clk) begin
    posterior[72] <= ({8{lupd}} & snx_72) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[16]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[108]) | ({8{lh_sel[7]}} & posterior[116]);
    snapshot[72] <= snx_72;
end
wire signed [7:0] snx_73;
assign snx_73 = ({8{serial_shift}} & snapshot[80]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[17]) | ({8{upd_sel[7]}} & wval[63]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[81]);
always @(posedge clk) begin
    posterior[73] <= ({8{lupd}} & snx_73) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[17]) | ({8{lh_sel[7]}} & posterior[63]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[81]);
    snapshot[73] <= snx_73;
end
wire signed [7:0] snx_74;
assign snx_74 = ({8{serial_shift}} & snapshot[81]) | ({8{upd_sel[5]}} & wval[12]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[18]) | ({8{upd_sel[7]}} & wval[85]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[96]);
always @(posedge clk) begin
    posterior[74] <= ({8{lupd}} & snx_74) | ({8{lh_sel[5]}} & posterior[12]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[18]) | ({8{lh_sel[7]}} & posterior[85]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[96]);
    snapshot[74] <= snx_74;
end
wire signed [7:0] snx_75;
assign snx_75 = ({8{serial_shift}} & snapshot[82]) | ({8{upd_sel[1]}} & wval[6]) | ({8{upd_sel[7]}} & wval[9]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[19]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[41]);
always @(posedge clk) begin
    posterior[75] <= ({8{lupd}} & snx_75) | ({8{lh_sel[1]}} & posterior[6]) | ({8{lh_sel[7]}} & posterior[9]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[19]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[41]);
    snapshot[75] <= snx_75;
end
wire signed [7:0] snx_76;
assign snx_76 = ({8{serial_shift}} & snapshot[83]) | ({8{upd_sel[7]}} & wval[3]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[20]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[119]);
always @(posedge clk) begin
    posterior[76] <= ({8{lupd}} & snx_76) | ({8{lh_sel[7]}} & posterior[3]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[20]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[119]);
    snapshot[76] <= snx_76;
end
wire signed [7:0] snx_77;
assign snx_77 = ({8{serial_shift}} & snapshot[84]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[21]) | ({8{upd_sel[7]}} & wval[68]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[106]);
always @(posedge clk) begin
    posterior[77] <= ({8{lupd}} & snx_77) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[21]) | ({8{lh_sel[7]}} & posterior[68]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[106]);
    snapshot[77] <= snx_77;
end
wire signed [7:0] snx_78;
assign snx_78 = ({8{serial_shift}} & snapshot[85]) | ({8{upd_sel[7]}} & wval[6]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[22]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[23]);
always @(posedge clk) begin
    posterior[78] <= ({8{lupd}} & snx_78) | ({8{lh_sel[7]}} & posterior[6]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[22]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[23]);
    snapshot[78] <= snx_78;
end
wire signed [7:0] snx_79;
assign snx_79 = ({8{serial_shift}} & snapshot[86]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[3]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[23]) | ({8{upd_sel[7]}} & wval[117]);
always @(posedge clk) begin
    posterior[79] <= ({8{lupd}} & snx_79) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[3]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[23]) | ({8{lh_sel[7]}} & posterior[117]);
    snapshot[79] <= snx_79;
end
wire signed [7:0] snx_80;
assign snx_80 = ({8{serial_shift}} & snapshot[87]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[24]) | ({8{upd_sel[7]}} & wval[70]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[88]);
always @(posedge clk) begin
    posterior[80] <= ({8{lupd}} & snx_80) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[24]) | ({8{lh_sel[7]}} & posterior[70]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[88]);
    snapshot[80] <= snx_80;
end
wire signed [7:0] snx_81;
assign snx_81 = ({8{serial_shift}} & snapshot[88]) | ({8{upd_sel[5]}} & wval[19]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[25]) | ({8{upd_sel[7]}} & wval[92]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[103]);
always @(posedge clk) begin
    posterior[81] <= ({8{lupd}} & snx_81) | ({8{lh_sel[5]}} & posterior[19]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[25]) | ({8{lh_sel[7]}} & posterior[92]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[103]);
    snapshot[81] <= snx_81;
end
wire signed [7:0] snx_82;
assign snx_82 = ({8{serial_shift}} & snapshot[89]) | ({8{upd_sel[1]}} & wval[13]) | ({8{upd_sel[7]}} & wval[16]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[26]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[48]);
always @(posedge clk) begin
    posterior[82] <= ({8{lupd}} & snx_82) | ({8{lh_sel[1]}} & posterior[13]) | ({8{lh_sel[7]}} & posterior[16]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[26]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[48]);
    snapshot[82] <= snx_82;
end
wire signed [7:0] snx_83;
assign snx_83 = ({8{serial_shift}} & (loading ? in_word : snapshot[90])) | ({8{upd_sel[7]}} & wval[10]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[27]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[120]);
always @(posedge clk) begin
    posterior[83] <= ({8{lupd}} & snx_83) | ({8{lh_sel[7]}} & posterior[10]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[27]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[120]);
    snapshot[83] <= snx_83;
end
wire signed [7:0] snx_84;
assign snx_84 = ({8{serial_shift}} & snapshot[91]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[1]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[28]) | ({8{upd_sel[7]}} & wval[75]);
always @(posedge clk) begin
    posterior[84] <= ({8{lupd}} & snx_84) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[1]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[28]) | ({8{lh_sel[7]}} & posterior[75]);
    snapshot[84] <= snx_84;
end
wire signed [7:0] snx_85;
assign snx_85 = ({8{serial_shift}} & snapshot[92]) | ({8{upd_sel[7]}} & wval[13]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[29]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[30]);
always @(posedge clk) begin
    posterior[85] <= ({8{lupd}} & snx_85) | ({8{lh_sel[7]}} & posterior[13]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[29]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[30]);
    snapshot[85] <= snx_85;
end
wire signed [7:0] snx_86;
assign snx_86 = ({8{serial_shift}} & snapshot[93]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[10]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[30]) | ({8{upd_sel[7]}} & wval[118]);
always @(posedge clk) begin
    posterior[86] <= ({8{lupd}} & snx_86) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[10]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[30]) | ({8{lh_sel[7]}} & posterior[118]);
    snapshot[86] <= snx_86;
end
wire signed [7:0] snx_87;
assign snx_87 = ({8{serial_shift}} & snapshot[94]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[31]) | ({8{upd_sel[7]}} & wval[77]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[95]);
always @(posedge clk) begin
    posterior[87] <= ({8{lupd}} & snx_87) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[31]) | ({8{lh_sel[7]}} & posterior[77]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[95]);
    snapshot[87] <= snx_87;
end
wire signed [7:0] snx_88;
assign snx_88 = ({8{serial_shift}} & snapshot[95]) | ({8{upd_sel[5]}} & wval[26]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[32]) | ({8{upd_sel[7]}} & wval[99]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[110]);
always @(posedge clk) begin
    posterior[88] <= ({8{lupd}} & snx_88) | ({8{lh_sel[5]}} & posterior[26]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[32]) | ({8{lh_sel[7]}} & posterior[99]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[110]);
    snapshot[88] <= snx_88;
end
wire signed [7:0] snx_89;
assign snx_89 = ({8{serial_shift}} & snapshot[96]) | ({8{upd_sel[1]}} & wval[20]) | ({8{upd_sel[7]}} & wval[23]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[33]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[55]);
always @(posedge clk) begin
    posterior[89] <= ({8{lupd}} & snx_89) | ({8{lh_sel[1]}} & posterior[20]) | ({8{lh_sel[7]}} & posterior[23]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[33]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[55]);
    snapshot[89] <= snx_89;
end
wire signed [7:0] snx_90;
assign snx_90 = ({8{serial_shift}} & in_word) | ({8{upd_sel[7]}} & wval[17]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[34]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[121]);
always @(posedge clk) begin
    posterior[90] <= ({8{lupd}} & snx_90) | ({8{lh_sel[7]}} & posterior[17]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[34]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[121]);
    snapshot[90] <= snx_90;
end
wire signed [7:0] snx_91;
assign snx_91 = ({8{serial_shift}} & snapshot[98]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[8]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[35]) | ({8{upd_sel[7]}} & wval[82]);
always @(posedge clk) begin
    posterior[91] <= ({8{lupd}} & snx_91) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[8]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[35]) | ({8{lh_sel[7]}} & posterior[82]);
    snapshot[91] <= snx_91;
end
wire signed [7:0] snx_92;
assign snx_92 = ({8{serial_shift}} & snapshot[99]) | ({8{upd_sel[7]}} & wval[20]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[36]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[37]);
always @(posedge clk) begin
    posterior[92] <= ({8{lupd}} & snx_92) | ({8{lh_sel[7]}} & posterior[20]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[36]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[37]);
    snapshot[92] <= snx_92;
end
wire signed [7:0] snx_93;
assign snx_93 = ({8{serial_shift}} & snapshot[24]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[17]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[37]) | ({8{upd_sel[7]}} & wval[119]);
always @(posedge clk) begin
    posterior[93] <= ({8{lupd}} & snx_93) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[17]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[37]) | ({8{lh_sel[7]}} & posterior[119]);
    snapshot[93] <= snx_93;
end
wire signed [7:0] snx_94;
assign snx_94 = ({8{serial_shift}} & snapshot[101]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[38]) | ({8{upd_sel[7]}} & wval[84]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[102]);
always @(posedge clk) begin
    posterior[94] <= ({8{lupd}} & snx_94) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[38]) | ({8{lh_sel[7]}} & posterior[84]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[102]);
    snapshot[94] <= snx_94;
end
wire signed [7:0] snx_95;
assign snx_95 = ({8{serial_shift}} & snapshot[102]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[5]) | ({8{upd_sel[5]}} & wval[33]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[39]) | ({8{upd_sel[7]}} & wval[106]);
always @(posedge clk) begin
    posterior[95] <= ({8{lupd}} & snx_95) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[5]) | ({8{lh_sel[5]}} & posterior[33]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[39]) | ({8{lh_sel[7]}} & posterior[106]);
    snapshot[95] <= snx_95;
end
wire signed [7:0] snx_96;
assign snx_96 = ({8{serial_shift}} & snapshot[103]) | ({8{upd_sel[1]}} & wval[27]) | ({8{upd_sel[7]}} & wval[30]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[40]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[62]);
always @(posedge clk) begin
    posterior[96] <= ({8{lupd}} & snx_96) | ({8{lh_sel[1]}} & posterior[27]) | ({8{lh_sel[7]}} & posterior[30]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[40]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[62]);
    snapshot[96] <= snx_96;
end
wire signed [7:0] snx_97;
assign snx_97 = ({8{serial_shift}} & snapshot[104]) | ({8{upd_sel[7]}} & wval[24]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[41]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[122]);
always @(posedge clk) begin
    posterior[97] <= ({8{lupd}} & snx_97) | ({8{lh_sel[7]}} & posterior[24]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[41]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[122]);
    snapshot[97] <= snx_97;
end
wire signed [7:0] snx_98;
assign snx_98 = ({8{serial_shift}} & snapshot[105]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[15]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[42]) | ({8{upd_sel[7]}} & wval[89]);
always @(posedge clk) begin
    posterior[98] <= ({8{lupd}} & snx_98) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[15]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[42]) | ({8{lh_sel[7]}} & posterior[89]);
    snapshot[98] <= snx_98;
end
wire signed [7:0] snx_99;
assign snx_99 = ({8{serial_shift}} & snapshot[106]) | ({8{upd_sel[7]}} & wval[27]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[43]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[44]);
always @(posedge clk) begin
    posterior[99] <= ({8{lupd}} & snx_99) | ({8{lh_sel[7]}} & posterior[27]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[43]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[44]);
    snapshot[99] <= snx_99;
end
wire signed [7:0] snx_100;
assign snx_100 = ({8{serial_shift}} & snapshot[107]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[24]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[44]) | ({8{upd_sel[7]}} & wval[120]);
always @(posedge clk) begin
    posterior[100] <= ({8{lupd}} & snx_100) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[24]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[44]) | ({8{lh_sel[7]}} & posterior[120]);
    snapshot[100] <= snx_100;
end
wire signed [7:0] snx_101;
assign snx_101 = ({8{serial_shift}} & snapshot[108]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[45]) | ({8{upd_sel[7]}} & wval[91]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[109]);
always @(posedge clk) begin
    posterior[101] <= ({8{lupd}} & snx_101) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[45]) | ({8{lh_sel[7]}} & posterior[91]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[109]);
    snapshot[101] <= snx_101;
end
wire signed [7:0] snx_102;
assign snx_102 = ({8{serial_shift}} & snapshot[109]) | ({8{upd_sel[7]}} & wval[1]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[12]) | ({8{upd_sel[5]}} & wval[40]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[46]);
always @(posedge clk) begin
    posterior[102] <= ({8{lupd}} & snx_102) | ({8{lh_sel[7]}} & posterior[1]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[12]) | ({8{lh_sel[5]}} & posterior[40]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[46]);
    snapshot[102] <= snx_102;
end
wire signed [7:0] snx_103;
assign snx_103 = ({8{serial_shift}} & snapshot[110]) | ({8{upd_sel[1]}} & wval[34]) | ({8{upd_sel[7]}} & wval[37]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[47]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[69]);
always @(posedge clk) begin
    posterior[103] <= ({8{lupd}} & snx_103) | ({8{lh_sel[1]}} & posterior[34]) | ({8{lh_sel[7]}} & posterior[37]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[47]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[69]);
    snapshot[103] <= snx_103;
end
wire signed [7:0] snx_104;
assign snx_104 = ({8{serial_shift}} & snapshot[111]) | ({8{upd_sel[7]}} & wval[31]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[48]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[123]);
always @(posedge clk) begin
    posterior[104] <= ({8{lupd}} & snx_104) | ({8{lh_sel[7]}} & posterior[31]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[48]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[123]);
    snapshot[104] <= snx_104;
end
wire signed [7:0] snx_105;
assign snx_105 = ({8{serial_shift}} & snapshot[0]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[22]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[49]) | ({8{upd_sel[7]}} & wval[96]);
always @(posedge clk) begin
    posterior[105] <= ({8{lupd}} & snx_105) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[22]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[49]) | ({8{lh_sel[7]}} & posterior[96]);
    snapshot[105] <= snx_105;
end
wire signed [7:0] snx_106;
assign snx_106 = ({8{serial_shift}} & snapshot[1]) | ({8{upd_sel[7]}} & wval[34]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[50]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[51]);
always @(posedge clk) begin
    posterior[106] <= ({8{lupd}} & snx_106) | ({8{lh_sel[7]}} & posterior[34]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[50]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[51]);
    snapshot[106] <= snx_106;
end
wire signed [7:0] snx_107;
assign snx_107 = ({8{serial_shift}} & snapshot[2]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[31]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[51]) | ({8{upd_sel[7]}} & wval[121]);
always @(posedge clk) begin
    posterior[107] <= ({8{lupd}} & snx_107) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[31]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[51]) | ({8{lh_sel[7]}} & posterior[121]);
    snapshot[107] <= snx_107;
end
wire signed [7:0] snx_108;
assign snx_108 = ({8{serial_shift}} & snapshot[3]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[4]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[52]) | ({8{upd_sel[7]}} & wval[98]);
always @(posedge clk) begin
    posterior[108] <= ({8{lupd}} & snx_108) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[4]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[52]) | ({8{lh_sel[7]}} & posterior[98]);
    snapshot[108] <= snx_108;
end
wire signed [7:0] snx_109;
assign snx_109 = ({8{serial_shift}} & snapshot[4]) | ({8{upd_sel[7]}} & wval[8]) | ({8{(upd_sel[1] | upd_sel[3])}} & wval[19]) | ({8{upd_sel[5]}} & wval[47]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[53]);
always @(posedge clk) begin
    posterior[109] <= ({8{lupd}} & snx_109) | ({8{lh_sel[7]}} & posterior[8]) | ({8{(lh_sel[1] | lh_sel[3])}} & posterior[19]) | ({8{lh_sel[5]}} & posterior[47]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[53]);
    snapshot[109] <= snx_109;
end
wire signed [7:0] snx_110;
assign snx_110 = ({8{serial_shift}} & snapshot[5]) | ({8{upd_sel[1]}} & wval[41]) | ({8{upd_sel[7]}} & wval[44]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[54]) | ({8{(upd_sel[3] | upd_sel[5])}} & wval[76]);
always @(posedge clk) begin
    posterior[110] <= ({8{lupd}} & snx_110) | ({8{lh_sel[1]}} & posterior[41]) | ({8{lh_sel[7]}} & posterior[44]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[54]) | ({8{(lh_sel[3] | lh_sel[5])}} & posterior[76]);
    snapshot[110] <= snx_110;
end
wire signed [7:0] snx_111;
assign snx_111 = ({8{serial_shift}} & snapshot[6]) | ({8{upd_sel[7]}} & wval[38]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[55]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[124]);
always @(posedge clk) begin
    posterior[111] <= ({8{lupd}} & snx_111) | ({8{lh_sel[7]}} & posterior[38]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[55]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[124]);
    snapshot[111] <= snx_111;
end
wire signed [7:0] snx_112;
assign snx_112 = ({8{serial_shift}} & snapshot[113]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[14]) | ({8{upd_sel[7]}} & wval[67]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[112]);
always @(posedge clk) begin
    posterior[112] <= ({8{lupd}} & snx_112) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[14]) | ({8{lh_sel[7]}} & posterior[67]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[112]);
    snapshot[112] <= snx_112;
end
wire signed [7:0] snx_113;
assign snx_113 = ({8{serial_shift}} & snapshot[114]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[21]) | ({8{upd_sel[7]}} & wval[74]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[113]);
always @(posedge clk) begin
    posterior[113] <= ({8{lupd}} & snx_113) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[21]) | ({8{lh_sel[7]}} & posterior[74]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[113]);
    snapshot[113] <= snx_113;
end
wire signed [7:0] snx_114;
assign snx_114 = ({8{serial_shift}} & snapshot[115]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[28]) | ({8{upd_sel[7]}} & wval[81]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[114]);
always @(posedge clk) begin
    posterior[114] <= ({8{lupd}} & snx_114) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[28]) | ({8{lh_sel[7]}} & posterior[81]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[114]);
    snapshot[114] <= snx_114;
end
wire signed [7:0] snx_115;
assign snx_115 = ({8{serial_shift}} & snapshot[116]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[35]) | ({8{upd_sel[7]}} & wval[88]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[115]);
always @(posedge clk) begin
    posterior[115] <= ({8{lupd}} & snx_115) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[35]) | ({8{lh_sel[7]}} & posterior[88]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[115]);
    snapshot[115] <= snx_115;
end
wire signed [7:0] snx_116;
assign snx_116 = ({8{serial_shift}} & snapshot[117]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[42]) | ({8{upd_sel[7]}} & wval[95]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[116]);
always @(posedge clk) begin
    posterior[116] <= ({8{lupd}} & snx_116) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[42]) | ({8{lh_sel[7]}} & posterior[95]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[116]);
    snapshot[116] <= snx_116;
end
wire signed [7:0] snx_117;
assign snx_117 = ({8{serial_shift}} & snapshot[118]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[49]) | ({8{upd_sel[7]}} & wval[102]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[117]);
always @(posedge clk) begin
    posterior[117] <= ({8{lupd}} & snx_117) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[49]) | ({8{lh_sel[7]}} & posterior[102]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[117]);
    snapshot[117] <= snx_117;
end
wire signed [7:0] snx_118;
assign snx_118 = ({8{serial_shift}} & snapshot[119]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[56]) | ({8{upd_sel[7]}} & wval[109]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[118]);
always @(posedge clk) begin
    posterior[118] <= ({8{lupd}} & snx_118) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[56]) | ({8{lh_sel[7]}} & posterior[109]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[118]);
    snapshot[118] <= snx_118;
end
wire signed [7:0] snx_119;
assign snx_119 = ({8{serial_shift}} & snapshot[120]) | ({8{upd_sel[7]}} & wval[4]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[63]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[119]);
always @(posedge clk) begin
    posterior[119] <= ({8{lupd}} & snx_119) | ({8{lh_sel[7]}} & posterior[4]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[63]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[119]);
    snapshot[119] <= snx_119;
end
wire signed [7:0] snx_120;
assign snx_120 = ({8{serial_shift}} & snapshot[121]) | ({8{upd_sel[7]}} & wval[11]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[70]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[120]);
always @(posedge clk) begin
    posterior[120] <= ({8{lupd}} & snx_120) | ({8{lh_sel[7]}} & posterior[11]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[70]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[120]);
    snapshot[120] <= snx_120;
end
wire signed [7:0] snx_121;
assign snx_121 = ({8{serial_shift}} & snapshot[122]) | ({8{upd_sel[7]}} & wval[18]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[77]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[121]);
always @(posedge clk) begin
    posterior[121] <= ({8{lupd}} & snx_121) | ({8{lh_sel[7]}} & posterior[18]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[77]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[121]);
    snapshot[121] <= snx_121;
end
wire signed [7:0] snx_122;
assign snx_122 = ({8{serial_shift}} & snapshot[123]) | ({8{upd_sel[7]}} & wval[25]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[84]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[122]);
always @(posedge clk) begin
    posterior[122] <= ({8{lupd}} & snx_122) | ({8{lh_sel[7]}} & posterior[25]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[84]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[122]);
    snapshot[122] <= snx_122;
end
wire signed [7:0] snx_123;
assign snx_123 = ({8{serial_shift}} & snapshot[124]) | ({8{upd_sel[7]}} & wval[32]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[91]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[123]);
always @(posedge clk) begin
    posterior[123] <= ({8{lupd}} & snx_123) | ({8{lh_sel[7]}} & posterior[32]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[91]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[123]);
    snapshot[123] <= snx_123;
end
wire signed [7:0] snx_124;
assign snx_124 = ({8{serial_shift}} & snapshot[125]) | ({8{upd_sel[7]}} & wval[39]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[98]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[124]);
always @(posedge clk) begin
    posterior[124] <= ({8{lupd}} & snx_124) | ({8{lh_sel[7]}} & posterior[39]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[98]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[124]);
    snapshot[124] <= snx_124;
end
wire signed [7:0] snx_125;
assign snx_125 = ({8{serial_shift}} & snapshot[126]) | ({8{upd_sel[7]}} & wval[46]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[105]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[125]);
always @(posedge clk) begin
    posterior[125] <= ({8{lupd}} & snx_125) | ({8{lh_sel[7]}} & posterior[46]) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[105]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[125]);
    snapshot[125] <= snx_125;
end
wire signed [7:0] snx_126;
assign snx_126 = ({8{serial_shift}} & snapshot[127]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[0]) | ({8{upd_sel[7]}} & wval[53]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[126]);
always @(posedge clk) begin
    posterior[126] <= ({8{lupd}} & snx_126) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[0]) | ({8{lh_sel[7]}} & posterior[53]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[126]);
    snapshot[126] <= snx_126;
end
wire signed [7:0] snx_127;
assign snx_127 = ({8{serial_shift}} & snapshot[14]) | ({8{(upd_sel[1] | upd_sel[3] | upd_sel[5])}} & wval[7]) | ({8{upd_sel[7]}} & wval[60]) | ({8{(upd_sel[0] | upd_sel[2] | upd_sel[4] | upd_sel[6])}} & wval[127]);
always @(posedge clk) begin
    posterior[127] <= ({8{lupd}} & snx_127) | ({8{(lh_sel[1] | lh_sel[3] | lh_sel[5])}} & posterior[7]) | ({8{lh_sel[7]}} & posterior[60]) | ({8{(lh_sel[0] | lh_sel[2] | lh_sel[4] | lh_sel[6])}} & posterior[127]);
    snapshot[127] <= snx_127;
end

// Only control and registered outputs need asynchronous reset.
// Every accepted frame loads all 128 words and clears old record contents before use.
// At step seven, increment the iteration counter and schedule the syndrome decision.
// done_now emits output word zero; the registered path then emits words one through 127.
// Outputs return to zero in WAIT; no reset is required between complete transactions.
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_WAIT;
        mode <= 1'b0;
        idx <= 7'd0;
        slot <= 3'd0;
        slot_mask <= 8'b00000000;
        iteration <= 4'd0;
        pending <= 1'b0;
        warn <= 1'b0;
        out_valid_r <= 1'b0;
        out_data_r <= 8'd0;
        out_warn_r <= 1'b0;
    end else begin
        out_valid_r <= 1'b0;
        out_data_r <= 8'd0;
        out_warn_r <= 1'b0;
        pending <= 1'b0;
            case (state)
                S_WAIT: begin
                    idx <= 7'd0;
                    slot <= 3'd0;
                    slot_mask <= 8'b00000000;
                    iteration <= 4'd0;
                    warn <= 1'b0;
                    if (in_mode_valid) begin
                        state <= S_LOAD;
                        mode <= in_mode;
                    end
                end
                S_LOAD: begin
                    if (in_data_valid) begin
                        if (idx == 7'd127) begin
                            state <= S_DEC;
                            idx <= 7'd0;
                            slot <= 3'd1;
                            slot_mask <= 8'b00000010;
                        end else begin
                            idx <= idx + 7'd1;
                            if (idx == 7'd126)
                                slot_mask <= 8'b00000001;
                        end
                    end
                end
                S_DEC: begin
                    if (done) begin
                        warn <= !syndrome_zero;
                        out_valid_r <= 1'b1;
                        out_data_r <= out_word;
                        out_warn_r <= !syndrome_zero;
                        idx <= 7'd2;
                        state <= S_OUT;
                        slot_mask <= 8'b00000000;
                    end else begin
                        slot <= slot + 3'd1;
                        slot_mask <= {slot_mask[6:0], slot_mask[7]};
                        if (slot == 3'd7) begin
                            pending <= 1'b1;
                            iteration <= iteration + 4'd1;
                        end
                    end
                end
                S_OUT: begin
                    out_valid_r <= 1'b1;
                    out_data_r <= out_word;
                    out_warn_r <= warn;
                    if (idx == 7'd127) begin
                        idx <= 7'd0;
                        state <= S_WAIT;
                    end else begin
                        idx <= idx + 7'd1;
                    end
                end
                default: state <= S_WAIT;
            endcase
    end
end

endmodule
