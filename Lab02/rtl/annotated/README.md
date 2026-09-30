# Annotated reading copy

[LDPC.v](LDPC.v) adds full-line English comments to the selected measured
[implementation](../LDPC.v). Removing those added comment lines restores the
measured source byte for byte, including its exact SHA256:

`e889c97978f6f83c89862dd0e5b2bc0e1aaf00573401ff58d07e6837b086fc91`

The comments explain the two-bank scheduling invariant, exact rounding,
minimum ties, compressed records, fixed slot permutations and output timing.
They do not change executable Verilog. Compile only one copy of module `LDPC`
at a time.

Start with [Architecture](../../docs/ARCHITECTURE.md) and
[Numerical model](../../docs/NUMERICAL_MODEL.md) for the complete explanation.
