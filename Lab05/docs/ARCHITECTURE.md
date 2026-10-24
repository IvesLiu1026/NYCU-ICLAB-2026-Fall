# A single memory, several schedules

The encoder has to retain pixels until their transform reads and retain
compressed bytes until output is permitted. A full image buffer would
waste area. This design keeps eight rows of pixels and lets the transform
follow the incoming raster stream. The rest of the same memory stores
completed compressed words.

![Architecture](figures/architecture.png)

[SVG](figures/architecture.svg) · [PDF](figures/architecture.pdf) ·
[Editable diagram](figures/architecture.drawio)

## Storage and access slots

The single-port memory has 1,360 words of 64 bits: 128 words for pixels
and 1,232 words for the bitstream ring. Eight pixels fit in each word.
The line buffer therefore stores 1,024 pixels, while the ring stores
9,856 bytes. The top module also has a two-word write FIFO and one output
word register.

A seven-bit segment index is rotated by `(4 × block_row) mod 7` before
addressing the line buffer. Input writes and transform reads use the same
mapping. This permits in-place replacement of old raster rows without
moving an entire row between banks.

Logic runs on the main clock. The memory clock toggles on falling edges,
giving it a period of two main cycles. An access slot starts on an even
image cycle. Pixel writes reserve one slot in eight cycles; active DCT
reads reserve one slot in four. The remaining slots first satisfy an
output read and then a pending entropy-word write. The first compressed
word can be prefetched during input, but no output byte is issued then.

![Memory access phase](figures/memory-phase.png)

Slot classification and addresses are registered ahead of the access.
Read tags travel with the memory request until capture. The macro's
timing behavior is part of this schedule; replacing it with an arbitrary
combinational array does not preserve the timing contract.

## Transform pipelines

Each block uses two passes over its eight row words. A captured word
feeds four horizontal frequencies, one per cycle. The row pipeline has
five arithmetic stages. Constant-coefficient products use shifts,
complements, additions and carry-save reduction.

The column pipeline interleaves four horizontal frequencies. It visits
rows in the order `0, 1, 6, 3, 4, 2, 5, 7`, matching its factored products
and migrating partial sums. Block parity and coefficient tags accompany
the data. Accumulation preserves the exact integer transform; the
quantizers implement the two signed rounding steps described in
[the arithmetic page](ALGORITHM.md).

The first DCT read starts at image cycle 878. An ordinary block advances
the read schedule by 64 cycles. When stored-word occupancy reaches the
configured threshold, an eligible block boundary can insert a single
112-cycle pause per image. The pause delays consumption of the line
buffer as well as entropy production. Its length is tied to safe pixel
overwrite timing.

Constant blocks in the final block row have a separate shortcut. After
the first pass proves all pixels equal, their AC coefficients are known
to be zero, so the second pass can be skipped. The entropy coder still
emits the correct DC field and end-of-block symbol. The following block
begins after 36 cycles in this case.

## Coefficient lifetimes replace a full buffer

The entropy scan needs coefficients in zigzag order, while quantization
produces columns. Keeping two complete coefficient blocks would reserve
registers for values that are already dead or have not arrived yet.

`JPEGLENC_QBUF` splits low and high bit planes. Forty-seven four-bit
slots store low bits, and 31 variable-width slots store the necessary
high bits, for 260 stored bits. Coefficients share a slot when their
live intervals do not overlap. Block parity selects the appropriate
write or read interpretation. This allocation belongs to the selected
fixed schedule; it is not a general-purpose coefficient RAM.

## Entropy words and output bytes

The entropy pipeline forms DC differences and AC run/size fields, reads
the fixed codebook, then packs code and amplitude bits. From position
16 onward, a zero coefficient with no later nonzero coefficient can
end the block early. This preserves the byte stream while avoiding
unneeded scan work.

The packer works with an open 32-bit segment and overflow bits. Two
segments form a 64-bit memory word. The two-entry FIFO absorbs a word
until a free write slot becomes available. Read and write pointers wrap
only within words 128 through 1,359.

After input finishes, the output register emits the most significant
byte first. A read is scheduled before the register empties, subject to
the shared-port arbitration. The final partial byte is padded with ones;
the final-word byte count prevents padding words from becoming output.
Image completion waits until the transform, flush, FIFO, ring and read
pipeline have all drained.

These fixed buffers are data-dependent. The passing finite corpus
establishes the measured result; it does not prove capacity for every
possible 128 × 128 image.
