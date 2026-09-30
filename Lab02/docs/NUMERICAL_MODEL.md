# Exact fixed-point normalized min-sum

The numerical contract determines the output bits. Hardware may reorganize
storage and arithmetic, but it must preserve clipping, rounding, message
exclusion, scheduling, and iteration stopping.

## Values and widths

| Quantity | Range | Representation |
| --- | --- | --- |
| Channel LLR | −31..31 | Signed six-bit input; −32 is outside the input contract |
| Posterior LLR | −123..123 | Signed eight-bit bank word |
| Clipped variable-to-check input | −31..31 | Sign plus five-bit magnitude in the check lane |
| Normalized check magnitude | 0..23 | Five bits |
| Stored expanded `−R_old` | −23..23 | Signed six-bit two's complement |

The posterior bound follows from a variable having at most four incident
checks: `31 + 4 × 23 = 123`. Removing its own old message leaves at most three
other messages, so the check input before clipping fits signed eight bits.
The eight-bit posterior must not be saturated to six bits.

## Exclude the target message, then clip

For variable `v` and check `c`, let `S_v` be the check-source posterior and
`R_old(c,v)` the old check-to-variable message. The incoming value is

```text
q(c,v) = clip(S_v − R_old(c,v), −31, 31).
```

The datapath computes the signed eight-bit subtraction through a stored
`−R_old` operand. `saturated_magnitude` returns `min(abs(value), 31)`; the sign
comes from the subtraction result. For the specified arithmetic, magnitude
clipping before normalization is equivalent to clipping the signed input.

## Normalize with the specified rounding

For an integer magnitude `m` between 0 and 31:

```text
N(m) = floor((3m + 2) / 4)
     = m − floor((m + 1) / 4)
     = m − floor(m / 4) − [m mod 4 = 3].
```

This is multiplication by 0.75 rounded to nearest, with halfway cases rounded
up. Examples: `N(2) = 2`, `N(3) = 2`, `N(6) = 5`, and `N(31) = 23`.
The source implements the final line using shifts and a two-bit equality.
It does not use a multiplier or a generic rounding unit.

`N` is monotone, so minimum selection and normalization commute in value.
The selected implementation normalizes all seven edge magnitudes in parallel
and selects the normalized first/second minima. Minimum flags are computed
from the unnormalized magnitudes with stable index tie-breaking.

## Two minima provide all seven excluded-edge minima

Sort the seven magnitudes by `(value, edge index)`. Let `m1`, `m2` be the first
two values and `a` the first index. For target edge `e`:

```text
out_magnitude[e] = N(m2), if e = a;
                   N(m1), otherwise.
```

If multiple edges share the smallest value, `m1 = m2`, so every target still
receives the correct minimum of its other six inputs. Stable tie-breaking
selects a reproducible argmin without changing those message magnitudes.

The RTL uses 21 pairwise comparisons. For each edge, six Boolean terms encode
which other edges precede it in the total order. Zero preceding edges identifies
the first minimum; exactly one identifies the second. Factoring the latter
predicate into two groups of three comparisons avoids a general population
count in this fixed seven-input problem.

## Signs and a worked check node

Let `s[e]` be one if input edge `e` is negative and zero otherwise. Define
`p = XOR(s[0..6])`. The outgoing sign is `p XOR s[e]`, excluding that edge's
own sign. Numerical zero is nonnegative.

Consider an illustrative check input, independent of the supplied test vectors:

```text
Incoming:       10   −6    4   −9    7   31  −12
Magnitudes:     10    6    4    9    7   31   12
First minimum:   4 at edge 2; second minimum: 6 at edge 1
Normalized:      3 and 5; total incoming sign parity: 1
Outgoing:       −3   +3   −5   +3   −3   −3   +3
```

Edge 2 receives magnitude five because its own smallest input is excluded.
Every other edge receives magnitude three. This example also exercises the
halfway rounding `0.75 × 6 = 4.5 → 5`. The architecture film visualizes these
same values.

For compact storage, only six outgoing signs are required: their XOR gives
the seventh. The parity identity holds for the Boolean sign encoding even
when a zero magnitude is paired with an internal sign bit.

## Replace the old message in the live posterior

The check node produces signed `R_new`. The live posterior update is

```text
L_next = L − R_old + R_new.
```

The subtraction used by this update remains unclipped. Clipping belongs only
to the incoming V2C value used by the check node. Feeding a clipped value into
the posterior update would change the algorithm.

The six-bit stored operand is sign-extended to eight bits. The new magnitude
and sign form a signed addend using two's-complement inversion plus carry.
The declared function result preserves Verilog's eight-bit result semantics;
the contract bounds keep valid posterior results representable.

## Scheduling and stopping are part of correctness

Flooding reads the iteration-start source bank throughout the iteration;
layered decoding reads the updated source as each layer completes. Splitting
one layer into two disjoint check halves preserves this dependency schedule.

After every complete iteration, hard decisions use posterior signs and all
64 parity checks are evaluated. Decoding executes at least one iteration and
at most eight. It must not terminate from a partial-layer syndrome or merely
from the input hard decisions. The warning is asserted only when the final
eighth-iteration syndrome remains nonzero.

Finite regression and SDF qualification establish the declared measured
result. They are not a formal proof over every possible input frame.
