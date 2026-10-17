# Binary32 at the ports, bounded fixed point inside

The external words use IEEE binary32 encoding. The datapath uses integer
products, shifts and interpolated tables, then converts the final value
back to binary32. A binary32 interface therefore does not imply a chain
of individually rounded binary32 arithmetic operations.

| Quantity | Selected representation |
| --- | --- |
| Scaled query | Signed 27 bits; 26 fractional bits, includes `log2(e)/sqrt(2)` |
| Key | 24-bit magnitude, sign and three-bit scale tag |
| Value | Signed 23 bits; 22 fractional bits |
| Output weight | Signed 24 bits; 23 fractional bits |
| Base-two score | Signed 34 bits; 24 fractional bits |
| Exponential mantissa | 20 bits; 19 fractional bits |
| State | `m`: signed 10; `l`: unsigned 32; `z0,z1`: signed 32 |
| State sums | 27 fractional bits before the stored low-bit masks |
| Reciprocal mantissa | 25 bits; 24 fractional bits |
| Head cache | Signed 25 bits; 24 fractional bits |
| Formatter input | Signed 29 bits; 27 fractional bits |

The range-specific input converters target K magnitudes from 0.5 to 255
and Q/V/weight magnitudes up to 0.5. The exact endpoint, subnormal and
rounding behavior is defined by the published slices and shifts; these
converters should not be substituted for a general floating-point library.

## Where approximation enters

The query scale constant is implemented as a shift/add integer expression.
Radix-four Booth multipliers discard selected low partial-product columns
and add fixed corrections. Their result is not generally equal to rounding
an exact full product once at the end.

The exponential uses 128 centered chord segments and an 11-bit
interpolation field. The reciprocal uses 256 index entries and a 15-bit
interpolation field after normalization. The log and sigmoid have their
own tables and interpolation paths. The sigmoid correction is split into
separate terms to fit the first-row dependency chain.

After each context update, `l` clears four low bits and each `z` clears
one. Large negative scale differences discard a contribution. Signed
shifts preserve the sign of negative weighted sums, so the exact sequence
of shifts, slices and additions is part of the arithmetic contract.

The formatter forms a one's-complement magnitude for negative results,
uses round-toward-zero conversion, then adjusts the exponent for the
fixed-point scale. That magnitude differs by one fixed-point unit from
an exact absolute value. The positive-zero output is explicit.

## Accuracy scope

The selected source completed a 1,000-frame functional gate check with
64 output words per frame and an absolute-error criterion of `1e-6`.
That is finite validation. It does not prove the error bound for every
legal binary32 input, nor does it establish exact IEEE arithmetic.

For reuse, exercise cancellation, close scores, tiny outputs, extreme
key magnitudes, signs, subnormals and rounding boundaries independently.
Preserve intermediate scaling and signedness when changing widths.
See [evaluation](EVALUATION.md) for the reported validation status.
