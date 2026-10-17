# Reading the FlashAttention circuit

[F_ATTN.v](F_ATTN.v) adds full-line reading notes to the
[selected RTL](../F_ATTN.v). The notes cover the rotating stores, registered
issue tables, five engines, shared context states, normalization, first-row
tail, projection and floating-point formatting.

Removing only lines beginning `// [Reading note] ` restores the selected
public source byte-for-byte. Its identity and the measured implementation's
identity are recorded in [source.json](../source.json). Publication removes
original comments and trailing whitespace; the executable Verilog tokens are unchanged.

Start with the [architecture](../../docs/ARCHITECTURE.md), then follow the
notes from the top-level module into the arithmetic units.
