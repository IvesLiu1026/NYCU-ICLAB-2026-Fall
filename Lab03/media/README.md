# ZUMA architecture film

[![Preview](zuma-preview.gif)](zuma-architecture.mp4)

[Watch the full film](zuma-architecture.mp4) · [Poster](zuma-poster.png) ·
[Cascade example](zuma-cascade.gif)

The film is 84 seconds, 1920 × 1080 at 24 fps, with English on-screen
explanations and no audio. The main looping preview is 16 seconds; the cascade
preview is 12 seconds.

| Chapter | Topic |
| --- | --- |
| 0:00 | Reported performance snapshot |
| 0:12 | Dense even/odd storage and circular addressing |
| 0:24 | Registered windows and cached equality flags |
| 0:36 | Synthetic three-level cascade: counts 3, 4 and 3 |
| 0:48 | Count-first output and replay |
| 1:00 | Dense compaction and seam repair |
| 1:12 | Performance product and Rank 1 snapshot comparison |

The scenes explain the selected circuit's register roles and dataflow. They
are conceptual views, not cycle-accurate RTL or gate-level waveforms. The
synthetic cyclic cascade is independently checked; no supplied test vector
appears in the film. Performance panels present the reported aggregate record.

See [Architecture](../docs/ARCHITECTURE.md), [Algorithm](../docs/ALGORITHM.md)
and [Results](../results/README.md) for the detailed explanation and numbers.
