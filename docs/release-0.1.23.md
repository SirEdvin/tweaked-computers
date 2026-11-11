# 0.1.23 ALPHA — lower callback host work

This patch decreases the host work of program callbacks and Console commands.
It changes no API, limit, setting or save format.

## What changed

- A later callback of a run does not validate its source again. The run keeps
  the validation result with its loaded program. Before, each callback did a
  lookup in a shared cache of 8 entries. When more than 8 different programs
  ran, each callback validated its complete source.
- The shared source cache holds 64 entries, which is the active-computer limit.
  It serves activation, first callbacks and Console commands.
- These `computer` methods keep the authority proofs of the callback or Console
  command: `getID`, `getLabel`, `setLabel`, `getTick`, `getLimits`, `getState`,
  `setState`, `deleteState`, `log`, `on`, `off`, `after`, `every` and
  `cancelTimer`. Before, each of these calls discarded the proofs, and the next
  peripheral call searched the wire network again.
- Each call still checks that its program run or Console session is active.
  `computer.stop` and other operations still discard the proofs. A new callback
  or command starts without proofs.

Results, errors, work charges and limits do not change.

## Measurements

All values come from headless runs on Factorio 2.1.23.

| Measurement | 0.1.22 | 0.1.23 |
| --- | ---: | ---: |
| Callback with 8 different running programs (hot loop) | 175 µs | 166 µs |
| Callback with 9 different running programs (hot loop) | 10.3 ms | 177 µs |
| Callback with 16 different running programs (hot loop) | 10.8 ms | 175 µs |
| One `computer.getTick()` call (hot loop) | 12.8 µs | 3.1 µs to 3.2 µs |
| Six-line monitor program, terminal, update tick median | 1.95 ms to 1.98 ms | 1.71 ms to 1.75 ms |
| Six-line monitor program, graphics, update tick median | 1.58 ms | 1.14 ms to 1.31 ms |

The hot loop calls the scheduler without real game ticks. The programs have
1.6 KB of source. The six-line monitor program calls `computer.getTick()`
between `peripheral.wrap` and its monitor calls. A chest report program without
`computer` calls did not change.

## Install and upgrade

Use `tweaked-computers_0.1.23.zip`, not GitHub's automatic source archive. Keep the
ZIP unextracted. Move conflicting older archives or extracted copies aside.
Factorio **2.1** is necessary. Base alone and optional Space Age are supported.
The tested engine is **2.1.23**, not each accepted 2.1 patch or mod combination.

Saves from 0.1.22 need no migration. For a save from 0.1.20 or older, read
[runtime upgrade and rollback](player/lifecycle.md#upgrading-to-trusted-native-lua)
first.

Back up the complete save and the matching mod set before you upgrade. To roll
back, restore both. Do not downgrade an upgraded save in place.

## Verification and limits

All engine checks used **2.1.23**, in base and Space Age. The final ZIP passed the
Python tooling tests, the packaged 52-fixture smoke matrix with its cold and
production-context phases, the monitor animations, the combined envelope
campaign, and an upgrade of a populated factory save from the published 0.1.22 ZIP.

Performance values come from headless runs. They do not include GPU time or
connected multiplayer. This remains **ALPHA**. Back up your saves.
