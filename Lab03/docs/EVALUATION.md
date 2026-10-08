# Evaluation and source identity

The objective is `area × total latency × clock period`. It uses the sum of
shot latencies, including their output bursts. Input loading and legal idle
gaps are not interchangeable with processing latency. Use one checker counting
convention throughout a comparison; a different sampling edge can add a cycle
per shot and materially change the total.

The [performance record](../results/benchmark.json) stores the
aggregate point and the fixed comparison snapshot. The
[source record](../rtl/source.json) stores the selected implementation's byte
identity and language. These are separate records; no source-specific
qualification claim is added to the aggregate performance record.

## Reproducing an implementation point

1. Freeze the exact RTL bytes and the test inputs. Confirm the interface and
   permitted clock before running tools.
2. Run RTL simulation with the supplied checker. Require complete output
   values, order, idle zeros, reset behavior and all expected test completions.
3. Run synthesis at the chosen period with the required input/output delays
   and load. Check setup, hold and latch inference, including output paths.
4. Run the matching synthesized design with its SDF delays and the same
   checker. Require functional completion and inspect actual timing violations.
5. Keep the exact source, clock, checker convention and raw reports together.
   A synthesis target or zero-delay mapped simulation alone does not establish
   a passing clock.

The clock must be strictly below 15 ns. The interface uses half-period input
and output delays and an output load of 0.05. The cell-area limit is 1,200,000,
and the shot-to-output-end limit is 1,000 cycles. Detailed evaluation assets
are retained privately; only selected RTL and sanitized presentation artifacts
are distributed here.

## Reading-copy identity

The [annotated copy](../rtl/annotated/ZUMA.v) adds full-line comments only.
Removing those added comments restores the exact executable source, including
its existing comments and whitespace. The two files have identical non-comment
text. The source SHA-256 is recorded in [source.json](../rtl/source.json).

The film and figures are conceptual illustrations. Their synthetic cascade is
checked as a cyclic sequence but is not a gate waveform or a measured clock trace.
