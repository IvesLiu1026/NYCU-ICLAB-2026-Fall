# Candidate performance

| Quantity | Selected candidate |
| --- | ---: |
| Clock period | 12.5 ns |
| Cell area, report units | 2,161,800.783689 |
| Checked frames | 1,000 |
| Wait per frame | 1 cycle |
| Total counted wait | 1,000 cycles |
| Total counted wait × period | 12,500 ns |
| Area² × total wait × period | 5.841728285447968 × 10¹⁶ |
| Strict SDF qualification | Open |

```text
2161800.783689² × 1000 × 12.5 = 58417282854479682.10560901250
```

Lower product is better under the same latency convention and verification
requirements. Area is quoted in the synthesis report's units; no physical
unit conversion is assumed. The source and finite functional checks are
described in [evaluation](../docs/EVALUATION.md).

![Candidate measurement and scope](figures/objective.png)

[SVG](figures/objective.svg) · [PDF](figures/objective.pdf) ·
[Performance data](performance.csv) · [Machine-readable benchmark](benchmark.json)

The product is conditional on unresolved SDF qualification. It is not an
accepted score or an official comparison rank. A shorter period may require
more cell area, and the area term is squared, so the tightest requested
clock need not give the smallest product.
