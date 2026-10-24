# From pixels to entropy bytes

The output is a raw entropy stream for 256 ordered 8 × 8 blocks of a
128 × 128 grayscale image. It contains no JPEG file headers or markers.
The image dimensions, integer transform, quantization shifts, zigzag
order and luminance codebook are fixed.

## Exact integer arithmetic

Subtract 128 from each unsigned pixel. With the fixed integer cosine
matrix `C`, the transform is

```text
R(u,y) = sum_x (pixel(x,y) - 128) × C(u,x)
A(u,v) = sum_y R(u,y) × C(v,y)
D(u,v) = round_s(A(u,v), 18)
Q(u,v) = round_s(D(u,v), S(u,v))
```

The signed rounding function rounds halfway magnitudes away from zero:

```text
round_s(a,n) = sign(a) × ((abs(a) + 2^(n-1)) >> n)
```

There is no rounding between the row and column accumulations.
Normalization and quantization are separate roundings even though both
divide by powers of two. For the synthetic arithmetic example
`A = -917504`, `S = 3`, normalization gives `D = -4`, then quantization
gives `Q = -1`. Dividing once by `2^21` with rounding would give zero.

The RTL implements the same decision with high bits and sign-sensitive
correction terms. This avoids placing a generic absolute-value,
wide-adder and variable-shift chain on the quantizer path.

[Machine-readable arithmetic example](example.json)

## Zigzag and run-length symbols

The quantized coefficients are read in the fixed zigzag order. The DC
symbol encodes the difference from the preceding block's DC value, with
the predictor initialized for each image. AC symbols count intervening
zeros and encode the nonzero coefficient's magnitude category.
Long runs use the zero-run symbol; a remaining all-zero suffix uses
end-of-block.

A nonzero value contributes an amplitude field after its Huffman code.
Positive values use their ordinary magnitude bits. Negative values use
the complemented magnitude representation for their category.
The codebook is expanded into fixed combinational constants in the
selected RTL.

The coder tracks whether any nonzero coefficient remains after the
current position. Its early end-of-block condition starts at position
16. A constant-block shortcut supplies DC and end-of-block directly
when the top-level schedule has proved the AC values zero.

## Packing and termination

Code and amplitude bits are appended most significant bit first. The
internal open segment is kept in complemented form, so bit placement
and merging can use a compact shift-and-OR network. Completed segments
are complemented back when placed in an output word.

The final partial byte receives one-bit padding. The packer records
how many bytes of the last 64-bit word are meaningful. The output
engine transmits exactly those bytes and keeps `out_data` zero whenever
`out_valid` is low.
