# Exact scheduling reduction

The algorithm minimizes a program's completion time for each legal input.
That does not establish a globally minimum-area or minimum-delay circuit.
`C` below is the integer cycle count reported by `Ex_cycle`; the evaluation
period `T` in nanoseconds is a separate physical constraint. The measured
physical objective is cell area multiplied by `T`.

## Remove the common intrinsic completion

For a legal interleaving of two independent dependency chains, let `SA` and
`SB` be their intrinsic latency sums, and `dA`, `dB` their accumulated waiting.

```text
C = max(SA + dA, SB + dB)
base = max(SA, SB)
```

A schedule completes within `base+t` exactly when both chain completions do:

```text
C <= base+t
    iff dA <= t+base-SA and dB <= t+base-SB.
```

Writing `delta = SA-SB` gives an equivalent expression for the extra completion:

```text
delta >= 0: C-base = max(dA, dB-delta)
delta <  0: C-base = max(dA+delta, dB).
```

For example, `SA=20`, `SB=17`, `dA=2`, `dB=4` gives `C=max(22,21)=22`.
The reduced expression gives `20+max(2,4-3)=22`. Waiting on the intrinsically
shorter chain can be hidden behind the longer chain's execution.

## Keep only nondominated waiting states

At a fixed prefix `(i,j)` and A-waiting budget `d`, retain the smallest reachable
B waiting and an attaining order. More B waiting under the same budget cannot
improve a continuation. The intrinsic work `PA[i]` and `PB[j]` is common to
the alternatives, so it need not be repeatedly included in wide cost comparisons.

Represent the frontier with threshold bits:

```text
Q[i,j,d][e] = 1 iff some legal schedule of the prefixes
                   has A waiting <= d and B waiting <= e.
```

For each budget, the vector is monotone in `e`: if a schedule fits one upper
bound, it fits every larger one. The circuit forms this frontier by appending
A, appending B and inheriting the smaller A budget. Shared intrinsic-prefix
differences reduce the timing tests to small constant comparisons.

## Compare monotone scores and preserve a witness

At the final prefixes, encode a candidate with bits `q[t]` meaning its
completion is at most `base+t`. For a set of candidates,

```text
q_best[t] = OR over candidates of q_candidate[t].
```

The OR is the threshold encoding of the minimum attainable completion. For
monotone vectors over the same thresholds, the right candidate is strictly
better exactly when it contributes a previously false threshold:

```verilog
|(right_score & ~left_score)
```

The score and its order mask have to travel together. Both masks are valid
choices on an equal-score tie, provided each attains that score. This freedom
allows different deterministic tie rules without changing the optimal cost.
An all-zero candidate represents no attainable completion in the represented
threshold range; final selection must obtain a feasible score.

## Bound the extra completion

For two chains of lengths `m` and `n`, positive integer latencies and at most
one issue per integer cycle,

```text
max(SA, SB, m+n) <= C_opt <= max(SA, SB) + min(m,n).
```

For the upper bound, assume `m <= n`. Reserve A's intrinsic issue times and
issue each B instruction at the first ready, unreserved cycle. Each extra
waiting cycle of B is caused by an A issue. Distinct B waiting intervals do
not overlap, so the total additional waiting is at most `m`. A completes at
`SA`, and B completes by `SB+m`. All-unit latencies attain the bound.
The [full constructive proof](COMPLETION_BOUND.md) makes these assumptions explicit.

With eight instructions, the shorter real chain has at most four members.
The optimum therefore needs at most four extra cycles. This bounds the final
optimum, not every candidate's waiting or either chain's individual waiting.
It does not justify truncating intermediate DP budgets arbitrarily. The
measured implementation uses seven final threshold bits; the bound guarantees
a feasible optimum in that representation.

## Physical implications and limits

The reduction replaces repeated full completion-time comparisons with shared
prefix arithmetic, small waiting predicates and monotone Boolean selection.
Witness selection and identifier reconstruction remain part of the circuit:
computing only an optimal cost is insufficient for the interface.

Mapped area and delay also depend on the library cells and synthesis choices.
The [reported measurements](../results/README.md) show how these two implementations
perform with UMC018.
