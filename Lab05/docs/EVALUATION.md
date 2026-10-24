# Selected-source evaluation

The selected 2.3 ns implementation completed RTL simulation, synthesis
timing checks and a matching SDF-annotated gate simulation on the supplied
100-image corpus. Both simulations produced the same per-image byte
counts and counted latencies: 370,662 cycles and 365,418 output bytes
in total. The input corpus contains 1,638,400 pixels.

The synthesis reports mark the checked setup and hold paths as met.
The gate simulation uses maximum delays with timing checks enabled and
the matching memory model. Its SDF annotation completed, all 100 images
passed, and the reviewed log contains no detected timing violations
or memory-access errors. This is finite test qualification for the
selected source, memory and period; it is not a proof over every image
or a post-layout signoff result.

## Source and dependencies

[Source metadata](../rtl/source.json) records the published RTL SHA-256.
The executable source matches the qualified implementation; only
comments and whitespace were removed for the release copy. The
[annotated version](../rtl/annotated/README.md) adds full-line reading
notes without changing that source.

The file defines `JPEGLENC`, `JPEGLENC_ROW`, `JPEGLENC_COL`,
`JPEGLENC_ENT`, `JPEGLENC_QBUF` and `JPEGLENC_SRAM`.
The wrapper requires an external single-port 1,360 × 64 macro named
`SU_1360X64_b8_m1`, including compatible pin and timing behavior.
The external model, timing libraries, mapped netlist, course checker
and supplied test vectors are not redistributed.

For an independent evaluation, provide that memory dependency and
compile one RTL copy. Apply the [input protocol](PROTOCOL.md), compare
every entropy byte against an independent exact integer reference,
and record the input corpus, source identity, period, total counted
latency and cell area. A new synthesis result needs its own gate check
with the corresponding netlist and SDF before it inherits a timing
qualification claim.

## Performance interpretation

The objective is cell area squared times clock period times the sum
of counted image latencies. Cell area includes the memory macro and
uses the synthesis report's units. The 2.3 ns point has a product of
5.927171168311149 × 10¹⁷. Compare like corpus sizes and the same latency
definition; input reception is excluded from the counted latency.

The [comparison method](../results/README.md) records the public
snapshot date, entry count and insertion-rank interpretation.
