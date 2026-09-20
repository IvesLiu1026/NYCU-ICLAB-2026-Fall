# The selected OISS circuit

OISS returns a minimum-completion legal issue order for eight instructions. The
entire solver is combinational Verilog-2005. There is no clock, reset, pipeline,
sequential state, memory macro or vendor IP in the RTL. A DP state in the
explanation below is a collection of wires, not a stored value updated each cycle.

The [unrolled source](../rtl/unrolled/OISS.v) is the recommended measured
implementation. The [parameterized source](../rtl/parameterized/OISS.v) uses
functions and generate loops for a more compact expression of the design.
The [annotated copies](../rtl/annotated/README.md) follow the circuit block by block.

## Interface and legal input contract

| Port | Meaning |
|---|---|
| `Inst_seq_I[95:0]` | Eight 12-bit instructions; instruction `i` is `[12*i +: 12]` |
| `Inst_latency_I[47:0]` | Eight 6-bit opcode latency fields; opcode `k` uses `[6*k +: 6]` |
| `Inst_order_O[23:0]` | Eight original instruction IDs; issue slot `i` is `[3*i +: 3]` |
| `Ex_cycle[8:0]` | Minimum program completion in integer cycles |

An instruction contains four 3-bit fields in descending significance:
`opcode`, `rs`, `rt`, `rd`. The instruction IDs are their original positions,
0 through 7. The first issue opportunity is cycle zero. At most one instruction
issues per cycle, and each instruction must wait until its hazard predecessors
have completed. Completion is issue time plus latency.

| Opcode | Operation | Legal latency |
|---:|---|---:|
| 0 | ADD | 1–5 |
| 1 | SUB | 1–5 |
| 2 | MUL | 20–40 |
| 3 | DIV | 30–50 |
| 4 | LOAD | 6–10 |
| 5 | STORE | 6–10 |
| 6 | BRANCH | 2–4 |
| 7 | JUMP | 1 |

The dependency graph must be empty, a single ordered chain with independent
instructions, or two disjoint ordered chains covering all eight instructions.
The circuit uses this guarantee to simplify grouping and scheduling. It is not
an arbitrary dependency-DAG solver. Register 0 is an ordinary register.

## Decode hazards and group instructions

All 28 original-order instruction pairs are checked in parallel for read-after-write,
write-after-read and write-after-write hazards. Arithmetic instructions and LOAD
write `rd`; arithmetic and BRANCH read `rs` and `rt`; STORE reads `rd`. The register
contract determines these hazards; no additional memory-alias model is assumed.

An instruction is connected if any hazard touches it. Under the guaranteed graph
shape, two adjacent connected instructions without a connecting edge identify a
change of chain. Prefix parity of these changes recovers the chain labels. With
two real chains, normalization names the shorter chain A, so A has two to four
members and B has the remaining entries. With one chain, A contains that chain
and B contains independent work. With no dependencies, A is empty.

Within a chain, members retain original program order. Independent instructions
are ranked by descending latency. The disjoint legal opcode ranges fix much of
this ordering: only MUL versus DIV, LOAD versus STORE, and the ADD/SUB/BRANCH
cluster require comparisons. A deterministic tie order preserves optimality.

The unrolled source prepares chain ranks from connectivity and local parity
before normalized membership is selected. One-hot rank selection compacts both
groups. The parameterized source compacts A with a three-stage conditional shift
network. Each member carries the count of nonmembers before it, then moves by
1, 2 and 4 positions as selected by that count. Relative order is preserved and
valid members do not collide. Its B side retains rank-indexed selection because
independent instructions are sorted by priority. Empty positions have zero latency.

## Share intrinsic prefix arithmetic

Let `PA[i]` be the sum of the first `i` A latencies and define `PB[j]` similarly.
These sums describe execution without issue conflicts with the other chain.
Nine bits cover legal totals. Zero padding lets fixed array endpoints also
represent the totals of shorter chains.

The prefix additions use explicit two-bit carry groups. For each bit,
`p = x XOR y`, `g = x AND y`, and the sum is `p XOR carry_in`. Expanding carry
within a two-bit group exposes short local Boolean equations while sharing group
boundaries. The signed prefix-difference circuits share their results across
several waiting-budget comparisons. Only small constant thresholds are needed,
so sign and high-bit tests can replace repeated full-width comparisons.

Both scheduling engines reuse the four-entry A prefix. The single-chain total
adds the remaining A slots to that existing value rather than rebuilding the
first half. These are physical arithmetic-sharing choices; they preserve the
underlying scheduling problem exactly.

## Two chains: keep a frontier of waiting budgets

At prefix `(i,j)`, chain finishes have the form `PA[i] + dA` and `PB[j] + dB`.
For each allowed A-waiting budget `d`, retain the smallest reachable B waiting
and an issue-order mask attaining it. A larger B waiting cannot improve a
continuation under the same A budget, so that state is dominated.

The frontier is encoded by `Q[i,j,d][e]`: a true bit means that some schedule
of these prefixes fits A waiting at most `d` and B waiting at most `e`.
These bits are monotone in `e`. The circuit combines three kinds of witnesses:
append A, append B, or inherit a schedule feasible with budget `d-1`.
With `difference = PA[i-1] - PB[j-1]`, the append tests reduce to small
comparisons such as `difference >= e+1-d` and `difference < e-d`.

Empty-prefix boundaries need no cross-chain waiting. At `(1,1)`, both first
instructions cannot issue at zero: one chain must wait. Additional boundary
bits follow from the positive-latency single-issue model and are constants in
the circuit. The remaining bits are combinational recurrence equations.

For a monotone score, bitwise OR represents the better attainable minimum.
The expression `|(right_score & ~left_score)` detects a strict improvement
from the right candidate. The associated mask must follow a witness attaining
the retained score; an arbitrary mask would lose correctness even if the score
were correct. Equal-score choices can use either valid attaining witness.

The two-chain splits are `(2,6)`, `(3,5)` and `(4,4)`. Their A budgets provide
7, 6 and 5 final candidates respectively, for 18 statically expressed finalists.
The actual chain size gates out the other splits. Each final score has seven
bits, with bit `t` meaning completion no later than `max(SA,SB)+t`, for `t=0..6`.
The winning mask accompanies the first feasible completion threshold.

## One chain and independent work

Independent instructions are ordered by descending latency: assigning longer
work to an earlier available issue slot cannot increase the maximum finish.
For a fixed chain completion, avoidable internal chain waiting can be moved
to the chain's initial offset, exposing at least as many earlier slots for
independent work. This reduces the search to a bounded set of initial offsets.

The single-chain engine computes the available slots around the chain and
tests how many leading independent instructions issue before it starts. For
each offset, the remaining independent instructions fill the available slots.
Shared deficit comparisons test whether their finishes fit behind the chain
completion. The minimum feasible offset determines both cost and order mask.
A nonempty chain has at least two members, so there are at most six independent
instructions. A completely empty graph uses descending-latency issue order
directly, with cost `max(i + latency[i])` over the sorted instructions.

## Reconstruct the original instruction order

An eight-bit mask records which compact group supplies each issue slot: one
means A and zero means B. Counting earlier A selections gives the next A index;
the complementary count gives the next B index. The output uses head counts
for the first four positions and tail counts for the last four. This limits
each observed count to three bits of the mask. One-hot count decoding selects
the original identifiers directly from the compact groups.

The selected scheduling path supplies `Ex_cycle` and the same attaining mask.
The output is a permutation of original instruction IDs, not a list of chain
ranks. Different equal-cost orders can be correct for the same input.

## Differences between the two released sources

| Circuit choice | Unrolled | Parameterized |
|---|---|---|
| Chain rank preparation | Early connectivity/parity ranks | Ranks after normalized membership |
| A compaction | One-hot rank selection | Order-preserving conditional shifts |
| Equal independent keys | Earlier original ID first | Later original ID first |
| Inner append-A/B ties | A at inner selectors; zero-budget direct selectors have their own right-tie rule | B |
| Merge with inherited budget | New witness on equal score | New witness on equal score |
| Final tournament ties | Left witness | Left witness |

The parameterized form is not a mechanical folding of the unrolled file.
Its loops elaborate into combinational hardware, not sequential software loops.
Each source therefore has its own hash and measured area/timing result.

## Correctness scope

The design computes its answer from the supplied instructions and latencies.
It contains no lookup of known test vectors, pattern-number conditions or stored
expected answers. Constant fields and narrowed widths follow the legal input
contract; DP boundary constants follow the scheduling model.

Validation checks the returned permutation, dependency legality and optimal
completion against an independent exhaustive-order reference. The selected
sources also have timed gate qualification at their recorded periods. Finite
tests do not prove exhaustive top-level equivalence or cover inputs outside
the documented contract. The [mathematical reduction](MATHEMATICAL_REDUCTION.md)
explains scheduling optimality; the [results](../results/README.md) describe the
separate physical and functional evidence.
