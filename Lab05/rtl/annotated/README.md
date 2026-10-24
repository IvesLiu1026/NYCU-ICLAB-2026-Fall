# Annotated RTL

[JPEGLENC.v](JPEGLENC.v) is a reading copy of the
[selected implementation](../JPEGLENC.v). The added `// [reading]` lines
explain the memory schedule, arithmetic, coefficient lifetimes and output
flush. Removing those lines restores the selected source byte for byte.

Compile one copy at a time. Both define the same six modules and depend
on the external memory macro described in [evaluation](../../docs/EVALUATION.md).
