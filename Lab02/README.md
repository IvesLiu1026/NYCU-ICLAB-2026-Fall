# Lab02 — QC-LDPC Decoder

An eight-lane hardware decoder for a 128-variable, 64-check QC-LDPC code.
It supports the specified flooding and layered schedules with exact fixed-point
normalized min-sum updates. Two edge-aligned banks and compact rotating message
records keep the datapath small while reusing eight check-node lanes.

**Selected result: 7.0 ns · 561,593 µm² · 82,336 total cycles · cost 1.817736 × 10¹⁷.**
**Approximate comparison rank: 10th of 121, including this design.**

[![LDPC architecture preview](media/ldpc-preview.gif)](media/ldpc-architecture.mp4)

[Watch the architecture film](media/ldpc-architecture.mp4) ·
[Read the circuit explanation](docs/ARCHITECTURE.md) ·
[Follow the arithmetic](docs/NUMERICAL_MODEL.md)

## Selected implementation

| RTL | Check-node lanes | Period | Cell area | TA2000 total cycles | Area² × period × cycles |
| --- | ---: | ---: | ---: | ---: | ---: |
| [LDPC.v](rtl/LDPC.v) | 8 | 7.0 ns | 561,592.795051 µm² | 82,336 | 1.8177362129 × 10¹⁷ |

The measured source passes all 2,000 patterns in both RTL simulation and SDF
gate simulation. Synthesis setup and hold checks pass. Mean post-input decode
latency is 41.168 cycles (288.176 ns); the maximum is 63 cycles. Input loading
and the 128 output cycles are outside this latency metric.

The ranking is an insertion comparison against a fixed snapshot of 120 valid
course results, producing 121 entries when this design is included. It is not
an official assigned course rank. The reported first-place cost is about
1.4404 × 10¹⁷; matching it would require a **20.76% reduction** from this design's
cost. The [results](results/README.md) explain the comparison and its scope.

## How it works

1. Load 128 signed channel LLRs and capture the flooding/layered mode.
2. Process each layer's 16 checks as two groups of eight; reuse the same lanes.
3. Move the next group into fixed edge slots with a step-dependent permutation.
4. Reconstruct the old check messages from compact records, then replace them
   with exact normalized min-sum updates.
5. Check all 64 parity equations after each full iteration; stop on a zero
   syndrome or after iteration eight.
6. Emit 128 signed posterior LLRs in natural variable order and a frame warning.

The first check group overlaps the final input cycle. The selected schedule
uses `8I − 1` post-input cycles for a frame that ends after `I` iterations.
Fewer lanes save area while increasing cycles; the squared area term makes
that tradeoff meaningful for this objective.

| Read next | Contents |
| --- | --- |
| [Architecture](docs/ARCHITECTURE.md) | Interface, two-bank semantics, step layout, compressed records and control |
| [Numerical model](docs/NUMERICAL_MODEL.md) | Signed widths, saturation, normalization, minimum ties and exact updates |
| [Annotated RTL](rtl/annotated/README.md) | Comment-only reading copy of the measured implementation |
| [Results](results/README.md) | Qualification, ranking, area breakdown and latency figures |
| [Architecture film](media/README.md) | MP4, looping preview, poster and explanation scope |

This collection presents the selected implementation. For technical questions,
start a [Discussion](https://github.com/IvesLiu1026/NYCU-ICLAB-2026-Fall/discussions).
