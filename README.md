# 2026 Fall NYCU ICLAB

Personal solutions to lab problems from the Integrated Circuit Design Laboratory (ICLAB) at
National Yang Ming Chiao Tung University, Fall 2026.

I'm not enrolled in this course, and IC design isn't my field. I just enjoy
solving puzzles. Some people do Sudoku; apparently, I do timing closure.

## About the course

ICLAB is a practical digital IC design course spanning RTL design and
verification through physical implementation. Topics include synchronous
circuits, pipelining, low-power design and SystemVerilog verification. Lab
exercises and projects develop experience with the tools and techniques used
to implement digital hardware. See the [official course overview](https://iclab.iee.nycu.edu.tw/iclab/courses.html).

This repository collects my selected implementations, technical explanations and
measured results for these problems. Each project directory contains its documentation and any published results.

## Projects

| Project | Topic | Selected result | Approx. comparison rank |
|---|---|---|---|
| [Lab01](Lab01/) | Out-of-order Instruction Issue Scheduler (OISS) | 15.6 ns / 122,611 µm² | 3 / 116 |
| [Lab02](Lab02/) | QC-LDPC Decoder | 7.0 ns / 561,593 µm² | 10 / 121 |
| [Lab03](Lab03/) | ZUMA | 2.8 ns / 157,211 µm² / 5,499 cycles | 1 / 122 |
| [Lab04](Lab04/) | FlashAttention | Write-up in progress | — |

The ranks are anonymous insertion comparisons against fixed, lab-specific
performance snapshots. They are not official course-assigned ranks, and the
labs use different cost formulas, so their rank positions should not be
compared as if they were one common leaderboard.

## License and learning use

This is a source-available project under the custom
[Personal Study and Reference License](LICENSE). Personal non-commercial study,
local simulation, synthesis and private learning modifications are permitted.
Other reuse or redistribution requires permission, subject to the license's
exceptions. See [Academic integrity](ACADEMIC_INTEGRITY.md) before using it for coursework.

**Learn from the ideas. Write your own solution.**

## Questions and feedback

For questions about the designs or other approaches, start a
[Discussion](https://github.com/IvesLiu1026/NYCU-ICLAB-2026-Fall/discussions) or contact me directly.
For reproducible bugs or documentation corrections, open an
[issue](https://github.com/IvesLiu1026/NYCU-ICLAB-2026-Fall/issues).
