# What the measured candidate establishes

The selected implementation has a 12.5 ns synthesis point with reported
cell area `2161800.783689`. Its setup and hold report checks pass. The
matching gate netlist completed 1,000 functional frames, each with 64
outputs and one counted wait cycle. No runtime timing-violation message
was observed in that run.

Strict SDF qualification remains open: annotation did not preserve all
delay values, and complete annotation coverage has not been established.
Consequently, this release reports a functional candidate, not an
accepted timing result. The absence of a runtime violation alone cannot
close that gap. No official ranking is assigned here.

## Keep implementation identity attached

[source.json](../rtl/source.json) records both the measured source hash
and the public source hash. Publication removes comments and trailing whitespace. All
executable Verilog tokens are preserved. Removing the marked full-line
reading notes from the annotated copy restores the public source exactly.

The source instantiates an external `DW_fp_i2flt` converter for unsigned
29-bit integer-to-binary32 conversion, with round-toward-zero selected.
The dependency implementation is not included. A simulator or synthesis
environment must provide its compatible implementation. The module name
in the source identifies an interface dependency, not a bundled library.

## Count the same interval

The counted latency is the wait after `in_valid` falls until the first
valid output, using the checker sampling convention. It excludes the 64
input beats and 64 output beats. With 1,000 checked frames and one wait
cycle per frame, the total counted latency is 1,000 cycles.

Use the same source, clock, input transaction count and latency convention
when comparing products. A pipeline stage count is not this latency.
Neither total output-stream length nor end-to-end transaction duration
should be silently substituted for it.

## Re-evaluation checklist

1. Check reset, idle zero, ignored invalid inputs, weight capture length,
   output order and all 64 output-valid beats over repeated transactions.
2. Decode the output words and compare against a mathematical reference
   with the intended absolute error threshold; test numerical boundaries.
3. Map the same source at the chosen period and inspect setup, hold,
   latches, the retained converter and input/output constraints.
4. Run the matching mapped netlist with SDF. Resolve annotation fidelity
   and coverage before accepting a clock, then check functional outputs
   and timing checks to completion.

The present 1,000-frame run contains 998 distinct input frames. Finite
success does not establish full-domain numerical correctness, a universal
minimum area or a globally optimal architecture.
