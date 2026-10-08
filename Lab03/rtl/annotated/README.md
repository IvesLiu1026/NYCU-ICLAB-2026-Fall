# Reading the ZUMA circuit

[ZUMA.v](ZUMA.v) is a reading copy of the [selected RTL](../ZUMA.v).
It adds full-line explanations at the storage, fetch, comparison, output,
frontier, write-selector and state-control blocks. It changes no executable
line, existing comment or source whitespace.

Removing only lines beginning `// [Reading note] ` restores the selected
source byte-for-byte. The original identity is in [source.json](../source.json).
Start with the [architecture](../../docs/ARCHITECTURE.md), then follow the
reading notes from top to bottom.
