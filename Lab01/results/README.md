# Measurements and validation

The recommended unrolled implementation has a measured cell area of
122,610.902388 µm² at 15.6 ns, giving an area–period product of
1,912,730.077253 µm²·ns. The parameterized implementation is independently
qualified at 15.5 ns and has a larger area–period product.

## Selected results

| Implementation | Area (µm²) | Period (ns) | Timing slack (ns) | Area × period (µm²·ns) |
|---|---:|---:|---:|---:|
| [Unrolled](../rtl/unrolled/OISS.v) | 122,610.902388 | 15.6 | +0.001160 | 1,912,730.077253 |
| [Parameterized](../rtl/parameterized/OISS.v) | 126,470.030354 | 15.5 | +0.006074 | 1,960,285.470487 |

Each row passed 100,000 RTL patterns and 100,000 timing-annotated gate patterns
at the stated period, with SDF annotation verified. A qualified result requires
both passing synthesis timing and passing timed gate simulation. Positive slack
here is small; a different source, tool configuration or library requires a
new qualification. Cell area is synthesized standard-cell area, not die area.

The unrolled product is 44.9202% below a 40 ns reference measurement of
86,816.318565 µm². That reference had a 100-pattern RTL and timed gate screen;
it should not be read as having the release pair's 100,000-pattern coverage.
The comparison is a measured reference, not a claim of global physical optimality.

RTL development and initial verification were carried out in my local environment,
with a friend assisting with synthesis and gate-level testing. Synthesis and
timing-annotated gate-level simulation were performed using Synopsys Design Compiler
and VCS with the UMC018 library.

The recorded versions are Design Compiler T-2022.03 and VCS T-2022.06; UMC018
is the 180 nm technology. The design uses the original course combinational
constraints. The period is the evaluation-time constraint for this combinational
block, not the count returned by `Ex_cycle`.

## Exact source identities

| Implementation | SHA256 |
|---|---|
| Unrolled | `50178b02593c4fbfbac4a7618ee166fcff0b36bfa99965c664e2473de3dd10b1` |
| Parameterized | `49021f4eb3a9d1b0989b81b97641e84b918c85dfe3ac0916442443db7b3afb57` |

The [release record](release.json) contains these hashes and exact numeric results.
The annotated reading copies reduce to the same bytes after removing their full-line
comments, so they describe these implementations without introducing another RTL variant.

## Comparison figures

![Area and period measurements](figures/performance.png)

Each gray point is a passing measured area/period pair from the broader comparison.
Points include 100-pattern screens and 100,000-pattern checks; only the highlighted
release pair carries the full qualification stated above. The figures do not imply
that every point has equal verification coverage. The zoom shows the two selected
implementations, which trade a small period difference against cell area.

![Cell area by family for the selected implementations](figures/cell_families.png)

Cell-family areas are summed from the selected mapped netlists using the matching
library cell areas. This shows how the final circuits map into gates; it is not
an estimate based on RTL line counts.

![Dependency-structure coverage](figures/coverage.png)

The coverage figure compares dependency shapes in the measured validation corpora.
It describes sampled input coverage, not an exhaustive proof of all legal inputs.

## Generality and additional functional evidence

Both implementations compute from the provided instructions and opcode latencies.
Source review found no stored expected answers, test-vector identity checks or
pattern-number exceptions. Narrow latency fields and fixed boundary values derive
from the [legal contract](../docs/ARCHITECTURE.md#interface-and-legal-input-contract)
and scheduling mathematics.

An additional functional regression passed 26,093 cases per implementation under
both Verilator 5.020 and Icarus Verilog 12.0, including 20,000 newly generated random
legal inputs and directed corner cases. The independent reference enumerates legal
topological orders and checks the minimum completion, returned permutation and
hazard legality; it does not use the RTL chain split or DP recurrence.

These functional checks are separate from the recorded timed gate qualifications.
They support general behavior within the contract, while finite regressions do not
prove exhaustive top-level equivalence or guarantee every unseen hidden case.
