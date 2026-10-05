# Measurements and validation

The unrolled implementation has the lower measured area–period product.
The parameterized implementation meets a slightly shorter period with more
cell area. Both implement the same scheduling contract.

## Selected results

| Implementation | Area (µm²) | Period (ns) | Timing slack (ps) | Area × period (µm²·ns) |
|---|---:|---:|---:|---:|
| [Unrolled](../rtl/unrolled/OISS.v) | 122,611 | 15.6 | +1.160 | 1,912,730 |
| [Parameterized](../rtl/parameterized/OISS.v) | 126,470 | 15.5 | +6.074 | 1,960,285 |

Both implementations passed synthesis timing, 100,000 RTL patterns and 100,000
gate-level patterns with SDF timing annotation at their stated periods. Cell area
means synthesized standard-cell area. Timing slack is the remaining timing margin;
both selected operating points are close to their timing constraint.

The unrolled area–period product is 44.9% below a 40 ns reference with an area
of 86,816 µm². That reference passed a smaller 100-pattern RTL and timed gate
screen. This comparison illustrates why minimizing area alone would choose a
different operating point from minimizing area times period.

## Approximate comparison rank

The two selected Lab01 implementations are inserted into a fixed anonymized
snapshot containing **115 valid Lab01 performance results**. Both points land at
**rank 3 of 116** because only two reference points have a lower `CT × Area`
value. This is a performance comparison, not an official course-assigned rank.

| Implementation | Comparison value | Approx. rank | Above the snapshot leader |
|---|---:|---:|---:|
| Unrolled | 1,912,730 µm²·ns | 3 / 116 | 3.73% |
| Parameterized | 1,960,285 µm²·ns | 3 / 116 | 6.31% |

The unrolled implementation is the recommended point because it has the lower
area–period product. Matching the anonymous snapshot leader would require a
3.59% reduction from the unrolled value. Sixteen source rows are not included
in this comparison because they do not provide a valid comparable performance
value. No student-level rows, identifiers, or source mapping are distributed.

## Measurement scope

The reported area is synthesized standard-cell area. The period is the
evaluation-time constraint for the combinational block; `Ex_cycle` reports
the scheduled program's completion in integer cycles. Results are specific
to the selected source and its measured evaluation conditions.

Both selected sources pass RTL simulation, synthesis timing checks and
SDF-annotated gate simulation on the declared 100,000-pattern workload.
Detailed toolchain identifiers and verification assets are retained privately.

## Comparison figures

![Area and period measurements](figures/performance.png)

Gray points show passing measurements from the broader comparison, with either
100-pattern or 100,000-pattern checks. The highlighted implementations have the
100,000-pattern RTL and timed gate coverage stated above. The zoom shows their
tradeoff between cell area and period.

![Cell area by family for the selected implementations](figures/cell_families.png)

Cell-family areas are summed from the mapped netlists using library cell areas.
The distribution shows which gate families account for the final circuit area.

![Dependency-structure coverage](figures/coverage.png)

The coverage figure shows how the validation inputs are distributed across the
supported dependency shapes.

## What validation checks

An independent reference enumerates legal instruction orders and checks three
properties: every instruction appears exactly once, the order respects all
dependencies, and its completion time is optimal. Directed and random legal inputs
also passed additional functional checks, independently of the timed gate tests.

These checks cover the documented
[input contract](../docs/ARCHITECTURE.md#interface-and-legal-input-contract).
Sampled validation is not an exhaustive correctness proof, and the measured
area–period product is not a proved global physical optimum.

Full-precision measurements and source identifiers are available
in the [measurement record](release.json).
