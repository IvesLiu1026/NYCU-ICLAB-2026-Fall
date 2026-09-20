# A constructive two-chain completion bound

Let A and B be two instruction chains of lengths m and n. A chain instruction
can issue only after the preceding instruction in that chain completes. Every
latency is a positive integer, the issue resource accepts at most one instruction
per integer cycle, and the two chains otherwise execute independently. Time zero
is the first issue opportunity. Completion is issue time plus latency. Assume
m <= n; otherwise exchange the chain names.

Write S_A and S_B for the sums of the latencies in the two chains. There exists a
legal schedule with completion at most max(S_A, S_B) + m. Therefore the optimum
completion satisfies

    max(S_A, S_B, m+n) <= C_opt <= max(S_A, S_B) + min(m, n).

The lower bound follows because every instruction in each chain must execute
serially, and m+n positive-latency instructions need m+n distinct issue cycles
through the final completion. The upper bound follows from the following
constructive schedule.

## Construction and proof

Reserve the A issue times at the intrinsic prefix sums of its latencies:
A_0 issues at zero and A_i issues at the sum of the latencies before it. These
reserved times are distinct integers because all latencies are positive. Giving
A priority whenever it is ready realizes exactly these times: a B issue in an
earlier cycle occupies only that earlier issue opportunity and cannot prevent
an A issue in the next cycle.

For each B instruction in order, let r be zero for the first instruction or the
completion time of the preceding B instruction. Issue it at the first integer
s >= r that is not an A reserved issue time. This is legal for both dependency
and issue-resource constraints. Such an s always exists among r through r+m,
since there are only m reserved A issue times in total.

Its waiting time s-r counts exactly the reserved A issue times in the integer
interval [r,s). Waiting intervals for distinct B instructions are disjoint: the
next ready time is at least s+1 because the intervening B latency is at least
one. Consequently each A issue can be charged to B waiting at most once. The
sum of all B waiting times W is at most m.

A completes at S_A. B completes at S_B + W by telescoping its ready and issue
times. Hence the whole schedule completes at

    max(S_A, S_B + W) <= max(S_A, S_B) + m.

No relation among the relative A and B latency magnitudes is needed. The proof
requires positive integer latencies, a single issue opportunity per cycle, and
no inter-chain dependencies or additional shared execution constraint.

## Tightness and final-score implication

For all unit latencies and m <= n, every legal schedule must issue all m+n
instructions in distinct cycles and finishes no earlier than m+n. The schedule
above attains m+n, while max(S_A,S_B)=n. Thus the additive constant m is tight
for this scheduling model; replacing it with m-1 is false in general.

For the legal two-chain splits (m,n)=(2,6),(3,5),(4,4), the optimum extra delay
above max(S_A,S_B) is therefore at most four. A final threshold score that means
"a legal completion with extra delay <= t exists" must have its global OR bit
four set when the DP represents all of these legal schedules.

This establishes an exact bound on schedule completion. It is not a lower bound
on synthesized cell area, circuit delay, or their product. The selected circuit retains
seven final threshold bits. The bound applies to its attainable optimum and
does not authorize dropping intermediate waiting states.
