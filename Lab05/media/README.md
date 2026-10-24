# Encoder architecture film

[![Preview](jpeg-preview.gif)](jpeg-architecture.mp4)

[Watch the full film](jpeg-architecture.mp4) · [Poster](jpeg-poster.png) ·
[Memory schedule loop](jpeg-memory.gif)

Animation made with [ManimGL](https://github.com/3b1b/manim).

The film is 78.1 seconds, 1920 × 1080 at 30 fps, with English
on-screen explanations and no audio. Both looping previews are 16 seconds.

| Chapter | Topic |
| --- | --- |
| 0:00 | A full image. A small working set. |
| 0:08 | Keep eight rows. Reuse them in place. |
| 0:18 | One port. Reserve the regular accesses. |
| 0:29 | Factor the products. Pipeline the carries. |
| 0:39 | Two roundings. Keep both decisions. |
| 0:49 | A coefficient needs storage only while it is live. |
| 0:58 | Codes become words. Words become bytes. |
| 1:09 | Qualified at the selected 2.3 ns point. |

The scenes explain the shared memory, transform stages, two rounding
decisions, coefficient lifetimes and entropy packing. They are conceptual
views, not cycle-accurate RTL or gate waveforms. The pixel tiles and live
ranges are illustrations. The negative rounding example was constructed
for the explanation and checked with exact integer arithmetic.

The measurement scenes show the selected 2.3 ns point, its native
100-image RTL and matching SDF gate checks, and Rank 1 / 118 snapshot
comparison. Counted latency excludes input reception and includes output
bytes and bubbles. It is not the complete image transaction duration.

See [Architecture](../docs/ARCHITECTURE.md), [Arithmetic](../docs/ALGORITHM.md),
[Evaluation](../docs/EVALUATION.md) and [Results](../results/README.md).
