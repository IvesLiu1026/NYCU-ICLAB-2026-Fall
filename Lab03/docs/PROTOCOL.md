# Interface and cycle contract

`ZUMA.v` is a positive-edge sequential Verilog-2005 module with an asynchronous
active-low reset. Colors are unsigned three-bit IDs, covering all eight values.

| Port | Direction / width | Meaning |
| --- | --- | --- |
| `clk`, `rst_n` | Input / 1 each | Clock and asynchronous active-low reset |
| `in_valid` | Input / 1 | Consecutive initial-ring loading beats |
| `ring_len` | Input / 8 | Initial count, 4–128; meaningful on the first beat |
| `in_color` | Input / 3 | One initial bead per loading beat |
| `shot_valid` | Input / 1 | One-cycle shot request |
| `shot_color` | Input / 3 | Inserted bead color |
| `shot_pos` | Input / 8 | Insert after this logical position; zero when empty |
| `out_valid` | Output / 1 | Valid result beat |
| `chain_num` | Output / 7 | Total elimination levels, constant during the burst |
| `elim_color` | Output / 3 | Color eliminated at this level |
| `elim_cnt` | Output / 9 | Beads eliminated at this level |

## Loading and reset

Reset makes all outputs zero, including while the clock is stopped. Each
loading phase has exactly the initial-ring count in consecutive valid beats.
The first loaded bead is logical zero. A new loading phase starts a new game
and discards all old state; it does not require a reset between games.

The initial ring is cyclically stable. The live ring, including a new shot,
never exceeds 256 beads. The internal nine-bit live count distinguishes a full
256-bead ring from an empty ring despite eight-bit position ports.

## Requests and output

Inputs change on negative edges. A shot is a one-cycle request and does not
overlap initial loading or output. Legal requests can begin one to four negative
edges after loading or the previous output ends. Cleanup may still be active;
the implementation has a pending-shot path for that case.

Each elimination level emits one consecutive valid beat in elimination order.
A shot with no elimination emits one beat with zero chain count and zero
elimination data. Every data output is zero whenever `out_valid` is low. The
chain count is the complete number of levels on every valid beat, including
the first. Shot-to-output-end latency is at most 1,000 cycles.

## State roles

| State | Main work |
| --- | --- |
| `S_IDLE` | Wait for loading or a shot |
| `S_LOAD` | Load the new game through staged input signals |
| `S_L1` | Read the first windows and capture first-level tests |
| `S_DEC` | Decide the first level and handle safe short results |
| `S_ZIP` | Count further levels; emit the first beat when counting stops |
| `S_OUTP` | Emit the saved second result and replay later levels |
| `S_CMP` | Compact and repair survivors; capture an early legal next shot |
| `S_INS` | Complete a shot that caused no elimination |

Loading has priority over the ordinary state transitions. Several registered
state predicates drive short output/write paths. The last output beat can
begin compaction, so output completion and cleanup completion are distinct
events internally.
