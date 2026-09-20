# Annotated reading copies

The detailed English commentary in these source files was written by **AI**.
The executable Verilog is copied from the two measured release files. The comments
explain input assumptions, signal meanings, recurrence, arithmetic, tie choices
and reconstruction of the final instruction order.

| Reading copy | Measured implementation |
|---|---|
| [Annotated unrolled RTL](unrolled/OISS.v) | [Unrolled RTL](../unrolled/OISS.v) |
| [Annotated parameterized RTL](parameterized/OISS.v) | [Parameterized RTL](../parameterized/OISS.v) |

These are two additional views of the same two implementations. Removing full-line
comments restores each measured source byte for byte. No separate physical
measurement is claimed for the reading copies. Compile one `OISS` source at a time.

Start with the interface and assumptions, then follow hazards, grouping and ranks,
compaction, intrinsic prefixes, the two scheduling engines and output reconstruction.
The [architecture](../../docs/ARCHITECTURE.md) explains how the blocks fit together;
the [mathematical reduction](../../docs/MATHEMATICAL_REDUCTION.md) explains the score.
