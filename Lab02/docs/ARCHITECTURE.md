# Eight-lane QC-LDPC architecture

The selected `LDPC` implementation is a sequential, half-parallel normalized
min-sum decoder. Its eight check-node lanes process 64 checks in eight steps
per iteration. The source implements the graph as fixed wiring; it does not
contain an addressable message RAM or a general-purpose graph processor.

## Interface and frame protocol

| Signal | Width | Meaning |
| --- | ---: | --- |
| `clk`, `rst_n` | 1 each | Clock and asynchronous active-low control/output reset |
| `in_mode_valid`, `in_mode` | 1 each | Capture mode 0 for flooding or mode 1 for layered decoding |
| `in_data_valid`, `in_data` | 1, 6 | 128 consecutive signed channel LLRs in natural variable order |
| `out_valid`, `out_data` | 1, 8 | 128 consecutive signed posterior LLRs in natural variable order |
| `out_warn` | 1 | One if the syndrome is still nonzero after iteration eight |

Channel values lie in −31 through +31. Input and output transactions do not
overlap. Output data and warning are zero while output valid is low. A new
frame does not require another reset. The complete input transaction overwrites
the data banks and drains zero records through the old-message rings before
their contents are used for decoding.

## A fixed graph with a useful layer structure

The expansion factor is 16. Each nonempty block in the 4 × 8 base matrix is a
16 × 16 cyclically shifted identity. The expanded graph has 128 variables,
64 checks and 448 edges; each check has seven neighbors.

```text
−1  14  10   2  13  12   9   3
 5  −1  14  10   2  13  12   9
 0   5  −1  14  10   2  13  12
 7   0   5  −1  14  10   2  13
```

An entry −1 omits that block. For check `16r + k`, a nonempty column `c`
connects to variable `16c + ((k + shift[r][c]) mod 16)`.

The 16 checks within one layer touch disjoint variables: each nonempty block
is a permutation. Therefore, processing a layer as two halves preserves the
specified messages and posterior results. The layered order of layers 0, 1,
2, 3 is retained. Within odd-numbered layers, checks 8–15 are processed first;
this changes physical alignment, not the numerical dependency order.

## Eight lanes and eight bank layouts

Each lane processes seven edges. At any decode step, the 128 physical slots
have three roles:

| Slots | Role |
| --- | --- |
| 0–55 | Seven edges for each of the eight active checks |
| 56–111 | Variables belonging to the other half of the same layer |
| 112–127 | Variables in the column absent from the current layer |

The next step permutes both banks into its required alignment. Moving from
the first half to the second swaps the active/inactive halves. Moving to a new
layer applies that layer's fixed QC permutation. The explicit `snx_*` and
bank-assignment equations select among these fixed mappings using the one-hot
`slot_mask`. This wiring still has a cell cost; it avoids a separately addressed
variable-read network on the check-node input.

## Two banks preserve both schedules

The names in the measured source have specific roles:

| Source array | Role |
| --- | --- |
| `posterior[0:127]` | Check-source bank, denoted `S` below |
| `snapshot[0:127]` | Live posterior/accumulator bank, denoted `L` below |

For an active edge with old check message `R_old`, the check input is
`q = S − R_old`. The check node clips that input and produces `R_new`.
The live posterior update is `L_next = L − R_old + R_new`.

In **flooding**, `S` remains the iteration-start posterior while `L` accumulates
new messages across the eight steps. At the final step, `S` captures the
completed accumulator for the next iteration. In **layered** mode, `S` captures
`L_next` every step, so the next layer observes the preceding layer's updates.
The two halves of one layer cannot influence each other because their variable
sets are disjoint.

The source uses `lupd = mode || slot_mask[7] || serial_shift`. When `lupd` is
true, the check-source bank reuses the already computed snapshot next value;
otherwise its hold terms only permute the old source values. Serial loading
and output use the same alignment network. Syndrome and output read the live
`snapshot` bank.

## Small records, expanded heads

An iteration produces one record for each of 64 checks. Each of eight lanes
keeps one expanded head plus seven compact tail records:

| Storage | Contents | Bits |
| --- | --- | ---: |
| Head, one per lane | Seven signed six-bit operands `−R_old` | 42 |
| Each tail record | Two five-bit normalized minima, three-bit argmin, six outgoing signs | 19 |

Total record storage is `8 × (42 + 7 × 19) = 1,400` bits. The two 128 × 8 banks
use another 2,048 bits. Control and registered outputs add 37 bits, for 3,485
state bits; the synthesis report also contains 3,485 sequential cells.

Only two negations are needed when expanding a tail record: negate its first
and second minima once, then select the appropriate signed operand for each
edge. Expansion happens before the register boundary. The next check step
therefore starts with an addition of a ready `−R_old` operand.

Saving six signs is sufficient. Each outgoing sign equals the XOR of the six
other incoming signs. Across seven outgoing signs, each incoming sign appears
six times, so their total parity is zero. The seventh outgoing sign equals the
XOR of the six stored signs. [Numerical model](NUMERICAL_MODEL.md) covers the
minimum-index and sign reconstruction in detail.

## Early first step and iteration boundaries

The first half of layer zero does not use channel word 127; that variable
belongs to a check in the second half. Consequently, the first check step runs
in the final accepted input cycle while the final word enters its next slot.
The remaining seven steps complete iteration one after input ends.

`pending` marks an iteration boundary. At that boundary, all 64 syndrome bits
are examined. At least one complete iteration is always executed. A zero
syndrome terminates; otherwise decoding continues through at most eight
iterations. The selected source's post-input latency is `8I − 1`, giving
7–63 cycles for `I = 1..8`. Every frame in the measured corpus matches this
formula. The 128 output cycles are separate.

The `done_now` path makes the first output word visible immediately upon the
boundary decision. Registered output logic supplies the remaining words, while
serial shifts restore natural variable order. `out_warn` stays constant across
the entire output frame.

## Measured implementation scope

The selected source is plain Verilog-2005. Its exact byte identity is recorded
in [release.json](../results/release.json). The 7.0 ns result is a standard-cell
synthesis and SDF gate-simulation qualification on the declared corpus; it is
not a post-layout, power, or global-optimality result.
