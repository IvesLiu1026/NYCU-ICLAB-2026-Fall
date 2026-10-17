# Lab04 — FlashAttention

A streaming attention circuit for 16 tokens, four channels and two heads.
Five three-stage engines process query/key pairs while inputs are arriving.
Rotating K/V storage, online base-two normalization and a shared output
projection keep the intermediate score matrix out of storage.

Selected result: 12.5 ns · 2,161,801 cell-area report units · one counted
wait cycle per frame.

Approximate snapshot comparison: Rank 1 / 120.

FlashAttention. The paperwork finally caught up.

[![FlashAttention architecture preview](media/attention-preview.gif)](media/attention-architecture.mp4)

[Watch the architecture film](media/attention-architecture.mp4) ·
[Read the architecture](docs/ARCHITECTURE.md) ·
[Follow a worked update](docs/ALGORITHM.md)

## Performance snapshot

| Metric | Selected result |
| --- | ---: |
| Clock period | 12.5 ns |
| Cell area, report units | 2,161,800.783689 |
| Wait after input, per frame | 1 cycle |
| Total counted wait, 1,000 frames | 1,000 cycles |
| Counted wait × period | 12,500 ns |
| Area² × total wait × period | 5.841728 × 10¹⁶ |
| Functional gate checks | 1,000 / 1,000 frames |
| Approximate snapshot comparison | Rank 1 / 120 |
| Reported SDF gate validation | Passed |

The one-cycle figure measures the wait from the end of input to the first
output under the checked protocol. Each transaction also receives 64 input
beats and emits 64 output beats. Work already in flight accounts for the
short wait. It is not a one-cycle end-to-end attention evaluation.

Synthesis report checks pass, and the gate simulation completed the finite
functional checks. SDF gate validation is also reported passing for the
selected point. See [evaluation](docs/EVALUATION.md).

The comparison inserts this result into 119 positive results with all
three evaluation stages marked as passing in the 18 October 2026 Lab04
snapshot. Recomputing area² × total latency × period places the result
first among 120 entries. This is a snapshot comparison;
the [results page](results/README.md) records the method and source.

## Architecture walkthrough

![Streaming attention architecture](docs/figures/architecture.png)

1. Capture Q/K/V in row-major order and the 4 × 4 output weights in the
   first 16 beats. Convert them to the internal arithmetic formats.
2. Rotate four K and four V component banks through 17 positions. Two
   neighboring taps per head supply the scheduled jobs.
3. Run five copies of a three-stage score, exponential/product and state
   update pipeline. Interleave logical contexts over 22 physical states.
4. Normalize completed heads with a shared reciprocal path. Merge the
   first row's last key through a sigmoid correction.
5. Reuse the projection arithmetic across four output coordinates, then
   format and emit 64 consecutive binary32 words.

| Read next | Contents |
| --- | --- |
| [Selected RTL](rtl/F_ATTN.v) | Verilog-2005 implementation and external converter instance |
| [Annotated RTL](rtl/annotated/README.md) | Reading copy with unchanged executable source |
| [Architecture](docs/ARCHITECTURE.md) | Rings, five engines, contexts and shared post-processing |
| [Attention algorithm](docs/ALGORITHM.md) | Base-two recurrence and a synthetic tail example |
| [Numerical model](docs/NUMERICAL_MODEL.md) | Formats, approximations, rounding and finite accuracy scope |
| [Interface and timing](docs/PROTOCOL.md) | Ports, reset, capture and output order |
| [Evaluation](docs/EVALUATION.md) | Source identity, latency accounting and timing status |
| [Results](results/README.md) | Performance and machine-readable measurement |
| [Architecture film](media/README.md) | Full film, short loops, poster and chapter list |

[Back to the course index](../README.md)
