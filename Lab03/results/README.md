# Reported performance and Rank 1 comparison

| Quantity | Reported benchmark |
| --- | ---: |
| Clock period | 2.8 ns |
| Cell area | 157,211 µm² |
| Total latency | 5,499 cycles |
| Total latency × period | 15,397.2 ns |
| Area × total latency × period | **2,420,609,209.2** |
| Approximate snapshot comparison | **Rank 1 / 122** |

```text
157,211 × 5,499 × 2.8 = 2,420,609,209.2
```

The performance point is recorded as a reported aggregate result. The cost is
recomputed directly from its three inputs. Lower cost is better.

## Anonymous reference comparison

The fixed 8 October 2026 snapshot has 121 positive results. Inserting the
reported benchmark produces 122 comparison entries and a first-place position.
This is a comparison rank, not an official assigned course rank.

| Result | Period | Area | Total cycles | Objective |
| --- | ---: | ---: | ---: | ---: |
| Reported benchmark | 2.8 ns | 157,211 µm² | 5,499 | 2.4206092092 × 10⁹ |
| Snapshot leader | 2.9 ns | 155,442.7 µm² | 5,713 | 2.57532802079 × 10⁹ |

The reported point has 1.14% more area, 3.75% fewer cycles and a 3.45% shorter
period. Their product is **6.01% lower** than the reference objective. This
comparison assumes the same total-latency counting convention. It does not
infer the reference architecture or compare implementations' source code.

![Objective comparison](figures/objective.png)

[SVG](figures/objective.svg) · [PDF](figures/objective.pdf) ·
[Comparison data](comparison.csv) · [Machine-readable benchmark](benchmark.json)

## Interpretation

Area, cycles and period must be considered together. A lower cycle count can
cost more read/comparison hardware, and a tighter period can change synthesis
mapping. A favorable product describes this benchmark point; it does not
establish a global optimum or predict every possible workload.

The [architecture walkthrough](../docs/ARCHITECTURE.md) explains the selected
dense zipper, and [evaluation](../docs/EVALUATION.md) explains source/clock
qualification and counting rules.
