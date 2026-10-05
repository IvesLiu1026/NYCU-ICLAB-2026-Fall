# Annotated reading copies

These reading copies add detailed English commentary to the measured sources.
The executable Verilog is copied from the two measured release files. The comments
explain input assumptions, signal meanings, recurrence, arithmetic, tie choices
and reconstruction of the final instruction order.

| Reading copy | Measured implementation |
|---|---|
| [Annotated unrolled RTL](unrolled/OISS.v) | [Unrolled RTL](../unrolled/OISS.v) |
| [Annotated parameterized RTL](parameterized/OISS.v) | [Parameterized RTL](../parameterized/OISS.v) |

The reading copies add comments to the same executable RTL. Compile one `OISS`
source at a time.

Start with the interface and assumptions, then follow hazards, grouping and ranks,
compaction, intrinsic prefixes, the two scheduling engines and output reconstruction.
The [architecture](../../docs/ARCHITECTURE.md) explains how the blocks fit together;
the [mathematical reduction](../../docs/MATHEMATICAL_REDUCTION.md) explains the score.
