# ZUMA architecture film

[![Preview](zuma-preview.gif)](zuma-architecture.mp4)

[Watch the full film](zuma-architecture.mp4) · [Poster](zuma-poster.png) ·
[Cascade example](zuma-cascade.gif)

Animation made with [ManimGL](https://github.com/3b1b/manim).

The film is 92.4 seconds, 1920 × 1080 at 30 fps, with English on-screen
explanations and no audio. Both looping previews are 16 seconds.

| Chapter | Topic |
| --- | --- |
| 0:00 | Performance snapshot |
| 0:09 | Dense even/odd storage and circular addressing |
| 0:21 | Registered windows and cached equality flags |
| 0:36 | Synthetic three-level cascade: counts 3, 4 and 3 |
| 0:55 | Count-first output and replay |
| 1:10 | Dense compaction and seam repair |
| 1:23 | Architecture and performance summary |

The scenes explain the selected circuit's register roles and dataflow. They
are conceptual views, not cycle-accurate RTL or gate-level waveforms. The
synthetic cyclic cascade is independently checked; no supplied test vector
appears in the film. Performance panels present the aggregate result
and its 1 / 122 snapshot comparison.

See [Architecture](../docs/ARCHITECTURE.md), [Algorithm](../docs/ALGORITHM.md)
and [Results](../results/README.md) for the detailed explanation and numbers.
