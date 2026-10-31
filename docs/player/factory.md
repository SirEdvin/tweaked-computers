# Combined factory controller

This controller combines the original device family: it configures a real inserter, samples stock
signals, stores expiring shared telemetry and draws a touchable merged screen.
Use the complete [factory-controller program](examples.md#factory-controller).
The optional second [shared-telemetry program](examples.md#shared-telemetry)
demonstrates shared versus independent physical storage.

The optional [Recipe Searcher](api/recipe-searcher.md) has its own late-game gate:
Circuit Computers and utility science as direct prerequisites, 200 red/green/utility
pack sets at 60 seconds each. Craft it from 10 steel plates, 5 advanced circuits
and 2 processing units in 2 seconds. No electricity is needed; connect its body to the red
Network, then run the separate [query example](examples.md#recipe-searcher-program).
It requires no physical product input and does not craft or configure machines.

## Build and wire

Research [Native circuit computers](getting-started.md). Place a computer, KV,
logic handler, configurator and a north-facing 2×2 rectangle of four monitor tiles.
The custom devices need no electricity. Put a powered inserter between a supply chest with
iron plates and an empty destination. Use a separate stock-reading chest, enable
its native **Read contents**, and put five normal-quality iron plates in it.

Connect each visible Network body and the named Input/Output/Factory targets sockets:

    COMPUTER NETWORK --red-- KV NETWORK --red-- MONITOR member NETWORK
                                 |
                                 +--red-- LOGIC middle NETWORK
                                 |
                                 +--red-- CONFIGURATOR NETWORK

    stock-reading chest --red-- LOGIC INPUT
    LOGIC OUTPUT --green-- inserter
    CONFIGURATOR TARGETS --green-- same inserter circuit

North-facing logic roles are INPUT / NETWORK / OUTPUT; configurator roles are
NETWORK / TARGETS. No internal role bridges exist. Vanilla poles may relay the
TARGETS circuit, not discovery. Red-to-green is never a discovery path. A merged
monitor shares content but does not connect its unwired members' networks.

Keep exactly one reachable peripheral of each type for this example. `find`
returns matches in name order; assigning one variable selects the first. Larger
factories should deliberately select names and `wrap(name, wire)`.

## Paste, Save, Run

Open the computer; copy the whole [program](examples.md#factory-controller),
Validate, Save, Run. There are no files/import commands. The first handler configures
green TARGETS inserters to A>0. A one-tick named timer finishes subscriptions and
display setup in a separate callback, so Space Age capability inspection and setup
fit the existing callback ceiling. Do not merge these handlers into one huge loop.

A stock subscription and 60-tick timer request refresh. Each refresh reads current
INPUT red, not a stale queued event. When `enabled` is true and stock is below
100, the handler emits A=1 on both OUTPUT colors; otherwise its contribution is
empty. Observe native propagation and in-flight items before diagnosing movement.

The `stock:iron` hash stores string fields `count`, `status` and `sample_tick`.
Refresh renews a three-simulation-second deadline on the whole hash. The display
shows iron count, FILLING/STOPPED and “Touch to toggle”. With an empty cursor and
no other GUI open, **Ctrl+left-click** a character cell (rebindable in Controls).
The event toggles retained `enabled` state and requests refresh. Borders are not
cells. Text is byte-indexed; it is not a Unicode terminal.

## Second computer: shared and private data

Place a second computer and second physical KV. Connect second computer NETWORK
red to the **first** database NETWORK. Connect its NETWORK green **only** to the
second database NETWORK: do not accidentally make a complete green path to the
first database. Save/Run [shared-telemetry](examples.md#shared-telemetry).

The observer writes `observer` in the shared red database and `private` in the
independent green database, then reads shared telemetry every 60 ticks. Its
state/log shows the controller's count/status. The private database has no
`stock:iron` hash. A physical database has one contents table regardless of color;
this is shared storage, not direct messaging or per-color storage.

Stop the controller. Its still-owned output clears; its last image and applied
inserter settings remain. Telemetry expires at the retained deadline and the
observer reports expired. A newer successful writer owns the bank; stopping the
older writer does not erase that new bank.

## Change and recover

Change `count < 100` to `count < 3`, Save but do not Apply. At stock=5 the old run
still fills. Apply creates a new run, retains `enabled` state, cancels old work
and stops at stock=5. Invalid candidate validation never retires the old run.
Close/Escape retains unsaved text; conflicts require reviewed Rebase or Reload.
Stop before confirming Reset State.

Ordinary cold load retains source/state/deadlines/subscriptions and the display
without replaying `start`. Computer items are plain hardware: ordinary mining and
replacement loses that computer's source/state. Qualifying native undo restores
saved source/label/state into a new stopped identity, not its execution. KV items
still retain contents and absolute deadlines. Blueprints/clipboard copies/clones
carry saved computer source/label but no application state, database contents or
runtime output. Player changes to native inserter settings remain until
another explicit configuration write; read/reconnect does not enforce old settings.

## Troubleshooting

- Missing required peripheral: open Peripherals, inspect NETWORK color, exact
  ports, force/surface and physical validity. This example faults on missing services; it is
  not an automatic reconnect manager. Repair and Run explicitly.
- Target absent: inspect TARGETS green and actual isolated native connectors.
  Discovery visibility is not target authority.
- No transfer: check supply/destination, direction/power, stock chest read mode
  and actual inserter condition; allow circuit/in-flight settling.
- Blank monitor: check physical validity of **all** members, matching orientation and a complete
  rectangle. Native touch/input/readability remain user alpha testing.
- `E_BUDGET`: split extra work across named callbacks; do not raise caps or retry
  in a busy loop. Pending/busy failures need a later event/tick.

The [API reference](api/common.md) explains individual operation errors and
[lifecycle](lifecycle.md) explains the boundaries of fail-safe cleanup.
