# Editable factory controller

This controller combines the original device types using native named callbacks. It requires
Factorio 2.0.77, base alone or Space Age. Back up your save before installing the
alpha candidate. Client typing, focus, zoom and multiplayer checks are still yours;
headless tests use explicit player/GUI doubles, not a real graphical player.

## Build and wire

Research **Native circuit computers** after circuit-network and advanced-circuit.
Power a computer, KV database, logic handler, configurator and a north-facing 2×2
rectangle of four monitor tiles. All tiles need electricity. Place an ordinary
inserter between a supply chest containing iron plates and an empty destination.
Use a separate stock-reading chest to control the threshold. Enable **Read
contents** in that stock chest's native circuit GUI. Put five iron plates in it.

Use actual small role ports, not the large body selection rectangle:

    COMPUTER NETWORK --red-- KV NETWORK --red-- MONITOR member NETWORK
                                 |
                                 +--red-- LOGIC middle NETWORK
                                 |
                                 +--red-- CONFIGURATOR NETWORK

    stock-reading chest --red-- LOGIC INPUT
    LOGIC OUTPUT --green-- inserter
    CONFIGURATOR TARGETS --green-- the same inserter circuit

Logic north-facing roles are INPUT / NETWORK / OUTPUT left-to-right. Configurator
roles are NETWORK / TARGETS. Rotate the whole body, not its protected helpers.
There is no internal connection between these roles. Vanilla poles can relay the
separate TARGETS network, but never computer discovery. A red-to-green chain is
not a discovery path. NETWORK carries no mod-generated signal protocol.

Keep exactly one reachable device of each peripheral type for the controller;
`find` returns all matches in sorted-name order, and assignment selects the first.
For a larger factory, inspect names and bind deliberately with `wrap(name, wire)`.
The shared monitor does not create an unwired bridge between its members.

## Enter the source

The optional Recipe Searcher is a separate late-game research, with exactly
Circuit Computers and utility science as direct prerequisites: 200 red/green/utility
pack sets at 60 seconds each. Craft it from 10 steel plates, 5 advanced circuits
and 2 processing units in 2 seconds, supply 30 kW and wire its body to the red
Network. It needs no product inventory or fluid input. Run the separate
[recipe-searcher-program.lua](../examples/recipe-searcher-program.lua) document
to inspect item/fluid recipes without replacing any machine configuration.

Open the computer with Ctrl + left-click after clearing the cursor.
Copy the document between the outer long
brackets in [factory-controller.lua](../examples/factory-controller.lua), not the
host wrapper `return [[...]]`, into the source text box. Validate, **Save**, then
**Run**. This saved program is one document: there are no filenames or imports.
The separate live Console can experiment without replacing this controller.
The source is also shipped in the installed ZIP; it does not execute through
`require` inside the guest.

The initial handler inspects/configures connected inserters to `signal-A > 0`.
A named one-tick timer admits the subscription/display setup in a second callback.
This keeps full Space Age capability inspection and subscription work inside the
unchanged per-callback ceiling. It is ordinary native event scheduling, not a
suspended stack or interpreter. The program intentionally configures one small
factory, not an unlimited target graph in one callback.

A filtered stock subscription and a 60-tick timer request refresh. Refresh reads
the current native input, not a stale queued sample. Below 100 plates, while
explicit `enabled` state is true, the logic bank emits signal-A = 1 on both OUTPUT
colors. The inserter transfers items. At 100 or above, the bank is empty and the
inserter stops after native propagation and any in-flight item settles.

Telemetry is a string-valued hash `stock:iron` containing `count`, `status` and
`sample_tick`. Each refresh renews its three-simulation-second whole-key deadline.
The merged display shows iron count, FILLING/STOPPED and “Touch to toggle”. With
an empty cursor and no other GUI open, Ctrl+left-click a character cell (rebindable
in Controls). The monitor event toggles the computer's copied persistent state;
the next refresh changes output. Borders are not cells. UTF-8 is byte-indexed,
not a Unicode terminal, and drawing never interprets rich text.

## Shared versus independent databases

Power a second computer and a second physical database. Connect the second
computer's NETWORK red to the first database NETWORK. Connect its NETWORK green
only to the second database NETWORK; do not also create a complete green path to
the first database. Paste, Save and Run
[shared-telemetry.lua](../examples/shared-telemetry.lua).

The observer writes its ID into `observer` in the shared red database, writes
`private` into the independent green database and reads the controller's shared
hash every 60 ticks. Its own state/log shows the shared count/status while the
independent database has no `stock:iron` telemetry. Both databases can be on other
same-color networks too, but one physical database always has one contents table,
not separate color copies. No direct computer-message service is involved.

Stop the controller: its still-owned output clears immediately, its recent
monitor image and already-applied target settings remain, and shared telemetry
expires after its retained absolute deadline. The observer then reports expired;
its independent marker remains private. Another successful writer can overwrite
a shared value; stopping an older writer cannot clear a newer writer's bank.

## Save, Apply and recovery exercise

Change `count < 100` to `count < 3` in the editor. Save without Apply: the old active
revision still fills at stock=5. Apply/Run the saved revision: a new run retains
`enabled` state, cancels old timers/subscriptions and now stops at stock=5. An
invalid candidate never retires the old run. Close/Escape retains an unsaved draft.
For conflicts, use Maintenance → Review current saved source and explicitly Rebase or Reload; never silently
replace another player's newer source. Stop before confirming Reset State.

A cold save/load retains active/saved source, enabled state, timer/subscription
IDs, database deadlines and the monitor model without replaying startup. Applied
inserter settings remain native settings: a player's later changes are not
periodically enforced by readback or reconnection. Mining stores committed
computer source/state and database contents/deadlines in tagged items; replacement
has a new stopped identity. Blueprints/clones include source/settings, not runtime
state, database content or active output. The editor can review formerly active
source separately from the saved source and unsaved player draft.

## Troubleshooting

- Missing peripheral: open Peripherals; inspect automatic red and green observations separately.
  Check actual NETWORK ports, force/surface, power and physical same-color paths.
- Target absent: check TARGETS color, actual isolated native connector and relay
  wires. Being visible in computer discovery does not authorize factory targets.
- No movement: check supply/destination, inserter direction/power, read-contents
  stock chest and native condition readback. Wait for circuit/in-flight settling.
- E_BUSY/pending: retry on a later named timer; do not spin. E_BUDGET faults the
  run and clears its bank. Divide extra factory work into bounded named callbacks.
- Unpowered monitor: every member must be powered. Buffer contents remain stored.
- Wire loss: output is fail-safe; this example faults on missing required services,
  not an automatic reconnect manager. Fix wiring, review diagnostics, then Run.

Full APIs: [computer](computer-runtime.md), [editor](program-editor.md),
[discovery](peripheral-network.md), [logic](logic-handler.md),
[KV](kv-database.md), [monitor](monitor.md), [configurator](configurator.md),
[lifecycle](device-lifecycle.md). Limits and verification boundaries:
[alpha candidate](alpha-candidate.md).
